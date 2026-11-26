// Rental application routes, mounted at /api/v1/rental-applications.
//
// Applicant and manager share this resource namespace; authorization is
// enforced per-handler by the service (applicant ownership vs manager scope).
import { Router } from 'express';
import multer from 'multer';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { validate } from '../../middleware/validate.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import { requireAuth } from '../auth/auth.middleware.js';
import { HttpError, ValidationError } from '../../shared/errors.js';
import * as controller from './rental-application.controller.js';
import {
  applicationIdParamSchema,
  documentIdParamSchema,
  saveApplicationSchema,
  submitApplicationSchema,
  resubmitApplicationSchema,
  transitionActionSchema,
  approveApplicationSchema,
  addNoteSchema,
  listApplicationsQuerySchema,
} from './rental-application.schema.js';

const MAX_DOC_BYTES = 10 * 1024 * 1024;

const documentUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_DOC_BYTES, files: 1, fields: 3, parts: 4 },
  fileFilter: (_req, file, callback) => {
    const allowed = new Set([
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ]);
    if (!allowed.has(file.mimetype)) {
      callback(new ValidationError('Unsupported document type'));
      return;
    }
    callback(null, true);
  },
});

const receiveDocument: RequestHandler = (req: Request, res: Response, next: NextFunction) => {
  documentUpload.single('file')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      next(
        error.code === 'LIMIT_FILE_SIZE'
          ? new HttpError('Document must be 10 MB or smaller', 413)
          : new ValidationError('Invalid document upload form'),
      );
      return;
    }
    next(error);
  });
};

export function createRentalApplicationRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  const rateLimit = createRateLimiter({
    windowMs: 60_000,
    max: 60,
    keyPrefix: 'rental-apps',
    identifierField: 'userId',
    ipMax: 300,
  });

  // ---- Applicant: drafts & submissions ----
  router.post('/applications/draft', rateLimit, validate(saveApplicationSchema), controller.saveDraft);
  router.post('/applications', rateLimit, validate(submitApplicationSchema), controller.submitApplication);
  router.post(
    '/applications/:applicationId/submit',
    validate(applicationIdParamSchema, 'params'),
    controller.submitDraft,
  );
  router.post(
    '/applications/:applicationId/resubmit',
    validate(applicationIdParamSchema, 'params'),
    validate(resubmitApplicationSchema),
    controller.resubmitApplication,
  );
  router.post(
    '/applications/:applicationId/withdraw',
    validate(applicationIdParamSchema, 'params'),
    controller.withdrawApplication,
  );

  // ---- Manager: inbox, detail, transitions, notes, approval, onboarding ----
  router.get(
    '/applications',
    validate(listApplicationsQuerySchema, 'query'),
    controller.listApplications,
  );
  router.get(
    '/applications/:applicationId',
    validate(applicationIdParamSchema, 'params'),
    controller.getApplication,
  );
  router.post(
    '/applications/:applicationId/transition',
    validate(applicationIdParamSchema, 'params'),
    validate(transitionActionSchema),
    controller.transition,
  );
  router.post(
    '/applications/:applicationId/approve',
    validate(applicationIdParamSchema, 'params'),
    validate(approveApplicationSchema),
    controller.approve,
  );
  router.post(
    '/applications/:applicationId/onboard',
    validate(applicationIdParamSchema, 'params'),
    controller.onboard,
  );
  router.post(
    '/applications/:applicationId/notes',
    validate(applicationIdParamSchema, 'params'),
    validate(addNoteSchema),
    controller.addNote,
  );

  // ---- Documents (applicant upload/list; shared download) ----
  router.post(
    '/applications/:applicationId/documents',
    validate(applicationIdParamSchema, 'params'),
    receiveDocument,
    controller.uploadDocument,
  );
  router.get(
    '/applications/:applicationId/documents',
    validate(applicationIdParamSchema, 'params'),
    controller.listDocuments,
  );
  router.get(
    '/documents/:documentId',
    validate(documentIdParamSchema, 'params'),
    controller.downloadDocument,
  );

  return router;
}