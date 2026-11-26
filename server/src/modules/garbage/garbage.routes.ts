// Garbage collection operations routes (Task 13.7) — mounted at /api/v1/garbage.
// Customer tracking + provider operational management share one engine; recurring
// agreements generate idempotent occurrences via a pg-boss worker.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  garbageJobListQuerySchema,
  garbageJobIdParamsSchema,
  garbageCancelSchema,
  garbageProgressSchema,
  garbageMissSchema,
  garbageFailSchema,
  assignGarbageStaffSchema,
  garbageChecklistUpdateSchema,
  garbageCompletionSchema,
  garbageCustomerConfirmationSchema,
  reportGarbageExceptionSchema,
  createGarbageJobSchema,
  createGarbageAgreementSchema,
  agreementIdParamsSchema,
  decideAgreementSchema,
  rescheduleGarbageSchema,
} from './garbage.schemas.js';
import {
  listCustomerJobs,
  getCustomerJob,
  cancelJob,
  confirmCompletion,
  reportException,
  listCustomerAgreements,
  decideAgreement,
  getAgreementOccurrences,
  createJob,
  listProviderJobs,
  getProviderJob,
  updateProgress,
  markMissed,
  failJob,
  providerCancelJob,
  assignStaff,
  updateChecklist,
  reschedule,
  submitCompletion,
  proposeAgreement,
  listProviderAgreements,
  setAgreementStatus,
} from './garbage.controller.js';

const agreementStatusSchema = z.object({
  status: z.enum(['active', 'suspended', 'cancelled', 'completed']),
});

export function createGarbageRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(garbageJobListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(garbageJobIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(garbageJobIdParamsSchema, 'params'), validate(garbageCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(garbageJobIdParamsSchema, 'params'), validate(garbageCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/exceptions', validate(garbageJobIdParamsSchema, 'params'), validate(reportGarbageExceptionSchema, 'body'), reportException);
  router.get('/agreements', listCustomerAgreements);
  router.post('/agreements/:agreementId/decide', validate(agreementIdParamsSchema, 'params'), validate(decideAgreementSchema, 'body'), decideAgreement);
  router.get('/agreements/:agreementId/occurrences', validate(agreementIdParamsSchema, 'params'), getAgreementOccurrences);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createGarbageJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(garbageJobListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(garbageJobIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(garbageJobIdParamsSchema, 'params'), validate(garbageProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/missed', validate(garbageJobIdParamsSchema, 'params'), validate(garbageMissSchema, 'body'), markMissed);
  router.post('/provider/jobs/:jobId/fail', validate(garbageJobIdParamsSchema, 'params'), validate(garbageFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(garbageJobIdParamsSchema, 'params'), validate(garbageCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/staff', validate(garbageJobIdParamsSchema, 'params'), validate(assignGarbageStaffSchema, 'body'), assignStaff);
  router.put('/provider/jobs/:jobId/checklist', validate(garbageJobIdParamsSchema, 'params'), validate(garbageChecklistUpdateSchema, 'body'), updateChecklist);
  router.post('/provider/jobs/:jobId/reschedule', validate(garbageJobIdParamsSchema, 'params'), validate(rescheduleGarbageSchema, 'body'), reschedule);
  router.post('/provider/jobs/:jobId/completion', validate(garbageJobIdParamsSchema, 'params'), validate(garbageCompletionSchema, 'body'), submitCompletion);
  router.post('/provider/agreements', validate(createGarbageAgreementSchema, 'body'), proposeAgreement);
  router.get('/provider/agreements', listProviderAgreements);
  router.post('/provider/agreements/:agreementId/status', validate(agreementIdParamsSchema, 'params'), validate(agreementStatusSchema, 'body'), setAgreementStatus);

  return router;
}