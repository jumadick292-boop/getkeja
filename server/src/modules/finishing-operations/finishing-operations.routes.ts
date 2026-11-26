// Finishing & Building Services routes (Task 13.15) — mounted at /api/v1/finishing-operations.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  finishingListQuerySchema,
  finishingIdParamsSchema,
  finishingAmendmentIdParamsSchema,
  finishingMaterialIdParamsSchema,
  createFinishingJobSchema,
  finishingProgressSchema,
  finishingFailSchema,
  finishingCancelSchema,
  finishingAssessmentSchema,
  finishingPlanSchema,
  finishingMaterialSchema,
  finishingMaterialDecisionSchema,
  finishingInspectionSchema,
  finishingAttachmentSchema,
  assignFinishingStaffSchema,
  proposeFinishingAmendmentSchema,
  decideFinishingAmendmentSchema,
  finishingCompletionSchema,
  finishingCustomerConfirmationSchema,
  reportFinishingExceptionSchema,
} from './finishing-operations.schemas.js';
import {
  listCustomerJobs, getCustomerJob, cancelJob, confirmCompletion, reportException,
  decideAmendment, decideMaterial,
  createJob, listProviderJobs, getProviderJob, updateProgress, failJob, providerCancelJob,
  recordAssessment, createPlan, addMaterial, decideMaterialProvider, recordInspection,
  addAttachment, assignStaff, revokeStaff, proposeAmendment, submitCompletion,
} from './finishing-operations.controller.js';

const jobStaffParams = z.object({ jobId: z.string().uuid(), staffUserId: z.string().uuid() });

export function createFinishingOperationsRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(finishingListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(finishingIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(finishingIdParamsSchema, 'params'), validate(finishingCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(finishingIdParamsSchema, 'params'), validate(finishingCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/exceptions', validate(finishingIdParamsSchema, 'params'), validate(reportFinishingExceptionSchema, 'body'), reportException);
  router.post('/jobs/:jobId/amendments/:amendmentId/decide', validate(finishingAmendmentIdParamsSchema, 'params'), validate(decideFinishingAmendmentSchema, 'body'), decideAmendment);
  router.post('/jobs/:jobId/materials/:materialId/decide', validate(finishingMaterialIdParamsSchema, 'params'), validate(finishingMaterialDecisionSchema, 'body'), decideMaterial);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createFinishingJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(finishingListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(finishingIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(finishingIdParamsSchema, 'params'), validate(finishingProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/fail', validate(finishingIdParamsSchema, 'params'), validate(finishingFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(finishingIdParamsSchema, 'params'), validate(finishingCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/assessments', validate(finishingIdParamsSchema, 'params'), validate(finishingAssessmentSchema, 'body'), recordAssessment);
  router.post('/provider/jobs/:jobId/plans', validate(finishingIdParamsSchema, 'params'), validate(finishingPlanSchema, 'body'), createPlan);
  router.post('/provider/jobs/:jobId/materials', validate(finishingIdParamsSchema, 'params'), validate(finishingMaterialSchema, 'body'), addMaterial);
  router.post('/provider/jobs/:jobId/materials/:materialId/decide', validate(finishingMaterialIdParamsSchema, 'params'), validate(finishingMaterialDecisionSchema, 'body'), decideMaterialProvider);
  router.post('/provider/jobs/:jobId/inspections', validate(finishingIdParamsSchema, 'params'), validate(finishingInspectionSchema, 'body'), recordInspection);
  router.post('/provider/jobs/:jobId/attachments', validate(finishingIdParamsSchema, 'params'), validate(finishingAttachmentSchema, 'body'), addAttachment);
  router.post('/provider/jobs/:jobId/staff', validate(finishingIdParamsSchema, 'params'), validate(assignFinishingStaffSchema, 'body'), assignStaff);
  router.delete('/provider/jobs/:jobId/staff/:staffUserId', validate(jobStaffParams, 'params'), revokeStaff);
  router.post('/provider/jobs/:jobId/amendments', validate(finishingIdParamsSchema, 'params'), validate(proposeFinishingAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/jobs/:jobId/completion', validate(finishingIdParamsSchema, 'params'), validate(finishingCompletionSchema, 'body'), submitCompletion);

  return router;
}