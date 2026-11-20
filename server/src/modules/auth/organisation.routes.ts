import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePermission } from './authorization.middleware.js';
import * as orgController from './organisation.controller.js';
import * as authSchema from './auth.schema.js';

const router = Router();

// All routes require authentication
router.use(requireAuth);

// Organisation CRUD
router.post('/', validate(authSchema.createOrganisationSchema), orgController.createOrganisation);
router.get('/', orgController.getOrganisations);
router.get('/:organizationId', orgController.getOrganisation);
router.patch('/:organizationId', validate(authSchema.updateOrganisationSchema), orgController.updateOrganisation);

// Invitations
router.post('/:organizationId/invitations', validate(authSchema.createInvitationSchema), orgController.createInvitation);
router.post('/:organizationId/invitations/accept', orgController.acceptInvitation);
router.get('/:organizationId/invitations', orgController.getInvitations);
router.delete('/:organizationId/invitations/:invitationId', orgController.revokeInvitation);

// Members
router.get('/:organizationId/members', orgController.getMembers);
router.patch('/:organizationId/members/:memberId', validate(authSchema.updateMemberSchema), orgController.updateMember);
router.delete('/:organizationId/members/:memberId', orgController.removeMember);

export default router;