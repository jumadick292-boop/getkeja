// Home Maintenance & Repairs routes (Task 13.12) — mounted at /api/v1/home-maintenance.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  homeMaintenanceListQuerySchema,
  homeMaintenanceIdParamsSchema,
  homeMaintenanceInspectionIdParamsSchema,
  homeMaintenanceAmendmentIdParamsSchema,
  homeMaintenancePartIdParamsSchema,
  homeMaintenanceStaffParamsSchema,
  createHomeMaintenanceJobSchema,
  homeMaintenanceProgressSchema,
  homeMaintenanceFailSchema,
  homeMaintenanceCancelSchema,
  homeMaintenanceInspectionSchema,
  homeMaintenanceWorkPlanSchema,
  homeMaintenancePartSchema,
  homeMaintenancePartDecisionSchema,
  assignHomeMaintenanceStaffSchema,
  proposeHomeMaintenanceAmendmentSchema,
  decideHomeMaintenanceAmendmentSchema,
  homeMaintenanceCompletionSchema,
  homeMaintenanceCustomerConfirmationSchema,
  reportHomeMaintenanceExceptionSchema,
} from './home-maintenance.schemas.js';
import {
  listCustomerJobs, getCustomerJob, cancelJob, confirmCompletion, reportException, decideAmendment,
  createJob, listProviderJobs, getProviderJob, updateProgress, failJob, providerCancelJob,
  recordInspection, createWorkPlan, addPart, decidePart, assignStaff, revokeStaff,
  proposeAmendment, submitCompletion,
} from './home-maintenance.controller.js';

const jobStaffParams = z.object({ jobId: z.string().uuid(), staffUserId: z.string().uuid() });

export function createHomeMaintenanceRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(homeMaintenanceListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(homeMaintenanceIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/exceptions', validate(homeMaintenanceIdParamsSchema, 'params'), validate(reportHomeMaintenanceExceptionSchema, 'body'), reportException);
  router.post('/jobs/:jobId/amendments/:amendmentId/decide', validate(homeMaintenanceAmendmentIdParamsSchema, 'params'), validate(decideHomeMaintenanceAmendmentSchema, 'body'), decideAmendment);
  router.post('/jobs/:jobId/parts/:partId/decide', validate(homeMaintenancePartIdParamsSchema, 'params'), validate(homeMaintenancePartDecisionSchema, 'body'), decidePart);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createHomeMaintenanceJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(homeMaintenanceListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(homeMaintenanceIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/fail', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/inspections', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceInspectionSchema, 'body'), recordInspection);
  router.post('/provider/jobs/:jobId/work-plans', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceWorkPlanSchema, 'body'), createWorkPlan);
  router.post('/provider/jobs/:jobId/parts', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenancePartSchema, 'body'), addPart);
  router.post('/provider/jobs/:jobId/staff', validate(homeMaintenanceIdParamsSchema, 'params'), validate(assignHomeMaintenanceStaffSchema, 'body'), assignStaff);
  router.delete('/provider/jobs/:jobId/staff/:staffUserId', validate(jobStaffParams, 'params'), revokeStaff);
  router.post('/provider/jobs/:jobId/amendments', validate(homeMaintenanceIdParamsSchema, 'params'), validate(proposeHomeMaintenanceAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/jobs/:jobId/completion', validate(homeMaintenanceIdParamsSchema, 'params'), validate(homeMaintenanceCompletionSchema, 'body'), submitCompletion);

  return router;
}