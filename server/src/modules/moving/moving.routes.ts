// Moving & relocation operations routes (Task 13.6) — mounted at /api/v1/moving.
// Customer job tracking + provider operational management share one engine.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  movingJobListQuerySchema,
  movingJobIdParamsSchema,
  movingCancelSchema,
  movingProgressSchema,
  movingFailSchema,
  assignStaffSchema,
  checklistUpdateSchema,
  createAssessmentSchema,
  assessmentIdParamsSchema,
  respondAssessmentSchema,
  completeAssessmentSchema,
  proposeRescheduleSchema,
  scheduleChangeIdParamsSchema,
  decideRescheduleSchema,
  proposeAmendmentSchema,
  amendmentIdParamsSchema,
  decideAmendmentSchema,
  completionSubmissionSchema,
  customerConfirmationSchema,
  createMovingJobSchema,
} from './moving.schemas.js';
import {
  listCustomerJobs,
  getCustomerJob,
  cancelJob,
  confirmCompletion,
  respondAssessment,
  customerProposeReschedule,
  decideReschedule,
  decideAmendment,
  createJob,
  listProviderJobs,
  getProviderJob,
  updateProgress,
  failJob,
  providerCancelJob,
  assignStaff,
  updateChecklist,
  requestAssessment,
  completeAssessment,
  providerProposeReschedule,
  proposeAmendment,
  submitCompletion,
} from './moving.controller.js';

const jobAssessmentParams = z.object({ jobId: z.string().uuid(), assessmentId: z.string().uuid() });
const jobChangeParams = z.object({ jobId: z.string().uuid(), changeId: z.string().uuid() });
const jobAmendmentParams = z.object({ jobId: z.string().uuid(), amendmentId: z.string().uuid() });

export function createMovingRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/jobs', validate(movingJobListQuerySchema, 'query'), listCustomerJobs);
  router.get('/jobs/:jobId', validate(movingJobIdParamsSchema, 'params'), getCustomerJob);
  router.post('/jobs/:jobId/cancel', validate(movingJobIdParamsSchema, 'params'), validate(movingCancelSchema, 'body'), cancelJob);
  router.post('/jobs/:jobId/confirm-completion', validate(movingJobIdParamsSchema, 'params'), validate(customerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/jobs/:jobId/assessments/:assessmentId/respond', validate(jobAssessmentParams, 'params'), validate(respondAssessmentSchema, 'body'), respondAssessment);
  router.post('/jobs/:jobId/reschedule', validate(movingJobIdParamsSchema, 'params'), validate(proposeRescheduleSchema, 'body'), customerProposeReschedule);
  router.post('/jobs/:jobId/schedule-changes/:changeId/decide', validate(jobChangeParams, 'params'), validate(decideRescheduleSchema, 'body'), decideReschedule);
  router.post('/jobs/:jobId/amendments/:amendmentId/decide', validate(jobAmendmentParams, 'params'), validate(decideAmendmentSchema, 'body'), decideAmendment);

  // ---- Provider ----
  router.post('/provider/jobs', validate(createMovingJobSchema, 'body'), createJob);
  router.get('/provider/jobs', validate(movingJobListQuerySchema, 'query'), listProviderJobs);
  router.get('/provider/jobs/:jobId', validate(movingJobIdParamsSchema, 'params'), getProviderJob);
  router.post('/provider/jobs/:jobId/progress', validate(movingJobIdParamsSchema, 'params'), validate(movingProgressSchema, 'body'), updateProgress);
  router.post('/provider/jobs/:jobId/fail', validate(movingJobIdParamsSchema, 'params'), validate(movingFailSchema, 'body'), failJob);
  router.post('/provider/jobs/:jobId/cancel', validate(movingJobIdParamsSchema, 'params'), validate(movingCancelSchema, 'body'), providerCancelJob);
  router.post('/provider/jobs/:jobId/staff', validate(movingJobIdParamsSchema, 'params'), validate(assignStaffSchema, 'body'), assignStaff);
  router.put('/provider/jobs/:jobId/checklist', validate(movingJobIdParamsSchema, 'params'), validate(checklistUpdateSchema, 'body'), updateChecklist);
  router.post('/provider/jobs/:jobId/assessments', validate(movingJobIdParamsSchema, 'params'), validate(createAssessmentSchema, 'body'), requestAssessment);
  router.post('/provider/jobs/:jobId/assessments/:assessmentId/complete', validate(jobAssessmentParams, 'params'), validate(completeAssessmentSchema, 'body'), completeAssessment);
  router.post('/provider/jobs/:jobId/reschedule', validate(movingJobIdParamsSchema, 'params'), validate(proposeRescheduleSchema, 'body'), providerProposeReschedule);
  router.post('/provider/jobs/:jobId/amendments', validate(movingJobIdParamsSchema, 'params'), validate(proposeAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/jobs/:jobId/completion', validate(movingJobIdParamsSchema, 'params'), validate(completionSubmissionSchema, 'body'), submitCompletion);

  return router;
}