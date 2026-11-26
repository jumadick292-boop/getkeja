// Shared scheduling repository (Task 13.9).
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  CalendarFilters,
  RescheduleRequest,
  SchedulingActivity,
  SchedulingCapacity,
  SchedulingDomain,
  SchedulingStatus,
  StaffAssignment,
  StaffAvailability,
} from './scheduling.types.js';

function mapActivity(row: Record<string, unknown>): SchedulingActivity {
  return {
    id: row.id as string,
    domain: row.domain as SchedulingDomain,
    resourceId: row.resourceId as string,
    movingJobId: (row.movingJobId as string) ?? null,
    garbageJobId: (row.garbageJobId as string) ?? null,
    garbageOccurrenceId: (row.garbageOccurrenceId as string) ?? null,
    laundryOrderId: (row.laundryOrderId as string) ?? null,
    homeMaintenanceJobId: (row.homeMaintenanceJobId as string) ?? null,
    cleaningJobId: (row.cleaningJobId as string) ?? null,
    installationJobId: (row.installationJobId as string) ?? null,
    startAt: row.startAt as string,
    endAt: row.endAt as string,
    timeZone: row.timeZone as string,
    allDay: (row.allDay as boolean) ?? false,
    status: row.status as SchedulingStatus,
    locationId: (row.locationId as string) ?? null,
    address: (row.address as string) ?? null,
    customerUserId: (row.customerUserId as string) ?? null,
    providerProfileId: (row.providerProfileId as string) ?? null,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    capacityKey: (row.capacityKey as string) ?? null,
    reminderState: (row.reminderState as string) ?? 'none',
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const ACTIVITY_SELECT = `
  SELECT id, domain, resource_id AS "resourceId", moving_job_id AS "movingJobId",
         garbage_job_id AS "garbageJobId", garbage_occurrence_id AS "garbageOccurrenceId",
         laundry_order_id AS "laundryOrderId", home_maintenance_job_id AS "homeMaintenanceJobId", cleaning_job_id AS "cleaningJobId", installation_job_id AS "installationJobId", start_at AS "startAt", end_at AS "endAt",
         time_zone AS "timeZone", all_day AS "allDay", status::text AS status,
         location_id AS "locationId", address, customer_user_id AS "customerUserId",
         provider_profile_id AS "providerProfileId", provider_organisation_id AS "providerOrganisationId",
         assigned_staff_user_id AS "assignedStaffUserId", capacity_key AS "capacityKey",
         reminder_state AS "reminderState", created_at AS "createdAt", updated_at AS "updatedAt"
  FROM scheduling_activities`;

export async function findActivityById(id: string): Promise<SchedulingActivity | null> {
  const r = await pool.query(`${ACTIVITY_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapActivity(r.rows[0]) : null;
}

export async function findActivityByResource(domain: SchedulingDomain, resourceId: string): Promise<SchedulingActivity | null> {
  const col: Record<SchedulingDomain, string> = {
    moving: 'moving_job_id',
    garbage: 'garbage_job_id',
    garbage_occurrence: 'garbage_occurrence_id',
    laundry: 'laundry_order_id',
    home_maintenance: 'home_maintenance_job_id',
    cleaning: 'cleaning_job_id',
    installation: 'installation_job_id',
  };
  const r = await pool.query(`${ACTIVITY_SELECT} WHERE ${col[domain]} = $1`, [resourceId]);
  return r.rows[0] ? mapActivity(r.rows[0]) : null;
}

export interface InsertActivityRow {
  domain: SchedulingDomain;
  resourceId: string;
  movingJobId: string | null;
  garbageJobId: string | null;
  garbageOccurrenceId: string | null;
  laundryOrderId: string | null;
  homeMaintenanceJobId: string | null;
  cleaningJobId: string | null;
  installationJobId: string | null;
  startAt: string;
  endAt: string;
  timeZone: string;
  allDay: boolean;
  status: SchedulingStatus;
  locationId: string | null;
  address: string | null;
  customerUserId: string | null;
  providerProfileId: string | null;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  capacityKey: string | null;
  createdBy: string;
}

export async function insertActivity(client: PoolClient, row: InsertActivityRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO scheduling_activities
       (domain, resource_id, moving_job_id, garbage_job_id, garbage_occurrence_id, laundry_order_id, home_maintenance_job_id, cleaning_job_id, installation_job_id,
        start_at, end_at, time_zone, all_day, status, location_id, address, customer_user_id,
        provider_profile_id, provider_organisation_id, assigned_staff_user_id, capacity_key, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::scheduling_status,$15,$16,$17,$18,$19,$20,$21,$22)
     RETURNING id`,
    [
      row.domain, row.resourceId, row.movingJobId, row.garbageJobId, row.garbageOccurrenceId, row.laundryOrderId, row.homeMaintenanceJobId, row.cleaningJobId, row.installationJobId,
      row.startAt, row.endAt, row.timeZone, row.allDay, row.status, row.locationId, row.address,
      row.customerUserId, row.providerProfileId, row.providerOrganisationId, row.assignedStaffUserId,
      row.capacityKey, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function updateActivityWindow(client: PoolClient, id: string, startAt: string, endAt: string, timeZone: string | null, actor: string): Promise<void> {
  await client.query(
    `UPDATE scheduling_activities SET start_at = $2, end_at = $3, time_zone = COALESCE($4, time_zone), updated_by = $5 WHERE id = $1`,
    [id, startAt, endAt, timeZone, actor],
  );
}

export async function setActivityStatus(client: PoolClient, id: string, status: SchedulingStatus, actor: string | null): Promise<void> {
  await client.query(`UPDATE scheduling_activities SET status = $2::scheduling_status, updated_by = $3 WHERE id = $1`, [id, status, actor]);
}

export async function setActivityStaff(client: PoolClient, id: string, staffUserId: string | null, capacityKey: string | null): Promise<void> {
  await client.query(`UPDATE scheduling_activities SET assigned_staff_user_id = $2, capacity_key = $3 WHERE id = $1`, [id, staffUserId, capacityKey]);
}

// Calendar query with date-window + filters (paged/limited).
export async function listCalendar(
  scope: { providerProfileIds?: string[]; customerUserId?: string; staffUserId?: string },
  filters: CalendarFilters,
): Promise<SchedulingActivity[]> {
  const where: string[] = [`start_at >= $1`, `start_at < $2`];
  const params: unknown[] = [filters.from, filters.to];
  if (scope.providerProfileIds) {
    params.push(scope.providerProfileIds);
    where.push(`provider_profile_id = ANY($${params.length}::uuid[])`);
  }
  if (scope.customerUserId) {
    params.push(scope.customerUserId);
    where.push(`customer_user_id = $${params.length}`);
  }
  if (scope.staffUserId || filters.staffUserId) {
    params.push(scope.staffUserId ?? filters.staffUserId);
    where.push(`assigned_staff_user_id = $${params.length}`);
  }
  if (filters.domains && filters.domains.length > 0) {
    params.push(filters.domains);
    where.push(`domain = ANY($${params.length}::scheduling_domain[])`);
  }
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::scheduling_status`);
  }
  if (filters.providerProfileId) {
    params.push(filters.providerProfileId);
    where.push(`provider_profile_id = $${params.length}`);
  }
  params.push(filters.limit);
  const r = await pool.query(
    `${ACTIVITY_SELECT} WHERE ${where.join(' AND ')} ORDER BY start_at ASC LIMIT $${params.length}`,
    params,
  );
  return r.rows.map(mapActivity);
}

// ---- Staff assignments ----
export async function insertStaffAssignment(client: PoolClient, row: {
  activityId: string; userId: string; providerOrganisationId: string | null; label: string | null; assignedBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO staff_assignments (activity_id, user_id, provider_organisation_id, label, assigned_by)
     VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    [row.activityId, row.userId, row.providerOrganisationId, row.label, row.assignedBy],
  );
  await client.query(
    `INSERT INTO staff_assignment_history (activity_id, user_id, action, changed_by) VALUES ($1,$2,'assigned',$3)`,
    [row.activityId, row.userId, row.assignedBy],
  );
  return r.rows[0]!;
}

export async function revokeStaffAssignment(client: PoolClient, activityId: string, userId: string, revokedBy: string): Promise<void> {
  await client.query(
    `UPDATE staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $2
      WHERE activity_id = $1 AND user_id = $3 AND is_active`,
    [activityId, revokedBy, userId],
  );
  await client.query(
    `INSERT INTO staff_assignment_history (activity_id, user_id, action, changed_by) VALUES ($1,$2,'revoked',$3)`,
    [activityId, userId, revokedBy],
  );
}

export async function listStaff(activityId: string): Promise<StaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, activity_id AS "activityId", user_id AS "userId", provider_organisation_id AS "providerOrganisationId",
            label, is_active AS "isActive", assigned_by AS "assignedBy", created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM staff_assignments WHERE activity_id = $1 ORDER BY created_at ASC`,
    [activityId],
  );
  return r.rows as unknown as StaffAssignment[];
}

export async function isStaffActive(activityId: string, userId: string): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM staff_assignments WHERE activity_id = $1 AND user_id = $2 AND is_active LIMIT 1`,
    [activityId, userId],
  );
  return (r.rowCount ?? 0) > 0;
}

// ---- Reschedule requests ----
function mapReschedule(row: Record<string, unknown>): RescheduleRequest {
  return {
    id: row.id as string,
    activityId: row.activityId as string,
    requestedBy: row.requestedBy as string,
    requestingParty: row.requestingParty as RescheduleRequest['requestingParty'],
    requestedStartAt: row.requestedStartAt as string,
    requestedEndAt: row.requestedEndAt as string,
    reason: (row.reason as string) ?? null,
    status: row.status as RescheduleRequest['status'],
    decidedBy: (row.decidedBy as string) ?? null,
    decidedAt: (row.decidedAt as string) ?? null,
    createdAt: row.createdAt as Date,
  };
}

const RESCHEDULE_SELECT = `
  SELECT id, activity_id AS "activityId", requested_by AS "requestedBy", requesting_party AS "requestingParty",
         requested_start_at AS "requestedStartAt", requested_end_at AS "requestedEndAt", reason, status::text AS status,
         decided_by AS "decidedBy", decided_at AS "decidedAt", created_at AS "createdAt"
  FROM reschedule_requests`;

export async function insertRescheduleRequest(client: PoolClient, row: {
  activityId: string; requestedBy: string; requestingParty: string; requestedStartAt: string; requestedEndAt: string; reason: string | null;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO reschedule_requests (activity_id, requested_by, requesting_party, requested_start_at, requested_end_at, reason)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [row.activityId, row.requestedBy, row.requestingParty, row.requestedStartAt, row.requestedEndAt, row.reason],
  );
  return r.rows[0]!;
}

export async function findReschedule(id: string): Promise<RescheduleRequest | null> {
  const r = await pool.query(`${RESCHEDULE_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapReschedule(r.rows[0]) : null;
}

export async function listReschedules(activityId: string): Promise<RescheduleRequest[]> {
  const r = await pool.query(`${RESCHEDULE_SELECT} WHERE activity_id = $1 ORDER BY created_at DESC`, [activityId]);
  return r.rows.map(mapReschedule);
}

export async function resolveReschedule(client: PoolClient, id: string, status: string, decidedBy: string): Promise<void> {
  await client.query(`UPDATE reschedule_requests SET status = $2, decided_by = $3, decided_at = NOW() WHERE id = $1`, [id, status, decidedBy]);
}

// ---- Availability ----
export async function listStaffAvailability(userId: string): Promise<StaffAvailability[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", day_of_week AS "dayOfWeek", open_time AS "openTime", close_time AS "closeTime",
            is_available AS "isAvailable", time_zone AS "timeZone"
       FROM staff_availability WHERE user_id = $1 ORDER BY day_of_week ASC`,
    [userId],
  );
  return r.rows as unknown as StaffAvailability[];
}

export async function replaceStaffAvailability(client: PoolClient, userId: string, rows: Array<{ dayOfWeek: number; openTime: string; closeTime: string; isAvailable: boolean; timeZone: string }>): Promise<void> {
  await client.query(`DELETE FROM staff_availability WHERE user_id = $1`, [userId]);
  for (const row of rows) {
    await client.query(
      `INSERT INTO staff_availability (user_id, day_of_week, open_time, close_time, is_available, time_zone)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [userId, row.dayOfWeek, row.openTime, row.closeTime, row.isAvailable, row.timeZone],
    );
  }
}

export async function isStaffOnLeave(userId: string, date: string): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM staff_leave WHERE user_id = $1 AND start_date <= $2::date AND end_date >= $2::date LIMIT 1`,
    [userId, date],
  );
  return (r.rowCount ?? 0) > 0;
}

export async function insertStaffLeave(client: PoolClient, userId: string, startDate: string, endDate: string, reason: string | null, createdBy: string): Promise<void> {
  await client.query(
    `INSERT INTO staff_leave (user_id, start_date, end_date, reason, created_by) VALUES ($1,$2,$3,$4,$5)`,
    [userId, startDate, endDate, reason, createdBy],
  );
}

// ---- Capacity ----
export async function findCapacity(providerProfileId: string, offeringId: string | null): Promise<SchedulingCapacity | null> {
  const r = await pool.query(
    `SELECT id, provider_profile_id AS "providerProfileId", offering_id AS "offeringId",
            capacity_per_slot AS "capacityPerSlot", slot_minutes AS "slotMinutes", buffer_minutes AS "bufferMinutes",
            min_notice_minutes AS "minNoticeMinutes", max_advance_days AS "maxAdvanceDays", time_zone AS "timeZone"
       FROM scheduling_capacity
      WHERE provider_profile_id = $1 AND COALESCE(offering_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE($2, '00000000-0000-0000-0000-000000000000'::uuid)`,
    [providerProfileId, offeringId],
  );
  return (r.rows[0] as unknown as SchedulingCapacity) ?? null;
}

export async function upsertCapacity(client: PoolClient, row: Omit<SchedulingCapacity, 'id'>): Promise<void> {
  await client.query(
    `INSERT INTO scheduling_capacity
       (provider_profile_id, offering_id, capacity_per_slot, slot_minutes, buffer_minutes, min_notice_minutes, max_advance_days, time_zone)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     ON CONFLICT (provider_profile_id, COALESCE(offering_id, '00000000-0000-0000-0000-000000000000'::uuid))
     DO UPDATE SET capacity_per_slot = EXCLUDED.capacity_per_slot, slot_minutes = EXCLUDED.slot_minutes,
       buffer_minutes = EXCLUDED.buffer_minutes, min_notice_minutes = EXCLUDED.min_notice_minutes,
       max_advance_days = EXCLUDED.max_advance_days, time_zone = EXCLUDED.time_zone, updated_at = NOW()`,
    [row.providerProfileId, row.offeringId, row.capacityPerSlot, row.slotMinutes, row.bufferMinutes, row.minNoticeMinutes, row.maxAdvanceDays, row.timeZone],
  );
}

// ---- Conflict detection ----
export async function hasOverlap(capacityKey: string, startAt: string, endAt: string, excludeActivityId?: string): Promise<boolean> {
  const params: unknown[] = [capacityKey, startAt, endAt];
  let exclude = '';
  if (excludeActivityId) {
    params.push(excludeActivityId);
    exclude = `AND id <> $${params.length}`;
  }
  const r = await pool.query(
    `SELECT 1 FROM scheduling_activities
      WHERE capacity_key = $1 AND status = 'confirmed'
        AND tstzrange(start_at, end_at) && tstzrange($2::timestamptz, $3::timestamptz)
        ${exclude} LIMIT 1`,
    params,
  );
  return (r.rowCount ?? 0) > 0;
}

// ---- Reminders ----
export async function upsertReminder(client: PoolClient, activityId: string, remindAt: string): Promise<void> {
  await client.query(
    `INSERT INTO scheduling_reminders (activity_id, remind_at, state)
     VALUES ($1,$2,'pending')
     ON CONFLICT (activity_id) DO UPDATE SET remind_at = EXCLUDED.remind_at, state = 'pending', sent_at = NULL`,
    [activityId, remindAt],
  );
}

export async function cancelReminders(activityId: string): Promise<void> {
  await pool.query(`UPDATE scheduling_reminders SET state = 'cancelled' WHERE activity_id = $1 AND state = 'pending'`, [activityId]);
}

export async function dueReminders(now: string, limit = 100): Promise<Array<{ id: string; activityId: string }>> {
  const r = await pool.query<{ id: string; activityId: string }>(
    `SELECT id, activity_id AS "activityId" FROM scheduling_reminders
      WHERE state = 'pending' AND remind_at <= $1 ORDER BY remind_at ASC LIMIT $2`,
    [now, limit],
  );
  return r.rows;
}

export async function markReminderSent(id: string): Promise<void> {
  await pool.query(`UPDATE scheduling_reminders SET state = 'sent', sent_at = NOW() WHERE id = $1 AND state = 'pending'`, [id]);
}

// Overdue: confirmed activities whose end is in the past.
export async function markOverdue(now: string): Promise<number> {
  const r = await pool.query(
    `UPDATE scheduling_activities SET status = 'missed', updated_at = NOW()
      WHERE status = 'confirmed' AND end_at < $1 RETURNING id`,
    [now],
  );
  return r.rows.length;
}