// Provider reporting service (Task 13.16). Date/domain/category-filtered
// operational, service-performance and customer-experience aggregates computed
// from authoritative records via the shared dashboard repository.
import { ForbiddenError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import type { ProviderDashboardFilters } from '../provider-dashboard/provider-dashboard.types.js';
import * as repo from '../provider-dashboard/provider-dashboard.repository.js';

async function loadScope(userId: string, organizationId: string | null | undefined) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  let orgScope: string | null = null;
  if (context.activeOrganizationId) {
    const roleIds = await authz.getUserOrganizationRoleIds(userId, context.activeOrganizationId);
    if (roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r)) ||
        (await authz.hasPermission(userId, 'provider.reports.view_org'))) {
      orgScope = context.activeOrganizationId;
    }
  }
  return { profiles: context.effectiveProfileIds, orgScope };
}

export async function getOperationalReport(userId: string, organizationId: string | null | undefined, filters: ProviderDashboardFilters) {
  const { profiles, orgScope } = await loadScope(userId, organizationId);
  return repo.getReport(profiles, orgScope, filters);
}

export async function getServicePerformance(userId: string, organizationId: string | null | undefined) {
  const { profiles, orgScope } = await loadScope(userId, organizationId);
  return repo.getCategoryPerformance(profiles, orgScope);
}

export async function getCustomerExperience(userId: string, organizationId: string | null | undefined) {
  const { profiles } = await loadScope(userId, organizationId);
  const { pool } = await import('../../db/pool.js');
  const dist = await pool.query(
    `SELECT overall_rating AS rating, COUNT(*)::int AS n
       FROM provider_reviews WHERE provider_profile_id = ANY($1::uuid[]) AND status = 'published'
      GROUP BY overall_rating ORDER BY overall_rating`,
    [profiles],
  );
  const complaints = await pool.query(
    `SELECT status, COUNT(*)::int AS n FROM complaints
      WHERE provider_profile_id = ANY($1::uuid[]) GROUP BY status`,
    [profiles],
  );
  return { ratingDistribution: dist.rows, complaintsByStatus: complaints.rows };
}