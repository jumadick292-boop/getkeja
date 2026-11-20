import multer from 'multer';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { HttpError, ValidationError } from '../../shared/errors.js';
import { MAX_VERIFICATION_DOCUMENT_BYTES } from './verification-document-upload.validation.js';

const allowedMimeTypes = new Set([
  'application/pdf', 'image/jpeg', 'image/png', 'image/webp',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_VERIFICATION_DOCUMENT_BYTES, files: 1, fields: 1, parts: 2 },
  fileFilter: (_req, file, callback) => {
    if (!allowedMimeTypes.has(file.mimetype)) {
      callback(new ValidationError('Use a PDF, JPEG, PNG, or WebP document'));
      return;
    }
    callback(null, true);
  },
});

export const receiveVerificationDocument: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  upload.single('file')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      next(error.code === 'LIMIT_FILE_SIZE'
        ? new HttpError('Verification document must be 10 MB or smaller', 413)
        : new ValidationError('Invalid verification document upload form'));
      return;
    }
    next(error);
  });
};
