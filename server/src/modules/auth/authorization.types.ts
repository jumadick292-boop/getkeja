export interface Permission {
  id: string;
  name: string;
  description: string | null;
  category: string;
  isSystem: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface Role {
  id: string;
  name: string;
  description: string | null;
  isSystem: boolean;
  isPubliclyAssignable: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export type RoleAssignmentScope = 'global' | 'organization' | 'resource';

export interface RoleAssignment {
  id: string;
  userId: string;
  roleId: string;
  scope: RoleAssignmentScope;
  organizationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  assignedBy: string | null;
  assignedAt: Date;
  expiresAt: Date | null;
  revokedAt: Date | null;
  revokedBy: string | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OrganisationInvitation {
  id: string;
  organisationId: string;
  email: string;
  role: string;
  invitedBy: string;
  tokenHash: string;
  status: 'pending' | 'accepted' | 'expired' | 'revoked';
  expiresAt: Date;
  acceptedAt: Date | null;
  acceptedBy: string | null;
  revokedAt: Date | null;
  revokedBy: string | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OrganisationMember {
  id: string;
  organisationId: string;
  userId: string;
  role: string;
  status: 'active' | 'invited' | 'suspended' | 'removed';
  invitedBy: string | null;
  invitedAt: Date | null;
  joinedAt: Date | null;
  removedAt: Date | null;
  removedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Organisation {
  id: string;
  name: string;
  slug: string;
  type: string;
  description: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  address: string | null;
  city: string | null;
  county: string | null;
  country: string;
  registrationNumber: string | null;
  taxId: string | null;
  logoUrl: string | null;
  websiteUrl: string | null;
  isVerified: boolean;
  verificationStatus: 'pending' | 'in_review' | 'verified' | 'rejected';
  verificationNotes: string | null;
  verifiedAt: Date | null;
  verifiedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthorizationContext {
  userId: string;
  sessionId: string;
  permission: string;
  resourceType?: string;
  resourceId?: string;
  organizationId?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Record<string, unknown>;
}

export interface AuthorizationDecision {
  allowed: boolean;
  reason: string;
  matchedRoles: string[];
  matchedPermissions: string[];
  matchedAssignments: RoleAssignment[];
  requiredMfa?: boolean;
  mfaMethods?: string[];
}

export interface ResolvedPermissions {
  permissions: Set<string>;
  roles: Set<string>;
  assignments: RoleAssignment[];
  organizationMemberships: OrganisationMember[];
  globalRoles: string[];
  cached: boolean;
  resolvedAt: Date;
}

export interface AuthorizationAuditEvent {
  id: string;
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
  createdAt: Date;
}

export interface RoleWithPermissions extends Role {
  permissions: Permission[];
}

export interface UserAuthorizationProfile {
  userId: string;
  globalRoles: string[];
  organizationMemberships: OrganisationMember[];
  roleAssignments: RoleAssignment[];
  permissions: Set<string>;
  isActive: boolean;
  isSuspended: boolean;
  isLocked: boolean;
  isDeactivated: boolean;
  mfaEnabled: boolean;
  mfaEnrolledAt: Date | null;
  lastMfaVerifiedAt: Date | null;
}

export interface CreateRoleAssignmentInput {
  userId: string;
  roleId: string;
  scope: RoleAssignmentScope;
  organizationId?: string;
  resourceType?: string;
  resourceId?: string;
  assignedBy?: string;
  expiresAt?: Date;
}

export interface UpdateRoleAssignmentInput {
  expiresAt?: Date | null;
  revokedAt?: Date | null;
  revokedBy?: string;
  revokedReason?: string;
}

export interface CreateOrganisationInvitationInput {
  organisationId: string;
  email: string;
  role: string;
  invitedBy: string;
  expiresAt?: Date;
}

export interface AcceptInvitationInput {
  token: string;
  userId: string;
}