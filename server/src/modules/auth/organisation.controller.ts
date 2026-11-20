import type { Request, Response, NextFunction } from 'express';
import * as orgService from './organisation.service.js';
import * as authz from './authorization.service.js';
import { ForbiddenError, NotFoundError } from '../../shared/errors.js';
import type { CreateOrganisationInput, UpdateOrganisationInput, CreateInvitationInput, UpdateMemberInput } from './organisation.service.js';

function getParamValue(req: Request, param: string): string | undefined {
  const value = req.params[param];
  return Array.isArray(value) ? value[0] : value;
}

export async function createOrganisation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const input: CreateOrganisationInput = req.body;
    const organisation = await orgService.createOrganisation(input, userId);
    res.status(201).json({ organisation });
  } catch (error) {
    next(error);
  }
}

export async function getOrganisations(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organisations = await orgService.getOrganisations(userId);
    res.json({ organisations });
  } catch (error) {
    next(error);
  }
}

export async function getOrganisation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;

    const isMember = await authz.isOrganizationMember(userId, organizationId);
    if (!isMember) {
      throw new ForbiddenError('Organization membership required');
    }

    const organisation = await orgService.getOrganisationById(organizationId);
    if (!organisation) {
      throw new NotFoundError('Organization not found');
    }

    res.json({ organisation });
  } catch (error) {
    next(error);
  }
}

export async function updateOrganisation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;
    const input: UpdateOrganisationInput = req.body;

    const organisation = await orgService.updateOrganisation(organizationId, userId, input);
    res.json({ organisation });
  } catch (error) {
    next(error);
  }
}

export async function createInvitation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;
    const input: CreateInvitationInput = { ...req.body, invitedBy: userId };

    const invitation = await orgService.createInvitation(organizationId, userId, input);
    res.status(201).json({ invitation });
  } catch (error) {
    next(error);
  }
}

export async function acceptInvitation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const { token } = req.body;

    if (!token) {
      throw new Error('Invitation token required');
    }

    const member = await orgService.acceptInvitation(token, userId);
    res.json({ member });
  } catch (error) {
    next(error);
  }
}

export async function getInvitations(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;

    const invitations = await orgService.getInvitations(organizationId, userId);
    res.json({ invitations });
  } catch (error) {
    next(error);
  }
}

export async function revokeInvitation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;
    const invitationId = getParamValue(req, 'invitationId')!;
    const { reason } = req.body;

    await orgService.revokeInvitation(organizationId, invitationId, userId, reason || 'Revoked by administrator');
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function getMembers(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;

    const members = await orgService.getMembers(organizationId, userId);
    res.json({ members });
  } catch (error) {
    next(error);
  }
}

export async function updateMember(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;
    const memberId = getParamValue(req, 'memberId')!;
    const input: UpdateMemberInput = req.body;

    const member = await orgService.updateMember(organizationId, memberId, userId, input);
    res.json({ member });
  } catch (error) {
    next(error);
  }
}

export async function removeMember(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const organizationId = getParamValue(req, 'organizationId')!;
    const memberId = getParamValue(req, 'memberId')!;

    await orgService.removeMember(organizationId, memberId, userId);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}