// Recurring billing controllers (Task 14.1).
import type { Response } from 'express';
import type { AuthUser } from '../../auth/auth.types.js';
import type { Request } from 'express';
import { ForbiddenError } from '../../../shared/errors.js';
import * as service from './billing.service.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function param(req: AuthenticatedRequest, name: string): string {
  const v = req.params[name];
  return (Array.isArray(v) ? v[0] : v) as string;
}

export async function createSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.createSchedule(userId, req.body);
  res.status(201).json({ success: true, data: schedule });
}

export async function listSchedules(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const q = req.query as Record<string, unknown>;
  const schedules = await service.listSchedules(userId, {
    propertyId: q.propertyId as string | undefined,
    unitId: q.unitId as string | undefined,
    tenantId: q.tenantId as string | undefined,
    tenancyId: q.tenancyId as string | undefined,
    status: q.status as never,
    limit: q.limit ? Number(q.limit) : 20,
    offset: q.offset ? Number(q.offset) : 0,
  });
  res.json({ success: true, data: schedules });
}

export async function getSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.getSchedule(userId, param(req, 'scheduleId'));
  res.json({ success: true, data: schedule });
}

export async function updateSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.changeRent(userId, param(req, 'scheduleId'), req.body);
  res.json({ success: true, data: schedule });
}

export async function activateSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.setStatus(userId, param(req, 'scheduleId'), 'active');
  res.json({ success: true, data: schedule });
}

export async function suspendSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.setStatus(userId, param(req, 'scheduleId'), 'suspended', (req.body as { reason?: string })?.reason ?? null);
  res.json({ success: true, data: schedule });
}

export async function resumeSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.setStatus(userId, param(req, 'scheduleId'), 'active');
  res.json({ success: true, data: schedule });
}

export async function cancelSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const schedule = await service.setStatus(userId, param(req, 'scheduleId'), 'cancelled', (req.body as { reason?: string })?.reason ?? null);
  res.json({ success: true, data: schedule });
}

export async function previewSchedule(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const periodStart = (req.query as { billingPeriodStart?: string }).billingPeriodStart;
  const preview = await service.preview(userId, param(req, 'scheduleId'), periodStart);
  res.json({ success: true, data: preview });
}

export async function listRentTerms(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const terms = await service.listRentTerms(userId, param(req, 'scheduleId'));
  res.json({ success: true, data: terms });
}

export async function listInvoices(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const q = req.query as Record<string, unknown>;
  const invoices = await service.listInvoices(userId, {
    propertyId: q.propertyId as string | undefined,
    unitId: q.unitId as string | undefined,
    tenantId: q.tenantId as string | undefined,
    tenancyId: q.tenancyId as string | undefined,
    billingScheduleId: q.billingScheduleId as string | undefined,
    status: q.status as never,
    source: q.source as string | undefined,
    fromDate: q.fromDate as string | undefined,
    toDate: q.toDate as string | undefined,
    limit: q.limit ? Number(q.limit) : 20,
    offset: q.offset ? Number(q.offset) : 0,
  });
  res.json({ success: true, data: invoices });
}

export async function getInvoice(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const { invoice, items } = await service.getInvoice(userId, param(req, 'invoiceId'));
  res.json({ success: true, data: { ...invoice, lineItems: items } });
}

export async function voidInvoice(req: AuthenticatedRequest, res: Response): Promise<void> {
  const userId = assertAuth(req);
  const reason = (req.body as { reason?: string })?.reason ?? '';
  const invoice = await service.voidInvoice(userId, param(req, 'invoiceId'), reason);
  res.json({ success: true, data: invoice });
}