// Task 13.7 — garbage collection operations integration tests.
// Exercises: accepted quotation -> one-time job -> lifecycle -> completion ->
// customer confirmation; recurring agreement -> idempotent occurrence
// generation; authorization; location privacy; invalid transitions.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import { generateRecurringWork } from './garbage.repository.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
const today = new Date().toISOString().slice(0, 10);
const collectionDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `gb_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Gb', lastName: 'Tester', email, password, role, termsAccepted: true,
  });
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

async function createApprovedProfile(userId: string, category = 'garbage_collection_provider'): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, $2::profile_category, $3, 'approved') RETURNING id`,
    [userId, category, `Biz ${category}`],
  );
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
  await pool.query(`DELETE FROM garbage_jobs WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  await pool.query(`DELETE FROM garbage_recurring_agreements WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider() {
  const { id, token } = await registerUser('garbage_provider');
  created.users.push(id);
  const profileId = await createApprovedProfile(id);
  created.profiles.push(profileId);
  await request(app).post('/api/v1/provider/services').set(auth(token)).send({
    profileId, domain: 'garbage', categoryId: 'garbage_household', title: 'Household waste', status: 'active',
  });
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

async function acceptedQuotation(customer: Session, provider: Session & { profileId: string }) {
  const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
    categoryId: 'garbage_household',
    description: 'Weekly household garbage collection',
    details: { wasteCategory: 'general', binCount: 2 },
    serviceCounty: 'Nairobi',
  });
  expect(created1.status, JSON.stringify(created1.body)).toBe(201);
  const requestId = created1.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId,
    items: [{ description: 'Household collection', quantity: 1, unitPrice: 2500, amount: 2500 }],
    subtotalAmount: 2500,
    totalAmount: 2500,
    validUntil: future,
    terms: 'Per collection',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  const accepted = await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  expect(accepted.status).toBe(200);
  return { requestId, quotationId };
}

describe('Task 13.7 garbage operations', () => {
  it('1. accepted quotation creates exactly one job; duplicate prevented', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);

    const job = await request(app).post('/api/v1/garbage/provider/jobs').set(auth(provider.token)).send({
      quotationId,
      location: { address: 'Collection site, Nairobi' },
      scheduledDate: collectionDate,
      scope: { wasteCategory: 'general', binCount: 2 },
    });
    expect(job.status, JSON.stringify(job.body)).toBe(201);
    expect(job.body.data.status).toBe('confirmed');
    expect(job.body.data.agreedPrice).toBe('2500.00');

    const dup = await request(app).post('/api/v1/garbage/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(dup.status).toBe(409);
  });

  it('2. full lifecycle to completion via customer confirmation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/garbage/provider/jobs').set(auth(provider.token)).send({ quotationId, scheduledDate: collectionDate, scope: { wasteCategory: 'general' } });
    const jobId = job.body.data.id as string;

    for (const to of ['scheduled', 'provider_assigned', 'en_route', 'arrived', 'collecting'] as const) {
      const r = await request(app).post(`/api/v1/garbage/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: to });
      expect(r.status, `to=${to} ${JSON.stringify(r.body)}`).toBe(200);
      expect(r.body.data.status).toBe(to);
    }

    const completion = await request(app).post(`/api/v1/garbage/provider/jobs/${jobId}/completion`).set(auth(provider.token)).send({
      notes: 'Collected 2 bins', outstandingIssue: false, evidenceDocumentIds: [],
    });
    expect(completion.status).toBe(200);
    expect(completion.body.data.status).toBe('awaiting_customer_confirmation');

    const confirm = await request(app).post(`/api/v1/garbage/jobs/${jobId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
    expect(confirm.status).toBe(200);
    expect(confirm.body.data.status).toBe('completed');

    const reopen = await request(app).post(`/api/v1/garbage/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: 'collecting' });
    expect(reopen.status).toBe(409);
  });

  it('3. recurring agreement + idempotent occurrence generation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);

    const propose = await request(app).post('/api/v1/garbage/provider/agreements').set(auth(provider.token)).send({
      quotationId,
      frequency: 'weekly',
      daysOfWeek: [1],
      startDate: today,
      agreedAmount: 2500,
      wasteCategory: 'general',
    });
    expect(propose.status, JSON.stringify(propose.body)).toBe(201);
    expect(propose.body.data.status).toBe('proposed');
    const agreementId = propose.body.data.id as string;

    // Customer accepts -> active.
    const decide = await request(app).post(`/api/v1/garbage/agreements/${agreementId}/decide`).set(auth(customer.token)).send({ accept: true });
    expect(decide.status).toBe(200);
    expect(decide.body.data.status).toBe('active');

    // Generate occurrences twice — must be idempotent.
    const first = await generateRecurringWork({ lookbackDays: 7, horizonDays: 14 });
    const second = await generateRecurringWork({ lookbackDays: 7, horizonDays: 14 });
    expect(second.occurrencesCreated).toBe(0);
    expect(second.jobsCreated).toBe(0);
    expect(first.jobsCreated).toBeGreaterThanOrEqual(1);

    const occ = await request(app).get(`/api/v1/garbage/agreements/${agreementId}/occurrences`).set(auth(customer.token));
    expect(occ.status).toBe(200);
    expect(Array.isArray(occ.body.data)).toBe(true);
  });

  it('4. authorization + location privacy', async () => {
    const customer = await newCustomer();
    const other = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/garbage/provider/jobs').set(auth(provider.token)).send({ quotationId, location: { address: 'Secret site' }, scheduledDate: collectionDate });
    const jobId = job.body.data.id as string;

    const forbidden = await request(app).get(`/api/v1/garbage/jobs/${jobId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    const otherProvider = await newProvider();
    const pForbidden = await request(app).get(`/api/v1/garbage/provider/jobs/${jobId}`).set(auth(otherProvider.token));
    expect(pForbidden.status).toBe(403);

    const detail = await request(app).get(`/api/v1/garbage/provider/jobs/${jobId}`).set(auth(provider.token));
    expect(detail.status).toBe(200);
    expect(detail.body.data.canViewLocations).toBe(true);
  });

  it('5. invalid transition rejected', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/garbage/provider/jobs').set(auth(provider.token)).send({ quotationId, scheduledDate: collectionDate });
    const jobId = job.body.data.id as string;
    // Cannot jump confirmed -> collecting.
    const bad = await request(app).post(`/api/v1/garbage/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: 'collecting' });
    expect(bad.status).toBe(409);
  });
});