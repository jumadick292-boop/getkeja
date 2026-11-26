// Garbage collection operations service (Task 13.7).
// Builds one-time collection jobs from an accepted marketplace quotation and
// recurring agreements that generate idempotent, Africa/Nairobi-safe
// occurrences. Business change + history + outbox share one transaction.
// Reuses provider context, org permissions and the transactional outbox.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  CreateGarbageAgreementInput,
  CreateGarbageJobInput,
  GarbageCompletionInput,
  GarbageCustomerConfirmationInput,
  GarbageProgressInput,
} from './garbage.schemas.js';
import type {
  GarbageActor,
  GarbageJob,
  GarbageJobDetail,
  GarbageJobScope,
  GarbageCollectionStatus,
} from './garbage.types.js';
import {
  assertGarbageTransition,
  GARBAGE_CHECKLIST_TEMPLATE,
  isGarbageTerminal,
} from './garbage.lifecycle.js';
import * as repo from './garbage.repository.js';

function actorFor(userId: string, job: GarbageJob): GarbageActor {
  if (job.customerUserId === userId) return 'customer';
  return 'provider';
}

async function loadProviderContext(userId: string, organizationId?: string | null): Promise<ProviderContext> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

async function assertProviderAccess(context: ProviderContext, job: GarbageJob, permission?: string): Promise<void> {
  const isOwnerProfile = context.effectiveProfileIds.includes(job.providerProfileId);
  if (isOwnerProfile) return;
  const isAssignedStaff = job.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM garbage_job_staff_assignments
        WHERE garbage_job_id = $1 AND user_id = $2 AND is_active`,
      [job.id, context.userId],
    )
  ).rowCount;
  if (!isAssignedStaff && !isActiveStaff) {
    throw new ForbiddenError('You are not authorized for this garbage collection');
  }
  if (permission) {
    const roleIds = job.providerOrganisationId
      ? await authz.getUserOrganizationRoleIds(context.userId, job.providerOrganisationId)
      : [];
    if (roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r))) return;
    if (!(await authz.hasPermission(context.userId, permission))) {
      throw new ForbiddenError(`Missing permission: ${permission}`);
    }
  }
}

async function loadJobForCustomer(userId: string, jobId: string): Promise<GarbageJob> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  if (job.customerUserId !== userId) throw new ForbiddenError('You may not access this garbage collection');
  return job;
}

async function quoteRequestId(quotationId: string): Promise<string> {
  const r = await pool.query<{ service_request_id: string }>(
    `SELECT service_request_id FROM service_quotations WHERE id = $1`,
    [quotationId],
  );
  if (!r.rows[0]) throw new NotFoundError('Quotation not found');
  return r.rows[0].service_request_id;
}

function defaultChecklist(): Record<string, boolean> {
  return Object.fromEntries(GARBAGE_CHECKLIST_TEMPLATE.map((t) => [t.id, false]));
}

// ---------------------------------------------------------------------------
// One-time job from an accepted quotation
// ---------------------------------------------------------------------------
export async function createJobFromQuotation(
  userId: string,
  input: CreateGarbageJobInput,
  organizationId?: string | null,
): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);

  const requestId = await quoteRequestId(input.quotationId);
  const accepted = await repo.findAcceptedQuotation(requestId);
  if (!accepted) throw new ConflictError('Quotation is not accepted');
  if (!context.effectiveProfileIds.includes(accepted.providerProfileId)) {
    throw new ForbiddenError('You may not create a job for this quotation');
  }
  const existing = await repo.findJobByRequestId(requestId);
  if (existing) throw new ConflictError('A garbage collection already exists for this request');

  const requestRow = await pool.query<{ details: Record<string, unknown>; customer_user_id: string }>(
    `SELECT details, customer_user_id AS "customer_user_id" FROM service_requests WHERE id = $1`,
    [requestId],
  );
  if (!requestRow.rows[0]) throw new NotFoundError('Service request not found');
  const requestDetails = requestRow.rows[0].details ?? {};

  const scope: GarbageJobScope = {
    wasteCategory: input.scope?.wasteCategory ?? input.wasteCategory ?? (requestDetails.wasteCategory as string | undefined),
    estimatedQuantity: input.scope?.estimatedQuantity ?? input.estimatedQuantity ?? (requestDetails.estimatedQuantity as string | undefined),
    binCount: input.scope?.binCount ?? input.binCount ?? (requestDetails.binCount as number | undefined),
    accessInstructions: input.scope?.accessInstructions,
    specialInstructions: input.scope?.specialInstructions,
    requestDetails,
  };

  const jobId = await transaction(async (client) => {
    const created = await repo.insertJob(client, {
      serviceRequestId: requestId,
      recurringOccurrenceId: null,
      agreementId: null,
      quotationId: accepted.id,
      quotationVersion: accepted.versionNumber,
      customerUserId: requestRow.rows[0]!.customer_user_id,
      providerProfileId: accepted.providerProfileId,
      providerOrganisationId: context.activeOrganizationId,
      collectionLocationId: input.location?.locationId ?? null,
      collectionAddress: input.location?.address ?? null,
      propertyId: input.propertyId ?? null,
      unitId: input.unitId ?? null,
      tenancyId: input.tenancyId ?? null,
      wasteCategory: scope.wasteCategory ?? null,
      estimatedQuantity: scope.estimatedQuantity ?? null,
      binCount: scope.binCount ?? null,
      agreedPrice: accepted.totalAmount,
      currency: accepted.currency,
      scope,
      checklist: defaultChecklist(),
      scheduledDate: input.scheduledDate ?? null,
      windowStart: input.windowStart ?? null,
      windowEnd: input.windowEnd ?? null,
      createdBy: userId,
    });
    await repo.insertHistory(client, {
      jobId: created.id,
      action: 'confirmed',
      changedBy: userId,
      newStatus: 'confirmed',
      metadata: { quotationId: accepted.id, version: accepted.versionNumber },
    });
    const eventType = 'garbage_job.confirmed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [requestRow.rows[0]!.customer_user_id],
      organisationId: context.activeOrganizationId,
      resourceType: 'garbage_job',
      resourceId: created.id,
      payload: { jobId: created.id, requestId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
    return created.id;
  });

  return (await repo.getJobDetail(jobId))!;
}

// ---------------------------------------------------------------------------
// Customer
// ---------------------------------------------------------------------------
export async function listCustomerJobs(userId: string, query: { status?: GarbageCollectionStatus; limit: number; offset: number }) {
  return repo.listJobsByCustomer(userId, query);
}

export async function getCustomerJob(userId: string, jobId: string): Promise<GarbageJobDetail> {
  await loadJobForCustomer(userId, jobId);
  return (await repo.getJobDetail(jobId))!;
}

export async function cancelJob(userId: string, jobId: string, reason: string): Promise<GarbageJobDetail> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  const actor = actorFor(userId, job);
  if (actor === 'provider') {
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, job);
  }
  assertGarbageTransition(job.status, 'cancelled', actor);
  await transaction(async (client) => {
    await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'cancelled', actorUserId: userId, reason });
    await repo.insertHistory(client, { jobId, action: 'cancelled', changedBy: userId, previousStatus: job.status, newStatus: 'cancelled', reason });
    const eventType = 'garbage_job.cancelled';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [actor === 'customer' ? job.providerProfileId : job.customerUserId].filter(Boolean) as string[],
      organisationId: null,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId, reason },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function confirmCompletion(userId: string, jobId: string, input: GarbageCustomerConfirmationInput): Promise<GarbageJobDetail> {
  const job = await loadJobForCustomer(userId, jobId);
  if (job.status !== 'awaiting_customer_confirmation') {
    throw new ConflictError('Collection is not awaiting customer confirmation');
  }
  if (!job.completionSubmittedAt) throw new ConflictError('Provider has not submitted completion yet');

  await transaction(async (client) => {
    await repo.recordCustomerConfirmation(client, jobId, { confirm: input.confirm, notes: input.notes ?? null });
    if (input.confirm) {
      await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'completed', actorUserId: userId });
      await repo.insertHistory(client, { jobId, action: 'completed', changedBy: userId, previousStatus: job.status, newStatus: 'completed' });
    } else if (input.exception) {
      await repo.insertException(client, jobId, userId, input.exception.type, input.exception.description);
      await repo.insertHistory(client, { jobId, action: 'completion_exception', changedBy: userId, metadata: { exception: input.exception } });
    }
    const eventType = input.confirm ? 'garbage_job.completed' : 'garbage_job.completion_exception';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [],
      organisationId: null,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId, confirm: input.confirm, exception: input.exception ?? null },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function reportException(userId: string, jobId: string, input: { type: string; description: string }): Promise<GarbageJobDetail> {
  const job = await loadJobForCustomer(userId, jobId);
  if (isGarbageTerminal(job.status)) throw new ConflictError('Collection is closed');
  await transaction(async (client) => {
    await repo.insertException(client, jobId, userId, input.type, input.description);
    await repo.insertHistory(client, { jobId, action: 'exception_reported', changedBy: userId, metadata: { type: input.type } });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
export async function listProviderJobs(userId: string, query: { status?: GarbageCollectionStatus; organizationId?: string; limit: number; offset: number }) {
  const context = await loadProviderContext(userId, query.organizationId);
  return repo.listJobsForProvider(context.effectiveProfileIds, userId, query);
}

export async function getProviderJob(userId: string, jobId: string, organizationId?: string | null): Promise<GarbageJobDetail & { canViewLocations: boolean }> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job);
  const detail = (await repo.getJobDetail(jobId))!;
  const canViewLocations = await canViewSensitiveLocations(context, job);
  return { ...detail, canViewLocations };
}

async function canViewSensitiveLocations(context: ProviderContext, job: GarbageJob): Promise<boolean> {
  const isOwnerProfile = context.effectiveProfileIds.includes(job.providerProfileId);
  const isAssignedStaff = job.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM garbage_job_staff_assignments WHERE garbage_job_id = $1 AND user_id = $2 AND is_active`,
      [job.id, context.userId],
    )
  ).rowCount;
  if (!isOwnerProfile && !isAssignedStaff && !isActiveStaff) return false;
  if (isOwnerProfile || isAssignedStaff) return true;
  return authz.hasPermission(context.userId, 'provider.garbage.view_locations');
}

export async function updateProgress(userId: string, jobId: string, input: GarbageProgressInput, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.update_progress');
  assertGarbageTransition(job.status, input.toStatus, 'provider');

  await transaction(async (client) => {
    if (input.checklist) await repo.mergeChecklist(client, jobId, input.checklist);
    await repo.updateJobStatus(client, {
      jobId,
      expectedFrom: job.status,
      toStatus: input.toStatus,
      actorUserId: userId,
      reason: input.reason ?? null,
    });
    await repo.insertHistory(client, { jobId, action: input.toStatus, changedBy: userId, previousStatus: job.status, newStatus: input.toStatus, reason: input.reason ?? null });
    const eventType = `garbage_job.${input.toStatus}`;
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}:${input.toStatus}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId, status: input.toStatus },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function markMissed(userId: string, jobId: string, reason: string, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.update_progress');
  assertGarbageTransition(job.status, 'missed', 'provider');
  await transaction(async (client) => {
    await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'missed', actorUserId: userId, reason });
    await repo.insertHistory(client, { jobId, action: 'missed', changedBy: userId, previousStatus: job.status, newStatus: 'missed', reason });
    const eventType = 'garbage_job.missed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId, reason },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function failJob(userId: string, jobId: string, reason: string, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.update_progress');
  assertGarbageTransition(job.status, 'failed', 'provider');
  await transaction(async (client) => {
    await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'failed', actorUserId: userId, reason });
    await repo.insertHistory(client, { jobId, action: 'failed', changedBy: userId, previousStatus: job.status, newStatus: 'failed', reason });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Staff ----
export async function assignStaff(userId: string, jobId: string, input: { userId: string; label?: string }, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.assign_staff');
  if (job.providerOrganisationId) {
    const member = await pool.query(
      `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'`,
      [job.providerOrganisationId, input.userId],
    );
    if (!member.rowCount) throw new ValidationError('Staff member is not an active organization member');
  }
  await transaction(async (client) => {
    await client.query(
      `UPDATE garbage_job_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $2
        WHERE garbage_job_id = $1 AND user_id = $3 AND is_active`,
      [jobId, userId, input.userId],
    );
    await client.query(
      `INSERT INTO garbage_job_staff_assignments (garbage_job_id, user_id, assigned_by, label)
       VALUES ($1,$2,$3,$4)`,
      [jobId, input.userId, userId, input.label ?? null],
    );
    if (job.assignedStaffUserId !== input.userId) {
      await client.query(`UPDATE garbage_jobs SET assigned_staff_user_id = $2 WHERE id = $1`, [jobId, input.userId]);
    }
    await repo.insertHistory(client, { jobId, action: 'staff_assigned', changedBy: userId, metadata: { userId: input.userId } });
    const eventType = 'garbage_job.staff_assigned';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}:${input.userId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [input.userId],
      organisationId: job.providerOrganisationId,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId, staffUserId: input.userId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Checklist ----
export async function updateChecklist(userId: string, jobId: string, items: Record<string, boolean>, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.update_progress');
  await transaction(async (client) => {
    await repo.mergeChecklist(client, jobId, items);
    await repo.insertHistory(client, { jobId, action: 'checklist_updated', changedBy: userId, metadata: { items } });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Reschedule ----
export async function reschedule(userId: string, jobId: string, input: { scheduledDate: string; windowStart?: string | null; windowEnd?: string | null; reason?: string }, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.manage_schedule');
  assertGarbageTransition(job.status, 'rescheduled', 'provider');
  await transaction(async (client) => {
    await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'rescheduled', actorUserId: userId, reason: input.reason ?? null });
    await repo.applyReschedule(client, jobId, input.scheduledDate, input.windowStart ?? null, input.windowEnd ?? null);
    await repo.insertHistory(client, { jobId, action: 'rescheduled', changedBy: userId, previousStatus: job.status, newStatus: 'rescheduled', reason: input.reason ?? null, metadata: { scheduledDate: input.scheduledDate } });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Completion ----
export async function submitCompletion(userId: string, jobId: string, input: GarbageCompletionInput, organizationId?: string | null): Promise<GarbageJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Garbage collection not found');
  await assertProviderAccess(context, job, 'provider.garbage.upload_evidence');
  assertGarbageTransition(job.status, 'awaiting_customer_confirmation', 'provider');
  await transaction(async (client) => {
    await repo.submitCompletion(client, jobId, {
      notes: input.notes ?? null,
      outstandingIssue: input.outstandingIssue,
      checklist: input.checklist,
      wasteCategory: input.wasteCategory ?? null,
      estimatedQuantity: input.estimatedQuantity ?? null,
      binCount: input.binCount ?? null,
    });
    if (input.evidenceDocumentIds.length > 0) {
      await repo.insertAttachments(client, jobId, input.evidenceDocumentIds, 'completion', userId);
    }
    await repo.updateJobStatus(client, { jobId, expectedFrom: job.status, toStatus: 'awaiting_customer_confirmation', actorUserId: userId });
    await repo.insertHistory(client, { jobId, action: 'completion_submitted', changedBy: userId, previousStatus: job.status, newStatus: 'awaiting_customer_confirmation' });
    const eventType = 'garbage_job.completion_submitted';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'garbage_job',
      resourceId: jobId,
      payload: { jobId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---------------------------------------------------------------------------
// Recurring agreements (provider proposes, customer accepts)
// ---------------------------------------------------------------------------
export async function proposeAgreement(userId: string, input: CreateGarbageAgreementInput, organizationId?: string | null) {
  const context = await loadProviderContext(userId, organizationId);

  let providerProfileId: string;
  let customerUserId: string;
  let quotationId: string | null = null;
  let agreedAmount: string;
  let currency = 'KES';

  if (input.quotationId) {
    const requestId = await quoteRequestId(input.quotationId);
    const accepted = await repo.findAcceptedQuotation(requestId);
    if (!accepted) throw new ConflictError('Quotation is not accepted');
    if (!context.effectiveProfileIds.includes(accepted.providerProfileId)) {
      throw new ForbiddenError('You may not create an agreement for this quotation');
    }
    providerProfileId = accepted.providerProfileId;
    quotationId = accepted.id;
    agreedAmount = accepted.totalAmount;
    currency = accepted.currency;
    const rr = await pool.query<{ customer_user_id: string }>(`SELECT customer_user_id FROM service_requests WHERE id = $1`, [requestId]);
    customerUserId = rr.rows[0]!.customer_user_id;
  } else if (input.serviceRequestId) {
    const rr = await pool.query<{ customer_user_id: string; details: Record<string, unknown> }>(
      `SELECT customer_user_id, details FROM service_requests WHERE id = $1`,
      [input.serviceRequestId],
    );
    if (!rr.rows[0]) throw new NotFoundError('Service request not found');
    providerProfileId = context.effectiveProfileIds[0]!;
    customerUserId = rr.rows[0].customer_user_id;
    agreedAmount = input.agreedAmount.toFixed(2);
  } else {
    throw new ValidationError('quotationId or serviceRequestId is required');
  }

  if (input.startDate && input.endDate && input.endDate < input.startDate) {
    throw new ValidationError('endDate must be on or after startDate');
  }
  if (input.frequency === 'weekly' && input.daysOfWeek.length === 0) {
    throw new ValidationError('weekly agreements require at least one day of week');
  }

  const agreementId = await transaction(async (client) => {
    const created = await repo.insertAgreement(client, {
      serviceRequestId: input.serviceRequestId ?? null,
      quotationId,
      providerProfileId,
      customerUserId,
      providerOrganisationId: context.activeOrganizationId,
      propertyId: input.propertyId ?? null,
      unitId: input.unitId ?? null,
      tenancyId: input.tenancyId ?? null,
      status: 'proposed',
      frequency: input.frequency,
      intervalDays: input.intervalDays ?? null,
      daysOfWeek: input.daysOfWeek,
      windowStart: input.windowStart ?? null,
      windowEnd: input.windowEnd ?? null,
      startDate: input.startDate,
      endDate: input.endDate ?? null,
      agreedAmount,
      currency,
      billingFrequency: input.billingFrequency ?? null,
      wasteCategory: input.wasteCategory ?? null,
      scope: input.scope ?? {},
      createdBy: userId,
    });
    const eventType = 'garbage_agreement.proposed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'garbage_agreement',
      resourceId: created.id,
      payload: { agreementId: created.id, frequency: input.frequency },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
    return created.id;
  });

  return repo.findAgreement(agreementId);
}

export async function decideAgreement(userId: string, agreementId: string, accept: boolean) {
  const agreement = await repo.findAgreement(agreementId);
  if (!agreement) throw new NotFoundError('Agreement not found');
  if (agreement.customerUserId !== userId) throw new ForbiddenError('Only the customer may respond to an agreement');
  if (agreement.status !== 'proposed') throw new ConflictError('Agreement is not awaiting a response');

  const nextStatus = accept ? 'active' : 'cancelled';
  await transaction(async (client) => {
    await repo.updateAgreementStatus(client, agreementId, nextStatus);
    const eventType = accept ? 'garbage_agreement.accepted' : 'garbage_agreement.declined';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${agreementId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [agreement.providerProfileId],
      organisationId: agreement.providerOrganisationId,
      resourceType: 'garbage_agreement',
      resourceId: agreementId,
      payload: { agreementId, accept },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return repo.findAgreement(agreementId);
}

export async function setAgreementStatus(userId: string, agreementId: string, status: 'suspended' | 'active' | 'cancelled' | 'completed', organizationId?: string | null) {
  const context = await loadProviderContext(userId, organizationId);
  const agreement = await repo.findAgreement(agreementId);
  if (!agreement) throw new NotFoundError('Agreement not found');
  const isOwnerProfile = context.effectiveProfileIds.includes(agreement.providerProfileId);
  const isCustomer = agreement.customerUserId === userId;
  if (!isOwnerProfile && !isCustomer) throw new ForbiddenError('You may not change this agreement');
  if (status === 'cancelled' || status === 'suspended') {
    if (!isOwnerProfile) throw new ForbiddenError('Only the provider may suspend or cancel an agreement');
  }
  await transaction(async (client) => {
    await repo.updateAgreementStatus(client, agreementId, status);
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `garbage_agreement.${status}:${agreementId}`,
      eventType: `garbage_agreement.${status}`,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [isCustomer ? agreement.providerProfileId : agreement.customerUserId].filter(Boolean) as string[],
      organisationId: agreement.providerOrganisationId,
      resourceType: 'garbage_agreement',
      resourceId: agreementId,
      payload: { agreementId, status },
      channels: ['in_app'],
      classification: classifyEventType(`garbage_agreement.${status}`),
    });
  });
  return repo.findAgreement(agreementId);
}

export async function listCustomerAgreements(userId: string) {
  return repo.listAgreementsByCustomer(userId);
}

export async function listProviderAgreements(userId: string, organizationId?: string | null) {
  const context = await loadProviderContext(userId, organizationId);
  return repo.listAgreementsByProvider(context.effectiveProfileIds);
}

export async function getAgreementOccurrences(userId: string, agreementId: string) {
  const agreement = await repo.findAgreement(agreementId);
  if (!agreement) throw new NotFoundError('Agreement not found');
  if (agreement.customerUserId !== userId) {
    const context = await loadProviderContext(userId);
    if (!context.effectiveProfileIds.includes(agreement.providerProfileId)) {
      throw new ForbiddenError('You may not access this agreement');
    }
  }
  return repo.listOccurrences(agreementId);
}

export { actorFor };