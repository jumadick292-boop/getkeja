// Installation & Technical Services routes (Task 13.14) — mounted at /api/v1/installation-operations.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  installationListQuerySchema,
  installationIdParamsSchema,
  installationAmendmentIdParamsSchema,
  installationEquipmentIdParamsSchema,
  createInstallationJobSchema,
  installationProgressSchema,
  installationFailSchema,
  installationCancelSchema,
  installationAssessmentSchema,
  installationPlanSchema,
  installationEquipmentSchema,
  installationEquipmentDecisionSchema,
  installationTestSchema,
  installationAttachmentSchema,
  assignInstallationStaffSchema,
  proposeInstallationAmendmentSchema,
  decideInstallationAmendmentSchema,
  installationCompletionSchema,
  installationCustomerConfirmationSchema,
  reportInstallationExceptionSchema,
} from './installation-operations.schemas.js';
import {
  listCustomerJobs, getCustomerJob, cancelJob, confirmCompletion, reportException,
  decideAmendment, decideEquipment,
  createJob, listProviderJobs, getProviderJob, updateProgress, failJob, providerCancelJob,
  recordAssessment, createPlan, addEquipment, decideEquipmentProvider, recordTest,
  addAttachment, assignStaff, revokeStaff, proposeAmendment, submitCompletion,
} from './installation-operations.controller.js';

const jobStaffParams = z.object({ jobId: z.string().uuid(), staffUserId: z.string().uuid() });

export function createInstallationOperationsRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(installationListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(installationIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(installationIdParamsSchema, 'params'), validate(installationCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(installationIdParamsSchema, 'params'), validate(installationCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/exceptions', validate(installationIdParamsSchema, 'params'), validate(reportInstallationExceptionSchema, 'body'), reportException);
  router.post('/jobs/:jobId/amendments/:amendmentId/decide', validate(installationAmendmentIdParamsSchema, 'params'), validate(decideInstallationAmendmentSchema, 'body'), decideAmendment);
  router.post('/jobs/:jobId/equipment/:equipmentId/decide', validate(installationEquipmentIdParamsSchema, 'params'), validate(installationEquipmentDecisionSchema, 'body'), decideEquipment);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createInstallationJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(installationListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(installationIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(installationIdParamsSchema, 'params'), validate(installationProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/fail', validate(installationIdParamsSchema, 'params'), validate(installationFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(installationIdParamsSchema, 'params'), validate(installationCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/assessments', validate(installationIdParamsSchema, 'params'), validate(installationAssessmentSchema, 'body'), recordAssessment);
  router.post('/provider/jobs/:jobId/plans', validate(installationIdParamsSchema, 'params'), validate(installationPlanSchema, 'body'), createPlan);
  router.post('/provider/jobs/:jobId/equipment', validate(installationIdParamsSchema, 'params'), validate(installationEquipmentSchema, 'body'), addEquipment);
  router.post('/provider/jobs/:jobId/equipment/:equipmentId/decide', validate(installationEquipmentIdParamsSchema, 'params'), validate(installationEquipmentDecisionSchema, 'body'), decideEquipmentProvider);
  router.post('/provider/jobs/:jobId/tests', validate(installationIdParamsSchema, 'params'), validate(installationTestSchema, 'body'), recordTest);
  router.post('/provider/jobs/:jobId/attachments', validate(installationIdParamsSchema, 'params'), validate(installationAttachmentSchema, 'body'), addAttachment);
  router.post('/provider/jobs/:jobId/staff', validate(installationIdParamsSchema, 'params'), validate(assignInstallationStaffSchema, 'body'), assignStaff);
  router.delete('/provider/jobs/:jobId/staff/:staffUserId', validate(jobStaffParams, 'params'), revokeStaff);
  router.post('/provider/jobs/:jobId/amendments', validate(installationIdParamsSchema, 'params'), validate(proposeInstallationAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/jobs/:jobId/completion', validate(installationIdParamsSchema, 'params'), validate(installationCompletionSchema, 'body'), submitCompletion);

  return router;
}