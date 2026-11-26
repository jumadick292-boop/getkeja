// Service marketplace controller (Task 13.5).
// Customer + provider HTTP handlers under /api/v1/marketplace.
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  AcceptQuotationInput,
  CreateServiceRequestInput,
  ServiceRequestListQuery,
  SubmitQuotationInput,
} from './marketplace.schemas.js';
import type { ServiceDomain } from './marketplace.types.js';
import * as service from './marketplace.service.js';

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

// ---- Catalogue ----
export async function browseCategories(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const domain = str(req.query.domain) as ServiceDomain | undefined;
  res.json({ success: true, data: await service.browseCategories(domain) });
}

// ---- Customer requests ----
export async function createRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const request = await service.createRequest(userId, req.body as CreateServiceRequestInput);
  res.status(201).json({ success: true, data: request });
}

export async function listMyRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as ServiceRequestListQuery;
  const result = await service.listMyRequests(userId, q);
  res.json({
    success: true,
    data: result.rows,
    pagination: { total: result.total, limit: q.limit, offset: q.offset },
  });
}

export async function getMyRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getMyRequest(userId, req.params.requestId as string) });
}

export async function cancelRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason?: string };
  res.json({ success: true, data: await service.cancelRequest(userId, req.params.requestId as string, body.reason) });
}

export async function acceptQuotation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const request = await service.acceptQuotation(
    userId,
    req.params.requestId as string,
    req.params.quotationId as string,
    req.body as AcceptQuotationInput,
  );
  res.json({ success: true, data: request });
}

// ---- Provider quotation inbox ----
export async function providerInbox(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as unknown as { domain?: ServiceDomain; organizationId?: string; limit: number; offset: number };
  const result = await service.listProviderInbox(userId, {
    domain: q.domain,
    organizationId: str(q.organizationId),
    limit: q.limit,
    offset: q.offset,
  });
  res.json({
    success: true,
    data: result.rows,
    pagination: { total: result.total, limit: q.limit, offset: q.offset },
  });
}

export async function providerRequestDetail(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.getProviderRequest(userId, req.params.requestId as string, organizationId ?? null) });
}

export async function submitQuotation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const request = await service.submitQuotation(
    userId,
    req.params.requestId as string,
    req.body as SubmitQuotationInput,
    organizationId ?? null,
  );
  res.status(201).json({ success: true, data: request });
}

export async function withdrawQuotation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const body = req.body as { reason?: string };
  await service.withdrawQuotation(userId, req.params.quotationId as string, body.reason, organizationId ?? null);
  res.json({ success: true, data: { withdrawn: true } });
}

export async function advanceJob(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  const toStatus = req.params.action === 'complete' ? 'completed' : 'in_progress';
  res.json({ success: true, data: await service.advanceJob(userId, req.params.requestId as string, toStatus, organizationId ?? null) });
}