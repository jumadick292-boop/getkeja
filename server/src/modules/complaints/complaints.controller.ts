// Provider complaints controller (Task 13.16).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type { CreateComplaintInput, ComplaintTransitionInput } from './complaints.schemas.js';
import * as service from './complaints.service.js';

interface AuthenticatedRequest extends Request { user?: AuthUser; }

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function orgId(req: AuthenticatedRequest): string | null {
  const h = req.headers['x-organization-id'];
  return typeof h === 'string' && h.length > 0 ? h : null;
}

export async function listReasons(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  res.json({ success: true, data: await service.listReasons() });
}

export async function submitComplaint(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CreateComplaintInput;
  res.status(201).json({ success: true, data: await service.submitComplaint(userId, String(req.params.domain), String(req.params.resourceId), body) });
}

export async function listCustomerComplaints(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { status?: string; limit?: number; offset?: number };
  const result = await service.listCustomerComplaints(userId, q.status, q.limit ?? 20, q.offset ?? 0);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit ?? 20, offset: q.offset ?? 0 } });
}

export async function listProviderComplaints(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { status?: string; limit?: number; offset?: number };
  const result = await service.listProviderComplaints(userId, orgId(req), q.status, q.limit ?? 20, q.offset ?? 0);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit ?? 20, offset: q.offset ?? 0 } });
}

export async function listAdminQueue(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { status?: string; limit?: number; offset?: number };
  const result = await service.listAdminQueue(userId, q.status, q.limit ?? 20, q.offset ?? 0);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit ?? 20, offset: q.offset ?? 0 } });
}

export async function getComplaint(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getComplaint(userId, orgId(req), String(req.params.complaintId)) });
}

export async function postMessage(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { body: string; documentIds?: string[] };
  res.status(201).json({ success: true, data: await service.postMessage(userId, orgId(req), String(req.params.complaintId), body.body, body.documentIds ?? []) });
}

export async function recordCorrectiveAction(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { action: string };
  res.status(201).json({ success: true, data: await service.recordCorrectiveAction(userId, orgId(req), String(req.params.complaintId), body.action) });
}

export async function addInternalNote(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { body: string };
  res.status(201).json({ success: true, data: await service.addInternalNote(userId, String(req.params.complaintId), body.body) });
}

export async function assignComplaint(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { adminUserId: string };
  res.json({ success: true, data: await service.assignComplaint(userId, String(req.params.complaintId), body.adminUserId) });
}

export async function changeStatus(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as ComplaintTransitionInput;
  res.json({ success: true, data: await service.changeStatus(userId, orgId(req), String(req.params.complaintId), body.to, body.reason ?? null, body.resolutionSummary ?? null) });
}