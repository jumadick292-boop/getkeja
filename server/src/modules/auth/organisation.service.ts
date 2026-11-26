import { randomUUID, createHash } from 'node:crypto';
import * as repo from './auth.repository.js';
import { ForbiddenError, NotFoundError, ConflictError } from '../../shared/errors.js';
import type { Organisation, OrganisationMember, OrganisationInvitation } from './auth.types.js';
import * as authz from './authorization.service.js';

export interface CreateOrganisationInput {
  name: string;
  slug: string;
  type: string;
  description?: string | null;
  contactEmail?: string | null;
  contactPhone?: string | null;
  address?: string | null;
  city?: string | null;
  county?: string | null;
  country?: string;
  registrationNumber?: string | null;
  taxId?: string | null;
  logoUrl?: string | null;
  websiteUrl?: string | null;
}

export interface UpdateOrganisationInput {
  name?: string;
  description?: string | null;
  contactEmail?: string | null;
  contactPhone?: string | null;
  address?: string | null;
  city?: string | null;
  county?: string | null;
  country?: string;
  registrationNumber?: string | null;
  taxId?: string | null;
  logoUrl?: string | null;
  websiteUrl?: string | null;
}

export interface CreateInvitationInput {
  email: string;
  role: 'owner' | 'admin' | 'member' | 'staff';
  invitedBy: string;
  expiresAt?: Date;
}

export interface UpdateMemberInput {
  role?: 'owner' | 'admin' | 'member' | 'staff';
  status?: 'active' | 'suspended' | 'removed';
  removedBy?: string;
}

// Map an organization membership role to a concrete RBAC role id.
function mapOrgRoleToRoleId(role: string): string {
  switch (role) {
    case 'owner':
      return 'organization_owner';
    case 'admin':
      return 'organization_admin';
    case 'member':
    case 'staff':
    default:
      return 'organization_member';
  }
}

export async function createOrganisation(input: CreateOrganisationInput, ownerId: string): Promise<Organisation> {
  const existing = await repo.findOrganisationBySlug(input.slug);
  if (existing) {
    throw new ConflictError('Organization slug already exists');
  }

  const organisation = await repo.createOrganisation(input);

  // Add creator as active owner
  await repo.addActiveOrganisationMember(organisation.id, ownerId, 'owner');

  // Create global role assignment for organization owner
  await repo.createRoleAssignment({
    userId: ownerId,
    roleId: 'organization_owner',
    scope: 'organization',
    organizationId: organisation.id,
    resourceType: null,
    resourceId: null,
    assignedBy: ownerId,
    expiresAt: null,
  });

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId: ownerId,
    action: 'create_organization',
    resourceType: 'organization',
    resourceId: organisation.id,
    permission: 'organization.create',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'create_organization', organizationName: input.name },
  });

  return organisation;
}

export async function getOrganisations(userId: string): Promise<Organisation[]> {
  const memberships = await repo.getUserOrganisationMemberships(userId);
  const orgIds = memberships.filter(m => m.status === 'active').map(m => m.organisationId);

  const organisations: Organisation[] = [];
  for (const orgId of orgIds) {
    const organisation = await repo.findOrganisationById(orgId);
    if (organisation) {
      organisations.push(organisation);
    }
  }

  return organisations;
}

export async function getOrganisationById(organisationId: string): Promise<Organisation | undefined> {
  return repo.findOrganisationById(organisationId);
}

export async function updateOrganisation(
  organisationId: string,
  userId: string,
  input: UpdateOrganisationInput
): Promise<Organisation> {
  // Check permission
  const isOwner = await authz.isOrganizationOwner(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.update');

  if (!isOwner && !hasPermission) {
    throw new ForbiddenError('Insufficient permissions to update organization');
  }

  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (input.name !== undefined) {
    fields.push(`name = $${paramIndex++}`);
    values.push(input.name);
  }
  if (input.description !== undefined) {
    fields.push(`description = $${paramIndex++}`);
    values.push(input.description);
  }
  if (input.contactEmail !== undefined) {
    fields.push(`contact_email = $${paramIndex++}`);
    values.push(input.contactEmail);
  }
  if (input.contactPhone !== undefined) {
    fields.push(`contact_phone = $${paramIndex++}`);
    values.push(input.contactPhone);
  }
  if (input.address !== undefined) {
    fields.push(`address = $${paramIndex++}`);
    values.push(input.address);
  }
  if (input.city !== undefined) {
    fields.push(`city = $${paramIndex++}`);
    values.push(input.city);
  }
  if (input.county !== undefined) {
    fields.push(`county = $${paramIndex++}`);
    values.push(input.county);
  }
  if (input.country !== undefined) {
    fields.push(`country = $${paramIndex++}`);
    values.push(input.country);
  }
  if (input.registrationNumber !== undefined) {
    fields.push(`registration_number = $${paramIndex++}`);
    values.push(input.registrationNumber);
  }
  if (input.taxId !== undefined) {
    fields.push(`tax_id = $${paramIndex++}`);
    values.push(input.taxId);
  }
  if (input.logoUrl !== undefined) {
    fields.push(`logo_url = $${paramIndex++}`);
    values.push(input.logoUrl);
  }
  if (input.websiteUrl !== undefined) {
    fields.push(`website_url = $${paramIndex++}`);
    values.push(input.websiteUrl);
  }

  if (fields.length === 0) {
    const org = await getOrganisationById(organisationId);
    if (!org) throw new NotFoundError('Organization not found');
    return org;
  }

fields.push(`updated_at = NOW()`);
  values.push(organisationId);

  const organisation = await repo.updateOrganisation(organisationId, {
    name: input.name,
    description: input.description,
    contactEmail: input.contactEmail,
    contactPhone: input.contactPhone,
    address: input.address,
    city: input.city,
    county: input.county,
    country: input.country,
    registrationNumber: input.registrationNumber,
    taxId: input.taxId,
    logoUrl: input.logoUrl,
    websiteUrl: input.websiteUrl,
  });

  if (!organisation) {
    throw new NotFoundError('Organization not found');
  }

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'update_organization',
    resourceType: 'organization',
    resourceId: organisationId,
    permission: 'organization.update',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'update_organization', changes: input },
  });

  return organisation;
}

export async function createInvitation(
  organisationId: string,
  userId: string,
  input: CreateInvitationInput
): Promise<OrganisationInvitation & { token: string }> {
  // Check if user has permission to invite
  const isMember = await authz.isOrganizationMember(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.manage_members');

  if (!isMember && !hasPermission) {
    throw new ForbiddenError('Organization membership required to send invitations');
  }

  // Check if organization exists
  const organisation = await getOrganisationById(organisationId);
  if (!organisation) {
    throw new NotFoundError('Organization not found');
  }

  // Check if there's already a pending invitation
  const existing = await repo.findPendingOrganisationInvitation(organisationId, input.email);
  if (existing) {
    throw new ConflictError('Pending invitation already exists for this email');
  }

  // Check if user is already a member
  const members = await repo.getOrganisationMembers(organisationId);
  const existingMember = members.find(m => m.email === input.email);
  if (existingMember) {
    throw new ConflictError('User is already a member of this organization');
  }

  const rawToken = randomUUID();
  const invitation = await repo.createOrganisationInvitation({
    organisationId,
    email: input.email,
    role: input.role,
    invitedBy: input.invitedBy,
    tokenHash: createHash('sha256').update(rawToken).digest('hex'),
    expiresAt: input.expiresAt ?? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days default
  });

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId: input.invitedBy,
    action: 'create_invitation',
    resourceType: 'organization_invitation',
    resourceId: invitation.id,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'create_invitation', email: input.email, role: input.role },
  });

  return { ...invitation, token: rawToken };
}

export async function acceptInvitation(token: string, userId: string): Promise<OrganisationMember> {
  const tokenHash = createHash('sha256').update(token).digest('hex');
  const invitation = await repo.findOrganisationInvitationByTokenHash(tokenHash);

  if (!invitation) {
    throw new NotFoundError('Invalid or expired invitation');
  }

  if (invitation.status !== 'pending') {
    throw new ForbiddenError('Invitation has already been used or revoked');
  }

  if (invitation.expiresAt < new Date()) {
    throw new ForbiddenError('Invitation has expired');
  }

  // Verify the user matches the invitation email
  const user = await repo.findUserById(userId);
  if (!user || user.email.toLowerCase() !== invitation.email.toLowerCase()) {
    throw new ForbiddenError('This invitation is for a different email address');
  }

  const acceptedInvitation = await repo.acceptOrganisationInvitation(invitation.id, userId);
  if (!acceptedInvitation) {
    throw new ForbiddenError('Failed to accept invitation');
  }

  // Ensure an active membership row exists for the accepting user.
  const existingMembers = await repo.getOrganisationMembers(invitation.organisationId);
  if (!existingMembers.some((m) => m.userId === userId)) {
    await repo.addActiveOrganisationMember(invitation.organisationId, userId, invitation.role);
  }

  // Create role assignment for the organization role
  await repo.createRoleAssignment({
    userId,
    roleId: mapOrgRoleToRoleId(invitation.role),
    scope: 'organization',
    organizationId: invitation.organisationId,
    resourceType: null,
    resourceId: null,
    assignedBy: invitation.invitedBy,
    expiresAt: null,
  });

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'accept_invitation',
    resourceType: 'organization_invitation',
    resourceId: invitation.id,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'accept_invitation', role: invitation.role },
  });

  // Return the created member
  const members = await repo.getOrganisationMembers(invitation.organisationId);
  const member = members.find(m => m.userId === userId);
  if (!member) {
    throw new Error('Member not found after accepting invitation');
  }

  return member;
}

export async function getMembers(organisationId: string, userId: string): Promise<OrganisationMember[]> {
  const isMember = await authz.isOrganizationMember(userId, organisationId);
  if (!isMember) {
    throw new ForbiddenError('Organization membership required');
  }

  return repo.getOrganisationMembers(organisationId);
}

export async function updateMember(
  organisationId: string,
  memberId: string,
  userId: string,
  input: UpdateMemberInput
): Promise<OrganisationMember> {
  const isOwner = await authz.isOrganizationOwner(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.manage_members');

  if (!isOwner && !hasPermission) {
    throw new ForbiddenError('Insufficient permissions to manage members');
  }

  // Get the member
  const member = await repo.findOrganisationMemberById(memberId);
  if (!member || member.organisationId !== organisationId) {
    throw new NotFoundError('Member not found');
  }

  // Prevent removing the last owner
  if (input.status === 'removed' && member.role === 'owner') {
    const isLastOwner = await repo.isLastOwner(organisationId, member.userId);
    if (isLastOwner) {
      throw new ForbiddenError('Cannot remove the last organization owner');
    }
  }

  // Prevent self-removal if owner
  if (member.userId === userId && member.role === 'owner' && input.status === 'removed') {
    const isLastOwner = await repo.isLastOwner(organisationId, userId);
    if (isLastOwner) {
      throw new ForbiddenError('Cannot remove yourself as the last owner');
    }
  }

  const updated = await repo.updateOrganisationMember(memberId, {
    role: input.role,
    status: input.status,
    removedBy: input.removedBy,
  });

  if (!updated) {
    throw new NotFoundError('Member not found');
  }

  // Update role assignment if role changed
  if (input.role && input.role !== member.role) {
    // Revoke old role assignment
    const assignments = await repo.getUserActiveRoleAssignments(member.userId);
    const oldAssignment = assignments.find(
      a => a.scope === 'organization' && a.organizationId === organisationId && a.roleId === member.role
    );
    if (oldAssignment) {
      await repo.revokeRoleAssignment(oldAssignment.id, userId, 'Role changed');
    }

    // Create new role assignment
    await repo.createRoleAssignment({
      userId: member.userId,
      roleId: mapOrgRoleToRoleId(input.role),
      scope: 'organization',
      organizationId: organisationId,
      resourceType: null,
      resourceId: null,
      assignedBy: userId,
      expiresAt: null,
    });

    // Invalidate permission cache
    await authz.invalidateUserPermissionCache(member.userId);
  }

  // Revoke role assignments if member removed
  if (input.status === 'removed') {
    const assignments = await repo.getUserActiveRoleAssignments(member.userId);
    for (const assignment of assignments) {
      if (assignment.scope === 'organization' && assignment.organizationId === organisationId) {
        await repo.revokeRoleAssignment(assignment.id, userId, 'Member removed');
      }
    }
    await authz.invalidateUserPermissionCache(member.userId);
  }

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'update_member',
    resourceType: 'organization_member',
    resourceId: memberId,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'update_member', changes: input, targetUserId: member.userId },
  });

  return updated;
}

export async function removeMember(
  organisationId: string,
  memberId: string,
  userId: string
): Promise<void> {
  const isOwner = await authz.isOrganizationOwner(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.manage_members');

  if (!isOwner && !hasPermission) {
    throw new ForbiddenError('Insufficient permissions to remove members');
  }

  const member = await repo.findOrganisationMemberById(memberId);
  if (!member || member.organisationId !== organisationId) {
    throw new NotFoundError('Member not found');
  }

  // Prevent removing the last owner
  if (member.role === 'owner') {
    const isLastOwner = await repo.isLastOwner(organisationId, member.userId);
    if (isLastOwner) {
      throw new ForbiddenError('Cannot remove the last organization owner');
    }
  }

  // Prevent self-removal if owner
  if (member.userId === userId && member.role === 'owner') {
    const isLastOwner = await repo.isLastOwner(organisationId, userId);
    if (isLastOwner) {
      throw new ForbiddenError('Cannot remove yourself as the last owner');
    }
  }

  await repo.updateOrganisationMember(memberId, {
    status: 'removed',
    removedBy: userId,
  });

  // Revoke all organization-scoped role assignments
  const assignments = await repo.getUserActiveRoleAssignments(member.userId);
  for (const assignment of assignments) {
    if (assignment.scope === 'organization' && assignment.organizationId === organisationId) {
      await repo.revokeRoleAssignment(assignment.id, userId, 'Member removed');
    }
  }

  await authz.invalidateUserPermissionCache(member.userId);

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'remove_member',
    resourceType: 'organization_member',
    resourceId: memberId,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'remove_member', targetUserId: member.userId, targetRole: member.role },
  });
}

export async function getInvitations(organisationId: string, userId: string): Promise<OrganisationInvitation[]> {
  const isMember = await authz.isOrganizationMember(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.manage_members');

  if (!isMember && !hasPermission) {
    throw new ForbiddenError('Organization membership required');
  }

  return repo.getOrganisationInvitations(organisationId);
}

export async function revokeInvitation(
  organisationId: string,
  invitationId: string,
  userId: string,
  reason: string
): Promise<void> {
  const isMember = await authz.isOrganizationMember(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.manage_members');

  if (!isMember && !hasPermission) {
    throw new ForbiddenError('Organization membership required');
  }

  const invitation = await repo.findOrganisationInvitationById(invitationId);
  if (!invitation || invitation.organisationId !== organisationId) {
    throw new NotFoundError('Invitation not found');
  }

  await repo.revokeOrganisationInvitation(invitationId, userId, reason);

  // Audit
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'revoke_invitation',
    resourceType: 'organization_invitation',
    resourceId: invitationId,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'revoke_invitation', email: invitation.email, reason },
  });
}

/**
 * Decline a pending invitation. The recipient must own the invitation email.
 * The token is hashed and matched; replay/expiry are enforced.
 */
export async function declineInvitation(token: string, userId: string): Promise<void> {
  const tokenHash = createHash('sha256').update(token).digest('hex');
  const invitation = await repo.findOrganisationInvitationByTokenHash(tokenHash);
  if (!invitation) throw new NotFoundError('Invalid or expired invitation');
  if (invitation.status !== 'pending') {
    throw new ForbiddenError('Invitation has already been used or revoked');
  }
  if (invitation.expiresAt < new Date()) {
    throw new ForbiddenError('Invitation has expired');
  }
  const user = await repo.findUserById(userId);
  if (!user || user.email.toLowerCase() !== invitation.email.toLowerCase()) {
    throw new ForbiddenError('This invitation is for a different email address');
  }
  await repo.declineOrganisationInvitation(invitation.id, userId);
  await repo.createAuthorizationAuditEvent({
    userId,
    action: 'decline_invitation',
    resourceType: 'organization_invitation',
    resourceId: invitation.id,
    permission: 'organization.manage_members',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'decline_invitation' },
  });
}

/**
 * Deactivate an organization. Owner/admin only. Inactive organizations are
 * excluded from provider context resolution and do not receive requests.
 */
export async function deactivateOrganisation(
  organisationId: string,
  userId: string,
  active: boolean,
): Promise<Organisation> {
  const isOwner = await authz.isOrganizationOwner(userId, organisationId);
  const hasPermission = await authz.hasPermission(userId, 'organization.update');
  if (!isOwner && !hasPermission) {
    throw new ForbiddenError('Insufficient permissions to change organization status');
  }
  const updated = await repo.setOrganisationActive(organisationId, active, userId);
  if (!updated) throw new NotFoundError('Organization not found');
  await repo.createAuthorizationAuditEvent({
    userId,
    action: active ? 'reactivate_organization' : 'deactivate_organization',
    resourceType: 'organization',
    resourceId: organisationId,
    permission: 'organization.update',
    allowed: true,
    ipAddress: null,
    userAgent: null,
    metadata: { action: 'organization_status', active },
  });
  return updated;
}