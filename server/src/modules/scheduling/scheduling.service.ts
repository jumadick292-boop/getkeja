// Shared scheduling service (Task 13.9).
// Coordinates scheduling, staff assignment, rescheduling and reminders across
// moving / garbage / laundry WITHOUT owning their lifecycles. Domain adapters
// validate resource ownership + eligibility and mirror confirmed windows back to
// the domain record. Business change + outbox share one transaction.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  AssignStaffInput,
  AvailabilityCheckInput,
  CapacityInput,
  CreateScheduleInput,
  RequestRescheduleInput,
} from './scheduling.schemas.js';
import type {
  CalendarFilters,
  SchedulingActivity,
  SchedulingDomain,
} from './scheduling.types.js';
import * as repo from './scheduling.repository.js';

interface ResourceInfo {
  customerUserId: string | null;
  providerProfileId: string;
  status: string;
  startAt: string | null;
  endAt: string | null;
  address: string | null;
}

const TERMINAL: Record<SchedulingDomain, string[]> = {
  moving: ['completed', 'cancelled', 'failed'],
  garbage: ['completed', 'cancelled', 'missed', 'failed'],
  garbage_occurrence: ['completed', 'cancelled', 'missed', 'failed'],
  laundry: ['completed', 'cancelled', 'failed', 'exception'],
  home_maintenance: ['completed', 'cancelled', 'failed'],
  cleaning: ['completed', 'cancelled', 'failed'],
  installation: ['completed', 'cancelled', 'failed'],
  finishing: ['completed', 'cancelled', 'failed'],
};

// Domain adapter: load the operational resource and validate scheduling
// eligibility. Returns normalized info; throws if not found / not owned / closed.
async function loadResource(domain: SchedulingDomain, resourceId: string): Promise<ResourceInfo> {
  switch (domain) {
    case 'moving': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                agreed_move_date AS "startDate", agreed_window_start AS "ws", agreed_window_end AS "we", origin_address AS "address"
           FROM moving_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Moving job not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'garbage': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                scheduled_date AS "startDate", collection_address AS "address" FROM garbage_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Garbage collection not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'garbage_occurrence': {
      const r = await pool.query(
        `SELECT a.customer_user_id AS "customerUserId", a.provider_profile_id AS "providerProfileId",
                o.status::text AS status, o.scheduled_date AS "startDate", o.window_start AS "ws"
           FROM garbage_recurring_occurrences o
           JOIN garbage_recurring_agreements a ON a.id = o.agreement_id
          WHERE o.id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Garbage occurrence not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: null };
    }
    case 'laundry': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                collection_date AS "startDate", collection_address AS "address" FROM laundry_orders WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Laundry order not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'home_maintenance': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                created_at AS "startDate", service_address AS "address" FROM home_maintenance_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Maintenance job not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'cleaning': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                created_at AS "startDate", service_address AS "address" FROM cleaning_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Cleaning job not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'installation': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                created_at AS "startDate", service_address AS "address" FROM installation_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Installation job not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    case 'finishing': {
      const r = await pool.query(
        `SELECT customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId", status::text AS status,
                created_at AS "startDate", service_address AS "address" FROM finishing_jobs WHERE id = $1`, [resourceId]);
      if (!r.rows[0]) throw new NotFoundError('Finishing job not found');
      const x = r.rows[0];
      return { customerUserId: x.customerUserId, providerProfileId: x.providerProfileId, status: x.status, startAt: x.startDate, endAt: null, address: x.address ?? null };
    }
    default:
      throw new ValidationError('Unsupported domain');
  }
}

function assertEligible(domain: SchedulingDomain, status: string): void {
  if (TERMINAL[domain].includes(status)) {
    throw new ConflictError(`A ${domain} resource in status ${status} cannot be scheduled or rescheduled`);
  }
}

async function loadProviderContext(userId: string, organizationId?: string | null): Promise<ProviderContext> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

function capacityKeyFor(staffUserId: string | null, providerProfileId: string): string {
  return staffUserId ? `staff:${staffUserId}` : `provider:${providerProfileId}`;
}

// ---------------------------------------------------------------------------
// Create / confirm a schedule for an existing resource.
// ---------------------------------------------------------------------------
export async function createSchedule(userId: string, input: CreateScheduleInput, organizationId?: string | null): Promise<SchedulingActivity> {
  const context = await loadProviderContext(userId, organizationId);
  const info = await loadResource(input.domain, input.resourceId);
  if (!context.effectiveProfileIds.includes(info.providerProfileId)) {
    throw new ForbiddenError('You may not schedule this resource');
  }
  assertEligible(input.domain, info.status);

  const existing = await repo.findActivityByResource(input.domain, input.resourceId);
  if (existing) throw new ConflictError('A schedule already exists for this resource');

  const capacityKey = input.capacityKey ?? capacityKeyFor(input.staffUserId ?? null, info.providerProfileId);

  // Friendly pre-check; the DB EXCLUDE constraint is the hard guarantee.
  if (await repo.hasOverlap(capacityKey, input.startAt, input.endAt)) {
    throw new ConflictError('The selected slot overlaps an existing confirmed appointment');
  }

  let activityId: string;
  try {
    activityId = await transaction(async (client) => {
      const created = await repo.insertActivity(client, {
        domain: input.domain,
        resourceId: input.resourceId,
        movingJobId: input.domain === 'moving' ? input.resourceId : null,
        garbageJobId: input.domain === 'garbage' ? input.resourceId : null,
        garbageOccurrenceId: input.domain === 'garbage_occurrence' ? input.resourceId : null,
        laundryOrderId: input.domain === 'laundry' ? input.resourceId : null,
        homeMaintenanceJobId: input.domain === 'home_maintenance' ? input.resourceId : null,
        cleaningJobId: input.domain === 'cleaning' ? input.resourceId : null,
        installationJobId: input.domain === 'installation' ? input.resourceId : null,
        finishingJobId: input.domain === 'finishing' ? input.resourceId : null,
        startAt: input.startAt,
        endAt: input.endAt,
        timeZone: input.timeZone,
        allDay: input.allDay,
        status: 'confirmed',
        locationId: input.locationId ?? null,
        address: input.address ?? info.address,
        customerUserId: info.customerUserId,
        providerProfileId: info.providerProfileId,
        providerOrganisationId: context.activeOrganizationId,
        assignedStaffUserId: input.staffUserId ?? null,
        capacityKey,
        createdBy: userId,
      });
      if (input.staffUserId) {
        await repo.insertStaffAssignment(client, { activityId: created.id, userId: input.staffUserId, providerOrganisationId: context.activeOrganizationId, label: null, assignedBy: userId });
      }
      if (input.reminderMinutesBefore != null) {
        const remindAt = new Date(new Date(input.startAt).getTime() - input.reminderMinutesBefore * 60000).toISOString();
        await repo.upsertReminder(client, created.id, remindAt);
      }
      const eventType = 'schedule.confirmed';
      await enqueueOutboxEventTransactional(client, {
        idempotencyKey: `${eventType}:${created.id}`,
        eventType,
        category: 'operational',
        priority: 'high',
        recipientUserIds: info.customerUserId ? [info.customerUserId] : [],
        organisationId: context.activeOrganizationId,
        resourceType: 'scheduling_activity',
        resourceId: created.id,
        payload: { activityId: created.id, domain: input.domain, startAt: input.startAt },
        channels: ['in_app'],
        classification: classifyEventType(eventType),
      });
      return created.id;
    });
  } catch (error) {
    // Unique violation (resource already scheduled) or EXCLUDE (overlap) => 409.
    const code = (error as { code?: string }).code;
    if (code === '23505' || code === '23P01') {
      throw new ConflictError('The resource is already scheduled or the slot is taken');
    }
    throw error;
  }

  return (await repo.findActivityById(activityId))!;
}

// ---------------------------------------------------------------------------
// Rescheduling (original schedule preserved until approval).
// ---------------------------------------------------------------------------
export async function requestReschedule(userId: string, activityId: string, input: RequestRescheduleInput) {
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  if (activity.status !== 'confirmed') throw new ConflictError('Only confirmed schedules can be rescheduled');
  const info = await loadResource(activity.domain, activity.resourceId);
  assertEligible(activity.domain, info.status);

  const isCustomer = info.customerUserId === userId;
  if (!isCustomer) {
    const context = await loadProviderContext(userId);
    if (!context.effectiveProfileIds.includes(info.providerProfileId)) {
      throw new ForbiddenError('You may not reschedule this activity');
    }
  }
  const party = isCustomer ? 'customer' : 'provider';

  const existing = await repo.listReschedules(activityId);
  if (existing.some((r) => r.status === 'pending')) {
    throw new ConflictError('A rescheduling request is already pending for this activity');
  }

  let requestId: string;
  await transaction(async (client) => {
    const createdRequest = await repo.insertRescheduleRequest(client, {
      activityId,
      requestedBy: userId,
      requestingParty: party,
      requestedStartAt: input.requestedStartAt,
      requestedEndAt: input.requestedEndAt,
      reason: input.reason ?? null,
    });
    requestId = createdRequest.id;
    const eventType = 'schedule.reschedule_requested';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${activityId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [isCustomer ? info.providerProfileId : info.customerUserId!].filter(Boolean),
      organisationId: activity.providerOrganisationId,
      resourceType: 'scheduling_activity',
      resourceId: activityId,
      payload: { activityId, requestedStartAt: input.requestedStartAt },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return repo.findReschedule(requestId!);
}

export async function decideReschedule(userId: string, activityId: string, requestId: string, accept: boolean): Promise<SchedulingActivity> {
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  const request = await repo.findReschedule(requestId);
  if (!request || request.activityId !== activityId) throw new NotFoundError('Reschedule request not found');
  if (request.status !== 'pending') throw new ConflictError('Reschedule request already decided');
  const info = await loadResource(activity.domain, activity.resourceId);
  assertEligible(activity.domain, info.status);

  // Only the party that did NOT propose may decide.
  const proposerIsCustomer = request.requestingParty === 'customer';
  if (proposerIsCustomer) {
    if (info.customerUserId === userId) throw new ForbiddenError('Provider must decide a customer-requested change');
    const context = await loadProviderContext(userId);
    if (!context.effectiveProfileIds.includes(info.providerProfileId)) throw new ForbiddenError('Not authorized');
  } else if (info.customerUserId !== userId) {
    throw new ForbiddenError('Only the customer may decide a provider-requested change');
  }

  await transaction(async (client) => {
    await repo.resolveReschedule(client, requestId, accept ? 'approved' : 'rejected', userId);
    if (accept) {
      if (await repo.hasOverlap(activity.capacityKey ?? capacityKeyFor(null, info.providerProfileId), request.requestedStartAt, request.requestedEndAt, activityId)) {
        throw new ConflictError('The requested slot overlaps an existing confirmed appointment');
      }
      await repo.updateActivityWindow(client, activityId, request.requestedStartAt, request.requestedEndAt, null, userId);
      await repo.cancelReminders(activityId);
    }
    const eventType = accept ? 'schedule.reschedule_approved' : 'schedule.reschedule_rejected';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${requestId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [proposerIsCustomer ? info.providerProfileId : info.customerUserId!].filter(Boolean),
      organisationId: activity.providerOrganisationId,
      resourceType: 'scheduling_activity',
      resourceId: activityId,
      payload: { activityId, requestId, accept },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.findActivityById(activityId))!;
}

export async function cancelSchedule(userId: string, activityId: string, reason?: string): Promise<SchedulingActivity> {
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  if (activity.status === 'cancelled' || activity.status === 'completed') {
    throw new ConflictError('Schedule is not active');
  }
  const info = await loadResource(activity.domain, activity.resourceId);
  const isCustomer = info.customerUserId === userId;
  if (!isCustomer) {
    const context = await loadProviderContext(userId);
    if (!context.effectiveProfileIds.includes(info.providerProfileId)) throw new ForbiddenError('Not authorized');
  }
  await transaction(async (client) => {
    await repo.setActivityStatus(client, activityId, 'cancelled', userId);
    await repo.cancelReminders(activityId);
    const eventType = 'schedule.cancelled';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${activityId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [isCustomer ? info.providerProfileId : info.customerUserId!].filter(Boolean),
      organisationId: activity.providerOrganisationId,
      resourceType: 'scheduling_activity',
      resourceId: activityId,
      payload: { activityId, reason: reason ?? null },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.findActivityById(activityId))!;
}

// ---------------------------------------------------------------------------
// Staff assignment.
// ---------------------------------------------------------------------------
export async function assignStaff(userId: string, activityId: string, input: AssignStaffInput, organizationId?: string | null): Promise<SchedulingActivity> {
  const context = await loadProviderContext(userId, organizationId);
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  const info = await loadResource(activity.domain, activity.resourceId);
  if (!context.effectiveProfileIds.includes(info.providerProfileId)) throw new ForbiddenError('Not authorized');
  if (activity.status !== 'confirmed') throw new ConflictError('Only confirmed schedules can be staffed');

  const capacityKey = capacityKeyFor(input.userId, info.providerProfileId);
  if (await repo.hasOverlap(capacityKey, activity.startAt, activity.endAt, activityId)) {
    throw new ConflictError('Staff member has an overlapping confirmed appointment');
  }

  await transaction(async (client) => {
    await repo.revokeStaffAssignment(client, activityId, input.userId, userId);
    await repo.insertStaffAssignment(client, { activityId, userId: input.userId, providerOrganisationId: activity.providerOrganisationId, label: input.label ?? null, assignedBy: userId });
    await repo.setActivityStaff(client, activityId, input.userId, capacityKey);
    const eventType = 'schedule.staff_assigned';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${activityId}:${input.userId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [input.userId],
      organisationId: activity.providerOrganisationId,
      resourceType: 'scheduling_activity',
      resourceId: activityId,
      payload: { activityId, staffUserId: input.userId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.findActivityById(activityId))!;
}

export async function revokeStaff(userId: string, activityId: string, staffUserId: string, organizationId?: string | null): Promise<SchedulingActivity> {
  const context = await loadProviderContext(userId, organizationId);
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  const info = await loadResource(activity.domain, activity.resourceId);
  if (!context.effectiveProfileIds.includes(info.providerProfileId)) throw new ForbiddenError('Not authorized');
  await transaction(async (client) => {
    await repo.revokeStaffAssignment(client, activityId, staffUserId, userId);
    if (activity.assignedStaffUserId === staffUserId) {
      await repo.setActivityStaff(client, activityId, null, capacityKeyFor(null, info.providerProfileId));
    }
    const eventType = 'schedule.staff_revoked';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${activityId}:${staffUserId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [],
      organisationId: activity.providerOrganisationId,
      resourceType: 'scheduling_activity',
      resourceId: activityId,
      payload: { activityId, staffUserId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.findActivityById(activityId))!;
}

// ---------------------------------------------------------------------------
// Calendar + detail.
// ---------------------------------------------------------------------------
export async function providerCalendar(userId: string, filters: CalendarFilters, organizationId?: string | null): Promise<SchedulingActivity[]> {
  const context = await loadProviderContext(userId, organizationId);
  return repo.listCalendar({ providerProfileIds: context.effectiveProfileIds, staffUserId: filters.staffUserId }, filters);
}

export async function customerCalendar(userId: string, filters: CalendarFilters): Promise<SchedulingActivity[]> {
  return repo.listCalendar({ customerUserId: userId }, filters);
}

export async function getActivityDetail(userId: string, activityId: string): Promise<SchedulingActivity & { staff: unknown[]; reschedules: unknown[]; canViewLocation: boolean }> {
  const activity = await repo.findActivityById(activityId);
  if (!activity) throw new NotFoundError('Schedule not found');
  const info = await loadResource(activity.domain, activity.resourceId);
  const isCustomer = info.customerUserId === userId;
  let canViewLocation = isCustomer;
  if (!isCustomer) {
    const context = await loadProviderContext(userId);
    const isOwner = context.effectiveProfileIds.includes(info.providerProfileId);
    const isStaff = activity.assignedStaffUserId === userId || await repo.isStaffActive(activityId, userId);
    if (!isOwner && !isStaff) throw new ForbiddenError('Not authorized');
    canViewLocation = isOwner || isStaff;
  }
  const [staff, reschedules] = await Promise.all([repo.listStaff(activityId), repo.listReschedules(activityId)]);
  return { ...activity, address: canViewLocation ? activity.address : null, staff, reschedules, canViewLocation };
}

// ---------------------------------------------------------------------------
// Availability / capacity.
// ---------------------------------------------------------------------------
export async function checkAvailability(input: AvailabilityCheckInput): Promise<{ available: boolean; reasons: string[] }> {
  const reasons: string[] = [];
  // Provider operating hours / exceptions.
  if (input.providerProfileId) {
    const day = new Date(input.startAt).getUTCDay();
    const closed = await pool.query(
      `SELECT 1 FROM provider_availability_exceptions
        WHERE specialized_profile_id = $1 AND exception_date = $2::date AND is_unavailable LIMIT 1`,
      [input.providerProfileId, input.startAt.slice(0, 10)],
    );
    if (closed.rowCount) reasons.push('Provider is closed on this date');
    if (!closed.rowCount) {
      const hours = await pool.query(
        `SELECT 1 FROM provider_operating_hours
          WHERE specialized_profile_id = $1 AND day_of_week = $2 AND NOT is_closed LIMIT 1`,
        [input.providerProfileId, day],
      );
      if (!hours.rowCount) reasons.push('Provider has no operating hours for this weekday');
    }
  }
  // Staff availability / leave.
  if (input.staffUserId) {
    const date = input.startAt.slice(0, 10);
    if (await repo.isStaffOnLeave(input.staffUserId, date)) reasons.push('Staff member is on leave');
    const avail = await repo.listStaffAvailability(input.staffUserId);
    const day = new Date(input.startAt).getUTCDay();
    const window = avail.find((a) => a.dayOfWeek === day && a.isAvailable);
    if (!window) reasons.push('Staff member is not available on this weekday');
  }
  // Overlap.
  const key = input.staffUserId ? `staff:${input.staffUserId}` : input.providerProfileId ? `provider:${input.providerProfileId}` : null;
  if (key && await repo.hasOverlap(key, input.startAt, input.endAt)) reasons.push('Overlapping confirmed appointment');
  return { available: reasons.length === 0, reasons };
}

export async function setStaffAvailability(userId: string, rows: Array<{ dayOfWeek: number; openTime: string; closeTime: string; isAvailable: boolean; timeZone: string }>): Promise<void> {
  await transaction(async (client) => repo.replaceStaffAvailability(client, userId, rows));
}

export async function addStaffLeave(userId: string, startDate: string, endDate: string, reason: string | undefined): Promise<void> {
  await transaction(async (client) => repo.insertStaffLeave(client, userId, startDate, endDate, reason ?? null, userId));
}

export async function setCapacity(userId: string, input: CapacityInput, organizationId?: string | null): Promise<void> {
  const context = await loadProviderContext(userId, organizationId);
  if (!context.effectiveProfileIds.includes(input.providerProfileId)) throw new ForbiddenError('Not authorized');
  await transaction(async (client) => repo.upsertCapacity(client, {
    providerProfileId: input.providerProfileId,
    offeringId: input.offeringId ?? null,
    capacityPerSlot: input.capacityPerSlot,
    slotMinutes: input.slotMinutes,
    bufferMinutes: input.bufferMinutes,
    minNoticeMinutes: input.minNoticeMinutes,
    maxAdvanceDays: input.maxAdvanceDays,
    timeZone: input.timeZone,
  }));
}

export async function hasProviderPermission(userId: string, permission: string): Promise<boolean> {
  return authz.hasPermission(userId, permission);
}