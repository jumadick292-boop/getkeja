// Laundry operations controller (Task 13.8).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  CreateLaundryOrderInput,
  LaundryCompletionInput,
  LaundryCustomerConfirmationInput,
  LaundryInspectionInput,
  LaundryItemInput,
  LaundryProgressInput,
  ProposeLaundryAmendmentInput,
  ScheduleHandoverInput,
} from './laundry.schemas.js';
import type { LaundryCollectionStatus } from './laundry.types.js';
import * as service from './laundry.service.js';

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
export async function listCustomerOrders(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { status?: LaundryCollectionStatus; limit: number; offset: number };
  const result = await service.listCustomerOrders(userId, q);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getCustomerOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getCustomerOrder(userId, req.params.orderId as string) });
}

export async function cancelOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.cancelOrder(userId, req.params.orderId as string, body.reason) });
}

export async function confirmCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.confirmCompletion(userId, req.params.orderId as string, req.body as LaundryCustomerConfirmationInput) });
}

export async function reportException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { type: string; description: string };
  res.json({ success: true, data: await service.reportException(userId, req.params.orderId as string, body) });
}

export async function resolveInspection(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { decision: 'approve' | 'reject'; notes?: string };
  res.json({ success: true, data: await service.resolveInspection(userId, req.params.orderId as string, req.params.inspectionId as string, body.decision, body.notes) });
}

export async function decideAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean };
  res.json({ success: true, data: await service.decideAmendment(userId, req.params.orderId as string, req.params.amendmentId as string, body.accept) });
}

// ---- Provider ----
export async function createOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.createOrderFromQuotation(userId, req.body as CreateLaundryOrderInput, organizationId ?? null) });
}

export async function listProviderOrders(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { status?: LaundryCollectionStatus; organizationId?: string; limit: number; offset: number };
  const result = await service.listProviderOrders(userId, {
    status: q.status,
    organizationId: str(q.organizationId),
    limit: q.limit,
    offset: q.offset,
  });
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit, offset: q.offset } });
}

export async function getProviderOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.getProviderOrder(userId, req.params.orderId as string, organizationId ?? null) });
}

export async function updateProgress(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.updateProgress(userId, req.params.orderId as string, req.body as LaundryProgressInput, organizationId ?? null) });
}

export async function failOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.failOrder(userId, req.params.orderId as string, body.reason, organizationId ?? null) });
}

export async function providerCancelOrder(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string };
  res.json({ success: true, data: await service.cancelOrder(userId, req.params.orderId as string, body.reason) });
}

export async function addItem(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.addItem(userId, req.params.orderId as string, req.body as LaundryItemInput, organizationId ?? null) });
}

export async function updateItem(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as Record<string, unknown>;
  res.json({ success: true, data: await service.updateItem(userId, req.params.orderId as string, req.params.itemId as string, body, organizationId ?? null) });
}

export async function recordInspection(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.recordInspection(userId, req.params.orderId as string, req.body as LaundryInspectionInput, organizationId ?? null) });
}

export async function assignStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { userId: string; label?: string };
  res.json({ success: true, data: await service.assignStaff(userId, req.params.orderId as string, body, organizationId ?? null) });
}

export async function revokeStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.revokeStaff(userId, req.params.orderId as string, req.params.staffUserId as string, organizationId ?? null) });
}

export async function updateChecklist(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { items: Record<string, boolean> };
  res.json({ success: true, data: await service.updateChecklist(userId, req.params.orderId as string, body.items, organizationId ?? null) });
}

export async function scheduleHandover(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.scheduleHandover(userId, req.params.orderId as string, req.body as ScheduleHandoverInput, organizationId ?? null) });
}

export async function confirmHandover(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { proofDocumentIds?: string[]; notes?: string };
  res.json({ success: true, data: await service.confirmHandover(userId, req.params.orderId as string, req.params.handoverId as string, body.proofDocumentIds ?? [], body.notes, organizationId ?? null) });
}

export async function proposeAmendment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.proposeAmendment(userId, req.params.orderId as string, req.body as ProposeLaundryAmendmentInput, organizationId ?? null) });
}

export async function submitCompletion(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.submitCompletion(userId, req.params.orderId as string, req.body as LaundryCompletionInput, organizationId ?? null) });
}