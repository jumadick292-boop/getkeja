// Provider controller — provider-facing HTTP handlers under /api/v1/provider.
import type { Request, Response } from 'express';
import { ForbiddenError, ValidationError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import * as profileService from '../profile/profile.service.js';
import * as orgService from '../auth/organisation.service.js';
import * as authz from '../auth/authorization.service.js';
import type {
  CreateOrganisationInput,
  UpdateOrganisationInput,
  CreateInvitationInput,
  UpdateMemberInput,
} from '../auth/organisation.service.js';
import type {
  CreateSpecializedProfileInput,
  UpdateSpecializedProfileInput,
} from '../profile/profile.schema.js';
import * as service from './provider.service.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

/**
 * GET /api/v1/provider/dashboard
 */
export async function getProviderDashboard(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = (req.query.organizationId as string | undefined) ?? null;
  const counts = await service.getProviderDashboard(userId, organizationId);
  res.json({ success: true, data: counts });
}

/**
 * GET /api/v1/provider/requests
 */
export async function getProviderRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as {
    serviceType?: 'moving' | 'garbage' | 'laundry';
    status?: string;
    organizationId?: string;
    limit?: number;
    offset?: number;
  };
  const result = await service.getProviderInbox(
    userId,
    {
      serviceType: q.serviceType,
      status: q.status,
      limit: q.limit ?? 20,
      offset: q.offset ?? 0,
    },
    q.organizationId ?? null,
  );
  res.json({
    success: true,
    data: result.rows,
    pagination: { limit: q.limit ?? 20, offset: q.offset ?? 0, total: result.total },
  });
}

/**
 * GET /api/v1/provider/requests/:requestId
 */
export async function getProviderRequestDetail(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const requestId = req.params.requestId as string;
  if (!requestId) throw new ValidationError('requestId is required');
  const detail = await service.getProviderRequestDetail(userId, requestId);
  res.json({ success: true, data: detail });
}

/**
 * POST /api/v1/provider/requests/:requestId/respond
 */
export async function respondToProviderRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const requestId = req.params.requestId as string;
  if (!requestId) throw new ValidationError('requestId is required');
  const body = req.body as { action: 'accept' | 'decline'; reason?: string | null };
  const updated = await service.respondToProviderRequest(
    userId,
    requestId,
    body.action,
    body.reason ?? null,
  );
  res.json({ success: true, data: updated });
}

/**
 * GET /api/v1/provider/discovery
 */
export async function discoverProviders(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const q = req.query as {
    category?: 'moving_service_provider' | 'garbage_collection_provider' | 'laundry_service_provider';
    latitude?: number;
    longitude?: number;
    county?: string;
    city?: string;
    limit?: number;
  };
  const providers = await service.discoverProviders({
    category: q.category,
    latitude: q.latitude,
    longitude: q.longitude,
    county: q.county,
    city: q.city,
    limit: q.limit ?? 20,
  });
  res.json({ success: true, data: providers });
}
// ---------------------------------------------------------------------------
// Provider profiles (delegate to the profile module; provider-scoped surface)
// ---------------------------------------------------------------------------

export async function listMyProviderProfiles(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profiles = await profileService.specialized.list(userId);
  res.json({ success: true, data: profiles });
}

export async function createMyProviderProfile(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const input = req.body as CreateSpecializedProfileInput;
  const profile = await profileService.specialized.create(userId, input);
  res.status(201).json({ success: true, data: profile });
}

export async function getMyProviderProfile(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profile = await profileService.specialized.get(req.params.profileId as string, userId);
  res.json({ success: true, data: profile });
}

export async function updateMyProviderProfile(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profile = await profileService.specialized.update(
    req.params.profileId as string,
    userId,
    req.body as UpdateSpecializedProfileInput,
  );
  res.json({ success: true, data: profile });
}

export async function submitMyProviderProfile(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profile = await profileService.specialized.submit(req.params.profileId as string, userId);
  res.json({ success: true, data: profile });
}

// ---------------------------------------------------------------------------
// Provider organizations (delegate to the organisation module)
// ---------------------------------------------------------------------------

export async function listMyOrganizations(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organisations = await orgService.getOrganisations(userId);
  res.json({ success: true, data: organisations });
}

export async function createMyOrganization(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organisation = await orgService.createOrganisation(req.body as CreateOrganisationInput, userId);
  res.status(201).json({ success: true, data: organisation });
}

export async function getMyOrganization(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = req.params.organizationId as string;
  const isMember = await authz.isOrganizationMember(userId, organizationId);
  if (!isMember) throw new ForbiddenError('Organization membership required');
  const organisation = await orgService.getOrganisationById(organizationId);
  res.json({ success: true, data: organisation });
}

export async function updateMyOrganization(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organisation = await orgService.updateOrganisation(
    req.params.organizationId as string,
    userId,
    req.body as UpdateOrganisationInput,
  );
  res.json({ success: true, data: organisation });
}

export async function setMyOrganizationActive(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { active: boolean };
  const organisation = await orgService.deactivateOrganisation(
    req.params.organizationId as string,
    userId,
    body.active,
  );
  res.json({ success: true, data: organisation });
}

// ---------------------------------------------------------------------------
// Organization staff & invitations
// ---------------------------------------------------------------------------

export async function listOrgStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const members = await orgService.getMembers(req.params.organizationId as string, userId);
  res.json({ success: true, data: members });
}

export async function inviteOrgStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const input: CreateInvitationInput = {
    ...(req.body as Omit<CreateInvitationInput, 'invitedBy'>),
    invitedBy: userId,
  };
  const invitation = await orgService.createInvitation(req.params.organizationId as string, userId, input);
  res.status(201).json({ success: true, data: invitation });
}

export async function listOrgInvitations(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const invitations = await orgService.getInvitations(req.params.organizationId as string, userId);
  res.json({ success: true, data: invitations });
}

export async function acceptOrgInvitation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const token = (req.body as { token?: string }).token;
  if (!token) throw new ValidationError('Invitation token required');
  const member = await orgService.acceptInvitation(token, userId);
  res.json({ success: true, data: member });
}

export async function declineOrgInvitation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const token = (req.body as { token?: string }).token;
  if (!token) throw new ValidationError('Invitation token required');
  await orgService.declineInvitation(token, userId);
  res.json({ success: true });
}

export async function revokeOrgInvitation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const reason = (req.body as { reason?: string }).reason ?? 'Revoked by administrator';
  await orgService.revokeInvitation(
    req.params.organizationId as string,
    req.params.invitationId as string,
    userId,
    reason,
  );
  res.json({ success: true });
}

export async function updateOrgStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const member = await orgService.updateMember(
    req.params.organizationId as string,
    req.params.memberId as string,
    userId,
    req.body as UpdateMemberInput,
  );
  res.json({ success: true, data: member });
}

export async function removeOrgStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  await orgService.removeMember(
    req.params.organizationId as string,
    req.params.memberId as string,
    userId,
  );
  res.json({ success: true });
}
