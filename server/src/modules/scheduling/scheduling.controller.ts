// Shared scheduling controller (Task 13.8/13.9).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  AssignStaffInput,
  AvailabilityCheckInput,
  CapacityInput,
  CreateScheduleInput,
  RequestRescheduleInput,
} from './scheduling.schemas.js';
import type { CalendarFilters } from './scheduling.types.js';
import * as service from './scheduling.service.js';

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

function calendarFilters(query: Record<string, unknown>): CalendarFilters {
  return {
    from: query.from as string,
    to: query.to as string,
    domains: query.domains as CalendarFilters['domains'],
    status: query.status as CalendarFilters['status'],
    staffUserId: str(query.staffUserId),
    limit: Number(query.limit ?? 200),
  };
}

export async function providerCalendar(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.providerCalendar(userId, calendarFilters(req.query as Record<string, unknown>), organizationId ?? null) });
}

export async function customerCalendar(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.customerCalendar(userId, calendarFilters(req.query as Record<string, unknown>)) });
}

export async function getActivity(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getActivityDetail(userId, req.params.activityId as string) });
}

export async function createSchedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.status(201).json({ success: true, data: await service.createSchedule(userId, req.body as CreateScheduleInput, organizationId ?? null) });
}

export async function requestReschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.status(201).json({ success: true, data: await service.requestReschedule(userId, req.params.activityId as string, req.body as RequestRescheduleInput) });
}

export async function decideReschedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { accept: boolean };
  res.json({ success: true, data: await service.decideReschedule(userId, req.params.activityId as string, req.params.requestId as string, body.accept) });
}

export async function cancelSchedule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason?: string };
  res.json({ success: true, data: await service.cancelSchedule(userId, req.params.activityId as string, body.reason) });
}

export async function assignStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.assignStaff(userId, req.params.activityId as string, req.body as AssignStaffInput, organizationId ?? null) });
}

export async function revokeStaff(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.revokeStaff(userId, req.params.activityId as string, req.params.staffUserId as string, organizationId ?? null) });
}

export async function checkAvailability(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  res.json({ success: true, data: await service.checkAvailability(req.body as AvailabilityCheckInput) });
}

export async function setStaffAvailability(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { days: Array<{ dayOfWeek: number; openTime: string; closeTime: string; isAvailable: boolean; timeZone: string }> };
  await service.setStaffAvailability(userId, body.days);
  res.json({ success: true, data: { updated: body.days.length } });
}

export async function addStaffLeave(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { startDate: string; endDate: string; reason?: string };
  await service.addStaffLeave(userId, body.startDate, body.endDate, body.reason);
  res.status(201).json({ success: true, data: { created: true } });
}

export async function setCapacity(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organizationId = str(req.query.organizationId);
  await service.setCapacity(userId, req.body as CapacityInput, organizationId ?? null);
  res.json({ success: true, data: { updated: true } });
}