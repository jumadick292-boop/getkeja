// Garbage collection operations controller (Task 13.7).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  CreateGarbageAgreementInput,
  CreateGarbageJobInput,
  GarbageCompletionInput,
  GarbageCustomerConfirmationInput,
  GarbageProgressInput,
} from './garbage.schemas.js';
import type { GarbageCollectionStatus } from './garbage.types.js';
import * as service from './garbage.service.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function str(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

// ---- Customer ----
export async function listCustomerJobs(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { status?: GarbageCollectionStatus; limit: number; offset: number };
  const result = await service.listCustomerJobs(userId, q);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getCustomerJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getCustomerJob(userId, req.params.jobId as string) });
}

export async function cancelJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.cancelJob(userId, req.params.jobId as string, body.reason) });
}

export async function confirmCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.confirmCompletion(userId, req.params.jobId as string, req.body as GarbageCustomerConfirmationInput) });
}

export async function reportException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { type: string; description: string };
  res.json({ success: true, data: await service.reportException(userId, req.params.jobId as string, body) });
}

export async function listCustomerAgreements(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.listCustomerAgreements(userId) });
}

export async function decideAgreement(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean };
  res.json({ success: true, data: await service.decideAgreement(userId, req.params.agreementId as string, body.accept) });
}

export async function getAgreementOccurrences(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getAgreementOccurrences(userId, req.params.agreementId as string) });
}

// ---- Provider ----
export async function createJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.createJobFromQuotation(userId, req.body as CreateGarbageJobInput, organizationId ?? null) });
}

export async function listProviderJobs(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { status?: GarbageCollectionStatus; organizationId?: string; limit: number; offset: number };
  const result = await service.listProviderJobs(userId, {
    status: q.status,
    organizationId: str(q.organizationId),
    limit: q.limit,
    offset: q.offset,
  });
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getProviderJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.getProviderJob(userId, req.params.jobId as string, organizationId ?? null) });
}

export async function updateProgress(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.updateProgress(userId, req.params.jobId as string, req.body as GarbageProgressInput, organizationId ?? null) });
}

export async function markMissed(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.markMissed(userId, req.params.jobId as string, body.reason, organizationId ?? null) });
}

export async function failJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.failJob(userId, req.params.jobId as string, body.reason, organizationId ?? null) });
}

export async function providerCancelJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.cancelJob(userId, req.params.jobId as string, body.reason) });
}

export async function assignStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { userId: string; label?: string };
  res.json({ success: true, data: await service.assignStaff(userId, req.params.jobId as string, body, organizationId ?? null) });
}

export async function updateChecklist(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { items: Record<string, boolean> };
  res.json({ success: true, data: await service.updateChecklist(userId, req.params.jobId as string, body.items, organizationId ?? null) });
}

export async function reschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.reschedule(userId, req.params.jobId as string, req.body as { scheduledDate: string; windowStart?: string | null; windowEnd?: string | null; reason?: string }, organizationId ?? null) });
}

export async function submitCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.submitCompletion(userId, req.params.jobId as string, req.body as GarbageCompletionInput, organizationId ?? null) });
}

export async function proposeAgreement(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.proposeAgreement(userId, req.body as CreateGarbageAgreementInput, organizationId ?? null) });
}

export async function listProviderAgreements(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.listProviderAgreements(userId, organizationId ?? null) });
}

export async function setAgreementStatus(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { status: 'suspended' | 'active' | 'cancelled' | 'completed' };
  res.json({ success: true, data: await service.setAgreementStatus(userId, req.params.agreementId as string, body.status, organizationId ?? null) });
}