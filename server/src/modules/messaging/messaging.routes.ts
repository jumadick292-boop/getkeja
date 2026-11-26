import { Router } from 'express';
import multer from 'multer';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { validate } from '../../middleware/validate.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import { requireAuth } from '../auth/auth.middleware.js';
import { HttpError, ValidationError } from '../../shared/errors.js';
import * as controller from './messaging.controller.js';
import {
  startConversationSchema,
  conversationIdParamSchema,
  messageIdParamSchema,
  attachmentIdParamSchema,
  listConversationsQuerySchema,
  listMessagesQuerySchema,
  sendMessageSchema,
} from './messaging.schema.js';

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;

const attachmentUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_ATTACHMENT_BYTES, files: 1, fields: 2, parts: 3 },
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
      callback(new ValidationError('Unsupported attachment type'));
      return;
    }
    callback(null, true);
  },
});

const receiveAttachment: RequestHandler = (req: Request, res: Response, next: NextFunction) => {
  attachmentUpload.single('file')(req, res, (error: unknown) => {
    if (error instanceof multer.MulterError) {
      next(
        error.code === 'LIMIT_FILE_SIZE'
          ? new HttpError('Attachment must be 10 MB or smaller', 413)
          : new ValidationError('Invalid attachment upload form'),
      );
      return;
    }
    next(error);
  });
};

export function createMessagingRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  const conversationRateLimit = createRateLimiter({
    windowMs: 60_000,
    max: 30,
    keyPrefix: 'messaging:conversations',
    identifierField: 'userId',
    ipMax: 200,
  });
  const messageRateLimit = createRateLimiter({
    windowMs: 60_000,
    max: 60,
    keyPrefix: 'messaging:messages',
    identifierField: 'userId',
    ipMax: 600,
  });

  // Static paths must precede the :conversationId param route.
  router.get('/conversations/unread-count', controller.getUnreadCount);
  router.get(
    '/conversations',
    validate(listConversationsQuerySchema, 'query'),
    controller.listConversations,
  );
  router.post(
    '/conversations',
    conversationRateLimit,
    validate(startConversationSchema),
    controller.startConversation,
  );
  router.get(
    '/conversations/:conversationId',
    validate(conversationIdParamSchema, 'params'),
    controller.getConversation,
  );
  router.get(
    '/conversations/:conversationId/messages',
    validate(conversationIdParamSchema, 'params'),
    validate(listMessagesQuerySchema, 'query'),
    controller.listMessages,
  );
  router.post(
    '/conversations/:conversationId/messages',
    messageRateLimit,
    validate(conversationIdParamSchema, 'params'),
    validate(sendMessageSchema),
    controller.sendMessage,
  );
  router.post(
    '/conversations/:conversationId/read',
    validate(conversationIdParamSchema, 'params'),
    controller.markConversationRead,
  );
  router.post(
    '/conversations/:conversationId/archive',
    validate(conversationIdParamSchema, 'params'),
    controller.archiveConversation,
  );
  router.post(
    '/conversations/:conversationId/reopen',
    validate(conversationIdParamSchema, 'params'),
    controller.reopenConversation,
  );
  router.post(
    '/conversations/:conversationId/attachments',
    messageRateLimit,
    validate(conversationIdParamSchema, 'params'),
    receiveAttachment,
    controller.uploadAttachment,
  );

  // Single-message read receipt (kept for clients that track per-message reads).
  router.post(
    '/messages/:messageId/read',
    validate(messageIdParamSchema, 'params'),
    controller.markMessageRead,
  );

  // Attachment download returns a short-lived presigned URL.
  router.get(
    '/attachments/:attachmentId',
    validate(attachmentIdParamSchema, 'params'),
    controller.downloadAttachment,
  );

  return router;
}