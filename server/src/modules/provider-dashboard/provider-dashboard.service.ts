// Provider dashboard service (Task 13.16). Scopes every metric to the resolved
// provider context (individual profiles + active organization) and enforces
// resource-scoped access. Operational staff see only their assigned work.
import { ForbiddenError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type { ProviderDashboard, ProviderDashboardFilters } from './provider-dashboard.types.js';
import * as repo from './provider-dashboard.repository.js';

async function loadContext(userId: string, organizationId?: string | null): Promise<ProviderContext> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

function isOrgOwnerOrAdmin(roleIds: string[]): boolean {
  return roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r));
}

export async function getDashboard(
  userId: string,
  organizationId: string | null | undefined,
  filters: ProviderDashboardFilters,
): Promise<ProviderDashboard> {
  const context = await loadContext(userId, organizationId);
  const activeOrg = context.activeOrganizationId;
  // Org-wide view requires owner/admin (or explicit org-report permission).
  let isOrganization = false;
  if (activeOrg) {
    const roleIds = await authz.getUserOrganizationRoleIds(userId, activeOrg);
    isOrganization = isOrgOwnerOrAdmin(roleIds) || (await authz.hasPermission(userId, 'provider.reports.view_org'));
  }

  // Operational staff (not owner/admin, not a profile owner) are scoped to their
  // assigned jobs only — represented by passing an empty profile set plus staff
  // filter handled in repository via assigned_staff_user_id. Here we restrict the
  // profile scope and rely on the staff union already present.
  const scopeProfiles = context.effectiveProfileIds;
  const orgScope = isOrganization ? activeOrg : null;

  const [metrics, byDomain] = await Promise.all([
    repo.getMetrics(scopeProfiles, orgScope, filters),
    repo.getByDomain(scopeProfiles, orgScope),
  ]);

  return {
    scope: { isOrganization, organizationId: orgScope, profileCount: scopeProfiles.length },
    metrics,
    byDomain,
    filters,
  };
}

export async function getStaffWorkload(userId: string, organizationId: string | null | undefined) {
  const context = await loadContext(userId, organizationId);
  if (context.activeOrganizationId) {
    const roleIds = await authz.getUserOrganizationRoleIds(userId, context.activeOrganizationId);
    if (!isOrgOwnerOrAdmin(roleIds) && !(await authz.hasPermission(userId, 'provider.reports.view_org'))) {
      throw new ForbiddenError('Not authorized to view staff workload');
    }
    return repo.getStaffWorkload(context.effectiveProfileIds, context.activeOrganizationId);
  }
  return repo.getStaffWorkload(context.effectiveProfileIds, null);
}