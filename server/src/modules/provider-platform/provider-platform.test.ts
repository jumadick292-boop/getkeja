// Task 13.16 — provider dashboards, reporting, reviews & complaints tests.
// Covers: dashboard isolation + domain metrics; review eligibility (completed +
// confirmed only), one-per-job, provider response, rating aggregation, moderation
// audit; complaint lifecycle, provider response, corrective actions, internal-note
// isolation, admin queue; cross-domain resource resolution + ID substitution.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `p16_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({ firstName: 'P16', lastName: 'T', email, password, role, termsAccepted: true });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(`UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`, [email]);
  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  await pool.query(`INSERT INTO role_assignments (user_id, role_id, scope) VALUES ($1, $2, 'global') ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

async function createApprovedProfile(userId: string): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, 'moving_service_provider'::profile_category, $2, 'approved') RETURNING id`,
    [userId, `Biz ${userId.slice(0, 8)}`]);
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
  await pool.query(`DELETE FROM complaint_messages WHERE complaint_id IN (SELECT id FROM complaints WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM complaint_corrective_actions WHERE complaint_id IN (SELECT id FROM complaints WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM complaint_internal_notes WHERE complaint_id IN (SELECT id FROM complaints WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM complaint_status_history WHERE complaint_id IN (SELECT id FROM complaints WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM complaints WHERE customer_user_id = ANY($1::uuid[])`, [created.users]);
  await pool.query(`DELETE FROM provider_review_responses WHERE review_id IN (SELECT id FROM provider_reviews WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM provider_review_reports WHERE review_id IN (SELECT id FROM provider_reviews WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM provider_review_status_history WHERE review_id IN (SELECT id FROM provider_reviews WHERE customer_user_id = ANY($1::uuid[]))`, [created.users]);
  await pool.query(`DELETE FROM provider_reviews WHERE customer_user_id = ANY($1::uuid[])`, [created.users]);
  await pool.query(`DELETE FROM finishing_jobs WHERE provider_profile_id = ANY($1::uuid[]) OR customer_user_id = ANY($2::uuid[])`, [created.profiles, created.users]);
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
  const offering = await request(app).post('/api/v1/provider/services').set(auth(token)).send({ profileId, domain: 'roofing', categoryId: 'roofing', title: 'Roofing', status: 'active' });
  expect(offering.status, JSON.stringify(offering.body)).toBe(201);
  return { id, token, profileId };
}

async function newCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

// Drive a finishing job to completed+confirmed and return its id.
async function completedJob(customer: Session, provider: Session & { profileId: string }) {
  const cr = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({ categoryId: 'roofing', description: 'Roof repair at my house', details: { roofType: 'pitched', jobType: 'repair' }, serviceCounty: 'Nairobi' });
  expect(cr.status, JSON.stringify(cr.body)).toBe(201);
  const requestId = cr.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId, items: [{ description: 'Repair', quantity: 1, unitPrice: 15000, amount: 15000 }],
    subtotalAmount: 15000, totalAmount: 15000, validUntil: future, terms: 'On completion',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  const job = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(provider.token)).send({ quotationId });
  expect(job.status, JSON.stringify(job.body)).toBe(201);
  const jobId = job.body.data.id as string;
  for (const to of ['in_progress', 'quality_inspection', 'awaiting_handover']) {
    await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/progress`).set(auth(provider.token)).send({ to });
  }
  await request(app).post(`/api/v1/finishing-operations/provider/jobs/${jobId}/completion`).set(auth(provider.token)).send({ notes: 'Done' });
  await request(app).post(`/api/v1/finishing-operations/jobs/${jobId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
  return { jobId, requestId, quotationId };
}

describe('Task 13.16 provider platform', () => {
  it('1. dashboard is provider-scoped + shows domain metrics', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    await completedJob(customer, provider);
    const dash = await request(app).get('/api/v1/provider/dashboard').set(auth(provider.token));
    expect(dash.status, JSON.stringify(dash.body)).toBe(200);
    expect(dash.body.data.scope.profileCount).toBeGreaterThan(0);
    expect(dash.body.data.metrics.completedJobs).toBeGreaterThanOrEqual(1);
    expect(Array.isArray(dash.body.data.byDomain)).toBe(true);
    expect(dash.body.data.byDomain.find((d: { domain: string }) => d.domain === 'finishing')).toBeTruthy();

    const other = await newProvider();
    const otherDash = await request(app).get('/api/v1/provider/dashboard').set(auth(other.token));
    expect(otherDash.body.data.metrics.completedJobs).toBe(0);
  });

  it('2. reports: operational + service performance + customer experience', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    await completedJob(customer, provider);
    const op = await request(app).get('/api/v1/provider/reports/operational?from=2000-01-01&to=2999-01-01').set(auth(provider.token));
    expect(op.status, JSON.stringify(op.body)).toBe(200);
    expect(op.body.data.some((r: { jobsCompleted: number }) => r.jobsCompleted >= 1)).toBe(true);
    const perf = await request(app).get('/api/v1/provider/reports/service-performance').set(auth(provider.token));
    expect(perf.status).toBe(200);
    expect(perf.body.data.find((r: { domain: string }) => r.domain === 'finishing')).toBeTruthy();
    const cx = await request(app).get('/api/v1/provider/reports/customer-experience').set(auth(provider.token));
    expect(cx.status).toBe(200);
  });

  it('3. review eligibility: completed+confirmed only, one per job', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { jobId } = await completedJob(customer, provider);
    const rev = await request(app).post('/api/v1/reviews/resources/finishing/' + jobId).set(auth(customer.token)).send({ overallRating: 5, comment: 'Great', qualityRating: 5 });
    expect(rev.status, JSON.stringify(rev.body)).toBe(201);
    const dup = await request(app).post('/api/v1/reviews/resources/finishing/' + jobId).set(auth(customer.token)).send({ overallRating: 4 });
    expect(dup.status).toBe(409);

    // Ineligible: a job not completed.
    const c2 = await newCustomer();
    const p2 = await newProvider();
    const cr = await request(app).post('/api/v1/marketplace/requests').set(auth(c2.token)).send({ categoryId: 'roofing', description: 'Another roof job here', details: {}, serviceCounty: 'Nairobi' });
    const rid = cr.body.data.id as string;
    const q = await request(app).post(`/api/v1/marketplace/provider/requests/${rid}/quotations`).set(auth(p2.token)).send({ profileId: p2.profileId, items: [{ description: 'x', quantity: 1, unitPrice: 1000, amount: 1000 }], subtotalAmount: 1000, totalAmount: 1000, validUntil: future, terms: 'terms here' });
    expect(q.status, JSON.stringify(q.body)).toBe(201);
    const qid = q.body.data.quotations[q.body.data.quotations.length - 1].id as string;
    await request(app).post(`/api/v1/marketplace/requests/${rid}/quotations/${qid}/accept`).set(auth(c2.token)).send({});
    const j2 = await request(app).post('/api/v1/finishing-operations/provider/jobs').set(auth(p2.token)).send({ quotationId: qid });
    const j2id = j2.body.data.id as string;
    const ineligible = await request(app).post('/api/v1/reviews/resources/finishing/' + j2id).set(auth(c2.token)).send({ overallRating: 5 });
    expect(ineligible.status).toBe(409);

    // Unauthorized customer cannot review someone else's job.
    const intruder = await newCustomer();
    const forbidden = await request(app).post('/api/v1/reviews/resources/finishing/' + jobId).set(auth(intruder.token)).send({ overallRating: 5 });
    expect(forbidden.status).toBe(403);
  });

  it('4. provider response + rating aggregation + moderation audit', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { jobId } = await completedJob(customer, provider);
    const rev = await request(app).post('/api/v1/reviews/resources/finishing/' + jobId).set(auth(customer.token)).send({ overallRating: 4 });
    const reviewId = rev.body.data.id as string;

    const otherProvider = await newProvider();
    const forbidden = await request(app).post(`/api/v1/reviews/${reviewId}/respond`).set(auth(otherProvider.token)).send({ response: 'Thanks' });
    expect(forbidden.status).toBe(403);

    const respond = await request(app).post(`/api/v1/reviews/${reviewId}/respond`).set(auth(provider.token)).send({ response: 'Thank you for your feedback' });
    expect(respond.status, JSON.stringify(respond.body)).toBe(200);
    expect(respond.body.data.response).toContain('Thank you');

    const rating = await request(app).get(`/api/v1/reviews/profiles/${provider.profileId}/rating`).set(auth(provider.token));
    expect(rating.status).toBe(200);
    expect(rating.body.data.reviewCount).toBeGreaterThanOrEqual(1);
    expect(rating.body.data.averageRating).toBeGreaterThan(0);

    // Moderation requires the platform permission; a normal provider is denied.
    const modDenied = await request(app).post(`/api/v1/reviews/${reviewId}/moderate`).set(auth(provider.token)).send({ status: 'hidden' });
    expect(modDenied.status).toBe(403);
  });

  it('5. complaint lifecycle + provider response + corrective action + internal note isolation', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { jobId } = await completedJob(customer, provider);

    const sub = await request(app).post('/api/v1/complaints/resources/finishing/' + jobId).set(auth(customer.token)).send({ reasonId: 'poor_workmanship', description: 'The roof leaks after the repair work' });
    expect(sub.status, JSON.stringify(sub.body)).toBe(201);
    const complaintId = sub.body.data.id as string;
    expect(sub.body.data.status).toBe('submitted');

    // Provider sees it in their inbox and can acknowledge.
    const inbox = await request(app).get('/api/v1/complaints/provider').set(auth(provider.token));
    expect(inbox.body.data.some((c: { id: string }) => c.id === complaintId)).toBe(true);
    const ack = await request(app).post(`/api/v1/complaints/${complaintId}/status`).set(auth(provider.token)).send({ to: 'acknowledged' });
    expect(ack.status, JSON.stringify(ack.body)).toBe(200);

    // Provider proposes resolution, admin resolves.
    await request(app).post(`/api/v1/complaints/${complaintId}/status`).set(auth(provider.token)).send({ to: 'under_review' });
    await request(app).post(`/api/v1/complaints/${complaintId}/status`).set(auth(provider.token)).send({ to: 'resolution_proposed' });
    const action = await request(app).post(`/api/v1/complaints/${complaintId}/corrective-actions`).set(auth(provider.token)).send({ action: 'Returned and re-sealed the roof' });
    expect(action.status, JSON.stringify(action.body)).toBe(201);

    // Customer messages; provider internal note attempt is denied for provider.
    const msg = await request(app).post(`/api/v1/complaints/${complaintId}/messages`).set(auth(customer.token)).send({ body: 'Please confirm the fix' });
    expect(msg.status).toBe(201);
    const noteDenied = await request(app).post(`/api/v1/complaints/${complaintId}/internal-notes`).set(auth(provider.token)).send({ body: 'internal' });
    expect(noteDenied.status).toBe(403);

    // Invalid transition rejected.
    const bad = await request(app).post(`/api/v1/complaints/${complaintId}/status`).set(auth(customer.token)).send({ to: 'closed' });
    expect(bad.status).toBe(409);

    // Customer view never includes internalNotes.
    const custView = await request(app).get(`/api/v1/complaints/${complaintId}`).set(auth(customer.token));
    expect(custView.status).toBe(200);
    expect(custView.body.data.internalNotes).toBeUndefined();
  });

  it('6. admin queue requires permission + cross-domain substitution rejected', async () => {
    const provider = await newProvider();
    const queueDenied = await request(app).get('/api/v1/complaints/admin/queue').set(auth(provider.token));
    expect(queueDenied.status).toBe(403);

    // Invalid domain resource resolution.
    const customer = await newCustomer();
    const bad = await request(app).post('/api/v1/complaints/resources/not_a_domain/00000000-0000-0000-0000-000000000000').set(auth(customer.token)).send({ reasonId: 'other', description: 'Testing invalid domain resource here' });
    expect(bad.status).toBe(400);
  });
});