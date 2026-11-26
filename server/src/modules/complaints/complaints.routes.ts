// Provider complaints routes (Task 13.16) — mounted at /api/v1/complaints.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  complaintResourceParamsSchema, createComplaintSchema, complaintIdParamsSchema,
  complaintListQuerySchema, complaintMessageSchema, complaintTransitionSchema,
  complaintCorrectiveActionSchema, complaintInternalNoteSchema, complaintAssignSchema,
} from './complaints.schemas.js';
import {
  listReasons, submitComplaint, listCustomerComplaints, listProviderComplaints,
  listAdminQueue, getComplaint, postMessage, recordCorrectiveAction,
  addInternalNote, assignComplaint, changeStatus,
} from './complaints.controller.js';

export function createComplaintsRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  router.get('/reasons', listReasons);

  // Customer
  router.post('/resources/:domain/:resourceId', validate(complaintResourceParamsSchema, 'params'), validate(createComplaintSchema, 'body'), submitComplaint);
  router.get('/mine', listCustomerComplaints);

  // Provider
  router.get('/provider', validate(complaintListQuerySchema, 'query'), listProviderComplaints);

  // Admin
  router.get('/admin/queue', validate(complaintListQuerySchema, 'query'), listAdminQueue);
  router.post('/:complaintId/assign', validate(complaintIdParamsSchema, 'params'), validate(complaintAssignSchema, 'body'), assignComplaint);
  router.post('/:complaintId/internal-notes', validate(complaintIdParamsSchema, 'params'), validate(complaintInternalNoteSchema, 'body'), addInternalNote);

  // Shared (resource-scoped in service)
  router.get('/:complaintId', validate(complaintIdParamsSchema, 'params'), getComplaint);
  router.post('/:complaintId/messages', validate(complaintIdParamsSchema, 'params'), validate(complaintMessageSchema, 'body'), postMessage);
  router.post('/:complaintId/corrective-actions', validate(complaintIdParamsSchema, 'params'), validate(complaintCorrectiveActionSchema, 'body'), recordCorrectiveAction);
  router.post('/:complaintId/status', validate(complaintIdParamsSchema, 'params'), validate(complaintTransitionSchema, 'body'), changeStatus);

  return router;
}