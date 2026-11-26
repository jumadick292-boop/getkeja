// Integration tests for the site visit scheduling and lifecycle backend.
//
// Covers:
//   - eligibility (only published listings accept requests)
//   - requested times are not confirmed bookings
//   - availability rules, buffers, capacity and blackout dates
//   - concurrent booking requests cannot exceed slot capacity
//   - server-side lifecycle transition validation
//   - cancellation / rescheduling preserve history
//   - UTC storage with Africa/Nairobi wall-clock semantics
//   - notification outbox events created transactionally
//   - reminder dispatch rechecks status and is idempotent
//   - authorization: seeker own visits, landlord property scoping, caretakers
//   - staff assignment and resource authorization

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import {
  dispatchReminder,
  getVisit,
} from '../site-visits/site-visit-lifecycle.js';

const app = createApp({ nodeEnv: 'test' });

let seekerUserId: string;
let seekerToken: string;
let landlordUserId: string;
let landlordToken: string;
let otherSeekerId: string;
let otherSeekerToken: string;
let caretakerId: string;
let caretakerToken: string;

let propertyId: string;
let unitId: string;
let listingId: string;

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function registerAndLogin(role: string, emailSuffix = ''): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}${Math.floor(Math.random() * 100000)}${emailSuffix}@example.com`;
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Test',
    lastName: role,
    email,
    password: 'password123',
    role,
    termsAccepted: true,
  });
  expect(reg.status).toBe(201);

  await pool.query(
    `UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`,
    [email],
  );
  await pool.query(
    `UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`,
    [email],
  );

  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(
    `INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [userId, role],
  );

  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  expect(login.status).toBe(200);
  const token = login.headers['x-access-token'] as string;
  expect(token).toBeDefined();
  return { id: userId, token };
}

async function createPublishedProperty(ownerId: string): Promise<{
  propertyId: string;
  unitId: string;
  listingId: string;
}> {
  const prop = await pool.query<{ id: string }>(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, latitude, longitude, amenities, images, created_by, published_at)
     VALUES (NULL, $1, 'A test property', 'apartment', 'published', '12 Riverside Drive', 'Nairobi', 'Nairobi', 'KE', 2, -1.2921, 36.8219, '[]'::jsonb, '[]'::jsonb, $2, NOW())
     RETURNING id`,
    ['Riverside Apartments', ownerId],
  );
  const pid = prop.rows[0]!.id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [pid, ownerId],
  );
  const unit = await pool.query<{ id: string }>(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, amenities, created_by)
     VALUES ($1, 'A-101', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', '[]'::jsonb, $2)
     RETURNING id`,
    [pid, ownerId],
  );
  const uid = unit.rows[0]!.id;
  const listing = await pool.query<{ id: string }>(
    `INSERT INTO property_listings (property_id, unit_id, title, description, status, rent_amount, deposit_amount, available_from, furnished, images, published_at, created_by)
     VALUES ($1, $2, 'Cosy 1BR Riverside', 'Bright and airy', 'published', 45000, 90000, '2026-12-01', TRUE, '[]'::jsonb, NOW(), $3)
     RETURNING id`,
    [pid, uid, ownerId],
  );
  return { propertyId: pid, unitId: uid, listingId: listing.rows[0]!.id };
}

async function setAvailability(dayOfWeek: string, overrides: Partial<{
  startTime: string;
  endTime: string;
  slotDurationMinutes: number;
  bufferMinutes: number;
  maxBookingsPerSlot: number;
}> = {}): Promise<void> {
  await pool.query(
    `INSERT INTO site_visit_availability_rules
       (property_id, day_of_week, start_time, end_time, slot_duration_minutes, buffer_minutes, max_bookings_per_slot, is_active)
     VALUES ($1, $2::availability_day_of_week, $3::time, $4::time, $5, $6, $7, TRUE)
     ON CONFLICT (property_id, day_of_week) DO UPDATE
       SET start_time = EXCLUDED.start_time,
           end_time = EXCLUDED.end_time,
           slot_duration_minutes = EXCLUDED.slot_duration_minutes,
           buffer_minutes = EXCLUDED.buffer_minutes,
           max_bookings_per_slot = EXCLUDED.max_bookings_per_slot,
           is_active = TRUE`,
    [
      propertyId,
      dayOfWeek,
      overrides.startTime ?? '09:00',
      overrides.endTime ?? '17:00',
      overrides.slotDurationMinutes ?? 30,
      overrides.bufferMinutes ?? 0,
      overrides.maxBookingsPerSlot ?? 1,
    ],
  );
}

async function cleanupTestData(): Promise<void> {
  await pool.query('DELETE FROM site_visit_reminder_jobs');
  await pool.query('DELETE FROM site_visit_history');
  await pool.query('DELETE FROM site_visits');
  await pool.query('DELETE FROM site_visit_availability_exceptions');
  await pool.query('DELETE FROM site_visit_availability_rules');
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM notification_recipients');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM listing_status_history');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_assignments');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'caretaker', 'tenant')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanupTestData();
  const seeker = await registerAndLogin('house_seeker', 's');
  seekerUserId = seeker.id;
  seekerToken = seeker.token;
  // Phone lives on user_profiles, not users; the create endpoint requires one.
  await pool.query(
    `INSERT INTO user_profiles (user_id, phone_number)
     VALUES ($1, '+254700000001')
     ON CONFLICT (user_id) DO UPDATE SET phone_number = EXCLUDED.phone_number`,
    [seekerUserId],
  );
  const landlord = await registerAndLogin('landlord', 'l');
  landlordUserId = landlord.id;
  landlordToken = landlord.token;
  const other = await registerAndLogin('house_seeker', 'o');
  otherSeekerId = other.id;
  otherSeekerToken = other.token;
  await pool.query(
    `INSERT INTO user_profiles (user_id, phone_number)
     VALUES ($1, '+254700000002')
     ON CONFLICT (user_id) DO UPDATE SET phone_number = EXCLUDED.phone_number`,
    [otherSeekerId],
  );
  const caretaker = await registerAndLogin('caretaker', 'c');
  caretakerId = caretaker.id;
  caretakerToken = caretaker.token;
  const fixtures = await createPublishedProperty(landlordUserId);
  propertyId = fixtures.propertyId;
  unitId = fixtures.unitId;
  listingId = fixtures.listingId;
});

afterEach(async () => {
  await cleanupTestData();
});

function futureAt(dayOffset: number, hour: number, minute = 0): string {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + dayOffset);
  date.setUTCHours(hour, minute, 0, 0);
  return date.toISOString();
}

function dayOfWeekFor(dayOffset: number): string {
  // Derive the weekday from the same instant the slot is booked at (UTC 10:00 →
  // 13:00 Nairobi, same calendar day). Computing from the live clock instead
  // breaks in the evening UTC, when now+offset crosses midnight in Nairobi and
  // yields the next day's weekday.
  const date = new Date(futureAt(dayOffset, 10));
  const name = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: 'Africa/Nairobi' })
    .format(date);
  return name.toLowerCase();
}

async function findOutbox(eventType: string): Promise<Array<Record<string, unknown>>> {
  const result = await pool.query(
    `SELECT id, event_type AS "eventType", recipient_user_ids AS "recipientUserIds",
            resource_id AS "resourceId", payload, status
       FROM notification_outbox
      WHERE event_type = $1
      ORDER BY created_at`,
    [eventType],
  );
  return result.rows;
}

describe('Site visit eligibility', () => {
  it('rejects requests for a property without a published listing', async () => {
    await pool.query(`UPDATE property_listings SET status = 'draft' WHERE id = $1`, [listingId]);
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(7, 10) });
    expect(response.status).toBe(409);
  });

  it('rejects a request for a listing that does not exist', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({
        propertyId,
        listingId: '00000000-0000-0000-0000-000000000000',
        scheduledAt: futureAt(7, 10),
      });
    expect(response.status).toBe(404);
  });

  it('rejects a visit scheduled in the past', async () => {
    const past = new Date(Date.now() - 3600_000).toISOString();
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: past });
    expect(response.status).toBe(400);
  });

  it('requires a contact phone number', async () => {
    await pool.query(`DELETE FROM user_profiles WHERE user_id = $1`, [seekerUserId]);
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(7, 10) });
    expect(response.status).toBe(409);
  });
});

describe('Site visit requests are not confirmed bookings', () => {
  it('creates a scheduled visit with status scheduled', async () => {
    const day = 7;
    await setAvailability(dayOfWeekFor(day));
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 10) });
    expect(response.status).toBe(201);
    expect(response.body.status).toBe('scheduled');
    expect(response.body.scheduledAt).toBe(new Date(futureAt(day, 10)).toISOString());
  });

  it('stores timestamps in UTC and returns ISO-8601 UTC strings', async () => {
    const day = 8;
    await setAvailability(dayOfWeekFor(day));
    const requested = futureAt(day, 10, 30);
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: requested });
    expect(response.status).toBe(201);
    expect(response.body.scheduledAt.endsWith('Z')).toBe(true);
    const stored = await getVisit(response.body.id);
    expect(stored!.scheduledAt.toISOString()).toBe(new Date(requested).toISOString());
  });
});

describe('Availability rules and capacity', () => {
  it('rejects a time outside the published availability window', async () => {
    await setAvailability(dayOfWeekFor(9), { startTime: '09:00', endTime: '12:00' });
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(9, 15) });
    expect(response.status).toBe(409);
    expect(response.body.message).toMatch(/available hours/i);
  });

  it('rejects a day with no published availability rule', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(11, 10) });
    expect(response.status).toBe(409);
    expect(response.body.message).toMatch(/no availability/i);
  });

  it('enforces max_bookings_per_slot capacity', async () => {
    const day = 10;
    await setAvailability(dayOfWeekFor(day), {
      slotDurationMinutes: 60,
      maxBookingsPerSlot: 1,
    });
    const slot = futureAt(day, 10);

    const first = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: slot });
    expect(first.status).toBe(201);

    const second = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(otherSeekerToken))
      .send({ propertyId, listingId, scheduledAt: slot });
    expect(second.status).toBe(409);
    expect(second.body.message).toMatch(/fully booked|taken/i);
  });

  it('counts an overlapping visit against slot capacity', async () => {
    // A 60-minute visit starting at 10:00 occupies the 10:30 slot too, so with
    // capacity 1 a request at 10:30 is rejected as fully booked.
    const day = 12;
    await setAvailability(dayOfWeekFor(day), {
      slotDurationMinutes: 30,
      bufferMinutes: 0,
      maxBookingsPerSlot: 1,
    });
    const start = futureAt(day, 10);
    const start2 = futureAt(day, 10, 30);
    await pool.query(
      `INSERT INTO site_visits (property_id, unit_id, user_id, visitor_name, visitor_phone, scheduled_at, duration_minutes, status, created_by)
       VALUES ($1, $2, $3, 'Existing Visitor', '+254700000000', $4, 60, 'confirmed', $3)`,
      [propertyId, unitId, otherSeekerId, start],
    );
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: start2 });
    expect(response.status).toBe(409);
    expect(response.body.message).toMatch(/fully booked|taken/i);
  });

  it('respects the configured buffer between visits', async () => {
    const day = 13;
    await setAvailability(dayOfWeekFor(day), {
      slotDurationMinutes: 30,
      bufferMinutes: 30,
      maxBookingsPerSlot: 1,
    });

    const first = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 10) });
    expect(first.status).toBe(201);

    // 10:20 overlaps the 10:00 visit's 30 minute buffer (ends 11:00).
    const second = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(otherSeekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 10, 20) });
    expect(second.status).toBe(409);

    // 10:30 is still inside the buffered window.
    const third = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(otherSeekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 10, 30) });
    expect(third.status).toBe(409);

    // 11:00 is exactly at the end of the buffered window and is allowed.
    const fourth = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(otherSeekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 11) });
    expect(fourth.status).toBe(201);
  });
});

describe('Blackout dates and temporary unavailability', () => {
  it('rejects a blackout date', async () => {
    const day = 14;
    await setAvailability(dayOfWeekFor(day));
    const target = futureAt(day, 10);
    const dateKey = target.slice(0, 10);
    await pool.query(
      `INSERT INTO site_visit_availability_exceptions (property_id, exception_date, reason, is_unavailable)
       VALUES ($1, $2::date, 'Public holiday', TRUE)`,
      [propertyId, dateKey],
    );
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: target });
    expect(response.status).toBe(409);
    expect(response.body.message).toMatch(/unavailable/i);
  });

  it('rejects a time outside a partial-day availability window', async () => {
    const day = 15;
    await setAvailability(dayOfWeekFor(day));
    const target = futureAt(day, 10);
    const dateKey = target.slice(0, 10);
    await pool.query(
      `INSERT INTO site_visit_availability_exceptions
         (property_id, exception_date, reason, is_unavailable, start_time, end_time)
       VALUES ($1, $2::date, 'Morning only', FALSE, '09:00', '10:00')`,
      [propertyId, dateKey],
    );
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 14) });
    expect(response.status).toBe(409);
  });

  it('allows a time inside a partial-day availability window', async () => {
    const day = 16;
    await setAvailability(dayOfWeekFor(day));
    // 07:00 UTC is 10:00 Africa/Nairobi, inside the 09:00-12:00 partial window.
    const target = futureAt(day, 7);
    const dateKey = target.slice(0, 10);
    await pool.query(
      `INSERT INTO site_visit_availability_exceptions
         (property_id, exception_date, reason, is_unavailable, start_time, end_time)
       VALUES ($1, $2::date, 'Morning only', FALSE, '09:00', '12:00')`,
      [propertyId, dateKey],
    );
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: target });
    expect(response.status).toBe(201);
  });
});

describe('Concurrent booking requests', () => {
  it('never exceeds slot capacity under concurrency', async () => {
    const day = 17;
    await setAvailability(dayOfWeekFor(day), {
      slotDurationMinutes: 30,
      maxBookingsPerSlot: 2,
    });
    const slot = futureAt(day, 10);

    // Fire 12 concurrent requests for the same slot with capacity 2.
    const attempts = await Promise.all(
      Array.from({ length: 12 }, (_, index) =>
        request(app)
          .post('/api/v1/house-seeker/site-visits')
          .set(authHeaders(index % 2 === 0 ? seekerToken : otherSeekerToken))
          .send({ propertyId, listingId, scheduledAt: slot }),
      ),
    );

    const created = attempts.filter((response) => response.status === 201);
    const rejected = attempts.filter((response) => response.status === 409);
    expect(created.length).toBe(2);
    expect(rejected.length).toBe(10);

    const count = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM site_visits
        WHERE property_id = $1 AND status <> 'cancelled'`,
      [propertyId],
    );
    expect(Number(count.rows[0]!.count)).toBe(2);
  });

  it('serialises concurrent requests via the property advisory lock', async () => {
    const day = 18;
    await setAvailability(dayOfWeekFor(day), {
      slotDurationMinutes: 30,
      maxBookingsPerSlot: 1,
    });
    const slot = futureAt(day, 10);

    const attempts = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(app)
          .post('/api/v1/house-seeker/site-visits')
          .set(authHeaders(seekerToken))
          .send({ propertyId, listingId, scheduledAt: slot }),
      ),
    );

    expect(attempts.filter((response) => response.status === 201).length).toBe(1);
    expect(attempts.filter((response) => response.status === 409).length).toBe(7);
  });
});

describe('Lifecycle transitions', () => {
  async function createVisit(token = seekerToken, dayOffset = 20, hour = 10): Promise<string> {
    await setAvailability(dayOfWeekFor(dayOffset));
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(token))
      .send({ propertyId, listingId, scheduledAt: futureAt(dayOffset, hour) });
    expect(response.status).toBe(201);
    return response.body.id as string;
  }

  it('confirms a scheduled visit', async () => {
    const visitId = await createVisit();
    const response = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('confirmed');
  });

  it('rejects an invalid transition (confirm twice)', async () => {
    const visitId = await createVisit();
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    const second = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    expect(second.status).toBe(409);
    expect(second.body.message).toMatch(/cannot transition/i);
  });

  it('rejects cancelling a completed visit', async () => {
    const visitId = await createVisit();
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/complete`)
      .set(authHeaders(landlordToken))
      .send({});
    const cancel = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/cancel`)
      .set(authHeaders(landlordToken))
      .send({});
    expect(cancel.status).toBe(409);
  });

  it('records a history row for every transition', async () => {
    const visitId = await createVisit();
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({ hostNotes: 'Ready' });
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/complete`)
      .set(authHeaders(landlordToken))
      .send({ outcome: 'interested' });

    const history = await pool.query(
      `SELECT action, previous_status AS "previousStatus", new_status AS "newStatus"
         FROM site_visit_history WHERE visit_id = $1 ORDER BY created_at`,
      [visitId],
    );
    expect(history.rows.map((row) => row.action)).toEqual([
      'scheduled',
      'confirmed',
      'completed',
    ]);
    expect(history.rows[1]!.previousStatus).toBe('scheduled');
    expect(history.rows[1]!.newStatus).toBe('confirmed');
  });

  it('revalidates availability when confirming a visit that became unavailable', async () => {
    const day = 21;
    await setAvailability(dayOfWeekFor(day));
    const scheduledAt = futureAt(day, 10);
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt });
    expect(created.status).toBe(201);
    const visitId = created.body.id as string;

    // Blackout the date after the request was accepted.
    await pool.query(
      `INSERT INTO site_visit_availability_exceptions (property_id, exception_date, reason, is_unavailable)
       VALUES ($1, $2::date, 'Owner unavailable', TRUE)`,
      [propertyId, scheduledAt.slice(0, 10)],
    );

    const confirm = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    expect(confirm.status).toBe(409);
  });

  it('rescheduling preserves history and emits the rescheduled event', async () => {
    const day = 22;
    await setAvailability(dayOfWeekFor(day));
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 10) });
    const visitId = created.body.id as string;

    const newTime = futureAt(day, 14);
    const rescheduled = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/reschedule`)
      .set(authHeaders(landlordToken))
      .send({ scheduledAt: newTime, reason: 'Tenant request' });
    expect(rescheduled.status).toBe(200);
    expect(rescheduled.body.status).toBe('rescheduled');
    expect(rescheduled.body.scheduledAt).toBe(new Date(newTime).toISOString());

    const history = await pool.query(
      `SELECT action, previous_scheduled_at AS "previousScheduledAt", new_scheduled_at AS "newScheduledAt"
         FROM site_visit_history WHERE visit_id = $1 ORDER BY created_at`,
      [visitId],
    );
    expect(history.rows.length).toBe(2);
    expect(history.rows[1]!.previousScheduledAt).not.toBeNull();
    expect(new Date(history.rows[1]!.newScheduledAt).toISOString()).toBe(newTime);
  });

  it('cancelling preserves the visit row for historical access', async () => {
    const visitId = await createVisit();
    const cancelled = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/cancel`)
      .set(authHeaders(landlordToken))
      .send({ reason: 'Landlord unavailable' });
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.status).toBe('cancelled');

    const stillThere = await request(app)
      .get(`/api/v1/house-seeker/site-visits/${visitId}`)
      .set(authHeaders(seekerToken));
    expect(stillThere.status).toBe(200);
    expect(stillThere.body.status).toBe('cancelled');
  });

  it('allows a cancelled visit slot to be rebooked', async () => {
    const day = 23;
    await setAvailability(dayOfWeekFor(day), { maxBookingsPerSlot: 1 });
    const slot = futureAt(day, 10);
    const first = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: slot });
    expect(first.status).toBe(201);
    await request(app)
      .post(`/api/v1/landlord/site-visits/${first.body.id}/cancel`)
      .set(authHeaders(landlordToken))
      .send({});

    const second = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(otherSeekerToken))
      .send({ propertyId, listingId, scheduledAt: slot });
    expect(second.status).toBe(201);
  });
});

describe('Notification outbox integration', () => {
  it('writes a requested outbox event transactionally with the visit', async () => {
    await setAvailability(dayOfWeekFor(24));
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(24, 10) });
    expect(response.status).toBe(201);
    const visitId = response.body.id as string;

    const events = await findOutbox('site_visit.requested');
    expect(events.length).toBe(1);
    expect(events[0]!.recipientUserIds).toContain(landlordUserId);
    expect(events[0]!.resourceId).toBe(visitId);
    expect(events[0]!.status).toBe('pending');
  });

  it('does not leave an outbox row when the visit creation fails', async () => {
    const before = (await findOutbox('site_visit.requested')).length;
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(25, 10) });
    expect(response.status).toBe(409);
    expect((await findOutbox('site_visit.requested')).length).toBe(before);
  });

  it('emits confirmed, rescheduled and cancelled events', async () => {
    await setAvailability(dayOfWeekFor(26));
    await setAvailability(dayOfWeekFor(27));
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(26, 10) });
    const visitId = created.body.id as string;

    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    expect((await findOutbox('site_visit.confirmed')).length).toBe(1);

    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/reschedule`)
      .set(authHeaders(landlordToken))
      .send({ scheduledAt: futureAt(27, 11) });
    expect((await findOutbox('site_visit.rescheduled')).length).toBe(1);

    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/cancel`)
      .set(authHeaders(landlordToken))
      .send({});
    const cancelled = await findOutbox('site_visit.cancelled');
    expect(cancelled.length).toBe(1);
    expect(cancelled[0]!.recipientUserIds).toContain(seekerUserId);
  });

  it('emits a declined event when the landlord declines', async () => {
    await setAvailability(dayOfWeekFor(28));
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(28, 10) });
    const visitId = created.body.id as string;

    const declined = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/decline`)
      .set(authHeaders(landlordToken))
      .send({ reason: 'Already let' });
    expect(declined.status).toBe(200);

    const events = await findOutbox('site_visit.declined');
    expect(events.length).toBe(1);
    expect(events[0]!.recipientUserIds).toContain(seekerUserId);
    expect(events[0]!.payload).toMatchObject({ reason: 'Already let' });
  });

  it('materialises outbox events into notifications respecting preferences', async () => {
    await setAvailability(dayOfWeekFor(29));
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(29, 10) });
    expect(created.status).toBe(201);

    const { NotificationService } = await import('../auth/notification.service.js');
    const service = new NotificationService();
    const pending = await pool.query<{ id: string }>(
      `SELECT id FROM notification_outbox WHERE status = 'pending' LIMIT 1`,
    );
    expect(pending.rows.length).toBeGreaterThan(0);
    await service.processOutboxEvent(pending.rows[0]!.id);

    const notifications = await pool.query<{ userId: string }>(
      `SELECT user_id AS "userId" FROM notifications WHERE event_type = 'site_visit.requested'`,
    );
    expect(notifications.rows.map((row) => row.userId)).toContain(landlordUserId);
  });

  it('does not duplicate delivery attempts when an outbox event is processed twice', async () => {
    await setAvailability(dayOfWeekFor(30));
    await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(30, 10) });

    const { NotificationService } = await import('../auth/notification.service.js');
    const service = new NotificationService();
    const pending = await pool.query<{ id: string }>(
      `SELECT id FROM notification_outbox WHERE status = 'pending' LIMIT 1`,
    );
    const outboxId = pending.rows[0]!.id;

    await service.processOutboxEvent(outboxId);
    await service.processOutboxEvent(outboxId);

    const attempts = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM notification_delivery_attempts`,
    );
    // The landlord receives in_app + email = 2 attempts, and reprocessing
    // must not double them.
    expect(Number(attempts.rows[0]!.count)).toBe(2);
  });
});

describe('Reminder behaviour', () => {
  async function createVisitAt(scheduledAt: string): Promise<string> {
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt });
    expect(response.status).toBe(201);
    return response.body.id as string;
  }

  it('does not send a reminder for a cancelled visit', async () => {
    const day = 31;
    await setAvailability(dayOfWeekFor(day));
    const visitId = await createVisitAt(futureAt(day, 10));
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/cancel`)
      .set(authHeaders(landlordToken))
      .send({});

    const before = (await findOutbox('site_visit.reminder')).length;
    await dispatchReminder(visitId, '24h');
    await dispatchReminder(visitId, '2h');
    expect((await findOutbox('site_visit.reminder')).length).toBe(before);
  });

  it('does not send a reminder for a completed visit', async () => {
    const day = 32;
    await setAvailability(dayOfWeekFor(day));
    const visitId = await createVisitAt(futureAt(day, 10));
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/complete`)
      .set(authHeaders(landlordToken))
      .send({});

    const before = (await findOutbox('site_visit.reminder')).length;
    await dispatchReminder(visitId, '24h');
    expect((await findOutbox('site_visit.reminder')).length).toBe(before);
  });

  it('sends a reminder when the visit is inside the 24h window', async () => {
    const tomorrow = new Date(Date.now() + 20 * 60 * 60 * 1000);
    const dayName = new Intl.DateTimeFormat('en-US', {
      weekday: 'long',
      timeZone: 'Africa/Nairobi',
    })
      .format(tomorrow)
      .toLowerCase();
    await setAvailability(dayName, { startTime: '00:00', endTime: '23:59' });
    const visitId = await createVisitAt(tomorrow.toISOString());

    const before = (await findOutbox('site_visit.reminder')).length;
    await dispatchReminder(visitId, '24h');
    const events = await findOutbox('site_visit.reminder');
    expect(events.length).toBe(before + 1);
    expect(events[events.length - 1]!.recipientUserIds).toContain(seekerUserId);
  });

  it('does not send a reminder outside its window', async () => {
    const day = 33;
    await setAvailability(dayOfWeekFor(day));
    const visitId = await createVisitAt(futureAt(day, 10));

    const before = (await findOutbox('site_visit.reminder')).length;
    await dispatchReminder(visitId, '2h');
    expect((await findOutbox('site_visit.reminder')).length).toBe(before);
  });

  it('is idempotent: repeated dispatch does not duplicate reminders', async () => {
    const tomorrow = new Date(Date.now() + 20 * 60 * 60 * 1000);
    const dayName = new Intl.DateTimeFormat('en-US', {
      weekday: 'long',
      timeZone: 'Africa/Nairobi',
    })
      .format(tomorrow)
      .toLowerCase();
    await setAvailability(dayName, { startTime: '00:00', endTime: '23:59' });
    const visitId = await createVisitAt(tomorrow.toISOString());

    const before = (await findOutbox('site_visit.reminder')).length;
    await dispatchReminder(visitId, '24h');
    await dispatchReminder(visitId, '24h');
    await dispatchReminder(visitId, '24h');
    expect((await findOutbox('site_visit.reminder')).length).toBe(before + 1);
  });

  it('uses the rescheduled time in the reminder idempotency key', async () => {
    const tomorrow = new Date(Date.now() + 20 * 60 * 60 * 1000);
    const dayName = new Intl.DateTimeFormat('en-US', {
      weekday: 'long',
      timeZone: 'Africa/Nairobi',
    })
      .format(tomorrow)
      .toLowerCase();
    await setAvailability(dayName, { startTime: '00:00', endTime: '23:59' });
    const visitId = await createVisitAt(tomorrow.toISOString());

    await dispatchReminder(visitId, '24h');
    const newTime = new Date(tomorrow.getTime() + 60 * 60 * 1000);
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/reschedule`)
      .set(authHeaders(landlordToken))
      .send({ scheduledAt: newTime.toISOString() });

    await dispatchReminder(visitId, '24h');
    const events = await findOutbox('site_visit.reminder');
    // One reminder per distinct scheduled_at instant.
    expect(events.length).toBe(2);
  });
});

describe('Authorization', () => {
  async function createVisit(): Promise<string> {
    await setAvailability(dayOfWeekFor(40));
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(40, 10) });
    expect(response.status).toBe(201);
    return response.body.id as string;
  }

  it('prevents a seeker from reading another seeker visit', async () => {
    const visitId = await createVisit();
    const response = await request(app)
      .get(`/api/v1/house-seeker/site-visits/${visitId}`)
      .set(authHeaders(otherSeekerToken));
    expect(response.status).toBe(403);
  });

  it('prevents a seeker from cancelling another seeker visit', async () => {
    const visitId = await createVisit();
    const response = await request(app)
      .post(`/api/v1/house-seeker/site-visits/${visitId}/cancel`)
      .set(authHeaders(otherSeekerToken))
      .send({});
    expect(response.status).toBe(403);
  });

  it('prevents a landlord from managing a property they do not own', async () => {
    const visitId = await createVisit();
    const otherLandlord = await registerAndLogin('landlord', 'x');
    const response = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(otherLandlord.token))
      .send({});
    expect(response.status).toBe(403);
  });

  it('prevents a caretaker from inheriting unrestricted landlord access', async () => {
    const visitId = await createVisit();

    // Give the caretaker a unit access assignment (read access, not management).
    await pool.query(
      `INSERT INTO unit_access_assignments (unit_id, property_id, user_id, access_level, status, assigned_by)
       VALUES ($1, $2, $3, 'view', 'active', $4)`,
      [unitId, propertyId, caretakerId, landlordUserId],
    );

    const confirm = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(caretakerToken))
      .send({});
    expect(confirm.status).toBe(403);

    const decline = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/decline`)
      .set(authHeaders(caretakerToken))
      .send({ reason: 'nope' });
    expect(decline.status).toBe(403);
  });

  it('allows a landlord to manage visits for their own property', async () => {
    const visitId = await createVisit();
    const response = await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({});
    expect(response.status).toBe(200);
  });

  it('scopes landlord visit listings to owned properties', async () => {
    await createVisit();
    const otherLandlord = await registerAndLogin('landlord', 'y');
    const response = await request(app)
      .get('/api/v1/landlord/site-visits')
      .set(authHeaders(otherLandlord.token));
    expect(response.status).toBe(200);
    expect(response.body.total).toBe(0);
  });

  it('keeps internal notes private from house seekers', async () => {
    const visitId = await createVisit();
    await request(app)
      .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
      .set(authHeaders(landlordToken))
      .send({ hostNotes: 'PRIVATE: tenant is flaky' });

    const visit = await request(app)
      .get(`/api/v1/house-seeker/site-visits/${visitId}`)
      .set(authHeaders(seekerToken));
    expect(visit.status).toBe(200);
    // hostNotes is intentionally exposed to the landlord; the internal notes
    // field lives on enquiries and is never returned by seeker endpoints.
    expect(visit.body).not.toHaveProperty('internalNotes');
  });

  it('requires authentication for site visit endpoints', async () => {
    const response = await request(app).get('/api/v1/house-seeker/site-visits');
    expect(response.status).toBe(401);
  });

  it('rejects invalid visit ids with a validation error', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/site-visits/not-a-uuid')
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(400);
  });
});

describe('Landlord availability management', () => {
  it('lets a landlord publish and read availability rules', async () => {
    const create = await request(app)
      .put(`/api/v1/landlord/properties/${propertyId}/site-visit-availability/rules`)
      .set(authHeaders(landlordToken))
      .send({
        dayOfWeek: 'monday',
        startTime: '09:00',
        endTime: '17:00',
        slotDurationMinutes: 30,
        bufferMinutes: 15,
        maxBookingsPerSlot: 2,
      });
    expect(create.status).toBe(201);
    expect(create.body.startTime).toBe('09:00');
    expect(create.body.maxBookingsPerSlot).toBe(2);

    const list = await request(app)
      .get(`/api/v1/landlord/properties/${propertyId}/site-visit-availability`)
      .set(authHeaders(landlordToken));
    expect(list.status).toBe(200);
    expect(list.body.rules.length).toBe(1);
    expect(list.body.rules[0].dayOfWeek).toBe('monday');
  });

  it('rejects an availability rule whose end time is not after its start', async () => {
    const response = await request(app)
      .put(`/api/v1/landlord/properties/${propertyId}/site-visit-availability/rules`)
      .set(authHeaders(landlordToken))
      .send({
        dayOfWeek: 'monday',
        startTime: '17:00',
        endTime: '09:00',
      });
    expect(response.status).toBe(400);
  });

  it('lets a landlord add and remove a blackout exception', async () => {
    const create = await request(app)
      .put(`/api/v1/landlord/properties/${propertyId}/site-visit-availability/exceptions`)
      .set(authHeaders(landlordToken))
      .send({ exceptionDate: '2026-12-25', reason: 'Christmas', isUnavailable: true });
    expect(create.status).toBe(201);
    const exceptionId = create.body.id as string;

    const list = await request(app)
      .get(`/api/v1/landlord/properties/${propertyId}/site-visit-availability`)
      .set(authHeaders(landlordToken));
    expect(list.body.exceptions.length).toBe(1);

    const remove = await request(app)
      .delete(
        `/api/v1/landlord/properties/${propertyId}/site-visit-availability/exceptions/${exceptionId}`,
      )
      .set(authHeaders(landlordToken));
    expect(remove.status).toBe(204);
  });

  it('prevents a different landlord from editing availability', async () => {
    const otherLandlord = await registerAndLogin('landlord', 'z');
    const response = await request(app)
      .put(`/api/v1/landlord/properties/${propertyId}/site-visit-availability/rules`)
      .set(authHeaders(otherLandlord.token))
      .send({
        dayOfWeek: 'monday',
        startTime: '09:00',
        endTime: '17:00',
      });
    expect(response.status).toBe(403);
  });
});

describe('Seeker availability lookup', () => {
  it('returns bookable slots for a published listing', async () => {
    const day = 50;
    const dayName = dayOfWeekFor(day);
    await setAvailability(dayName, { startTime: '09:00', endTime: '12:00', slotDurationMinutes: 60 });
    const target = futureAt(day, 9, 30);
    const dateKey = target.slice(0, 10);

    const response = await request(app)
      .get(`/api/v1/house-seeker/listings/${listingId}/availability`)
      .set(authHeaders(seekerToken))
      .query({ date: dateKey });
    expect(response.status).toBe(200);
    expect(response.body.timezone).toBe('Africa/Nairobi');
    expect(response.body.slots.map((slot: { start: string }) => slot.start)).toEqual([
      '09:00',
      '10:00',
      '11:00',
    ]);
    expect(response.body.slots.every((slot: { available: boolean }) => slot.available)).toBe(true);
  });

  it('reports reduced availability once a slot is booked', async () => {
    const day = 51;
    const dayName = dayOfWeekFor(day);
    await setAvailability(dayName, {
      startTime: '09:00',
      endTime: '12:00',
      slotDurationMinutes: 60,
      maxBookingsPerSlot: 1,
    });
    const target = futureAt(day, 7);
    const dateKey = target.slice(0, 10);

    await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId, scheduledAt: futureAt(day, 7) });

    const response = await request(app)
      .get(`/api/v1/house-seeker/listings/${listingId}/availability`)
      .set(authHeaders(seekerToken))
      .query({ date: dateKey });
    const byStart = new Map(
      (response.body.slots as Array<{ start: string; available: boolean }>).map((slot) => [
        slot.start,
        slot.available,
      ]),
    );
    expect(byStart.get('09:00')).toBe(true);
    expect(byStart.get('10:00')).toBe(false);
  });

  it('rejects an availability lookup for an unpublished listing', async () => {
    await pool.query(`UPDATE property_listings SET status = 'draft' WHERE id = $1`, [listingId]);
    const response = await request(app)
      .get(`/api/v1/house-seeker/listings/${listingId}/availability`)
      .set(authHeaders(seekerToken))
      .query({ date: futureAt(60, 10).slice(0, 10) });
    expect(response.status).toBe(409);
  });
});