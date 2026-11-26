// Provider authorization — resolves the effective provider context for a user
// and decides resource-scoped access to service requests.
//
// Access is NOT role-name based. It is derived from:
//   - owned specialized_profiles (individual provider),
//   - specialized_profiles reached through ACTIVE organization memberships,
//   - active garbage_providers reachable via org membership or ownership,
//   - explicit request assignment (provider_id / garbage_provider_id).
//
// A user must never see a request merely by knowing its id: every access path
// below is gated by an approved/active provider profile or an explicit
// assignment. Organization membership alone never grants customer-request
// access; it only contributes provider profiles to the effective context.

import { pool } from '../../db/pool.js';
import * as authz from '../auth/authorization.service.js';
import { contextHasEligibleOffering } from './provider.repository.js';
import {
  PROVIDER_CATEGORIES,
  type ProviderCategory,
  type ProviderContext,
} from './provider.types.js';

const EMPTY_BY_CATEGORY: Record<ProviderCategory, string[]> = {
  moving_service_provider: [],
  garbage_collection_provider: [],
  laundry_service_provider: [],
};

export async function resolveProviderContext(
  userId: string,
  requestedOrganizationId?: string | null,
): Promise<ProviderContext> {
  const organizationIds = await authz.getUserOrganizations(userId);

  // Active org filter: never trust the first membership; validate the request
  // and exclude deactivated organizations.
  let activeOrganizationId: string | null = null;
  if (requestedOrganizationId) {
    if (!organizationIds.includes(requestedOrganizationId)) {
      activeOrganizationId = null;
    } else {
      activeOrganizationId = requestedOrganizationId;
    }
  }

  // Restrict to organizations that are active (not deactivated).
  const activeOrgRows = organizationIds.length
    ? await pool.query<{ id: string }>(
        `SELECT id FROM organisations WHERE id = ANY($1::uuid[]) AND is_active = TRUE`,
        [organizationIds],
      )
    : { rows: [] as Array<{ id: string }> };
  const activeOrgSet = new Set(activeOrgRows.rows.map((r) => r.id));
  if (activeOrganizationId && !activeOrgSet.has(activeOrganizationId)) {
    activeOrganizationId = null;
  }
  const orgScope = activeOrganizationId ? [activeOrganizationId] : [...activeOrgSet];

  // Individual approved+active provider profiles owned by the user.
  const individual = await pool.query<{ id: string; profile_category: ProviderCategory }>(
    `SELECT sp.id, sp.profile_category
       FROM specialized_profiles sp
       LEFT JOIN provider_profile_extensions ppe ON ppe.specialized_profile_id = sp.id
      WHERE sp.user_id = $1
        AND sp.profile_category = ANY($2::profile_category[])
        AND sp.verification_status = 'approved'
        AND (ppe.operating_status IS NULL OR ppe.operating_status::text = 'active')`,
    [userId, PROVIDER_CATEGORIES],
  );

  // Organization provider profiles (approved+active) for the active org scope.
  const orgProfiles = orgScope.length
    ? await pool.query<{ id: string; profile_category: ProviderCategory }>(
        `SELECT sp.id, sp.profile_category
           FROM specialized_profiles sp
           LEFT JOIN provider_profile_extensions ppe ON ppe.specialized_profile_id = sp.id
          WHERE sp.organisation_id = ANY($1::uuid[])
            AND sp.profile_category = ANY($2::profile_category[])
            AND sp.verification_status = 'approved'
            AND (ppe.operating_status IS NULL OR ppe.operating_status::text = 'active')`,
        [orgScope, PROVIDER_CATEGORIES],
      )
    : { rows: [] as Array<{ id: string; profile_category: ProviderCategory }> };

  const approvedByCategory: Record<ProviderCategory, string[]> = {
    moving_service_provider: [...EMPTY_BY_CATEGORY.moving_service_provider],
    garbage_collection_provider: [...EMPTY_BY_CATEGORY.garbage_collection_provider],
    laundry_service_provider: [...EMPTY_BY_CATEGORY.laundry_service_provider],
  };
  const effective = new Set<string>();
  for (const row of [...individual.rows, ...orgProfiles.rows]) {
    effective.add(row.id);
    approvedByCategory[row.profile_category].push(row.id);
  }

  // Active garbage providers reachable via org membership or ownership.
  // An empty org scope must NOT match all providers — only linked/owned ones.
  const garbageProviderIds: string[] = [];
  const garbage = await pool.query<{ id: string }>(
    `SELECT id FROM garbage_providers
      WHERE status = 'active'
        AND (
          specialized_profile_id = ANY($1::uuid[])
          OR organisation_id = ANY($2::uuid[])
          OR created_by = $3
        )`,
    [[...effective], orgScope, userId],
  );
  for (const row of garbage.rows) garbageProviderIds.push(row.id);

  const individualProfileIds = individual.rows.map((r) => r.id);
  const organizationProfileIds = orgProfiles.rows.map((r) => r.id);

  return {
    userId,
    individualProfileIds,
    organizationProfileIds,
    effectiveProfileIds: [...effective],
    approvedByCategory,
    garbageProviderIds,
    organizationIds,
    activeOrganizationId,
    isProvider:
      effective.size > 0 || garbageProviderIds.length > 0,
  };
}

export type ProviderRequestAccess =
  | { allowed: true; assigned: boolean; serviceType: 'moving' | 'garbage' | 'laundry' }
  | { allowed: false; reason: string };

/**
 * Decide whether a provider context may access a specific request, and whether
 * the access is via explicit assignment (full detail) or discovery (masked).
 */
export async function canAccessProviderRequest(
  context: ProviderContext,
  requestId: string,
): Promise<ProviderRequestAccess> {
  if (!context.isProvider) {
    return { allowed: false, reason: 'Not an approved service provider' };
  }

  // Moving
  const moving = await pool.query<{ provider_id: string | null; status: string }>(
    `SELECT provider_id, status::text as status FROM moving_requests WHERE id = $1`,
    [requestId],
  );
  if (moving.rows[0]) {
    const row = moving.rows[0];
    if (row.provider_id && context.effectiveProfileIds.includes(row.provider_id)) {
      return { allowed: true, assigned: true, serviceType: 'moving' };
    }
    if (row.provider_id === null && row.status === 'submitted') {
      if (!(await contextHasEligibleOffering(context.effectiveProfileIds, 'moving'))) {
        return { allowed: false, reason: 'No active moving service offering' };
      }
      return { allowed: true, assigned: false, serviceType: 'moving' };
    }
    return { allowed: false, reason: 'Request not available to this provider' };
  }

  // Laundry
  const laundry = await pool.query<{ provider_id: string | null; status: string }>(
    `SELECT provider_id, status::text as status FROM laundry_requests WHERE id = $1`,
    [requestId],
  );
  if (laundry.rows[0]) {
    const row = laundry.rows[0];
    if (row.provider_id && context.effectiveProfileIds.includes(row.provider_id)) {
      return { allowed: true, assigned: true, serviceType: 'laundry' };
    }
    if (row.provider_id === null && row.status === 'submitted') {
      if (!(await contextHasEligibleOffering(context.effectiveProfileIds, 'laundry'))) {
        return { allowed: false, reason: 'No active laundry service offering' };
      }
      return { allowed: true, assigned: false, serviceType: 'laundry' };
    }
    return { allowed: false, reason: 'Request not available to this provider' };
  }

  // Garbage
  const garbage = await pool.query<{ garbage_provider_id: string | null }>(
    `SELECT garbage_provider_id FROM garbage_collection_requests WHERE id = $1`,
    [requestId],
  );
  if (garbage.rows[0]) {
    const row = garbage.rows[0];
    if (row.garbage_provider_id && context.garbageProviderIds.includes(row.garbage_provider_id)) {
      return { allowed: true, assigned: true, serviceType: 'garbage' };
    }
    return { allowed: false, reason: 'Request not available to this provider' };
  }

  return { allowed: false, reason: 'Request not found' };
}