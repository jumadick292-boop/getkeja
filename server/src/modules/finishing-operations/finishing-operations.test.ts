// Task 13.15 — finishing & building services operations integration tests.
// Exercises: accepted quotation -> job (exactly once) -> inspection (internal
// notes hidden) -> plan + material + quality inspection -> lifecycle with stage
// skipping -> handover -> customer confirmation; amendment approve; material
// approve; staff assign/revoke; strict per-category validation (roofing/flooring/
// tiling/painting); authorization; invalid transitions; scheduling integration.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `fin_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Fin', lastName: 'Tester', email, password, role, termsAccepted: true,
  });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(`UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`, [email]);
  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  await pool.query(
    `INSERT INTO role_assignments (user_id, role_id, scope) VALUES ($1, $2, 'global') ON CONFLICT DO NOTHING`,
    [userId, role],
  );
  const login = await request(app).post('/api/auth/login/email').send({ email, password });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

async function createApprovedProfile(userId: string): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, 'moving_service_provider'::profile_category, $2, 'approved') RETURNING id`,
    [userId, `Biz ${userId.slice(0, 8)}`],
  );
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
  await pool.query(`DELETE FROM finishing_jobs WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM role_assignments WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider(categoryId = 'roofing', domain = 'roofing') {
  const { id, token } = await registerUser('service_provider');
  created.users.push(id);
  const profileId = await createApprovedProfile(id);
  created.profiles.push(profileId);
  const offering = await request(app).post('/api/v1/provider/services').set(auth(token)).send({
    profileId, domain, categoryId, title: 'Finishing', status: 'active',
  });
  expect(offering.status, JSON.stringify(offering.body)).toBe(201);
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

async function acceptedQuotation(customer: Session, provider: Session & { profileId: string }, categoryId = 'roofing', domain = 'roofing', details: Record<string, unknown> = {}) {
  const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
    categoryId,
    description: 'Request for finishing service at my property',
    details,
    serviceCounty: 'Nairobi',
  });
  expect(created1.status, JSON.stringify(created1.body)).toBe(201);
  const requestId = created1.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId,
    items: [{ description: 'Finishing work', quantity: 1, unitPrice: 20000, amount: 20000 }],
    subtotalAmount: 20000, totalAmount: 20000, validUntil: future, terms: 'On completion',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  const accepted = await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  expect(accepted.status).toBe(200);
  return { requestId, quotationId };
}

describe('Task 13.15 finishing & building services operations', () => {
  it('1. accepted quotation creates exactly one job (idempotent)', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider, 'roofing', 'roofing', { roofType: 'pitched', jobType: 'repair', approximateAreaSqM: 40 });
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(job.status, JSON.stringify(job.body)).toBe(201);
    expect(job.body.data.status).toBe('confirmed');
    expect(job.body.data.agreedPrice).toBe('20000.00');
    const jobId = job.body.data.id as string;
    const dup = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(dup.status).toBe(201);
    expect(dup.body.data.id).toBe(jobId);
  });

  it('2. strict per-category validation rejects invalid details', async () => {
    const customer = await newCustomer();
    for (const [categoryId, bad] of [
      ['roofing', { unknownField: 'x', approximateAreaSqM: -3 }],
      ['flooring', { floorType: 'marble', areaSqM: -1 }],
      ['tiling', { surface: 'ceiling', areaSqM: -5 }],
      ['painting', { surface: 'roof', rooms: -2 }],
    ] as const) {
      const res = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
        categoryId,
        description: 'Request for finishing service at my property',
        details: bad,
        serviceCounty: 'Nairobi',
      });
      expect(res.status, `${categoryId} ${JSON.stringify(res.body)}`).toBe(400);
    }
  });

  it('3. lifecycle with stage skipping + handover + customer confirmation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    // Simple job: skip inspection/plan, go straight to in_progress.
    const start = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'in_progress' });
    expect(start.status, JSON.stringify(start.body)).toBe(200);
    expect(start.body.data.status).toBe('in_progress');

    await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'quality_inspection' });
    await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'awaiting_handover' });
    const done = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/completion`).set(auth(provider.token)).send({ notes: 'Painted and inspected' });
    expect(done.status).toBe(200);
    expect(done.body.data.status).toBe('completed_pending_confirmation');

    const confirm = await request(app).post(`/api/v1/finishing-operations/jobs/${jobId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
    expect(confirm.status).toBe(200);
    expect(confirm.body.data.status).toBe('completed');

    const reopen = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'in_progress' });
    expect(reopen.status).toBe(409);
  });

  it('4. inspection internal notes hidden + plan + material + quality inspection', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const insp = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/assessments`).set(auth(provider.token)).send({
      findings: 'Roof deck needs reinforcement', measurements: '40 sqm', customerVisibleReport: 'Site ready',
      internalNotes: 'SECRET internal margin', complete: true,
    });
    expect(insp.status, JSON.stringify(insp.body)).toBe(200);

    const plan = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/plans`).set(auth(provider.token)).send({
      summary: 'Replace tiles + waterproof', steps: ['Strip', 'Waterproof', 'Tile'], deliverables: 'Finished roof',
    });
    expect(plan.status).toBe(200);

    const mat = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/materials`).set(auth(provider.token)).send({
      description: 'Ceramic tile 600x600', category: 'tile', quantity: 50, finishOrSpec: 'matte grey', proposedCost: 12000,
    });
    expect(mat.status).toBe(201);
    const materialId = mat.body.data.materials[mat.body.data.materials.length - 1].id as string;

    const qi = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/inspections`).set(auth(provider.token)).send({
      name: 'Water ingress test', outcome: 'passed', details: 'No leaks after 24h',
    });
    expect(qi.status).toBe(201);

    const providerView = await request(app).get(`/api/v1/finishing-operations/provider/jobs/${jobId}`).set(auth(provider.token));
    expect(providerView.body.data.assessments[0].internalNotes).toContain('SECRET');

    const customerView = await request(app).get(`/api/v1/finishing-operations/jobs/${jobId}`).set(auth(customer.token));
    expect(customerView.status).toBe(200);
    expect(customerView.body.data.assessments[0].internalNotes).toBeNull();
    expect(customerView.body.data.assessments[0].customerVisibleReport).toBe('Site ready');
    expect(customerView.body.data.materials[0].finishOrSpec).toBe('matte grey');

    // Customer approves the proposed material.
    const approve = await request(app).post(`/api/v1/finishing-operations/jobs/${jobId}/materials/${materialId}/decide`).set(auth(customer.token)).send({ decision: 'approve' });
    expect(approve.status).toBe(200);
    expect(approve.body.data.materials.find((m: { id: string }) => m.id === materialId).approvalStatus).toBe('approved');
  });

  it('5. amendment proposed by provider + approved by customer', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const amend = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/amendments`).set(auth(provider.token)).send({ reason: 'Add extra waterproofing layer', additionalCost: 15000 });
    expect(amend.status, JSON.stringify(amend.body)).toBe(201);
    const amendmentId = amend.body.data.amendments[amend.body.data.amendments.length - 1].id as string;

    const decide = await request(app).post(`/api/v1/finishing-operations/jobs/${jobId}/amendments/${amendmentId}/decide`).set(auth(customer.token)).send({ decision: 'approve' });
    expect(decide.status).toBe(200);
    expect(decide.body.data.amendments.find((a: { id: string }) => a.id === amendmentId).status).toBe('approved');
  });

  it('6. staff assignment + revocation removes access', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const staff = await newProvider();
    const assign = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/staff`).set(auth(provider.token)).send({ userId: staff.id, label: 'Tiler' });
    expect(assign.status, JSON.stringify(assign.body)).toBe(200);

    const staffView = await request(app).get(`/api/v1/finishing-operations/provider/jobs/${jobId}`).set(auth(staff.token));
    expect(staffView.status).toBe(200);

    const revoke = await request(app).delete(`/api/v1/finishing-operations/provider/jobs/${jobId}/staff/${staff.id}`).set(auth(provider.token));
    expect(revoke.status).toBe(200);
    const after = await request(app).get(`/api/v1/finishing-operations/provider/jobs/${jobId}`).set(auth(staff.token));
    expect(after.status).toBe(403);
  });

  it('7. scheduling integration + resource isolation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const start = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
    const end = new Date(start.getTime() + 3 * 60 * 60 * 1000);
    const sched = await request(app).post('/api/v1/scheduling/activities').set(auth(provider.token)).send({
      domain: 'finishing', resourceId: jobId, startAt: start.toISOString(), endAt: end.toISOString(),
      timeZone: 'Africa/Nairobi', allDay: false,
    });
    expect(sched.status, JSON.stringify(sched.body)).toBe(201);
    expect(sched.body.data.domain).toBe('finishing');
    expect(sched.body.data.finishingJobId).toBe(jobId);
  });

  it('8. authorization + invalid transition', async () => {
    const customer = await newCustomer();
    const other = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const forbidden = await request(app).get(`/api/v1/finishing-operations/jobs/${jobId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    const otherProvider = await newProvider();
    const pForbidden = await request(app).get(`/api/v1/finishing-operations/provider/jobs/${jobId}`).set(auth(otherProvider.token));
    expect(pForbidden.status).toBe(403);

    const bad = await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'completed' });
    expect(bad.status).toBe(409);
  });
});