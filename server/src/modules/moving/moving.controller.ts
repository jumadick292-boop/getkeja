// Moving & relocation operations controller (Task 13.6).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  AssignStaffInput,
  CompletionSubmissionInput,
  CreateAssessmentInput,
  CreateMovingJobInput,
  CustomerConfirmationInput,
  MovingProgressInput,
  ProposeAmendmentInput,
  ProposeRescheduleInput,
} from './moving.schemas.js';
import type { MovingJobStatus } from './moving.types.js';
import * as service from './moving.service.js';

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
  const q = req.query as unknown as { status?: MovingJobStatus; limit: number; offset: number };
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
  res.json({ success: true, data: await service.confirmCompletion(userId, req.params.jobId as string, req.body as CustomerConfirmationInput) });
}

export async function respondAssessment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean; customerNotes?: string };
  res.json({ success: true, data: await service.respondAssessment(userId, req.params.assessmentId as string, body.accept, body.customerNotes) });
}

export async function customerProposeReschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.proposeReschedule(userId, req.params.jobId as string, req.body as ProposeRescheduleInput) });
}

export async function decideReschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean };
  res.json({ success: true, data: await service.decideReschedule(userId, req.params.jobId as string, req.params.changeId as string, body.accept) });
}

export async function decideAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean };
  res.json({ success: true, data: await service.decideAmendment(userId, req.params.jobId as string, req.params.amendmentId as string, body.accept) });
}

// ---- Provider ----
export async function createJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.createJobFromQuotation(userId, req.body as CreateMovingJobInput, organizationId ?? null) });
}

export async function listProviderJobs(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { status?: MovingJobStatus; organizationId?: string; limit: number; offset: number };
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
  res.json({ success: true, data: await service.updateProgress(userId, req.params.jobId as string, req.body as MovingProgressInput, organizationId ?? null) });
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
  res.json({ success: true, data: await service.assignStaff(userId, req.params.jobId as string, req.body as AssignStaffInput, organizationId ?? null) });
}

export async function updateChecklist(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { items: Record<string, boolean> };
  res.json({ success: true, data: await service.updateChecklist(userId, req.params.jobId as string, body.items, organizationId ?? null) });
}

export async function requestAssessment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.requestAssessment(userId, req.params.jobId as string, req.body as CreateAssessmentInput, organizationId ?? null) });
}

export async function completeAssessment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { outcome: string; providerNotes?: string };
  res.json({ success: true, data: await service.completeAssessment(userId, req.params.assessmentId as string, body.outcome, body.providerNotes, organizationId ?? null) });
}

export async function providerProposeReschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.proposeReschedule(userId, req.params.jobId as string, req.body as ProposeRescheduleInput) });
}

export async function proposeAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.proposeAmendment(userId, req.params.jobId as string, req.body as ProposeAmendmentInput, organizationId ?? null) });
}

export async function submitCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.submitCompletion(userId, req.params.jobId as string, req.body as CompletionSubmissionInput, organizationId ?? null) });
}