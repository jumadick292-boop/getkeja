// Task 13.6 — moving & relocation operations integration tests.
// Exercises the full workflow: accepted quotation -> moving job -> lifecycle ->
// staff -> assessment -> reschedule -> amendment -> completion -> confirmation,
// plus authorization, location privacy, duplicate prevention and terminal jobs.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
const moveDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `mv_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Mv', lastName: 'Tester', email, password, role, termsAccepted: true,
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

async function createApprovedProfile(userId: string, category = 'moving_service_provider'): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, $2::profile_category, $3, 'approved') RETURNING id`,
    [userId, category, `Biz ${category}`],
  );
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
  // Delete moving jobs first (FK to profiles/users), then profiles, then users.
  await pool.query(
    `DELETE FROM moving_jobs WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`,
    [created.profiles, created.users],
  );
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider() {
  const { id, token } = await registerUser('moving_company');
  created.users.push(id);
  const profileId = await createApprovedProfile(id);
  created.profiles.push(profileId);
  await request(app).post('/api/v1/provider/services').set(auth(token)).send({
    profileId, domain: 'moving', categoryId: 'moving_household', title: 'Household moves', status: 'active',
  });
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

// Drive a request to an accepted quotation; returns { requestId, quotationId }.
async function acceptedQuotation(customer: Session, provider: Session & { profileId: string }) {
  const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
    categoryId: 'moving_household',
    description: 'Move a 3 bedroom house across town next month',
    details: { rooms: 3 },
    serviceCounty: 'Nairobi',
  });
  const requestId = created1.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId,
    items: [{ description: 'Household move', quantity: 1, unitPrice: 18000, amount: 18000 }],
    subtotalAmount: 18000,
    totalAmount: 18000,
    validUntil: future,
    terms: 'Payment on completion',
  });
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  const accepted = await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  expect(accepted.status).toBe(200);
  return { requestId, quotationId };
}

describe('Task 13.6 moving operations', () => {
  it('1. accepted quotation creates exactly one job; duplicate prevented', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);

    const job = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({
      quotationId,
      origin: { address: 'Origin house, Nairobi' },
      destination: { address: 'Destination house, Nairobi' },
      agreedMoveDate: moveDate,
      scope: { serviceCategories: ['moving_household'], capabilities: ['moving_packing'] },
    });
    expect(job.status).toBe(201);
    expect(job.body.data.status).toBe('confirmed');
    expect(job.body.data.agreedPrice).toBe('18000.00');

    const dup = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(dup.status).toBe(409);
  });

  it('2. full lifecycle to completion via customer confirmation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({
      quotationId,
      origin: { address: 'A' },
      destination: { address: 'B' },
      agreedMoveDate: moveDate,
      scope: { serviceCategories: ['moving_household'] },
    });
    const jobId = job.body.data.id as string;

    for (const [to, expected] of [
      ['preparation', 'preparation'],
      ['ready_for_move', 'ready_for_move'],
      ['in_progress', 'in_progress'],
      ['arrived_at_destination', 'arrived_at_destination'],
      ['unloading', 'unloading'],
    ] as const) {
      const r = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: to });
      expect(r.status, `to=${to} ${JSON.stringify(r.body)}`).toBe(200);
      expect(r.body.data.status).toBe(expected);
    }

    // Provider submits completion -> awaiting customer confirmation (NOT completed).
    const completion = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/completion`).set(auth(provider.token)).send({
      notes: 'All items moved', outstandingIssue: false, evidenceDocumentIds: [],
    });
    expect(completion.status).toBe(200);
    expect(completion.body.data.status).toBe('awaiting_customer_confirmation');

    // Customer confirms -> completed.
    const confirm = await request(app).post(`/api/v1/moving/jobs/${jobId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
    expect(confirm.status).toBe(200);
    expect(confirm.body.data.status).toBe('completed');

    // Completed job cannot be reopened.
    const reopen = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: 'in_progress' });
    expect(reopen.status).toBe(409);
  });

  it('3. assessment + reschedule + amendment flows', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({
      quotationId, origin: { address: 'A' }, destination: { address: 'B' }, agreedMoveDate: moveDate,
      scope: { serviceCategories: ['moving_household'] },
    });
    const jobId = job.body.data.id as string;

    // Assessment requested by provider, accepted + completed by customer/provider.
    const assessment = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/assessments`).set(auth(provider.token)).send({ proposedAt: future, locationAddress: 'Origin' });
    expect(assessment.status).toBe(201);
    const assessmentId = assessment.body.data.assessments[assessment.body.data.assessments.length - 1].id as string;
    const accept = await request(app).post(`/api/v1/moving/jobs/${jobId}/assessments/${assessmentId}/respond`).set(auth(customer.token)).send({ accept: true });
    expect(accept.status).toBe(200);
    const complete = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/assessments/${assessmentId}/complete`).set(auth(provider.token)).send({ outcome: 'Quote confirmed' });
    expect(complete.status).toBe(200);

    // Provider proposes reschedule; customer decides.
    const resched = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/reschedule`).set(auth(provider.token)).send({ proposedDate: moveDate, reason: 'Truck availability' });
    expect(resched.status).toBe(200);
    const changeId = resched.body.data.scheduleChanges[resched.body.data.scheduleChanges.length - 1].id as string;
    const decide = await request(app).post(`/api/v1/moving/jobs/${jobId}/schedule-changes/${changeId}/decide`).set(auth(customer.token)).send({ accept: true });
    expect(decide.status).toBe(200);

    // Provider proposes amendment; customer accepts -> price updated.
    const amend = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/amendments`).set(auth(provider.token)).send({ reason: 'Extra piano', revisedScope: { notes: 'piano added' }, additionalCost: 2000 });
    expect(amend.status).toBe(201);
    const amendmentId = amend.body.data.amendments[amend.body.data.amendments.length - 1].id as string;
    const decideAmend = await request(app).post(`/api/v1/moving/jobs/${jobId}/amendments/${amendmentId}/decide`).set(auth(customer.token)).send({ accept: true });
    expect(decideAmend.status).toBe(200);
    expect(decideAmend.body.data.agreedPrice).toBe('20000.00');
  });

  it('4. authorization + location privacy', async () => {
    const customer = await newCustomer();
    const other = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({
      quotationId, origin: { address: 'Secret origin' }, destination: { address: 'Secret dest' }, agreedMoveDate: moveDate,
      scope: { serviceCategories: ['moving_household'] },
    });
    const jobId = job.body.data.id as string;

    // Other customer cannot view.
    const forbidden = await request(app).get(`/api/v1/moving/jobs/${jobId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    // Unrelated provider cannot view.
    const otherProvider = await newProvider();
    const pForbidden = await request(app).get(`/api/v1/moving/provider/jobs/${jobId}`).set(auth(otherProvider.token));
    expect(pForbidden.status).toBe(403);

    // Assigned provider can view sensitive locations.
    const detail = await request(app).get(`/api/v1/moving/provider/jobs/${jobId}`).set(auth(provider.token));
    expect(detail.status).toBe(200);
    expect(detail.body.data.canViewLocations).toBe(true);
  });

  it('5. invalid transition rejected', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/moving/provider/jobs').set(auth(provider.token)).send({ quotationId, origin: { address: 'A' }, destination: { address: 'B' }, agreedMoveDate: moveDate, scope: { serviceCategories: ['moving_household'] } });
    const jobId = job.body.data.id as string;
    // Cannot jump confirmed -> in_progress.
    const bad = await request(app).post(`/api/v1/moving/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ toStatus: 'in_progress' });
    expect(bad.status).toBe(409);
  });
});