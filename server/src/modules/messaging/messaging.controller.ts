import type { Request, Response } from 'express';
import type { AuthUser } from '../auth/auth.types.js';
import { ForbiddenError, ValidationError } from '../../shared/errors.js';
import { pool } from '../../db/pool.js';
import * as service from './messaging.service.js';
import * as repo from './messaging.repository.js';
import { decodeMessageCursor, type ConversationContextType } from './messaging.repository.js';
import { putPrivateDocument, signedPrivateDocumentUrl } from '../profile/private-document-storage.service.js';
import { randomUUID } from 'node:crypto';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function getParam(req: AuthenticatedRequest, name: string): string {
  const value = req.params[name];
  if (value === undefined) return '';
  return (Array.isArray(value) ? value[0] : value) as string;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const ALLOWED_ATTACHMENT_MIME = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'text/plain',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

export async function startConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body;
  const result = await service.startConversation(userId, {
    type: (body.type ?? 'enquiry') as ConversationContextType,
    subject: body.subject ?? null,
    propertyId: body.propertyId ?? null,
    unitId: body.unitId ?? null,
    enquiryId: body.enquiryId ?? null,
    rentalApplicationId: body.rentalApplicationId ?? null,
    rentalProposalId: body.rentalProposalId ?? null,
    siteVisitId: body.siteVisitId ?? null,
    tenancyId: body.tenancyId ?? null,
    movingJobId: body.movingJobId ?? null,
    marketplaceRequestId: body.marketplaceRequestId ?? null,
    garbageJobId: body.garbageJobId ?? null,
    laundryOrderId: body.laundryOrderId ?? null,
    schedulingActivityId: body.schedulingActivityId ?? null,
    participantUserIds: body.participantUserIds ?? [],
    message: body.message ?? null,
  });
  res.status(result.reused ? 200 : 201).json({
    conversation: result.conversation,
    firstMessage: result.firstMessage,
    reused: result.reused,
  });
}

export async function listConversations(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as Record<string, unknown>;
  const result = await service.listMyConversations(userId, {
    status: typeof query.status === 'string' ? query.status : undefined,
    type: typeof query.type === 'string' ? query.type : undefined,
    propertyId: typeof query.propertyId === 'string' ? query.propertyId : undefined,
    search: typeof query.search === 'string' ? query.search : undefined,
    limit: Number(query.limit) || 20,
    offset: Number(query.offset) || 0,
  });
  res.json(result);
}

export async function getUnreadCount(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.getMyUnreadCount(userId));
}

export async function getConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.getMyConversation(userId, getParam(req, 'conversationId')));
}

export async function listMessages(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const conversationId = getParam(req, 'conversationId');
  const query = req.query as Record<string, unknown>;
  const before = typeof query.before === 'string' ? decodeMessageCursor(query.before) : null;
  const limit = Number(query.limit) || 30;
  const result = await service.listMyMessages(userId, conversationId, {
    before,
    limit: Math.min(Math.max(limit, 1), 100),
  });
  res.json(result);
}

export async function sendMessage(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body;
  const message = await service.sendMessage(userId, {
    conversationId: getParam(req, 'conversationId'),
    content: body.content,
    type: body.type,
    replyToId: body.replyToId ?? null,
  });
  res.status(201).json(message);
}

export async function markConversationRead(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.markConversationRead(userId, getParam(req, 'conversationId')));
}

export async function markMessageRead(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.markMessageRead(userId, getParam(req, 'messageId')));
}

export async function archiveConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.archiveConversation(userId, getParam(req, 'conversationId')));
}

export async function reopenConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await service.reopenConversation(userId, getParam(req, 'conversationId')));
}

export async function uploadAttachment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const conversationId = getParam(req, 'conversationId');

  // Authorize before touching storage.
  await repo.assertActiveParticipant(pool, conversationId, userId);

  const file = (req as unknown as { file?: { buffer: Buffer; originalname: string; mimetype: string; size: number } }).file;
  if (!file) throw new ValidationError('A file is required');
  if (!file.size || file.size <= 0) throw new ValidationError('Uploaded file is empty');
  if (file.size > MAX_ATTACHMENT_BYTES) {
    throw new ValidationError(`Attachment exceeds the ${MAX_ATTACHMENT_BYTES} byte limit`);
  }
  if (!ALLOWED_ATTACHMENT_MIME.has(file.mimetype)) {
    throw new ValidationError('Unsupported attachment type');
  }

  const content = (req.body?.content as string | undefined)?.trim();
  const type = (req.body?.type as string | undefined) ?? 'text';

  // Persist the message (with the file reference) and upload the object, all
  // guarded so a storage failure does not leave an orphan message.
  const message = await service.sendMessage(userId, {
    conversationId,
    content: content && content.length > 0 ? content : 'Attachment',
    type: type === 'system' ? 'system' : 'text',
  });

  const storageKey = `messages/${conversationId}/${message.id}/${randomUUID()}`;
  try {
    await putPrivateDocument(storageKey, file.buffer, file.mimetype);
  } catch (error) {
    // Best-effort cleanup of the just-created message to avoid a dangling row.
    await repo.dbTransaction(async (client) => {
      await client.query(`DELETE FROM messages WHERE id = $1`, [message.id]);
    }).catch(() => undefined);
    throw error;
  }

  const attachment = await repo.insertAttachment({
    messageId: message.id,
    fileName: file.originalname,
    filePath: storageKey,
    fileSizeBytes: file.size,
    mimeType: file.mimetype,
    uploadedBy: userId,
  });

  res.status(201).json({ message, attachment });
}

export async function downloadAttachment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const attachmentId = getParam(req, 'attachmentId');
  const { attachment } = await service.getAttachmentForDownload(userId, attachmentId);
  const url = await signedPrivateDocumentUrl(
    attachment.filePath,
    attachment.fileName,
    attachment.mimeType ?? 'application/octet-stream',
  );
  res.json({
    id: attachment.id,
    url,
    expiresInSeconds: 300,
  });
}