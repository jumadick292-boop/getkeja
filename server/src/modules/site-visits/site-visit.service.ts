// Site visit scheduling and lifecycle rules.
//
// Single source of truth for:
//   - status transition validation (server-side only)
//   - slot availability, capacity, buffers and blackout dates
//   - UTC normalisation of stored/returned timestamps
//
// All availability checks run against the database so concurrent requests
// observe the same committed state. Callers must wrap check + write in a
// transaction that holds a property-scoped advisory lock.

import type { PoolClient } from 'pg';
import { ConflictError, HttpError, ValidationError } from '../../shared/errors.js';

// Valid site visit status transitions (DB enum:
// scheduled, confirmed, completed, cancelled, no_show, rescheduled).
export const VISIT_TRANSITIONS: Record<string, readonly string[]> = {
  scheduled: ['confirmed', 'cancelled', 'rescheduled'],
  confirmed: ['completed', 'no_show', 'cancelled', 'rescheduled'],
  rescheduled: ['confirmed', 'cancelled', 'rescheduled'],
  completed: [],
  cancelled: [],
  no_show: [],
};

export const ACTIVE_VISIT_STATUSES = ['scheduled', 'confirmed', 'rescheduled'] as const;
export const TERMINAL_VISIT_STATUSES = ['completed', 'cancelled', 'no_show'] as const;

export function isValidTransition(currentStatus: string, newStatus: string): boolean {
  const allowed = VISIT_TRANSITIONS[currentStatus];
  return allowed !== undefined && allowed.includes(newStatus);
}

export function assertValidTransition(currentStatus: string, newStatus: string): void {
  if (!isValidTransition(currentStatus, newStatus)) {
    throw new ConflictError(
      `Cannot transition site visit from '${currentStatus}' to '${newStatus}'`,
    );
  }
}

export function assertTransitionAllowed(currentStatus: string, newStatus: string): void {
  assertValidTransition(currentStatus, newStatus);
}

export function isTerminalStatus(status: string): boolean {
  return (TERMINAL_VISIT_STATUSES as readonly string[]).includes(status);
}

export function isActiveStatus(status: string): boolean {
  return (ACTIVE_VISIT_STATUSES as readonly string[]).includes(status);
}

// ---------------------------------------------------------------------------
// Time helpers
// ---------------------------------------------------------------------------

/** Property display timezone. Stored values are always UTC. */
export const PROPERTY_TIME_ZONE = 'Africa/Nairobi';

/** Parse an ISO timestamp into a Date, rejecting invalid values. */
export function parseUtcDate(value: unknown, fieldName = 'scheduledAt'): Date {
  if (typeof value !== 'string' && typeof value !== 'number' && !(value instanceof Date)) {
    throw new ValidationError(`${fieldName} must be an ISO-8601 timestamp`);
  }
  const date = new Date(value as string | number | Date);
  if (Number.isNaN(date.getTime())) {
    throw new ValidationError(`${fieldName} must be a valid ISO-8601 timestamp`);
  }
  return date;
}

/** Serialise a Date as a UTC ISO-8601 string. */
export function toUtcIso(date: Date): string {
  return date.toISOString();
}

/**
 * Calendar date (YYYY-MM-DD) for an instant in the property timezone.
 * Used for blackout-date matching so a Nairobi-local date is compared
 * correctly regardless of the server's UTC clock.
 */
export function zonedDateKey(date: Date, timeZone = PROPERTY_TIME_ZONE): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const pick = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return `${pick('year')}-${pick('month')}-${pick('day')}`;
}

/** Wall-clock HH:MM for an instant in the property timezone. */
export function zonedTimeString(date: Date, timeZone = PROPERTY_TIME_ZONE): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);
  const pick = (type: string) => parts.find((p) => p.type === type)?.value ?? '00';
  return `${pick('hour')}:${pick('minute')}`;
}

/** Day-of-week name for an instant in the property timezone. */
export function zonedDayOfWeek(date: Date, timeZone = PROPERTY_TIME_ZONE): string {
  const formatted = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'long',
  }).format(date);
  return formatted.toLowerCase();
}

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

interface AvailabilityRuleRow {
  start_time: string;
  end_time: string;
  slot_duration_minutes: number;
  buffer_minutes: number;
  max_bookings_per_slot: number;
}

export interface AvailabilityDecision {
  allowed: boolean;
  reason?: string;
  slotKey?: string;
  capacity?: number;
}

function timeToMinutes(value: string): number {
  const [hours = '0', minutes = '0'] = value.split(':');
  return Number(hours) * 60 + Number(minutes);
}

function minutesToTime(total: number): string {
  const hours = Math.floor(total / 60);
  const minutes = total % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

/**
 * Compute the slot start (HH:MM in property timezone) that a requested time
 * falls into, given the rule's slot duration. Returns null when the rule's
 * window cannot produce a slot.
 */
export function slotStartOf(
  requested: Date,
  rule: Pick<AvailabilityRuleRow, 'start_time' | 'end_time' | 'slot_duration_minutes'>,
  timeZone = PROPERTY_TIME_ZONE,
): string | null {
  const startMinute = timeToMinutes(rule.start_time);
  const endMinute = timeToMinutes(rule.end_time);
  const slot = rule.slot_duration_minutes > 0 ? rule.slot_duration_minutes : 30;
  if (endMinute <= startMinute) return null;
  const requestedMinute = timeToMinutes(zonedTimeString(requested, timeZone));
  if (requestedMinute < startMinute || requestedMinute >= endMinute) return null;
  const offset = requestedMinute - startMinute;
  const slotIndex = Math.floor(offset / slot);
  return minutesToTime(startMinute + slotIndex * slot);
}

async function countSlotBookings(
  client: PoolClient,
  propertyId: string,
  dayKey: string,
  slotStart: string,
  slotDurationMinutes: number,
  bufferMinutes: number,
  excludeVisitId?: string,
): Promise<number> {
  // Count visits whose [start, end + buffer) window overlaps this slot's
  // [slotStart, slotStart + slotDuration + buffer) window on the same local day.
  const result = await client.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
       FROM site_visits sv
      WHERE sv.property_id = $1
        AND sv.id IS DISTINCT FROM $2
        AND sv.status NOT IN ('cancelled', 'no_show', 'completed')
        AND (sv.scheduled_at AT TIME ZONE $3)::date = $4::date
        AND (sv.scheduled_at AT TIME ZONE $3)::time
              < ($5::time + ($6::int || ' minutes')::interval)
        AND ((sv.scheduled_at + (sv.duration_minutes || ' minutes')::interval
              + ($7::int || ' minutes')::interval) AT TIME ZONE $3)::time
              > $5::time`,
    [
      propertyId,
      excludeVisitId ?? null,
      PROPERTY_TIME_ZONE,
      dayKey,
      slotStart,
      slotDurationMinutes,
      bufferMinutes,
    ],
  );
  return Number(result.rows[0]?.count ?? '0');
}

/**
 * Decide whether a visit may be created at `requested` for a property.
 *
 * Rules:
 *  - If no active availability rule exists for the local weekday, the request
 *    is rejected (landlords must publish availability first).
 *  - The requested time must fall inside the rule window.
 *  - A blackout exception for the local date with is_unavailable = true blocks
 *    the request.
 *  - The slot must respect max_bookings_per_slot, buffer_minutes and the rule's
 *    slot duration.
 */
export async function evaluateAvailability(
  client: PoolClient,
  propertyId: string,
  requested: Date,
  excludeVisitId?: string,
): Promise<AvailabilityDecision> {
  const dayKey = zonedDateKey(requested);
  const dayName = zonedDayOfWeek(requested);

  const ruleResult = await client.query<AvailabilityRuleRow>(
    `SELECT start_time, end_time, slot_duration_minutes, buffer_minutes, max_bookings_per_slot
       FROM site_visit_availability_rules
      WHERE property_id = $1 AND is_active = true AND day_of_week = $2::availability_day_of_week
      LIMIT 1`,
    [propertyId, dayName],
  );

  if (ruleResult.rows.length === 0) {
    return {
      allowed: false,
      reason: 'No availability has been published for this property on the requested day.',
    };
  }

  const rule = ruleResult.rows[0]!;

  const exceptionResult = await client.query<{ is_unavailable: boolean; start_time: string | null; end_time: string | null }>(
    `SELECT is_unavailable, start_time, end_time
       FROM site_visit_availability_exceptions
      WHERE property_id = $1 AND exception_date = $2::date
      LIMIT 1`,
    [propertyId, dayKey],
  );

  const exception = exceptionResult.rows[0];
  if (exception?.is_unavailable) {
    return {
      allowed: false,
      reason: 'The property is unavailable on the requested date.',
    };
  }

  const slotStart = slotStartOf(requested, rule);
  if (!slotStart) {
    return {
      allowed: false,
      reason: 'The requested time is outside the available hours for this property.',
    };
  }

  const slotDuration =
    rule.slot_duration_minutes > 0 ? rule.slot_duration_minutes : 30;

  // Partial-day availability exception: restrict to a sub-window.
  if (exception && !exception.is_unavailable && exception.start_time && exception.end_time) {
    const requestedMinute = timeToMinutes(zonedTimeString(requested));
    const startMinute = timeToMinutes(exception.start_time);
    const endMinute = timeToMinutes(exception.end_time);
    if (requestedMinute < startMinute || requestedMinute >= endMinute) {
      return {
        allowed: false,
        reason: 'The requested time is outside the available hours for this property on this date.',
      };
    }
  }

  const bookings = await countSlotBookings(
    client,
    propertyId,
    dayKey,
    slotStart,
    slotDuration,
    rule.buffer_minutes,
    excludeVisitId,
  );

  const capacity = rule.max_bookings_per_slot > 0 ? rule.max_bookings_per_slot : 1;
  if (bookings >= capacity) {
    return {
      allowed: false,
      reason: 'The requested time slot is already fully booked. Please choose another time.',
      slotKey: `${dayKey} ${slotStart}`,
      capacity,
    };
  }

  return {
    allowed: true,
    slotKey: `${dayKey} ${slotStart}`,
    capacity,
  };
}

/**
 * Direct overlap check independent of availability rules. Used as a
 * defence-in-depth guard so two visits can never overlap on the same property
 * even if availability rules are misconfigured or absent.
 */
export async function hasOverlappingVisit(
  client: PoolClient,
  propertyId: string,
  start: Date,
  end: Date,
  excludeVisitId?: string,
): Promise<boolean> {
  const result = await client.query(
    `SELECT 1
       FROM site_visits
      WHERE property_id = $1
        AND id IS DISTINCT FROM $2
        AND status NOT IN ('cancelled', 'no_show')
        AND scheduled_at < $3
        AND scheduled_at + (duration_minutes || ' minutes')::interval > $4
      LIMIT 1`,
    [propertyId, excludeVisitId ?? null, end, start],
  );
  return result.rows.length > 0;
}

/** Property-scoped advisory lock key. */
export function propertyLockKey(propertyId: string): number {
  // hashtext returns int4; pg_advisory_xact_lock(bigint) accepts it.
  return Math.abs(hashString(propertyId)) % 2_147_483_647;
}

function hashString(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}

export async function acquirePropertyLock(client: PoolClient, propertyId: string): Promise<void> {
  await client.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [propertyId]);
}

export function assertNotPast(date: Date, message = 'Visit must be scheduled in the future'): void {
  if (date.getTime() <= Date.now()) {
    throw new HttpError(message, 400);
  }
}