// Task 13.9 — shared scheduling integration tests.
// Exercises: create schedule for a laundry order (exactly once), overlap
// conflict, reschedule request/approval (original preserved until approval),
// staff assign/revoke, unified provider + customer calendar, and domain
// eligibility (cancelled resource cannot be scheduled).
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
const base = Date.now() + 5 * 24 * 60 * 60 * 1000;
const startA = new Date(base).toISOString();
const endA = new Date(base + 60 * 60 * 1000).toISOString();
const startB = new Date(base + 30 * 60 * 1000).toISOString(); // overlaps A
const endB = new Date(base + 90 * 60 * 1000).toISOString();
const startC = new Date(base + 3 * 24 * 60 * 60 * 1000).toISOString();
const endC = new Date(base + 3 * 24 * 60 * 60 * 1000 + 60 * 60 * 1000).toISOString();

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `sc_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({ firstName: 'Sc', lastName: 'Tester', email, password, role, termsAccepted: true });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(`UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`, [email]);
  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

async function createApprovedProfile(userId: string): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, 'laundry_service_provider'::profile_category, $2, 'approved') RETURNING id`,
    [userId, `Biz ${userId}`],
  );
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
  await pool.query(`DELETE FROM scheduling_activities WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  await pool.query(`DELETE FROM laundry_orders WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider() {
  const { id, token } = await registerUser('laundry_provider');
  created.users.push(id);
  const profileId = await createApprovedProfile(id);
  created.profiles.push(profileId);
  await request(app).post('/api/v1/provider/services').set(auth(token)).send({ profileId, domain: 'laundry', categoryId: 'laundry_wash_fold', title: 'Wash', status: 'active' });
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

async function laundryOrder(customer: Session, provider: Session & { profileId: string }): Promise<string> {
  const req = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({ categoryId: 'laundry_wash_fold', description: 'Wash and fold', details: { notes: 'weekly' }, serviceCounty: 'Nairobi' });
  const requestId = req.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId, items: [{ description: 'Wash', quantity: 5, unitPrice: 200, amount: 1000 }], subtotalAmount: 1000, totalAmount: 1000, validUntil: future, terms: 'Per order',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId, collectionDate: startA.slice(0, 10) });
  return order.body.data.id as string;
}

describe('Task 13.9 unified scheduling', () => {
  it('1. create schedule exactly once; duplicate prevented', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const orderId = await laundryOrder(customer, provider);

    const res = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({
      domain: 'laundry', resourceId: orderId, startAt: startA, endAt: endA, timeZone: 'Africa/Nairobi', reminderMinutesBefore: 60,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body.data.status).toBe('confirmed');
    const activityId = res.body.data.id as string;

    const dup = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderId, startAt: startC, endAt: endC });
    expect(dup.status).toBe(409);
    expect(activityId).toBeTruthy();
  });

  it('2. overlapping staff assignment rejected by DB exclusion', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const orderA = await laundryOrder(customer, provider);
    const orderB = await laundryOrder(customer, provider);
    const staff = await newCustomer(); // any user id

    const a = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderA, startAt: startA, endAt: endA, staffUserId: staff.id });
    expect(a.status, JSON.stringify(a.body)).toBe(201);

    const b = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderB, startAt: startB, endAt: endB, staffUserId: staff.id });
    expect(b.status).toBe(409);
  });

  it('3. reschedule preserves original until approval', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const orderId = await laundryOrder(customer, provider);
    const created1 = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderId, startAt: startA, endAt: endA });
    const activityId = created1.body.data.id as string;

    const req = await request(app).post(`/api/v1/scheduling/activities/${activityId}/reschedule`).set(auth(customer.token)).send({ requestedStartAt: startC, requestedEndAt: endC, reason: 'Work trip' });
    expect(req.status).toBe(201);
    const requestId = req.body.data.id as string;

    // Original schedule unchanged before approval.
    const before = await request(app).get(`/api/v1/scheduling/activities/${activityId}`).set(auth(customer.token));
    expect(before.body.data.startAt).toBe(startA);

    // Concurrent second request rejected.
    const second = await request(app).post(`/api/v1/scheduling/activities/${activityId}/reschedule`).set(auth(customer.token)).send({ requestedStartAt: startC, requestedEndAt: endC });
    expect(second.status).toBe(409);

    // Provider approves.
    const decide = await request(app).post(`/api/v1/scheduling/activities/${activityId}/reschedule/${requestId}/decide`).set(auth(provider.token)).send({ accept: true });
    expect(decide.status).toBe(200);
    expect(decide.body.data.startAt).toBe(startC);
  });

  it('4. staff assign + revoke + calendar visibility', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const orderId = await laundryOrder(customer, provider);
    const created1 = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderId, startAt: startA, endAt: endA });
    const activityId = created1.body.data.id as string;
    const staff = await newCustomer();

    const assign = await request(app).post(`/api/v1/scheduling/activities/${activityId}/staff`).set(auth(provider.token)).send({ userId: staff.id });
    expect(assign.status).toBe(200);
    expect(assign.body.data.assignedStaffUserId).toBe(staff.id);

    // Provider calendar includes it.
    const cal = await request(app).get('/api/v1/scheduling/provider/calendar').set(auth(provider.token)).query({ from: startA, to: endC });
    expect(cal.status).toBe(200);
    expect(cal.body.data.some((a: { id: string }) => a.id === activityId)).toBe(true);

    // Customer calendar includes it.
    const ccal = await request(app).get('/api/v1/scheduling/customer/calendar').set(auth(customer.token)).query({ from: startA, to: endC });
    expect(ccal.body.data.some((a: { id: string }) => a.id === activityId)).toBe(true);

    // Revoke -> staff loses access to detail.
    const revoke = await request(app).delete(`/api/v1/scheduling/activities/${activityId}/staff/${staff.id}`).set(auth(provider.token));
    expect(revoke.status).toBe(200);
    const staffDetail = await request(app).get(`/api/v1/scheduling/activities/${activityId}`).set(auth(staff.token));
    expect(staffDetail.status).toBe(403);
  });

  it('5. cancelled resource cannot be scheduled', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const orderId = await laundryOrder(customer, provider);
    await request(app).post(`/api/v1/laundry/orders/${orderId}/cancel`).set(auth(customer.token)).send({ reason: 'Changed plans' });

    const res = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({ domain: 'laundry', resourceId: orderId, startAt: startC, endAt: endC });
    expect(res.status).toBe(409);
  });
});