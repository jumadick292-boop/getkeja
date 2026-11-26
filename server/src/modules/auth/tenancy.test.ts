// Tenancy lifecycle API tests.
//
// Exercises the landlord-facing tenancy CRUD and participant management under
// /api/v1/auth/tenancies. The tenancy tables and routes exist but previously
// had no dedicated coverage.
//
// Setup mirrors landlord.test.ts: register+verify a landlord, create a property
// with ownership, a unit, then drive the tenancy endpoints over HTTP.

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let landlordUserId: string;
let accessToken: string;
let propertyId: string;
let unitId: string;
let seekerUserId: string;
let seekerToken: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}${Math.floor(Math.random() * 100000)}@example.com`;
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
  await pool.query(
    `INSERT INTO user_profiles (user_id, phone_number) VALUES ((SELECT id FROM users WHERE email = $1), $2)
     ON CONFLICT (user_id) DO UPDATE SET phone_number = EXCLUDED.phone_number`,
    [email, `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`],
  );

  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id;
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

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createPropertyWithUnit(ownerId: string): Promise<{ propertyId: string; unitId: string }> {
  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by)
     VALUES (NULL, 'Tenancy Test Property', 'desc', 'apartment', 'published', '1 Test Rd', 'Nairobi', 'Nairobi', 'KE', 1, $1)
     RETURNING id`,
    [ownerId],
  );
  const pid = prop.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [pid, ownerId],
  );
  const unit = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, 'T-1', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', $2)
     RETURNING id`,
    [pid, ownerId],
  );
  return { propertyId: pid, unitId: unit.rows[0].id };
}

async function cleanup(): Promise<void> {
  await pool.query('DELETE FROM tenancy_participants');
  await pool.query('DELETE FROM tenancy_history');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
  const landlord = await registerAndLogin('landlord');
  landlordUserId = landlord.id;
  accessToken = landlord.token;
  const seeker = await registerAndLogin('house_seeker');
  seekerUserId = seeker.id;
  seekerToken = seeker.token;
  const fixtures = await createPropertyWithUnit(landlordUserId);
  propertyId = fixtures.propertyId;
  unitId = fixtures.unitId;
});

afterEach(async () => {
  await cleanup();
});

function futureDate(days: number): string {
  return new Date(Date.now() + days * 86400000).toISOString().slice(0, 10);
}

describe('Tenancy API', () => {
  it('creates a tenancy', async () => {
    const response = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({
        propertyId,
        unitId,
        tenancyType: 'residential',
        startDate: futureDate(1),
        rentAmount: 50000,
        depositAmount: 100000,
        rentDueDay: 1,
      });
    expect(response.status).toBe(201);
    expect(response.body.id).toBeDefined();
    expect(response.body.status).toBeDefined();
  });

  it('rejects creating a tenancy with an invalid payload', async () => {
    const response = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1) }); // missing rentAmount
    expect(response.status).toBe(400);
  });

  it('gets a tenancy by id', async () => {
    const create = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });
    const tenancyId = create.body.id;

    const response = await request(app)
      .get(`/api/v1/auth/tenancies/${tenancyId}`)
      .set(authHeaders(accessToken));
    expect(response.status).toBe(200);
    expect(response.body.id).toBe(tenancyId);
    expect(Number(response.body.rentAmount)).toBe(50000);
  });

  it('updates a tenancy', async () => {
    const create = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });
    const tenancyId = create.body.id;

    const response = await request(app)
      .patch(`/api/v1/auth/tenancies/${tenancyId}`)
      .set(authHeaders(accessToken))
      .send({ rentAmount: 55000 });
    expect(response.status).toBe(200);
    expect(Number(response.body.rentAmount)).toBe(55000);
  });

  it('denies a non-owner from reading a tenancy', async () => {
    const create = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });
    const tenancyId = create.body.id;

    const response = await request(app)
      .get(`/api/v1/auth/tenancies/${tenancyId}`)
      .set(authHeaders(seekerToken));
    expect([403, 404]).toContain(response.status);
  });

  it('lists tenancies for a property the caller owns', async () => {
    await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });

    const response = await request(app)
      .get('/api/v1/auth/tenancies')
      .query({ propertyId })
      .set(authHeaders(accessToken));
    expect(response.status).toBe(200);
    const items = Array.isArray(response.body) ? response.body : response.body.items;
    expect(items.length).toBeGreaterThanOrEqual(1);
  });

  it('deletes a tenancy (204) and it can no longer be read', async () => {
    const create = await request(app)
      .post('/api/v1/auth/tenancies')
      .set(authHeaders(accessToken))
      .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });
    const tenancyId = create.body.id;

    const del = await request(app)
      .delete(`/api/v1/auth/tenancies/${tenancyId}`)
      .set(authHeaders(accessToken));
    expect(del.status).toBe(204);

    const read = await request(app)
      .get(`/api/v1/auth/tenancies/${tenancyId}`)
      .set(authHeaders(accessToken));
    expect([403, 404]).toContain(read.status);
  });

  describe('participants', () => {
    let tenancyId: string;

    beforeEach(async () => {
      const create = await request(app)
        .post('/api/v1/auth/tenancies')
        .set(authHeaders(accessToken))
        .send({ propertyId, unitId, startDate: futureDate(1), rentAmount: 50000, depositAmount: 100000 });
      tenancyId = create.body.id;
    });

    it('adds and lists a participant', async () => {
      const add = await request(app)
        .post(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken))
        .send({
          userId: seekerUserId,
          role: 'co_tenant',
        });
      expect([200, 201]).toContain(add.status);

      const list = await request(app)
        .get(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken));
      expect(list.status).toBe(200);
      expect(Array.isArray(list.body.items ?? list.body)).toBe(true);
    });

    it('updates a participant role', async () => {
      const add = await request(app)
        .post(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken))
        .send({ userId: seekerUserId, role: 'co_tenant' });
      const participantId = add.body.id;

      const update = await request(app)
        .patch(`/api/v1/auth/tenancies/${tenancyId}/participants/${participantId}`)
        .set(authHeaders(accessToken))
        .send({ role: 'authorized_representative', canAuthorizeRepairs: true });
      expect(update.status).toBe(200);
      expect(update.body.role).toBe('authorized_representative');
      expect(update.body.canAuthorizeRepairs).toBe(true);
    });

    it('removes a participant (204) and drops them from the active list', async () => {
      const add = await request(app)
        .post(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken))
        .send({ userId: seekerUserId, role: 'co_tenant' });
      const participantId = add.body.id;

      // Present in the active list before removal.
      const before = await request(app)
        .get(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken));
      const beforeItems = before.body.items ?? before.body;
      expect(beforeItems.some((p: { user_id: string }) => p.user_id === seekerUserId)).toBe(true);

      const remove = await request(app)
        .delete(`/api/v1/auth/tenancies/${tenancyId}/participants/${participantId}`)
        .set(authHeaders(accessToken));
      expect(remove.status).toBe(204);

      // No longer in the active list after removal.
      const list = await request(app)
        .get(`/api/v1/auth/tenancies/${tenancyId}/participants`)
        .set(authHeaders(accessToken));
      const items = list.body.items ?? list.body;
      expect(items.some((p: { user_id: string }) => p.user_id === seekerUserId)).toBe(false);
    });
  });
});