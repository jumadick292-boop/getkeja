// Provider reporting controller (Task 13.16).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type { ProviderDashboardFilters } from '../provider-dashboard/provider-dashboard.types.js';
import * as service from './provider-reporting.service.js';

interface AuthenticatedRequest extends Request { user?: AuthUser; }

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function orgId(req: AuthenticatedRequest): string | null {
  const h = req.headers['x-organization-id'];
  return typeof h === 'string' && h.length > 0 ? h : null;
}

function str(v: unknown): string | undefined {
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function filters(req: AuthenticatedRequest): ProviderDashboardFilters {
  const q = req.query as Record<string, unknown>;
  return { domain: str(q.domain), categoryId: str(q.categoryId), from: str(q.from), to: str(q.to) };
}

export async function getOperationalReport(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getOperationalReport(userId, orgId(req), filters(req)) });
}

export async function getServicePerformance(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getServicePerformance(userId, orgId(req)) });
}

export async function getCustomerExperience(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getCustomerExperience(userId, orgId(req)) });
}