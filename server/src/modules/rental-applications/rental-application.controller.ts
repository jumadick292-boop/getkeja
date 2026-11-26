// Rental application controller: applicant + manager + shared document handlers.
import type { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { ForbiddenError, ValidationError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import * as service from './rental-application.service.js';
import {
  putPrivateDocument,
  signedPrivateDocumentUrl,
} from '../profile/private-document-storage.service.js';

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

const MAX_DOC_BYTES = 10 * 1024 * 1024;
const ALLOWED_DOC_MIME = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'text/plain',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

// ---------------------------------------------------------------------------
// Applicant
// ---------------------------------------------------------------------------

export async function saveDraft(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body;
  const application = await service.saveDraft(
    userId,
    {
      propertyId: body.propertyId,
      listingId: body.listingId ?? null,
      unitId: body.unitId ?? null,
      preferredStartDate: body.preferredStartDate ?? null,
      preferredEndDate: body.preferredEndDate ?? null,
      proposedRentAmount: body.proposedRentAmount ?? null,
      employerName: body.employerName ?? null,
      employerContact: body.employerContact ?? null,
      monthlyIncome: body.monthlyIncome ?? null,
      previousLandlordName: body.previousLandlordName ?? null,
      previousLandlordContact: body.previousLandlordContact ?? null,
      guarantorName: body.guarantorName ?? null,
      guarantorEmail: body.guarantorEmail ?? null,
      guarantorPhone: body.guarantorPhone ?? null,
      guarantorRelationship: body.guarantorRelationship ?? null,
    },
    body.id ?? undefined,
  );
  res.status(body.id ? 200 : 201).json(application);
}

export async function submitApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body;
  const application = await service.createApplication(
    userId,
    {
      propertyId: body.propertyId,
      listingId: body.listingId ?? null,
      unitId: body.unitId ?? null,
      preferredStartDate: body.preferredStartDate ?? null,
      preferredEndDate: body.preferredEndDate ?? null,
      proposedRentAmount: body.proposedRentAmount ?? null,
      employerName: body.employerName ?? null,
      employerContact: body.employerContact ?? null,
      monthlyIncome: body.monthlyIncome ?? null,
      previousLandlordName: body.previousLandlordName ?? null,
      previousLandlordContact: body.previousLandlordContact ?? null,
      guarantorName: body.guarantorName ?? null,
      guarantorEmail: body.guarantorEmail ?? null,
      guarantorPhone: body.guarantorPhone ?? null,
      guarantorRelationship: body.guarantorRelationship ?? null,
    },
    false,
  );
  res.status(201).json(application);
}

export async function submitDraft(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const application = await service.submitDraft(userId, getParam(req, 'applicationId'));
  res.status(200).json(application);
}

export async function resubmitApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body;
  const application = await service.resubmitApplication(userId, getParam(req, 'applicationId'), {
    preferredStartDate: body.preferredStartDate ?? undefined,
    preferredEndDate: body.preferredEndDate ?? undefined,
    proposedRentAmount: body.proposedRentAmount ?? undefined,
    employerName: body.employerName ?? undefined,
    employerContact: body.employerContact ?? undefined,
    monthlyIncome: body.monthlyIncome ?? undefined,
    guarantorName: body.guarantorName ?? undefined,
    guarantorPhone: body.guarantorPhone ?? undefined,
    responseNote: body.responseNote ?? undefined,
  });
  res.json(application);
}

export async function withdrawApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const application = await service.withdrawApplication(userId, getParam(req, 'applicationId'));
  res.json(application);
}

// ---------------------------------------------------------------------------
// Manager
// ---------------------------------------------------------------------------

export async function listApplications(req: AuthenticatedRequest, res: Response) {
  const managerId = assertAuth(req);
  const q = req.query as Record<string, unknown>;
  const result = await service.listInbox(managerId, {
    propertyId: typeof q.propertyId === 'string' ? q.propertyId : undefined,
    unitId: typeof q.unitId === 'string' ? q.unitId : undefined,
    status: typeof q.status === 'string' ? q.status : undefined,
    fromDate: typeof q.fromDate === 'string' ? new Date(q.fromDate) : undefined,
    toDate: typeof q.toDate === 'string' ? new Date(q.toDate) : undefined,
    limit: Number(q.limit) || 20,
    offset: Number(q.offset) || 0,
  });
  res.json(result);
}

export async function getApplication(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  const detail = await service.getApplicationDetail(actorId, getParam(req, 'applicationId'));
  res.json(detail);
}

export async function transition(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  const body = req.body;
  const result = await service.transitionApplication({
    applicationId: getParam(req, 'applicationId'),
    actorId,
    actorKind: 'manager',
    action: body.action,
    reason: body.reason ?? null,
  });
  res.json(result);
}

export async function approve(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  const body = req.body;
  const result = await service.transitionApplication({
    applicationId: getParam(req, 'applicationId'),
    actorId,
    actorKind: 'manager',
    action: 'approve',
    reason: body.reason ?? null,
    terms: {
      approvedRentAmount: body.approvedRentAmount ?? undefined,
      approvedDepositAmount: body.approvedDepositAmount ?? undefined,
      approvedStartDate: body.approvedStartDate ?? undefined,
      approvedEndDate: body.approvedEndDate ?? undefined,
    },
  });
  res.json(result);
}

export async function onboard(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  const onboarding = await service.retryOnboarding(actorId, getParam(req, 'applicationId'));
  res.json({ onboarding });
}

export async function addNote(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  const note = await service.addInternalNote(actorId, getParam(req, 'applicationId'), req.body.note);
  res.status(201).json(note);
}

// ---------------------------------------------------------------------------
// Documents (shared)
// ---------------------------------------------------------------------------

export async function uploadDocument(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const applicationId = getParam(req, 'applicationId');

  const file = (req as unknown as { file?: { buffer: Buffer; originalname: string; mimetype: string; size: number } }).file;
  if (!file) throw new ValidationError('A file is required');
  if (!file.size || file.size <= 0) throw new ValidationError('Uploaded file is empty');
  if (file.size > MAX_DOC_BYTES) {
    throw new ValidationError(`Document exceeds the ${MAX_DOC_BYTES} byte limit`);
  }
  if (!ALLOWED_DOC_MIME.has(file.mimetype)) {
    throw new ValidationError('Unsupported document type');
  }

  const category = (req.body?.category as string | undefined)?.trim() || 'supporting';

  const record = (await service.attachDocument(userId, applicationId, {
    storageKey: `pending/${randomUUID()}`,
    fileName: file.originalname,
    mimeType: file.mimetype,
    fileSizeBytes: file.size,
    category,
  })) as { id: string };

  const storageKey = `rental-applications/${applicationId}/${record.id}/${randomUUID()}`;
  try {
    await putPrivateDocument(storageKey, file.buffer, file.mimetype);
  } catch (error) {
    // Best-effort cleanup so we don't keep a metadata row without an object.
    const { pool } = await import('../../db/pool.js');
    await pool
      .query(`DELETE FROM rental_application_documents WHERE id = $1`, [record.id])
      .catch(() => undefined);
    throw error;
  }

  // Persist the real storage key now that the object exists.
  const { pool } = await import('../../db/pool.js');
  await pool.query(`UPDATE rental_application_documents SET storage_key = $1 WHERE id = $2`, [
    storageKey,
    record.id,
  ]);

  res.status(201).json({ ...(record as object), storageKey });
}

export async function listDocuments(req: AuthenticatedRequest, res: Response) {
  const actorId = assertAuth(req);
  // Authorization + scoping enforced by getApplicationDetail.
  const detail = await service.getApplicationDetail(actorId, getParam(req, 'applicationId'));
  res.json(detail.documents);
}

export async function downloadDocument(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const doc = await service.getDocumentForDownload(userId, getParam(req, 'documentId'));
  const url = await signedPrivateDocumentUrl(
    doc.storageKey,
    doc.fileName,
    doc.mimeType ?? 'application/octet-stream',
  );
  res.json({ id: getParam(req, 'documentId'), url, expiresInSeconds: 300 });
}