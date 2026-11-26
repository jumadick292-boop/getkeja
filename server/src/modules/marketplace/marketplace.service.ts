// Service marketplace service (Task 13.5).
// Customer request lifecycle + provider quotation engine with atomic,
// row-locked quotation acceptance. Business change, history and outbox events
// share one transaction. Catalogue prices are indicative only; the accepted
// quotation is the binding commercial artefact.
import type { PoolClient } from 'pg';
import { transaction } from '../../db/tx.js';
import { pool } from '../../db/pool.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type {
  AcceptQuotationInput,
  CreateServiceRequestInput,
  ServiceRequestListQuery,
  SubmitQuotationInput,
} from './marketplace.schemas.js';
import type {
  ServiceDomain,
  ServiceQuotationStatus,
  ServiceRequest,
  ServiceRequestStatus,
} from './marketplace.types.js';
import { assertQuotable, assertTransition } from './marketplace.lifecycle.js';
import * as repo from './marketplace.repository.js';

function money(value: number): string {
  return value.toFixed(2);
}

// ---------------------------------------------------------------------------
// Catalogue (customer browse)
// ---------------------------------------------------------------------------
export async function browseCategories(domain?: ServiceDomain) {
  const categories = await repo.listCategories(domain);
  return { categories };
}

// ---------------------------------------------------------------------------
// Customer request lifecycle
// ---------------------------------------------------------------------------
export async function createRequest(userId: string, input: CreateServiceRequestInput): Promise<ServiceRequest> {
  const category = await repo.findCategoryById(input.categoryId);
  if (!category) throw new ValidationError('Unknown or inactive service category');

  const id = await transaction(async (client) => {
    const created = await repo.insertRequest(client, {
      categoryId: category.id,
      domain: category.domain,
      customerUserId: userId,
      title: input.title ?? null,
      description: input.description,
      details: input.details as import('./marketplace.types.js').ServiceRequestDetails,
      savedLocationId: input.savedLocationId ?? null,
      serviceAddress: input.serviceAddress ?? null,
      serviceCounty: input.serviceCounty ?? null,
      serviceCity: input.serviceCity ?? null,
      serviceLatitude: input.serviceLatitude != null ? String(input.serviceLatitude) : null,
      serviceLongitude: input.serviceLongitude != null ? String(input.serviceLongitude) : null,
      preferredDateTime: input.preferredDateTime ?? null,
      contactName: input.contactName ?? null,
      contactPhone: input.contactPhone ?? null,
      contactEmail: input.contactEmail ?? null,
      createdBy: userId,
    });
    await repo.insertHistory(client, {
      requestId: created.id,
      action: 'created',
      previousStatus: null,
      newStatus: 'open',
      changedBy: userId,
    });
    return created.id;
  });

  const request = await repo.getRequestDetail(id);
  if (!request) throw new NotFoundError('Request not found');
  return request;
}

export async function listMyRequests(userId: string, query: ServiceRequestListQuery) {
  return repo.listCustomerRequests(userId, {
    status: query.status,
    domain: query.domain,
    limit: query.limit,
    offset: query.offset,
  });
}

async function loadOwnedRequest(userId: string, requestId: string): Promise<ServiceRequest> {
  const request = await repo.findRequestById(requestId);
  if (!request) throw new NotFoundError('Request not found');
  if (request.customerUserId !== userId) throw new ForbiddenError('You may not access this request');
  return request;
}

export async function getMyRequest(userId: string, requestId: string): Promise<ServiceRequest> {
  await loadOwnedRequest(userId, requestId);
  const detail = await repo.getRequestDetail(requestId);
  if (!detail) throw new NotFoundError('Request not found');
  return detail;
}

export async function cancelRequest(userId: string, requestId: string, reason?: string): Promise<ServiceRequest> {
  const request = await loadOwnedRequest(userId, requestId);
  assertTransition(request.status, 'cancelled', 'customer');

  await transaction(async (client) => {
    await repo.updateRequestStatus(client, {
      requestId,
      expectedFrom: request.status,
      toStatus: 'cancelled',
      actorUserId: userId,
      reason: reason ?? 'Cancelled by customer',
    });
    // Withdraw any live quotations so providers do not keep working a dead request.
    await client.query(
      `UPDATE service_quotations SET status = 'withdrawn'
        WHERE service_request_id = $1 AND status IN ('submitted','revised')`,
      [requestId],
    );
  });

  const detail = await repo.getRequestDetail(requestId);
  if (!detail) throw new NotFoundError('Request not found');
  return detail;
}

// ---------------------------------------------------------------------------
// Provider quotation engine
// ---------------------------------------------------------------------------
async function assertProviderCanQuote(
  context: Awaited<ReturnType<typeof resolveProviderContext>>,
  profileId: string,
  domain: ServiceDomain,
): Promise<void> {
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  if (!context.effectiveProfileIds.includes(profileId)) {
    throw new ForbiddenError('Profile is not in your provider context');
  }
  const eligible = await repo.providerEligibleDomains(context.effectiveProfileIds);
  if (!eligible.has(domain)) {
    throw new ForbiddenError('No active service offering for this request category');
  }
}

export async function listProviderInbox(userId: string, query: { domain?: ServiceDomain; organizationId?: string; limit: number; offset: number }) {
  const context = await resolveProviderContext(userId, query.organizationId ?? null);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return repo.listProviderInbox(context, { domain: query.domain, limit: query.limit, offset: query.offset });
}

export async function getProviderRequest(userId: string, requestId: string, organizationId?: string | null): Promise<ServiceRequest & { eligibleProfileIds: string[] }> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  const request = await repo.findRequestById(requestId);
  if (!request) throw new NotFoundError('Request not found');

  const assigned = request.assignedProviderId != null && context.effectiveProfileIds.includes(request.assignedProviderId);
  if (assigned) {
    const detail = await repo.getRequestDetail(requestId);
    return { ...detail!, eligibleProfileIds: context.effectiveProfileIds };
  }
  // Discovery access: only while quotable and the provider is eligible for the domain.
  assertQuotable(request.status);
  const eligible = await repo.providerEligibleDomains(context.effectiveProfileIds);
  if (!eligible.has(request.domain)) throw new ForbiddenError('Request not available to this provider');
  const detail = await repo.getRequestDetail(requestId);
  return { ...detail!, eligibleProfileIds: context.effectiveProfileIds };
}

export async function submitQuotation(
  userId: string,
  requestId: string,
  input: SubmitQuotationInput,
  organizationId?: string | null,
): Promise<ServiceRequest> {
  const context = await resolveProviderContext(userId, organizationId);
  const request = await repo.findRequestById(requestId);
  if (!request) throw new NotFoundError('Request not found');

  // Assigned provider may only revise its own winning quotation; others must quote while open.
  await assertProviderCanQuote(context, input.profileId, request.domain);

  await transaction(async (client) => {
    // Lock the request so concurrent acceptance/revision is serialized.
    const locked = await client.query<{ status: ServiceRequestStatus }>(
      `SELECT status::text AS status FROM service_requests WHERE id = $1 FOR UPDATE`,
      [requestId],
    );
    const currentStatus = locked.rows[0]?.status ?? request.status;

    const existing = await repo.findLiveQuotation(requestId, input.profileId);
    if (existing) {
      if (input.expectedVersion != null && input.expectedVersion !== existing.versionNumber) {
        throw new ConflictError('Quotation was revised concurrently; please reload');
      }
      // Revise: supersede the live quotation (frees the live slot), insert a new version.
      await client.query(
        `UPDATE service_quotations SET status = 'superseded' WHERE id = $1`,
        [existing.id],
      );
    } else if (!assertQuotableSafe(currentStatus)) {
      throw new ConflictError(`Request is not accepting quotations (status: ${currentStatus})`);
    }

    const version = (await repo.maxQuotationVersion(client, requestId, input.profileId)) + 1;
    const created = await repo.insertQuotation(client, {
      serviceRequestId: requestId,
      providerProfileId: input.profileId,
      versionNumber: version,
      currency: input.currency,
      subtotalAmount: money(input.subtotalAmount),
      totalAmount: money(input.totalAmount),
      estimatedStart: input.estimatedStart ?? null,
      estimatedCompletion: input.estimatedCompletion ?? null,
      validUntil: input.validUntil,
      terms: input.terms ?? null,
      notes: input.notes ?? null,
      supersedesId: existing?.id ?? null,
      createdBy: userId,
    });
    await repo.insertQuotationItems(
      client,
      created.id,
      input.items.map((it, i) => ({
        description: it.description,
        quantity: money(it.quantity),
        unitPrice: money(it.unitPrice),
        amount: money(it.amount),
        sortOrder: i,
      })),
    );

    // Promote request open -> quoted (idempotent; trigger records history).
    if (currentStatus === 'open') {
      await repo.updateRequestStatus(client, {
        requestId,
        expectedFrom: 'open',
        toStatus: 'quoted',
        actorUserId: userId,
      });
    }

    const eventType = existing ? 'quotation.revised' : 'quotation.submitted';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [request.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'service_request',
      resourceId: requestId,
      payload: { requestId, quotationId: created.id, versionNumber: version },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });

  const detail = await repo.getRequestDetail(requestId);
  if (!detail) throw new NotFoundError('Request not found');
  return detail;
}

function assertQuotableSafe(status: ServiceRequestStatus): boolean {
  try {
    assertQuotable(status);
    return true;
  } catch {
    return false;
  }
}

export async function withdrawQuotation(
  userId: string,
  quotationId: string,
  reason?: string,
  organizationId?: string | null,
): Promise<void> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  const quotation = await repo.findQuotationById(quotationId);
  if (!quotation) throw new NotFoundError('Quotation not found');
  if (!context.effectiveProfileIds.includes(quotation.providerProfileId)) {
    throw new ForbiddenError('You may not manage this quotation');
  }
  if (!['submitted', 'revised'].includes(quotation.status)) {
    throw new ConflictError('Only live quotations can be withdrawn');
  }

  await transaction(async (client) => {
    const r = await client.query(
      `UPDATE service_quotations SET status = 'withdrawn'
        WHERE id = $1 AND status IN ('submitted','revised') RETURNING id`,
      [quotationId],
    );
    if (r.rows.length === 0) throw new ConflictError('Quotation changed concurrently');
    const eventType = 'quotation.withdrawn';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${quotationId}`,
      eventType,
      category: 'operational',
      priority: 'low',
      recipientUserIds: [],
      organisationId: context.activeOrganizationId,
      resourceType: 'service_request',
      resourceId: quotation.serviceRequestId,
      payload: { requestId: quotation.serviceRequestId, quotationId, reason: reason ?? null },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
}

// ---------------------------------------------------------------------------
// Customer quotation acceptance — atomic, row-locked, single winner.
// ---------------------------------------------------------------------------
export async function acceptQuotation(
  userId: string,
  requestId: string,
  quotationId: string,
  input: AcceptQuotationInput,
): Promise<ServiceRequest> {
  const request = await repo.findRequestById(requestId);
  if (!request) throw new NotFoundError('Request not found');
  if (request.customerUserId !== userId) throw new ForbiddenError('You may not access this request');
  assertQuotable(request.status);

  await transaction(async (client) => {
    // Serialize all acceptors on this request.
    const lock = await client.query<{ status: ServiceRequestStatus; customer: string }>(
      `SELECT status::text AS status, customer_user_id AS customer FROM service_requests WHERE id = $1 FOR UPDATE`,
      [requestId],
    );
    const lockedStatus = lock.rows[0]?.status ?? request.status;
    assertQuotable(lockedStatus);

    const q = await client.query<{
      id: string;
      status: ServiceQuotationStatus;
      version: number;
      provider: string;
      validUntil: string;
    }>(
      `SELECT id, status::text AS status, version_number AS version,
              provider_profile_id AS provider, valid_until AS "validUntil"
         FROM service_quotations
        WHERE id = $1 AND service_request_id = $2
        FOR UPDATE`,
      [quotationId, requestId],
    );
    const quotation = q.rows[0];
    if (!quotation) throw new NotFoundError('Quotation not found');
    if (!['submitted', 'revised'].includes(quotation.status)) {
      throw new ConflictError('Quotation is no longer live');
    }
    if (input.expectedVersion != null && input.expectedVersion !== quotation.version) {
      throw new ConflictError('Quotation version changed; please reload');
    }
    if (new Date(quotation.validUntil).getTime() < Date.now()) {
      throw new ConflictError('Quotation has expired');
    }

    // Accept the chosen quotation.
    await client.query(`UPDATE service_quotations SET status = 'accepted' WHERE id = $1`, [quotationId]);
    // Decline every other live quotation on this request (single winner).
    await client.query(
      `UPDATE service_quotations SET status = 'declined'
        WHERE service_request_id = $1 AND id <> $2 AND status IN ('submitted','revised')`,
      [requestId, quotationId],
    );

    await repo.updateRequestStatus(client, {
      requestId,
      expectedFrom: lockedStatus,
      toStatus: 'accepted',
      actorUserId: userId,
    });
    await client.query(
      `UPDATE service_requests
          SET accepted_quotation_id = $2, assigned_provider_id = $3
        WHERE id = $1`,
      [requestId, quotationId, quotation.provider],
    );

    const eventType = 'service_request.accepted';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${requestId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [request.customerUserId],
      organisationId: null,
      resourceType: 'service_request',
      resourceId: requestId,
      payload: { requestId, quotationId, providerProfileId: quotation.provider },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });

  const detail = await repo.getRequestDetail(requestId);
  if (!detail) throw new NotFoundError('Request not found');
  return detail;
}

// Advance an accepted job (provider): accepted -> in_progress -> completed.
export async function advanceJob(
  userId: string,
  requestId: string,
  toStatus: 'in_progress' | 'completed',
  organizationId?: string | null,
): Promise<ServiceRequest> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  const request = await repo.findRequestById(requestId);
  if (!request) throw new NotFoundError('Request not found');
  if (request.assignedProviderId == null || !context.effectiveProfileIds.includes(request.assignedProviderId)) {
    throw new ForbiddenError('You are not the assigned provider for this request');
  }
  assertTransition(request.status, toStatus, 'provider');

  await transaction(async (client) => {
    await repo.updateRequestStatus(client, {
      requestId,
      expectedFrom: request.status,
      toStatus,
      actorUserId: userId,
      extra:
        toStatus === 'in_progress'
          ? { startedAt: new Date().toISOString() }
          : { completedAt: new Date().toISOString() },
    });
    const eventType = toStatus === 'completed' ? 'service_request.completed' : 'service_request.scheduled';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${requestId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [request.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'service_request',
      resourceId: requestId,
      payload: { requestId, status: toStatus },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });

  const detail = await repo.getRequestDetail(requestId);
  if (!detail) throw new NotFoundError('Request not found');
  return detail;
}