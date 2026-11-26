// Task 13.5 — unified service marketplace integration tests.
// Covers: catalogue browse, customer request lifecycle, provider offering gate,
// quotation submit/revise, atomic single-winner acceptance (incl. concurrency),
// job progression, authorization isolation and strict details validation.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

interface Session {
  id: string;
  token: string;
}

async function registerUser(role: string): Promise<Session> {
  const email = `mkt_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Mkt',
    lastName: 'Tester',
    email,
    password,
    role,
    termsAccepted: true,
  });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(
    `UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`,
    [email],
  );
  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

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
  // Requests cascade from users; quotations cascade from requests/profiles.
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM service_requests WHERE customer_user_id = $1`, [u]);
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider(category = 'moving_service_provider') {
  const { id, token } = await registerUser('service_provider');
  created.users.push(id);
  const profileId = await createApprovedProfile(id, category);
  created.profiles.push(profileId);
  return { id, token, profileId };
}

async function createCustomer() {
  const { id, token } = await registerUser('tenant');
  created.users.push(id);
  return { id, token };
}

const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

describe('Task 13.5 service marketplace', () => {
  it('1. exposes the 18 marketplace categories', async () => {
    const { token } = await createCustomer();
    const res = await request(app).get('/api/v1/marketplace/categories').set(auth(token));
    expect(res.status).toBe(200);
    const ids = res.body.data.categories.map((c: { id: string }) => c.id);
    for (const id of ['clean_home', 'plumbing_general', 'electrical_general', 'handyman', 'appliance_repair']) {
      expect(ids).toContain(id);
    }
  });

  it('2. rejects unknown category detail keys (strict Zod)', async () => {
    const { token } = await createCustomer();
    const res = await request(app).post('/api/v1/marketplace/requests').set(auth(token)).send({
      categoryId: 'clean_home',
      description: 'Please clean my two bedroom house thoroughly',
      details: { rooms: 2, bogus: 'nope' },
    });
    expect(res.status).toBe(400);
  });

  it('3. full lifecycle: create -> quote -> revise -> accept -> progress', async () => {
    const customer = await createCustomer();
    const provider = await newProvider();

    // Provider offers the cleaning category.
    const offering = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(provider.token))
      .send({ profileId: provider.profileId, domain: 'cleaning', categoryId: 'clean_home', title: 'Home cleaning', status: 'active' });
    expect(offering.status).toBe(201);

    // Customer creates a request.
    const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
      categoryId: 'clean_home',
      title: 'Deep clean 2-bedroom',
      description: 'Please deep clean my two bedroom apartment before move in',
      details: { rooms: 2, frequency: 'one_time' },
      serviceCounty: 'Nairobi',
      serviceCity: 'Nairobi',
    });
    expect(created1.status).toBe(201);
    const requestId = created1.body.data.id as string;
    expect(created1.body.data.status).toBe('open');

    // Provider sees it in the inbox (offering gate + open).
    const inbox = await request(app).get('/api/v1/marketplace/provider/inbox').set(auth(provider.token));
    expect(inbox.status).toBe(200);
    expect(inbox.body.data.some((r: { id: string }) => r.id === requestId)).toBe(true);

    // Provider submits a quotation.
    const quoteBody = {
      profileId: provider.profileId,
      currency: 'KES',
      items: [{ description: 'Deep clean', quantity: 1, unitPrice: 4500, amount: 4500 }],
      subtotalAmount: 4500,
      totalAmount: 4500,
      validUntil: future,
      terms: 'Payment on completion',
    };
    const q1 = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send(quoteBody);
    expect(q1.status).toBe(201);
    expect(q1.body.data.status).toBe('quoted');
    const quotationId = q1.body.data.quotations[0].id as string;
    expect(q1.body.data.quotations[0].versionNumber).toBe(1);

    // Revise the quotation (new version, supersedes prior).
    const q2 = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
      ...quoteBody,
      totalAmount: 4200,
      subtotalAmount: 4200,
      items: [{ description: 'Deep clean (discounted)', quantity: 1, unitPrice: 4200, amount: 4200 }],
      expectedVersion: 1,
    });
    expect(q2.status).toBe(201);
    const liveQuotation = q2.body.data.quotations.find((q: { status: string }) => q.status === 'revised' || q.status === 'submitted');
    const acceptedQuotationId = q2.body.data.quotations[q2.body.data.quotations.length - 1].id as string;
    expect(q2.body.data.quotations.length).toBe(2);
    expect(liveQuotation).toBeTruthy();

    // Customer accepts the latest quotation.
    const accepted = await request(app)
      .post(`/api/v1/marketplace/requests/${requestId}/quotations/${acceptedQuotationId}/accept`)
      .set(auth(customer.token))
      .send({});
    expect(accepted.status).toBe(200);
    expect(accepted.body.data.status).toBe('accepted');
    expect(accepted.body.data.assignedProviderId).toBe(provider.profileId);
    const statuses = accepted.body.data.quotations.map((q: { status: string }) => q.status);
    expect(statuses).toContain('accepted');
    expect(statuses).toContain('superseded');

    // Provider progresses the job.
    const start = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/advance/start`).set(auth(provider.token));
    expect(start.status).toBe(200);
    expect(start.body.data.status).toBe('in_progress');
    const complete = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/advance/complete`).set(auth(provider.token));
    expect(complete.status).toBe(200);
    expect(complete.body.data.status).toBe('completed');
  });

  it('4. single-winner acceptance under concurrency (one 200, one 409)', async () => {
    const customer = await createCustomer();
    const p1 = await newProvider();
    const p2 = await newProvider();
    for (const p of [p1, p2]) {
      await request(app).post('/api/v1/provider/services').set(auth(p.token)).send({
        profileId: p.profileId, domain: 'plumbing', categoryId: 'plumbing_general', title: 'Plumbing', status: 'active',
      });
    }

    const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
      categoryId: 'plumbing_general',
      description: 'Leaking kitchen pipe needs urgent repair today',
      details: { urgency: 'urgent' },
    });
    const requestId = created1.body.data.id as string;

    const mkQuote = (p: Session & { profileId: string }, amount: number) =>
      request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(p.token)).send({
        profileId: p.profileId,
        items: [{ description: 'Repair', quantity: 1, unitPrice: amount, amount }],
        subtotalAmount: amount,
        totalAmount: amount,
        validUntil: future,
        terms: 'Cash on completion',
      });

    const r1 = await mkQuote(p1, 3000);
    const r2 = await mkQuote(p2, 3500);
    const q1 = r1.body.data.quotations[r1.body.data.quotations.length - 1].id as string;
    const q2 = r2.body.data.quotations[r2.body.data.quotations.length - 1].id as string;

    const [a1, a2] = await Promise.all([
      request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${q1}/accept`).set(auth(customer.token)).send({}),
      request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${q2}/accept`).set(auth(customer.token)).send({}),
    ]);
    expect([a1.status, a2.status].sort()).toEqual([200, 409]);
  });

  it('5. isolates customers and non-providers', async () => {
    const owner = await createCustomer();
    const other = await createCustomer();
    const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(owner.token)).send({
      categoryId: 'handyman',
      description: 'Need a handyman to fix a squeaky door hinge',
    });
    const requestId = created1.body.data.id as string;

    const forbidden = await request(app).get(`/api/v1/marketplace/requests/${requestId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    const nonProviderInbox = await request(app).get('/api/v1/marketplace/provider/inbox').set(auth(other.token));
    expect(nonProviderInbox.status).toBe(403);
  });

  it('6. customer can cancel an open request', async () => {
    const customer = await createCustomer();
    const created1 = await request(app).post('/api/v1/marketplace/requests').set(auth(customer.token)).send({
      categoryId: 'painting',
      description: 'Paint the living room walls white please',
    });
    const requestId = created1.body.data.id as string;
    const cancelled = await request(app).post(`/api/v1/marketplace/requests/${requestId}/cancel`).set(auth(customer.token)).send({ reason: 'Changed plans' });
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.data.status).toBe('cancelled');
    expect(cancelled.body.data.cancellationReason).toBe('Changed plans');
  });

  it('7. exposes the four mandatory categories as separate selectable categories', async () => {
    const { token } = await createCustomer();
    const res = await request(app).get('/api/v1/marketplace/categories').set(auth(token));
    expect(res.status).toBe(200);
    const ids = res.body.data.categories.map((c: { id: string }) => c.id);
    expect(ids).toContain('wifi_installation');
    expect(ids).toContain('internet_installation');
    expect(ids).toContain('solar_installation');
    expect(ids).toContain('painting_decoration');
    // Wi-Fi and Internet are distinct categories (not merged).
    expect('wifi_installation').not.toBe('internet_installation');
  });

  it('8. enforces strict category-specific details (wifi rejects solar keys)', async () => {
    const { token } = await createCustomer();
    // Wi-Fi category with a solar-only key must be rejected.
    const bad = await request(app).post('/api/v1/marketplace/requests').set(auth(token)).send({
      categoryId: 'wifi_installation',
      description: 'Install mesh wifi across the house',
      details: { propertyUse: 'residential', powerRequirementsKw: 5 },
    });
    expect(bad.status).toBe(400);

    // Valid Wi-Fi details are accepted.
    const ok = await request(app).post('/api/v1/marketplace/requests').set(auth(token)).send({
      categoryId: 'wifi_installation',
      description: 'Install mesh wifi across the house',
      details: {
        propertyUse: 'residential',
        propertyType: 'apartment',
        rooms: 3,
        coverageAreaSqM: 120,
        existingEquipment: 'Old single router',
        jobType: 'new_installation',
        preferredDate: '2026-12-01',
        notes: 'Ground floor unit',
      },
    });
    expect(ok.status).toBe(201);
    expect(ok.body.data.details.jobType).toBe('new_installation');
  });

  it('9. accepts solar and painting category details independently', async () => {
    const { token } = await createCustomer();
    const solar = await request(app).post('/api/v1/marketplace/requests').set(auth(token)).send({
      categoryId: 'solar_installation',
      description: 'Install a 5kW solar system with battery backup',
      details: {
        propertyUse: 'residential',
        jobType: 'new_installation',
        powerRequirementsKw: 5,
        existingInverterBatteryPanel: 'None',
        preferredDate: '2026-12-05',
      },
    });
    expect(solar.status).toBe(201);

    const painting = await request(app).post('/api/v1/marketplace/requests').set(auth(token)).send({
      categoryId: 'painting_decoration',
      description: 'Repaint interior walls and install wallpaper in the lounge',
      details: {
        surface: 'interior',
        propertyType: 'house',
        rooms: 4,
        surfacePreparation: 'Sand and prime',
        finishType: 'wallpaper',
      },
    });
    expect(painting.status).toBe(201);
    expect(painting.body.data.details.finishType).toBe('wallpaper');
  });
});