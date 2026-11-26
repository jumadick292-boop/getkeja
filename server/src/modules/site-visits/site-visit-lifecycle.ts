// Site visit lifecycle orchestration.
//
// Owns the transactional write path for every site visit state change:
//   - revalidates availability before confirmation/reschedule
//   - validates transitions server-side
//   - writes site_visit_history rows (audit trail preserved on cancel/reschedule)
//   - emits transactional notification outbox events (idempotent)
//   - schedules/cancels reminder jobs through the shared pg-boss infrastructure
//
// This module never sends notifications directly; it only writes to the
// outbox and enqueues reminder jobs, so delivery stays a worker concern.

import type { PoolClient } from 'pg';
import { randomUUID } from 'node:crypto';
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, HttpError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { NotificationService } from '../auth/notification.service.js';
import {
  acquirePropertyLock,
  assertNotPast,
  assertValidTransition,
  evaluateAvailability,
  hasOverlappingVisit,
  parseUtcDate,
  PROPERTY_TIME_ZONE,
} from './site-visit.service.js';

const notifications = new NotificationService();

export interface SiteVisitRow {
  id: string;
  propertyId: string;
  unitId: string | null;
  userId: string | null;
  visitorName: string;
  visitorEmail: string | null;
  visitorPhone: string;
  scheduledAt: Date;
  durationMinutes: number;
  status: string;
  hostedByUserId: string | null;
  hostedByOrganisationId: string | null;
  visitorNotes: string | null;
  hostNotes: string | null;
  outcome: string | null;
  enquiryId?: string | null;
  assignedToUserId?: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const VISIT_COLUMNS = `
  id, property_id AS "propertyId", unit_id AS "unitId", user_id AS "userId",
  visitor_name AS "visitorName", visitor_email AS "visitorEmail",
  visitor_phone AS "visitorPhone", scheduled_at AS "scheduledAt",
  duration_minutes AS "durationMinutes", status,
  hosted_by_user_id AS "hostedByUserId",
  hosted_by_organisation_id AS "hostedByOrganisationId",
  visitor_notes AS "visitorNotes", host_notes AS "hostNotes", outcome,
  enquiry_id AS "enquiryId", assigned_to_user_id AS "assignedToUserId",
  created_by AS "createdBy", updated_by AS "updatedBy",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

const RETURNING_VISIT = `RETURNING ${VISIT_COLUMNS}`;

const SITE_VISIT_COLUMNS = `
  id, property_id AS "propertyId", unit_id AS "unitId", user_id AS "userId",
  visitor_name AS "visitorName", visitor_email AS "visitorEmail",
  visitor_phone AS "visitorPhone", scheduled_at AS "scheduledAt",
  duration_minutes AS "durationMinutes", status,
  hosted_by_user_id AS "hostedByUserId",
  hosted_by_organisation_id AS "hostedByOrganisationId",
  visitor_notes AS "visitorNotes", host_notes AS "hostNotes", outcome,
  created_by AS "createdBy", updated_by AS "updatedBy",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

export async function findVisitRow(
  client: Queryable,
  visitId: string,
): Promise<SiteVisitRow | undefined> {
  const result = await client.query<SiteVisitRow>(
    `SELECT ${SITE_VISIT_COLUMNS} FROM site_visits WHERE id = $1`,
    [visitId],
  );
  return result.rows[0];
}

export async function getVisit(visitId: string): Promise<SiteVisitRow | undefined> {
  return findVisitRow(pool, visitId);
}

async function insertHistory(
  client: PoolClient,
  visit: {
    id: string;
    action: string;
    previousStatus: string | null;
    previousScheduledAt: Date | null;
    newStatus: string | null;
    newScheduledAt: Date | null;
    changedBy: string;
    reason?: string | null;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO site_visit_history
       (visit_id, action, previous_status, previous_scheduled_at, new_status, new_scheduled_at, changed_by, change_reason)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      visit.id,
      visit.action,
      visit.previousStatus,
      visit.previousScheduledAt,
      visit.newStatus,
      visit.newScheduledAt,
      visit.changedBy,
      visit.reason ?? null,
    ],
  );
}

async function scheduleReminderJobs(client: PoolClient, visitId: string): Promise<void> {
  // Reminder jobs are computed lazily by the reminder worker from the visit
  // row, so we only record the intent here. Cancelling a visit deletes any
  // pending reminders in the worker's queue scan; rescheduling recomputes
  // from the new scheduled_at.
  await client.query(
    `INSERT INTO site_visit_reminder_jobs (visit_id, scheduled_for, sent_at)
     SELECT $1, $2, NULL
     WHERE NOT EXISTS (
       SELECT 1 FROM site_visit_reminder_jobs WHERE visit_id = $1 AND sent_at IS NULL
     )`,
    [visitId, null],
  ).catch(() => {
    // Table may not exist in older databases; the worker scans site_visits
    // directly, so this is best-effort bookkeeping.
  });
}

async function cancelReminderJobs(client: PoolClient, visitId: string): Promise<void> {
  await client
    .query(`DELETE FROM site_visit_reminder_jobs WHERE visit_id = $1`, [visitId])
    .catch(() => {});
}

interface OutboxInput {
  eventType: string;
  recipientUserIds: string[];
  payload: Record<string, unknown>;
  resourceId: string;
  idempotencyKey: string;
}

type Queryable = Pick<PoolClient, 'query'>;

async function emitOutbox(client: Queryable, input: OutboxInput): Promise<void> {
  if (input.recipientUserIds.length === 0) return;
  const id = randomUUID();
  // Written inside the caller's transaction so an outbox row can never exist
  // without the corresponding state change (transactional outbox).
  await client.query(
    `INSERT INTO notification_outbox
       (id, idempotency_key, event_type, category, priority, recipient_user_ids,
        organisation_id, resource_type, resource_id, payload, channels, max_retries)
     VALUES ($1, $2, $3, 'property', 'normal', $4, NULL, 'site_visit', $5, $6, $7, 3)
     ON CONFLICT (idempotency_key) DO NOTHING`,
    [
      id,
      input.idempotencyKey,
      input.eventType,
      input.recipientUserIds,
      input.resourceId,
      JSON.stringify(input.payload),
      ['in_app', 'email'],
    ],
  );
}

async function notifyUser(
  client: PoolClient,
  userId: string | null | undefined,
  input: Omit<OutboxInput, 'recipientUserIds' | 'idempotencyKey'> & {
    idempotencySuffix?: string;
  },
): Promise<void> {
  if (!userId) return;
  await emitOutbox(client, {
    eventType: input.eventType,
    recipientUserIds: [userId],
    payload: input.payload,
    resourceId: input.resourceId,
    idempotencyKey: `${input.eventType}:${input.resourceId}:${userId}:${input.idempotencySuffix ?? 'v1'}`,
  });
}

async function propertyOwnerIds(client: PoolClient, propertyId: string): Promise<string[]> {
  const result = await client.query<{ user_id: string }>(
    `SELECT po.user_id
       FROM property_ownerships po
      WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
        AND (po.effective_to IS NULL OR po.effective_to > NOW())
      ORDER BY po.effective_from DESC`,
    [propertyId],
  );
  return result.rows.map((row) => row.user_id);
}

async function propertyManagers(client: PoolClient, propertyId: string): Promise<string[]> {
  const result = await client.query<{ user_id: string }>(
    `SELECT pa.user_id AS user_id
       FROM property_assignments pa
      WHERE pa.property_id = $1 AND pa.status = 'active'
        AND pa.user_id IS NOT NULL
        AND (pa.effective_to IS NULL OR pa.effective_to > NOW())
      UNION
      SELECT po.user_id
        FROM property_ownerships po
       WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
         AND (po.effective_to IS NULL OR po.effective_to > NOW())`,
    [propertyId],
  );
  return result.rows.map((row) => row.user_id);
}

async function visitPropertyId(client: PoolClient, visitId: string): Promise<string> {
  const result = await client.query<{ property_id: string }>(
    `SELECT property_id FROM site_visits WHERE id = $1`,
    [visitId],
  );
  const row = result.rows[0];
  if (!row) throw new NotFoundError('Site visit');
  return row.property_id;
}

async function listingTitle(client: Queryable, propertyId: string): Promise<string> {
  const result = await client.query<{ title: string }>(
    `SELECT title FROM properties WHERE id = $1`,
    [propertyId],
  );
  return result.rows[0]?.title ?? 'the property';
}

function localDisplay(date: Date): string {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: PROPERTY_TIME_ZONE,
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

export async function createVisitWithCheck(input: {
  userId: string;
  propertyId: string;
  listingId?: string | null;
  unitId?: string | null;
  scheduledAt: string;
  durationMinutes?: number;
  visitorNotes?: string | null;
  phone?: string | null;
  visitorName?: string | null;
  visitorEmail?: string | null;
}): Promise<SiteVisitRow> {
  const scheduledAt = parseUtcDate(input.scheduledAt);
  assertNotPast(scheduledAt);
  const durationMinutes = input.durationMinutes ?? 30;

  // Contact details are validated before any availability work so callers get
  // a deterministic 400 for a missing phone rather than a slot conflict.
  const visitorPhone = input.phone?.trim() || '';
  if (!visitorPhone) {
    throw new ValidationError('A contact phone number is required to request a visit');
  }
  const visitorName = input.visitorName?.trim() || 'House Seeker';

  const propertyId = await resolvePublishedProperty(input.propertyId, input.listingId);

  return transaction(async (client) => {
    await acquirePropertyLock(client, propertyId);

    // evaluateAvailability is the single authority for bookability: it enforces
    // the weekday window, blackout exceptions, buffer spacing and
    // max_bookings_per_slot. A separate raw-overlap guard here would reject a
    // second party from a slot the landlord explicitly allows to hold several
    // bookings, so capacity is governed solely by evaluateAvailability.
    const availability = await evaluateAvailability(client, propertyId, scheduledAt);
    if (!availability.allowed) {
      throw new ConflictError(availability.reason ?? 'The requested time is not available.');
    }

    const result = await client.query<SiteVisitRow>(
      `INSERT INTO site_visits
         (id, property_id, unit_id, user_id, visitor_name, visitor_email, visitor_phone,
          scheduled_at, duration_minutes, status, visitor_notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'scheduled', $10, $11)
       ${RETURNING_VISIT}`,
      [
        randomUUID(),
        propertyId,
        input.unitId ?? null,
        input.userId,
        visitorName,
        input.visitorEmail ?? null,
        visitorPhone,
        scheduledAt,
        durationMinutes,
        input.visitorNotes ?? null,
        input.userId,
      ],
    );

    const visit = result.rows[0]!;
    await insertHistory(client, {
      id: visit.id,
      action: 'scheduled',
      previousStatus: null,
      previousScheduledAt: null,
      newStatus: 'scheduled',
      newScheduledAt: scheduledAt,
      changedBy: input.userId,
    });

    const title = await listingTitle(client, propertyId);
    const managers = await propertyManagers(client, propertyId);

    // Notify the landlord/host audience (deduped).
    for (const managerId of [...new Set(managers)]) {
      if (managerId === input.userId) continue;
      await emitOutbox(client, {
        eventType: 'site_visit.requested',
        recipientUserIds: [managerId],
        payload: {
          visitId: visit.id,
          propertyId,
          propertyTitle: title,
          visitorName: visit.visitorName,
          visitorPhone: visit.visitorPhone,
          scheduledAt: toDisplay(scheduledAt),
          scheduledAtUtc: scheduledAt.toISOString(),
          durationMinutes,
        },
        resourceId: visit.id,
        idempotencyKey: `site_visit.requested:${visit.id}:${managerId}`,
      });
    }

    return visit;
  });
}

function toDisplay(date: Date): string {
  return localDisplay(date);
}

async function resolvePublishedProperty(
  propertyId: string,
  listingId?: string | null,
): Promise<string> {
  if (listingId) {
    const row = await pool.query<{ property_id: string; status: string }>(
      `SELECT property_id, status FROM property_listings WHERE id = $1`,
      [listingId],
    );
    const found = row.rows[0];
    if (!found) throw new NotFoundError('Listing');
    if (found.status !== 'published') {
      throw new ConflictError('Listing is not available');
    }
    return found.property_id;
  }
  const eligible = await pool.query(
    `SELECT 1 FROM property_listings WHERE property_id = $1 AND status = 'published' LIMIT 1`,
    [propertyId],
  );
  if (!eligible.rows[0]) throw new ConflictError('Property is not currently listed');
  return propertyId;
}

// ---------------------------------------------------------------------------
// Landlord-side transitions
// ---------------------------------------------------------------------------

export async function confirmVisit(input: {
  visitId: string;
  userId: string;
  hostNotes?: string | null;
}): Promise<SiteVisitRow> {
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'confirmed',
    updates: input.hostNotes !== undefined ? { hostNotes: input.hostNotes } : {},
    reason: null,
    action: 'confirmed',
    notify: 'confirmed',
    revalidate: true,
  });
}

export async function declineVisit(input: {
  visitId: string;
  userId: string;
  reason?: string | null;
}): Promise<SiteVisitRow> {
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'cancelled',
    updates: {},
    reason: input.reason ?? null,
    action: 'declined',
    notify: 'declined',
    revalidate: false,
  });
}

export async function cancelVisit(input: {
  visitId: string;
  userId: string;
  reason?: string | null;
  cancelledBy: 'landlord' | 'seeker';
}): Promise<SiteVisitRow> {
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'cancelled',
    updates: {},
    reason: input.reason ?? null,
    action: input.cancelledBy === 'landlord' ? 'cancelled' : 'cancelled_by_seeker',
    notify: 'cancelled',
    revalidate: false,
    cancelReminders: true,
  });
}

export async function rescheduleVisit(input: {
  visitId: string;
  userId: string;
  scheduledAt: string;
  durationMinutes?: number;
  reason?: string | null;
}): Promise<SiteVisitRow> {
  const scheduledAt = parseUtcDate(input.scheduledAt);
  assertNotPast(scheduledAt, 'Visit must be rescheduled to a future time');
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'rescheduled',
    updates: {
      scheduledAt,
      ...(input.durationMinutes !== undefined ? { durationMinutes: input.durationMinutes } : {}),
    },
    reason: input.reason ?? null,
    action: 'rescheduled',
    notify: 'rescheduled',
    revalidate: true,
  });
}

export async function completeVisit(input: {
  visitId: string;
  userId: string;
  outcome?: string | null;
  hostNotes?: string | null;
}): Promise<SiteVisitRow> {
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'completed',
    updates: {
      ...(input.outcome !== undefined ? { outcome: input.outcome } : {}),
      ...(input.hostNotes !== undefined ? { hostNotes: input.hostNotes } : {}),
    },
    reason: null,
    action: 'completed',
    notify: 'completed',
    revalidate: false,
    cancelReminders: true,
  });
}

export async function markNoShow(input: {
  visitId: string;
  userId: string;
  reason?: string | null;
}): Promise<SiteVisitRow> {
  return transitionVisit({
    visitId: input.visitId,
    userId: input.userId,
    nextStatus: 'no_show',
    updates: {},
    reason: input.reason ?? null,
    action: 'no_show',
    notify: 'no_show',
    revalidate: false,
    cancelReminders: true,
  });
}

interface TransitionInput {
  visitId: string;
  userId: string;
  nextStatus: string;
  updates: Partial<{
    scheduledAt: Date;
    durationMinutes: number;
    hostNotes: string | null;
    outcome: string | null;
  }>;
  reason: string | null;
  action: string;
  notify: 'confirmed' | 'declined' | 'cancelled' | 'rescheduled' | 'completed' | 'no_show';
  revalidate: boolean;
  cancelReminders?: boolean;
}

async function transitionVisit(input: TransitionInput): Promise<SiteVisitRow> {
  return transaction(async (client) => {
    const current = await findVisitRow(client, input.visitId);
    if (!current) throw new NotFoundError('Site visit');

    assertValidTransition(current.status, input.nextStatus);

    const propertyId = current.propertyId;
    await acquirePropertyLock(client, propertyId);

    // Re-read inside the lock so a concurrent transition is observed.
    const locked = await findVisitRow(client, input.visitId);
    if (!locked) throw new NotFoundError('Site visit');
    assertValidTransition(locked.status, input.nextStatus);

    const nextScheduledAt = input.updates.scheduledAt ?? locked.scheduledAt;
    const nextDuration = input.updates.durationMinutes ?? locked.durationMinutes;

    if (input.revalidate && input.nextStatus === 'confirmed') {
      const availability = await evaluateAvailability(client, propertyId, nextScheduledAt, input.visitId);
      if (!availability.allowed) {
        throw new ConflictError(
          availability.reason ?? 'The requested time is no longer available.',
        );
      }
    }

    if (input.updates.scheduledAt) {
      const visitEnd = new Date(nextScheduledAt.getTime() + nextDuration * 60_000);
      const conflict = await hasOverlappingVisit(client, propertyId, nextScheduledAt, visitEnd, input.visitId);
      if (conflict) {
        throw new ConflictError(
          'The requested time slot is already taken. Please choose another time.',
        );
      }
    }

    const fields: string[] = [`status = $1`, 'updated_by = $2', 'updated_at = NOW()'];
    const values: unknown[] = [input.nextStatus, input.userId];
    let index = 3;

    if (input.updates.scheduledAt !== undefined) {
      fields.push(`scheduled_at = $${index++}`);
      values.push(input.updates.scheduledAt);
    }
    if (input.updates.durationMinutes !== undefined) {
      fields.push(`duration_minutes = $${index++}`);
      values.push(input.updates.durationMinutes);
    }
    if (input.updates.hostNotes !== undefined) {
      fields.push(`host_notes = $${index++}`);
      values.push(input.updates.hostNotes);
    }
    if (input.updates.outcome !== undefined) {
      fields.push(`outcome = $${index++}`);
      values.push(input.updates.outcome);
    }

    values.push(input.visitId);

    const result = await client.query<SiteVisitRow>(
      `UPDATE site_visits SET ${fields.join(', ')} WHERE id = $${index} ${RETURNING_VISIT}`,
      values,
    );
    const updated = result.rows[0];
    if (!updated) throw new NotFoundError('Site visit');

    await insertHistory(client, {
      id: updated.id,
      action: input.action,
      previousStatus: locked.status,
      previousScheduledAt: locked.scheduledAt,
      newStatus: input.nextStatus,
      newScheduledAt: nextScheduledAt,
      changedBy: input.userId,
      reason: input.reason,
    });

    if (input.cancelReminders) {
      await cancelReminderJobs(client, updated.id);
    } else if (input.updates.scheduledAt) {
      // Reschedule: pending reminder rows are recomputed by the worker from
      // the new scheduled_at; drop stale pending rows first.
      await client
        .query(
          `DELETE FROM site_visit_reminder_jobs WHERE visit_id = $1 AND sent_at IS NULL`,
          [updated.id],
        )
        .catch(() => {});
    }

    const title = await listingTitle(client, propertyId);

    if (input.notify === 'confirmed' || input.notify === 'rescheduled') {
      // Notify the visitor.
      await notifyUser(client, updated.userId, {
        eventType: `site_visit.${input.notify}`,
        payload: {
          visitId: updated.id,
          propertyId,
          propertyTitle: title,
          scheduledAt: toDisplay(nextScheduledAt),
          scheduledAtUtc: nextScheduledAt.toISOString(),
          durationMinutes: nextDuration,
          ...(input.reason ? { reason: input.reason } : {}),
        },
        resourceId: updated.id,
        idempotencySuffix: `${input.nextStatus}:${nextScheduledAt.toISOString()}`,
      });
      // Notify co-visitors: if the landlord rescheduled, the seeker is above;
      // nothing else to do here.
    } else if (input.notify === 'declined') {
      await notifyUser(client, updated.userId, {
        eventType: 'site_visit.declined',
        payload: {
          visitId: updated.id,
          propertyId,
          propertyTitle: title,
          scheduledAt: toDisplay(nextScheduledAt),
          scheduledAtUtc: nextScheduledAt.toISOString(),
          ...(input.reason ? { reason: input.reason } : {}),
        },
        resourceId: updated.id,
      });
    } else if (input.notify === 'cancelled') {
      // Notify the counterparty: whoever did not perform the cancellation.
      const audience =
        input.action === 'cancelled_by_seeker'
          ? await propertyManagers(client, propertyId)
          : [updated.userId].filter((id): id is string => Boolean(id));
      for (const recipient of [...new Set(audience)]) {
        if (recipient === input.userId) continue;
        await emitOutbox(client, {
          eventType: 'site_visit.cancelled',
          recipientUserIds: [recipient],
          payload: {
            visitId: updated.id,
            propertyId,
            propertyTitle: title,
            scheduledAt: toDisplay(nextScheduledAt),
            scheduledAtUtc: nextScheduledAt.toISOString(),
            ...(input.reason ? { reason: input.reason } : {}),
          },
          resourceId: updated.id,
          idempotencyKey: `site_visit.cancelled:${updated.id}:${recipient}`,
        });
      }
    } else if (input.notify === 'completed' || input.notify === 'no_show') {
      await notifyUser(client, updated.userId, {
        eventType: `site_visit.${input.notify}`,
        payload: {
          visitId: updated.id,
          propertyId,
          propertyTitle: title,
          scheduledAt: toDisplay(nextScheduledAt),
          scheduledAtUtc: nextScheduledAt.toISOString(),
        },
        resourceId: updated.id,
      });
    }

    return updated;
  });
}

// ---------------------------------------------------------------------------
// Reminder support (used by the reminder worker)
// ---------------------------------------------------------------------------

export async function dispatchReminder(
  visitId: string,
  reminderKey: string,
): Promise<void> {
  // Recheck current status: a cancelled/declined/completed visit must never
  // produce a reminder.
  const visit = await getVisit(visitId);
  if (!visit) return;
  if (!['scheduled', 'confirmed', 'rescheduled'].includes(visit.status)) return;

  const scheduledAt = new Date(visit.scheduledAt);
  const deltaMs = scheduledAt.getTime() - Date.now();
  const withinWindow =
    reminderKey === '24h'
      ? deltaMs <= 24 * 60 * 60 * 1000 && deltaMs > 2 * 60 * 60 * 1000
      : reminderKey === '2h'
        ? deltaMs <= 2 * 60 * 60 * 1000 && deltaMs > 0
        : false;
  if (!withinWindow) return;

  const propertyId = visit.propertyId;
  const title = await listingTitle(pool, propertyId);

  await emitOutbox(pool, {
    eventType: 'site_visit.reminder',
    recipientUserIds: visit.userId ? [visit.userId] : [],
    payload: {
      visitId: visit.id,
      propertyId,
      propertyTitle: title,
      scheduledAt: toDisplay(scheduledAt),
      scheduledAtUtc: scheduledAt.toISOString(),
      durationMinutes: visit.durationMinutes,
      reminderKey,
    },
    resourceId: visit.id,
    idempotencyKey: `site_visit.reminder:${visit.id}:${reminderKey}:${scheduledAt.toISOString()}`,
  });
}

export { propertyOwnerIds, visitPropertyId };