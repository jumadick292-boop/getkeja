// Provider service — orchestrates inbox, detail (with privacy masking),
// provider response (lifecycle + atomic outbox), dashboard and discovery.
import { pool } from '../../db/pool.js';
import { ForbiddenError, NotFoundError } from '../../shared/errors.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import {
  assertTransition,
  updateDomainRequestStatus,
  type ServiceDomain,
} from '../service-requests/service-requests.lifecycle.js';
import { findProviders } from '../location/provider-discovery.repository.js';
import type { ProviderDiscoveryQuery } from '../location/provider-discovery.schema.js';
import * as repo from './provider.repository.js';
import {
  canAccessProviderRequest,
  resolveProviderContext,
} from './provider.authorization.js';
import type {
  ProviderContext,
  ProviderRequestRow,
} from './provider.types.js';

function toPublicRow(row: ProviderRequestRow, assigned: boolean): ProviderRequestRow {
  // Inbox rows never carry contact details or exact coordinates.
  return {
    id: row.id,
    serviceType: row.serviceType,
    status: row.status,
    providerId: row.providerId,
    propertyId: row.propertyId,
    unitId: row.unitId,
    preferredAt: row.preferredAt,
    createdAt: row.createdAt,
    summary: row.summary,
    category: row.category,
    providerName: row.providerName,
    assigned,
    propertyCity: row.propertyCity,
    propertyCounty: row.propertyCounty,
  };
}

export async function getProviderInbox(
  userId: string,
  filters: repo.InboxFilters,
  organizationId?: string | null,
): Promise<{ rows: ProviderRequestRow[]; total: number }> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) {
    throw new ForbiddenError('No approved provider profile or organization context');
  }
  const { rows, total } = await repo.listProviderInbox(context, filters);
  return { rows: rows.map((r) => toPublicRow(r, r.assigned)), total };
}

export async function getProviderRequestDetail(userId: string, requestId: string) {
  const context = await resolveProviderContext(userId);
  const access = await canAccessProviderRequest(context, requestId);
  if (!access.allowed) {
    throw new ForbiddenError(access.reason);
  }
  const detail = await repo.fetchProviderRequestDetail(access.serviceType, requestId);
  if (!detail) throw new NotFoundError('Request not found');

  const base = {
    id: detail.id,
    serviceType: detail.serviceType,
    status: detail.status,
    providerId: detail.providerId,
    propertyId: detail.propertyId,
    unitId: detail.unitId,
    propertyCity: detail.propertyCity,
    propertyCounty: detail.propertyCounty,
    preferredAt: detail.preferredAt,
    summary: detail.summary,
    category: detail.category,
    providerName: detail.providerName,
    createdAt: detail.createdAt,
    assigned: access.assigned,
  };

  if (!access.assigned) {
    // Discoverable (unassigned) request: mask contact + exact coordinates.
    return {
      ...base,
      pickupLocation: detail.pickupLocation,
      destinationLocation: detail.destinationLocation,
      pickupLatitude: null,
      pickupLongitude: null,
      contactName: null,
      contactPhone: null,
      contactEmail: null,
    };
  }

  return {
    ...base,
    pickupLocation: detail.pickupLocation,
    destinationLocation: detail.destinationLocation,
    pickupLatitude: detail.pickupLatitude,
    pickupLongitude: detail.pickupLongitude,
    contactName: detail.contactName,
    contactPhone: detail.contactPhone,
    contactEmail: detail.contactEmail,
  };
}

function targetStatusFor(
  domain: ServiceDomain,
  action: 'accept' | 'decline',
): string {
  if (domain === 'garbage') {
    return action === 'accept' ? 'assigned' : 'cancelled';
  }
  return action === 'accept' ? 'accepted' : 'declined';
}

export async function respondToProviderRequest(
  userId: string,
  requestId: string,
  action: 'accept' | 'decline',
  reason?: string | null,
) {
  const context = await resolveProviderContext(userId);
  const access = await canAccessProviderRequest(context, requestId);
  if (!access.allowed) {
    throw new ForbiddenError(access.reason);
  }
  // A provider may only *respond* (accept/decline) to a request that is
  // assigned to them or discoverable and still open.
  if (access.assigned === false && action !== 'accept') {
    throw new ForbiddenError('Only an assigned provider may decline this request');
  }

  const domain = access.serviceType;
  const detail = await repo.fetchProviderRequestDetail(domain, requestId);
  if (!detail) throw new NotFoundError('Request not found');

  const toStatus = targetStatusFor(domain, action);
  // Validate transition before opening the transaction.
  assertTransition(domain, detail.status, toStatus, 'provider');

  const eventType = action === 'accept' ? 'service_request.accepted' : 'service_request.declined';

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const updated = await updateDomainRequestStatus(client, {
      domain,
      requestId,
      expectedFromStatus: detail.status,
      toStatus,
      actorUserId: userId,
      reason: action === 'decline' ? reason ?? 'Declined by provider' : null,
    });

    // Atomic outbox: notify the customer (request creator). No private
    // provider data is placed in the payload.
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${requestId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [detail.createdBy],
      organisationId: context.activeOrganizationId,
      resourceType: domain === 'garbage' ? 'garbage_request' : `${domain}_request`,
      resourceId: requestId,
      payload: {
        requestId,
        serviceType: domain,
        status: updated.status,
        action,
      },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });

    await client.query('COMMIT');
    return updated;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function getProviderDashboard(userId: string, organizationId?: string | null) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) {
    throw new ForbiddenError('No approved provider profile or organization context');
  }
  return repo.getProviderDashboardCounts(context);
}

export async function discoverProviders(query: {
  category?: 'moving_service_provider' | 'garbage_collection_provider' | 'laundry_service_provider';
  latitude?: number;
  longitude?: number;
  county?: string;
  city?: string;
  limit: number;
}) {
  // Coordinate-based discovery reuses the existing Haversine repository,
  // which returns only public fields (no raw coordinates/contact data).
  if (query.latitude !== undefined && query.longitude !== undefined) {
    return findProviders(query as ProviderDiscoveryQuery);
  }
  // Text fallback (no Google Maps / coordinates): match by county/city.
  return repo.findProvidersByText(query);
}