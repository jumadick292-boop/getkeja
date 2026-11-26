// Cleaning & Property Care routes (Task 13.13) — mounted at /api/v1/cleaning-operations.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  cleaningListQuerySchema,
  cleaningIdParamsSchema,
  cleaningAmendmentIdParamsSchema,
  cleaningMaterialIdParamsSchema,
  cleaningChecklistIdParamsSchema,
  createCleaningJobSchema,
  cleaningProgressSchema,
  cleaningFailSchema,
  cleaningCancelSchema,
  cleaningAssessmentSchema,
  cleaningChecklistSchema,
  cleaningChecklistUpdateSchema,
  cleaningAreaSchema,
  cleaningMaterialSchema,
  cleaningMaterialDecisionSchema,
  cleaningAttachmentSchema,
  assignCleaningStaffSchema,
  proposeCleaningAmendmentSchema,
  decideCleaningAmendmentSchema,
  cleaningCompletionSchema,
  cleaningCustomerConfirmationSchema,
  reportCleaningExceptionSchema,
} from './cleaning-operations.schemas.js';
import {
  listCustomerJobs, getCustomerJob, cancelJob, confirmCompletion, reportException,
  decideAmendment, decideMaterial,
  createJob, listProviderJobs, getProviderJob, updateProgress, failJob, providerCancelJob,
  recordAssessment, createChecklist, updateChecklistItem, addArea, addMaterial,
  decideMaterialProvider, addAttachment, assignStaff, revokeStaff, proposeAmendment,
  submitCompletion,
} from './cleaning-operations.controller.js';

const jobStaffParams = z.object({ jobId: z.string().uuid(), staffUserId: z.string().uuid() });

export function createCleaningOperationsRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(cleaningListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(cleaningIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(cleaningIdParamsSchema, 'params'), validate(cleaningCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(cleaningIdParamsSchema, 'params'), validate(cleaningCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/exceptions', validate(cleaningIdParamsSchema, 'params'), validate(reportCleaningExceptionSchema, 'body'), reportException);
  router.post('/jobs/:jobId/amendments/:amendmentId/decide', validate(cleaningAmendmentIdParamsSchema, 'params'), validate(decideCleaningAmendmentSchema, 'body'), decideAmendment);
  router.post('/jobs/:jobId/materials/:materialId/decide', validate(cleaningMaterialIdParamsSchema, 'params'), validate(cleaningMaterialDecisionSchema, 'body'), decideMaterial);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createCleaningJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(cleaningListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(cleaningIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(cleaningIdParamsSchema, 'params'), validate(cleaningProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/fail', validate(cleaningIdParamsSchema, 'params'), validate(cleaningFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(cleaningIdParamsSchema, 'params'), validate(cleaningCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/assessments', validate(cleaningIdParamsSchema, 'params'), validate(cleaningAssessmentSchema, 'body'), recordAssessment);
  router.post('/provider/jobs/:jobId/checklists', validate(cleaningIdParamsSchema, 'params'), validate(cleaningChecklistSchema, 'body'), createChecklist);
  router.post('/provider/jobs/:jobId/checklists/:checklistId/items', validate(cleaningChecklistIdParamsSchema, 'params'), validate(cleaningChecklistUpdateSchema, 'body'), updateChecklistItem);
  router.post('/provider/jobs/:jobId/areas', validate(cleaningIdParamsSchema, 'params'), validate(cleaningAreaSchema, 'body'), addArea);
  router.post('/provider/jobs/:jobId/materials', validate(cleaningIdParamsSchema, 'params'), validate(cleaningMaterialSchema, 'body'), addMaterial);
  router.post('/provider/jobs/:jobId/materials/:materialId/decide', validate(cleaningMaterialIdParamsSchema, 'params'), validate(cleaningMaterialDecisionSchema, 'body'), decideMaterialProvider);
  router.post('/provider/jobs/:jobId/attachments', validate(cleaningIdParamsSchema, 'params'), validate(cleaningAttachmentSchema, 'body'), addAttachment);
  router.post('/provider/jobs/:jobId/staff', validate(cleaningIdParamsSchema, 'params'), validate(assignCleaningStaffSchema, 'body'), assignStaff);
  router.delete('/provider/jobs/:jobId/staff/:staffUserId', validate(jobStaffParams, 'params'), revokeStaff);
  router.post('/provider/jobs/:jobId/amendments', validate(cleaningIdParamsSchema, 'params'), validate(proposeCleaningAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/jobs/:jobId/completion', validate(cleaningIdParamsSchema, 'params'), validate(cleaningCompletionSchema, 'body'), submitCompletion);

  return router;
}