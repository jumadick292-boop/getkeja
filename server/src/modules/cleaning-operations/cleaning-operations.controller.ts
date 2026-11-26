// Cleaning & Property Care controller (Task 13.13).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  CleaningAreaInput,
  CleaningAssessmentInput,
  CleaningAttachmentInput,
  CleaningChecklistInput,
  CleaningMaterialInput,
  CleaningProgressInput,
  CreateCleaningJobInput,
  ProposeCleaningAmendmentInput,
} from './cleaning-operations.schemas.js';
import type { CleaningOperationStatus } from './cleaning-operations.types.js';
import * as service from './cleaning-operations.service.js';

interface AuthenticatedRequest extends Request { user?: AuthUser; }

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function orgId(req: AuthenticatedRequest): string | null {
  const h = req.headers['x-organization-id'];
  return typeof h === 'string' && h.length > 0 ? h : null;
}

function str(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

function listQuery(req: AuthenticatedRequest) {
  return req.query as unknown as { status?: CleaningOperationStatus; limit: number; offset: number };
}

// ---- Customer ----
export async function listCustomerJobs(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = listQuery(req);
  const result = await service.listCustomerJobs(userId, q);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getCustomerJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getCustomerJob(userId, String(req.params.jobId)) });
}

export async function cancelJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason?: string };
  res.json({ success: true, data: await service.cancelJob(userId, String(req.params.jobId), str(body.reason) ?? null) });
}

export async function confirmCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { confirm: boolean; notes?: string };
  res.json({ success: true, data: await service.confirmCompletion(userId, String(req.params.jobId), body.confirm, str(body.notes) ?? null) });
}

export async function reportException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { type: string; description: string };
  res.json({ success: true, data: await service.reportException(userId, String(req.params.jobId), body.type, body.description) });
}

export async function decideAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { decision: 'approve' | 'reject' };
  res.json({ success: true, data: await service.decideAmendment(userId, String(req.params.jobId), String(req.params.amendmentId), body.decision) });
}

export async function decideMaterial(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { decision: 'approve' | 'reject' };
  res.json({ success: true, data: await service.decideMaterial(userId, String(req.params.jobId), String(req.params.materialId), body.decision) });
}

// ---- Provider ----
export async function createJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CreateCleaningJobInput;
  res.status(201).json({ success: true, data: await service.createJobFromQuotation(userId, body, orgId(req)) });
}

export async function listProviderJobs(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = listQuery(req);
  const result = await service.listProviderJobs(userId, orgId(req), q);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getProviderJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getProviderJob(userId, orgId(req), String(req.params.jobId)) });
}

export async function updateProgress(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningProgressInput;
  res.json({ success: true, data: await service.updateProgress(userId, orgId(req), String(req.params.jobId), body) });
}

export async function failJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.failJob(userId, orgId(req), String(req.params.jobId), body.reason) });
}

export async function providerCancelJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason?: string };
  res.json({ success: true, data: await service.providerCancelJob(userId, orgId(req), String(req.params.jobId), str(body.reason) ?? null) });
}

export async function recordAssessment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningAssessmentInput;
  res.json({ success: true, data: await service.recordAssessment(userId, orgId(req), String(req.params.jobId), body) });
}

export async function createChecklist(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningChecklistInput;
  res.json({ success: true, data: await service.createChecklist(userId, orgId(req), String(req.params.jobId), body) });
}

export async function updateChecklistItem(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { itemId: string; done: boolean };
  res.json({ success: true, data: await service.updateChecklistItem(userId, orgId(req), String(req.params.jobId), String(req.params.checklistId), body.itemId, body.done) });
}

export async function addArea(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningAreaInput;
  res.json({ success: true, data: await service.addArea(userId, orgId(req), String(req.params.jobId), body) });
}

export async function addMaterial(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningMaterialInput;
  res.status(201).json({ success: true, data: await service.addMaterial(userId, orgId(req), String(req.params.jobId), body) });
}

export async function decideMaterialProvider(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { decision: 'approve' | 'reject' };
  res.json({ success: true, data: await service.decideMaterialProvider(userId, orgId(req), String(req.params.jobId), String(req.params.materialId), body.decision) });
}

export async function addAttachment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CleaningAttachmentInput;
  res.status(201).json({ success: true, data: await service.addAttachment(userId, orgId(req), String(req.params.jobId), body) });
}

export async function assignStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { userId: string; label?: string };
  res.json({ success: true, data: await service.assignStaff(userId, orgId(req), String(req.params.jobId), body.userId, str(body.label) ?? null) });
}

export async function revokeStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.revokeStaff(userId, orgId(req), String(req.params.jobId), String(req.params.staffUserId)) });
}

export async function proposeAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as ProposeCleaningAmendmentInput;
  res.status(201).json({ success: true, data: await service.proposeAmendment(userId, orgId(req), String(req.params.jobId), body) });
}

export async function submitCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { notes?: string };
  res.json({ success: true, data: await service.submitCompletion(userId, orgId(req), String(req.params.jobId), str(body.notes) ?? null) });
}