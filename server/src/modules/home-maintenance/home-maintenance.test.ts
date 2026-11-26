// Task 13.12 — home maintenance operations integration tests.
// Exercises: accepted quotation -> job (exactly once) -> inspection (internal
// notes hidden from customer) -> lifecycle with stage skipping -> completion ->
// customer confirmation; amendment approve; staff assign/revoke; authorization;
// invalid transitions.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `hm_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Hm', lastName: 'Tester', email, password, role, termsAccepted: true,
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
  await pool.query(`DELETE FROM home_maintenance_jobs WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM role_assignments WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider() {
  const { id, token } = await registerUser('service_provider');
  created.users.push(id);
  const profileId = await createApprovedProfile(id);
  created.profiles.push(profileId);
  const offering = await request(app).post('/api/v1/provider/services').set(auth(token)).send({
    profileId, domain: 'plumbing', categoryId: 'plumbing_general', title: 'Plumbing', status: 'active',
  });
  expect(offering.status, JSON.stringify(offering.body)).toBe(201);
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

async function acceptedQuotation(customer: Session, provider: Session & { profileId: string }) {
  const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
    categoryId: 'plumbing_general',
    description: 'Kitchen sink is leaking under the cabinet',
    details: { problemType: 'leak', fixture: 'kitchen sink', urgency: 'standard', notes: 'leak under sink' },
    serviceCounty: 'Nairobi',
  });
  expect(created1.status, JSON.stringify(created1.body)).toBe(201);
  const requestId = created1.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId,
    items: [{ description: 'Fix leak', quantity: 1, unitPrice: 1500, amount: 1500 }],
    subtotalAmount: 1500, totalAmount: 1500, validUntil: future, terms: 'On completion',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  const accepted = await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  expect(accepted.status).toBe(200);
  return { requestId, quotationId };
}

describe('Task 13.12 home maintenance operations', () => {
  it('1. accepted quotation creates exactly one job (idempotent)', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);

    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(job.status, JSON.stringify(job.body)).toBe(201);
    expect(job.body.data.status).toBe('confirmed');
    expect(job.body.data.agreedPrice).toBe('1500.00');
    const jobId = job.body.data.id as string;

    const dup = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    expect(dup.status).toBe(201);
    expect(dup.body.data.id).toBe(jobId);
  });

  it('2. lifecycle with stage skipping + customer confirmation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    // Simple repair: skip inspection, go straight to in_progress.
    const start = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'in_progress' });
    expect(start.status, JSON.stringify(start.body)).toBe(200);
    expect(start.body.data.status).toBe('in_progress');

    await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'quality_check' });
    const done = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/completion`).set(auth(provider.token)).send({ notes: 'Leak fixed' });
    expect(done.status).toBe(200);
    expect(done.body.data.status).toBe('completed_pending_confirmation');

    // Customer cannot be skipped; provider cannot reopen after completion.
    const confirm = await request(app).post(`/api/v1/home-maintenance/jobs/${jobId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
    expect(confirm.status).toBe(200);
    expect(confirm.body.data.status).toBe('completed');

    const reopen = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'in_progress' });
    expect(reopen.status).toBe(409);
  });

  it('3. inspection internal notes are hidden from the customer', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const insp = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/inspections`).set(auth(provider.token)).send({
      findings: 'Corroded pipe', diagnosis: 'Replace section', customerVisibleReport: 'Pipe needs replacement',
      internalNotes: 'SECRET internal margin note', complete: true,
    });
    expect(insp.status, JSON.stringify(insp.body)).toBe(200);

    const providerView = await request(app).get(`/api/v1/home-maintenance/provider/jobs/${jobId}`).set(auth(provider.token));
    expect(providerView.body.data.inspections[0].internalNotes).toContain('SECRET');

    const customerView = await request(app).get(`/api/v1/home-maintenance/jobs/${jobId}`).set(auth(customer.token));
    expect(customerView.status).toBe(200);
    expect(customerView.body.data.inspections[0].internalNotes).toBeNull();
    expect(customerView.body.data.inspections[0].customerVisibleReport).toBe('Pipe needs replacement');
  });

  it('4. amendment proposed by provider + approved by customer', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const amend = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/amendments`).set(auth(provider.token)).send({ reason: 'Additional corroded section', additionalCost: 800 });
    expect(amend.status, JSON.stringify(amend.body)).toBe(201);
    const amendmentId = amend.body.data.amendments[amend.body.data.amendments.length - 1].id as string;

    const decide = await request(app).post(`/api/v1/home-maintenance/jobs/${jobId}/amendments/${amendmentId}/decide`).set(auth(customer.token)).send({ decision: 'approve' });
    expect(decide.status).toBe(200);
    expect(decide.body.data.amendments.find((a: { id: string }) => a.id === amendmentId).status).toBe('approved');
  });

  it('5. staff assignment + revocation removes access', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const staff = await newProvider();
    const assign = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/staff`).set(auth(provider.token)).send({ userId: staff.id, label: 'Technician' });
    expect(assign.status, JSON.stringify(assign.body)).toBe(200);

    const staffView = await request(app).get(`/api/v1/home-maintenance/provider/jobs/${jobId}`).set(auth(staff.token));
    expect(staffView.status).toBe(200);

    const revoke = await request(app).delete(`/api/v1/home-maintenance/provider/jobs/${jobId}/staff/${staff.id}`).set(auth(provider.token));
    expect(revoke.status).toBe(200);
    const after = await request(app).get(`/api/v1/home-maintenance/provider/jobs/${jobId}`).set(auth(staff.token));
    expect(after.status).toBe(403);
  });

  it('6. authorization + invalid transition', async () => {
    const customer = await newCustomer();
    const other = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const job = await request(app).post('/api/v1/home-maintenance/provider/jobs').set(auth(provider.token)).send({ quotationId });
    const jobId = job.body.data.id as string;

    const forbidden = await request(app).get(`/api/v1/home-maintenance/jobs/${jobId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    const otherProvider = await newProvider();
    const pForbidden = await request(app).get(`/api/v1/home-maintenance/provider/jobs/${jobId}`).set(auth(otherProvider.token));
    expect(pForbidden.status).toBe(403);

    // Invalid: confirmed -> completed (must go through completion flow).
    const bad = await request(app).post(`/api/v1/home-maintenance/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to: 'completed' });
    expect(bad.status).toBe(409);
  });
});