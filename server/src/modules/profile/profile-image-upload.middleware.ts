import multer from 'multer';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { HttpError, ValidationError } from '../../shared/errors.js';
import { MAX_PROFILE_IMAGE_BYTES } from './profile-image-upload.validation.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_PROFILE_IMAGE_BYTES,
    files: 1,
    fields: 2,
    parts: 3,
  },
  fileFilter: (_req, file, callback) => {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      callback(new ValidationError('Only JPEG, PNG, and WebP images are supported'));
      return;
    }
    callback(null, true);
  },
});

export const receiveProfileImage: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  upload.single('file')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        next(new HttpError('Image must be 5 MB or smaller', 413));
        return;
      }
      next(new ValidationError('Invalid image upload form'));
      return;
    }
    next(error);
  });
};
