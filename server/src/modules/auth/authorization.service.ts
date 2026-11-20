import { getRedis } from '../../db/redis.js';
import * as repo from './auth.repository.js';
import type {
  AuthUser,
  Permission,
  RoleAssignment,
  OrganisationMember,
  AuthorizationContext,
  AuthorizationDecision,
  ResolvedPermissions,
  AuthorizationAuditEvent,
  UserAuthorizationProfile,
  Property,
  Unit,
  Tenancy,
  PropertyDocument,
  SiteVisit,
  RentalApplication,
} from './auth.types.js';
import type { RoleAssignmentScope } from './authorization.types.js';

const PERMISSION_CACHE_TTL = 300; // 5 minutes
const PERMISSION_CACHE_PREFIX = 'auth:permissions:';
const USER_PERMISSIONS_CACHE_PREFIX = 'auth:user-permissions:';

async function getRedisClient() {
  try {
    return getRedis();
  } catch {
    return null;
  }
}

async function getCachedPermissions(userId: string): Promise<ResolvedPermissions | null> {
  const redis = await getRedisClient();
  if (!redis) return null;
  try {
    const cached = await redis.get(`${USER_PERMISSIONS_CACHE_PREFIX}${userId}`);
    if (cached) {
      const parsed = JSON.parse(cached);
      return {
        ...parsed,
        permissions: new Set(parsed.permissions),
        roles: new Set(parsed.roles),
        resolvedAt: new Date(parsed.resolvedAt),
        cached: true,
      };
    }
  } catch {
    // Redis error, continue without cache
  }
  return null;
}

async function setCachedPermissions(userId: string, permissions: ResolvedPermissions): Promise<void> {
  const redis = await getRedisClient();
  if (!redis) return;
  try {
    const toCache = {
      ...permissions,
      permissions: Array.from(permissions.permissions),
      roles: Array.from(permissions.roles),
      resolvedAt: permissions.resolvedAt.toISOString(),
    };
    await redis.setex(`${USER_PERMISSIONS_CACHE_PREFIX}${userId}`, PERMISSION_CACHE_TTL, JSON.stringify(toCache));
  } catch {
    // Redis error, ignore
  }
}

export async function invalidateUserPermissionCache(userId: string): Promise<void> {
  const redis = await getRedisClient();
  if (!redis) return;
  try {
    await redis.del(`${USER_PERMISSIONS_CACHE_PREFIX}${userId}`);
  } catch {
    // Redis error, ignore
  }
}

export async function invalidateOrganizationPermissionCache(organizationId: string): Promise<void> {
  const redis = await getRedisClient();
  if (!redis) return;
  try {
    // Invalidate all users in this organization - we'd need to track which users belong to which org
    // For now, we'll use a pattern-based approach or rely on TTL
    const keys = await redis.keys(`${USER_PERMISSIONS_CACHE_PREFIX}*`);
    if (keys.length > 0) {
      // This is a simplified approach - in production you'd want a more targeted invalidation
      // For now, we'll rely on TTL and the fact that the cache will be refreshed on next request
    }
  } catch {
    // Redis error, ignore
  }
}

async function buildUserAuthorizationProfile(userId: string): Promise<UserAuthorizationProfile | null> {
  const user = await repo.findUserWithRolesById(userId);
  if (!user) return null;

  const globalRoleIds = await repo.getUserGlobalRoleIds(userId);
  const organizationMemberships = await repo.getUserOrganisationMemberships(userId);
  const roleAssignments = await repo.getUserActiveRoleAssignments(userId);

  const profile: UserAuthorizationProfile = {
    userId,
    globalRoles: globalRoleIds,
    organizationMemberships,
    roleAssignments,
    permissions: new Set(),
    isActive: user.isActive,
    isSuspended: user.isSuspended,
    isLocked: user.isLocked,
    isDeactivated: user.isDeactivated,
    mfaEnabled: user.mfaEnabled,
    mfaEnrolledAt: user.mfaEnrolledAt,
    lastMfaVerifiedAt: user.lastMfaVerifiedAt,
  };

  return profile;
}

async function resolvePermissionsForProfile(profile: UserAuthorizationProfile): Promise<Set<string>> {
  const permissions = new Set<string>();

  // 1. Global role permissions
  for (const roleId of profile.globalRoles) {
    const rolePerms = await repo.getRolePermissions(roleId);
    for (const perm of rolePerms) {
      permissions.add(perm.id);
    }
  }

  // 2. Organization-scoped role permissions
  const orgRoleIds = new Set<string>();
  for (const assignment of profile.roleAssignments) {
    if (assignment.scope === 'organization' && assignment.organizationId) {
      orgRoleIds.add(assignment.roleId);
    }
  }
  for (const roleId of orgRoleIds) {
    const rolePerms = await repo.getRolePermissions(roleId);
    for (const perm of rolePerms) {
      permissions.add(perm.id);
    }
  }

  // 3. Resource-scoped role permissions
  const resourceRoleIds = new Set<string>();
  for (const assignment of profile.roleAssignments) {
    if (assignment.scope === 'resource') {
      resourceRoleIds.add(assignment.roleId);
    }
  }
  for (const roleId of resourceRoleIds) {
    const rolePerms = await repo.getRolePermissions(roleId);
    for (const perm of rolePerms) {
      permissions.add(perm.id);
    }
  }

  return permissions;
}

export async function resolveUserPermissions(userId: string): Promise<ResolvedPermissions> {
  // Try cache first
  const cached = await getCachedPermissions(userId);
  if (cached) {
    return cached;
  }

  const profile = await buildUserAuthorizationProfile(userId);
  if (!profile) {
    return {
      permissions: new Set(),
      roles: new Set(),
      assignments: [],
      organizationMemberships: [],
      globalRoles: [],
      cached: false,
      resolvedAt: new Date(),
    };
  }

  const permissions = await resolvePermissionsForProfile(profile);

  const result: ResolvedPermissions = {
    permissions,
    roles: new Set([...profile.globalRoles, ...profile.roleAssignments.map((a: RoleAssignment) => a.roleId)]),
    assignments: profile.roleAssignments,
    organizationMemberships: profile.organizationMemberships,
    globalRoles: profile.globalRoles,
    cached: false,
    resolvedAt: new Date(),
  };

  await setCachedPermissions(userId, result);
  return result;
}

function checkResourceAccess(
  permission: string,
  resourceType: string | undefined,
  resourceId: string | undefined,
  assignments: RoleAssignment[]
): { allowed: boolean; reason: string; matchedAssignments: RoleAssignment[] } {
  if (!resourceType || !resourceId) {
    // No resource context provided - permission granted based on global/org roles
    return { allowed: true, reason: 'Global or organization-scoped permission', matchedAssignments: [] };
  }

  // Check for explicit resource-scoped assignment
  const resourceAssignments = assignments.filter(
    (a: RoleAssignment) => a.scope === 'resource' && a.resourceType === resourceType && a.resourceId === resourceId
  );

  if (resourceAssignments.length > 0) {
    return {
      allowed: true,
      reason: 'Explicit resource-scoped assignment',
      matchedAssignments: resourceAssignments,
    };
  }

  // Check for organization-scoped assignment that might cover this resource
  // This would require checking if the resource belongs to the organization
  // For now, we'll deny if no explicit resource assignment
  return {
    allowed: false,
    reason: 'No explicit resource-scoped assignment found',
    matchedAssignments: [],
  };
}

export async function authorize(context: AuthorizationContext): Promise<AuthorizationDecision> {
  const { userId, sessionId, permission, resourceType, resourceId, organizationId, ipAddress, userAgent, metadata } = context;

  const toNullable = (val: string | undefined): string | null => val ?? null;

  // 1. Check if user exists and is active
  const user = await repo.findUserWithRolesById(userId);
  if (!user) {
    await auditAuthorization({
      userId,
      sessionId,
      decision: 'deny',
      permissionId: permission,
      resourceType: toNullable(resourceType),
      resourceId: toNullable(resourceId),
      organizationId: toNullable(organizationId),
      ipAddress: toNullable(ipAddress),
      userAgent: toNullable(userAgent),
      metadata: { ...metadata, reason: 'User not found' },
    });
    return {
      allowed: false,
      reason: 'User not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // 2. Check account status
  if (!user.isActive || user.isSuspended || user.isLocked || user.isDeactivated) {
    await auditAuthorization({
      userId,
      sessionId,
      decision: 'deny',
      permissionId: permission,
      resourceType: toNullable(resourceType),
      resourceId: toNullable(resourceId),
      organizationId: toNullable(organizationId),
      ipAddress: toNullable(ipAddress),
      userAgent: toNullable(userAgent),
      metadata: { ...metadata, reason: 'Account inactive', accountStatus: user.accountStatus },
    });
    return {
      allowed: false,
      reason: `Account ${user.accountStatus}`,
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // 3. Resolve user permissions
  const resolved = await resolveUserPermissions(userId);

  // 4. Check if user has the required permission
  const hasPermission = resolved.permissions.has(permission);
  const matchedPermissions = hasPermission ? [permission] : [];
  const matchedRoles = Array.from(resolved.roles);

  let allowed = hasPermission;
  let reason = hasPermission ? 'Permission granted via role' : 'Permission not granted by any role';
  let matchedAssignments: RoleAssignment[] = [];

  // 5. If permission granted, check resource-level access
  if (allowed && resourceType && resourceId) {
    const resourceCheck = checkResourceAccess(permission, resourceType, resourceId, resolved.assignments);
    allowed = resourceCheck.allowed;
    reason = resourceCheck.reason;
    matchedAssignments = resourceCheck.matchedAssignments;
  }

  // 6. Check if organization membership is required and validate
  if (allowed && organizationId) {
    const isMember = resolved.organizationMemberships.some(
      (m: OrganisationMember) => m.organisationId === organizationId && m.status === 'active'
    );
    if (!isMember) {
      allowed = false;
      reason = 'User is not an active member of the required organization';
      matchedAssignments = [];
    }
  }

  // 7. Audit the decision
  await auditAuthorization({
    userId,
    sessionId,
    decision: allowed ? 'allow' : 'deny',
    permissionId: permission,
    resourceType: toNullable(resourceType),
    resourceId: toNullable(resourceId),
    organizationId: toNullable(organizationId),
    ipAddress: toNullable(ipAddress),
    userAgent: toNullable(userAgent),
    metadata: { ...metadata, reason, matchedRoles, matchedPermissions: matchedPermissions.length },
  });

  return {
    allowed,
    reason,
    matchedRoles,
    matchedPermissions,
    matchedAssignments,
  };
}

async function auditAuthorization(data: {
  userId: string | null;
  sessionId: string | null;
  decision: 'allow' | 'deny';
  permissionId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  organizationId: string | null;
  ipAddress: string | null;
  userAgent: string | null;
  metadata: Record<string, unknown>;
}): Promise<void> {
  try {
    await repo.createAuthorizationAuditEvent({
      userId: data.userId,
      action: data.decision,
      resourceType: data.resourceType,
      resourceId: data.resourceId,
      permission: data.permissionId,
      allowed: data.decision === 'allow',
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      metadata: data.metadata,
    });
  } catch {
    // Audit failure should not block the request
    console.error('Failed to write authorization audit event:', data);
  }
}

export async function requirePermission(userId: string, permission: string, resourceContext?: {
  resourceType?: string;
  resourceId?: string;
  organizationId?: string;
}): Promise<AuthorizationDecision> {
  return authorize({
    userId,
    sessionId: '', // Will be filled by middleware
    permission,
    ...resourceContext,
  });
}

export async function hasPermission(userId: string, permission: string): Promise<boolean> {
  const resolved = await resolveUserPermissions(userId);
  return resolved.permissions.has(permission);
}

export async function hasAnyPermission(userId: string, permissions: string[]): Promise<boolean> {
  const resolved = await resolveUserPermissions(userId);
  return permissions.some(p => resolved.permissions.has(p));
}

export async function hasAllPermissions(userId: string, permissions: string[]): Promise<boolean> {
  const resolved = await resolveUserPermissions(userId);
  return permissions.every(p => resolved.permissions.has(p));
}

export async function hasPlatformRole(userId: string, roleId: string): Promise<boolean> {
  const globalRoles = await repo.getUserGlobalRoleIds(userId);
  return globalRoles.includes(roleId);
}

export async function hasSystemRole(userId: string): Promise<boolean> {
  return repo.hasSystemRole(userId);
}

export async function isOrganizationMember(userId: string, organizationId: string): Promise<boolean> {
  const memberships = await repo.getUserOrganisationMemberships(userId);
  return memberships.some(m => m.organisationId === organizationId && m.status === 'active');
}

export async function isOrganizationOwner(userId: string, organizationId: string): Promise<boolean> {
  const memberships = await repo.getUserOrganisationMemberships(userId);
  return memberships.some(m => m.organisationId === organizationId && m.status === 'active' && m.role === 'owner');
}

export async function getUserOrganizations(userId: string): Promise<string[]> {
  const memberships = await repo.getUserOrganisationMemberships(userId);
  return memberships.filter(m => m.status === 'active').map(m => m.organisationId);
}

export async function getUserOrganizationRoleIds(userId: string, organizationId: string): Promise<string[]> {
  const assignments = await repo.getUserActiveRoleAssignments(userId);
  return assignments
    .filter(a => a.scope === 'organization' && a.organizationId === organizationId)
    .map(a => a.roleId);
}

/**
 * Check if user can access a specific property
 */
export async function canAccessProperty(
  userId: string,
  propertyId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const property = await repo.findPropertyById(propertyId);
  if (!property) {
    return {
      allowed: false,
      reason: 'Property not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // If no specific permission required, check if user has any access to this property
  if (!requiredPermission) {
    // Check ownership
    const ownerships = await repo.findPropertyOwnerships(propertyId);
    const isOwner = ownerships.some(o => o.userId === userId && o.status === 'active');
    if (isOwner) {
      return {
        allowed: true,
        reason: 'Property owner',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    // Check property assignments
    const assignments = await repo.findPropertyAssignments(propertyId);
    const hasAssignment = assignments.some(a => a.userId === userId && a.status === 'active');
    if (hasAssignment) {
      return {
        allowed: true,
        reason: 'Property assignment',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    // Check unit access assignments for any unit in this property
    const units = await repo.findUnitsByProperty(propertyId);
    for (const unit of units) {
      const unitAccess = await repo.findUnitAccessAssignments(unit.id);
      const hasUnitAccess = unitAccess.some(a => a.userId === userId && a.status === 'active');
      if (hasUnitAccess) {
        return {
          allowed: true,
          reason: 'Unit access assignment',
          matchedRoles: [],
          matchedPermissions: [],
          matchedAssignments: [],
        };
      }
    }

    // Check if user is a member of the organization that owns/manages this property
    const memberships = await repo.getUserOrganisationMemberships(userId);
    const orgIds = memberships.filter(m => m.status === 'active').map(m => m.organisationId);
    if (property.organisationId && orgIds.includes(property.organisationId)) {
      return {
        allowed: true,
        reason: 'Organization membership',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    return {
      allowed: false,
      reason: 'No access to property',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // If specific permission required, use full authorization
  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'property',
    resourceId: propertyId,
    organizationId: property.organisationId ?? undefined,
  });
}

/**
 * Check if user can access a specific unit
 */
export async function canAccessUnit(
  userId: string,
  unitId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const unit = await repo.findUnitById(unitId);
  if (!unit) {
    return {
      allowed: false,
      reason: 'Unit not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // First check property access
  const propertyAccess = await canAccessProperty(userId, unit.propertyId);
  if (!propertyAccess.allowed) {
    return propertyAccess;
  }

  // If no specific permission required, check unit-level access
  if (!requiredPermission) {
    // Check unit access assignments
    const unitAccess = await repo.findUnitAccessAssignments(unitId);
    const hasUnitAccess = unitAccess.some(a => a.userId === userId && a.status === 'active');
    if (hasUnitAccess) {
      return {
        allowed: true,
        reason: 'Unit access assignment',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    return {
      allowed: true,
      reason: 'Property access grants unit access',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // If specific permission required, use full authorization
  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'unit',
    resourceId: unitId,
    organizationId: unit.propertyId, // Will need to fetch property org ID
  });
}

/**
 * Check if user can access a specific tenancy
 */
export async function canAccessTenancy(
  userId: string,
  tenancyId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const tenancy = await repo.findTenancyById(tenancyId);
  if (!tenancy) {
    return {
      allowed: false,
      reason: 'Tenancy not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // First check property access
  const propertyAccess = await canAccessProperty(userId, tenancy.propertyId);
  if (!propertyAccess.allowed) {
    return propertyAccess;
  }

  // If no specific permission required, check tenancy participation
  if (!requiredPermission) {
    const participants = await repo.findTenancyParticipants(tenancyId);
    const isParticipant = participants.some(p => p.userId === userId && p.status === 'active');
    if (isParticipant) {
      return {
        allowed: true,
        reason: 'Tenancy participant',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    // Check if managed by user
    if (tenancy.managedByUserId === userId) {
      return {
        allowed: true,
        reason: 'Tenancy manager',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    // Check if managed by user's organization
    if (tenancy.managedByOrganisationId) {
      const memberships = await repo.getUserOrganisationMemberships(userId);
      const orgIds = memberships.filter(m => m.status === 'active').map(m => m.organisationId);
      if (orgIds.includes(tenancy.managedByOrganisationId)) {
        return {
          allowed: true,
          reason: 'Organization manages tenancy',
          matchedRoles: [],
          matchedPermissions: [],
          matchedAssignments: [],
        };
      }
    }

    return {
      allowed: false,
      reason: 'Not a participant or manager of this tenancy',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // If specific permission required, use full authorization
  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'tenancy',
    resourceId: tenancyId,
  });
}

/**
 * Check if user can access a specific property document
 */
export async function canAccessPropertyDocument(
  userId: string,
  documentId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const document = await repo.findPropertyDocumentById(documentId);
  if (!document) {
    return {
      allowed: false,
      reason: 'Document not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // Check property access first
  const propertyAccess = await canAccessProperty(userId, document.propertyId);
  if (!propertyAccess.allowed) {
    return propertyAccess;
  }

  // If no specific permission required, check document access level
  if (!requiredPermission) {
    // Check if user is a tenant in any tenancy for this property
    const tenancies = await repo.findPropertyDocumentsByTenancy(document.tenancyId || '');
    // This is a simplified check - in reality you'd check document visibility settings
    return {
      allowed: true,
      reason: 'Property access grants document access',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'document',
    resourceId: documentId,
  });
}

/**
 * Check if user can access a specific site visit
 */
export async function canAccessSiteVisit(
  userId: string,
  visitId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) {
    return {
      allowed: false,
      reason: 'Site visit not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // Check property access first
  const propertyAccess = await canAccessProperty(userId, visit.propertyId);
  if (!propertyAccess.allowed) {
    return propertyAccess;
  }

  // If no specific permission required, check visit participant
  if (!requiredPermission) {
    // Check if user is the visitor or host
    if (visit.userId === userId || visit.hostedByUserId === userId) {
      return {
        allowed: true,
        reason: 'Site visit participant',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    return {
      allowed: false,
      reason: 'Not a participant in this site visit',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'site_visit',
    resourceId: visitId,
  });
}

/**
 * Check if user can access a specific rental application
 */
export async function canAccessRentalApplication(
  userId: string,
  applicationId: string,
  requiredPermission?: string
): Promise<AuthorizationDecision> {
  const application = await repo.findRentalApplicationById(applicationId);
  if (!application) {
    return {
      allowed: false,
      reason: 'Rental application not found',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  // Check property access first
  const propertyAccess = await canAccessProperty(userId, application.propertyId);
  if (!propertyAccess.allowed) {
    return propertyAccess;
  }

  // If no specific permission required, check application access
  if (!requiredPermission) {
    // Applicant can always access their own application
    if (application.userId === userId) {
      return {
        allowed: true,
        reason: 'Application applicant',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    // Property owner/manager can access applications
    const ownerships = await repo.findPropertyOwnerships(application.propertyId);
    const isOwner = ownerships.some(o => o.userId === userId && o.status === 'active');
    if (isOwner) {
      return {
        allowed: true,
        reason: 'Property owner',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    const assignments = await repo.findPropertyAssignments(application.propertyId);
    const hasAssignment = assignments.some(a => a.userId === userId && a.status === 'active');
    if (hasAssignment) {
      return {
        allowed: true,
        reason: 'Property assignment',
        matchedRoles: [],
        matchedPermissions: [],
        matchedAssignments: [],
      };
    }

    return {
      allowed: false,
      reason: 'Not authorized to view this rental application',
      matchedRoles: [],
      matchedPermissions: [],
      matchedAssignments: [],
    };
  }

  return authorize({
    userId,
    sessionId: '',
    permission: requiredPermission,
    resourceType: 'rental_application',
    resourceId: applicationId,
  });
}