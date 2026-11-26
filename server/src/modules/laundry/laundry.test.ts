// Task 13.8 — laundry operations integration tests.
// Exercises: accepted quotation -> laundry order (exactly once) -> item intake +
// inspection/approval -> processing with stage skipping -> completion ->
// customer confirmation; amendment approve/reject; staff assign/revoke;
// authorization + location privacy; invalid transitions.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });
const future = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
const collectionDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `ld_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Ld', lastName: 'Tester', email, password, role, termsAccepted: true,
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

async function createApprovedProfile(userId: string, category = 'laundry_service_provider'): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, business_name, verification_status)
     VALUES ($1, $2::profile_category, $3, 'approved') RETURNING id`,
    [userId, category, `Biz ${category}`],
  );
  return r.rows[0]!.id;
}

const created = { users: [] as string[], profiles: [] as string[] };
afterAll(async () => {
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
  await request(app).post('/api/v1/provider/services').set(auth(token)).send({
    profileId, domain: 'laundry', categoryId: 'laundry_wash_fold', title: 'Wash & fold', status: 'active',
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
    categoryId: 'laundry_wash_fold',
    description: 'Weekly wash and fold for a household',
    details: { notes: 'weekly household wash' },
    serviceCounty: 'Nairobi',
  });
  expect(created1.status, JSON.stringify(created1.body)).toBe(201);
  const requestId = created1.body.data.id as string;
  const quote = await request(app).post(`/api/v1/marketplace/provider/requests/${requestId}/quotations`).set(auth(provider.token)).send({
    profileId: provider.profileId,
    items: [{ description: 'Wash & fold', quantity: 10, unitPrice: 200, amount: 2000 }],
    subtotalAmount: 2000,
    totalAmount: 2000,
    validUntil: future,
    terms: 'Per order',
  });
  expect(quote.status, JSON.stringify(quote.body)).toBe(201);
  const quotationId = quote.body.data.quotations[quote.body.data.quotations.length - 1].id as string;
  const accepted = await request(app).post(`/api/v1/marketplace/requests/${requestId}/quotations/${quotationId}/accept`).set(auth(customer.token)).send({});
  expect(accepted.status).toBe(200);
  return { requestId, quotationId };
}

describe('Task 13.8 laundry operations', () => {
  it('1. accepted quotation creates exactly one order; duplicate prevented', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);

    const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({
      quotationId,
      fulfilmentMode: 'collection',
      collection: { address: 'Home, Nairobi' },
      collectionDate,
      scope: { services: ['laundry_wash_fold'] },
      items: [{ itemCategory: 'garment', quantity: 10 }],
    });
    expect(order.status, JSON.stringify(order.body)).toBe(201);
    expect(order.body.data.status).toBe('confirmed');
    expect(order.body.data.agreedPrice).toBe('2000.00');
    expect(order.body.data.items.length).toBe(1);

    const dup = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId });
    expect(dup.status).toBe(409);
  });

  it('2. intake + inspection approval + stage skipping + completion', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId, collectionDate });
    const orderId = order.body.data.id as string;

    // Provider adds an item.
    const itemRes = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/items`).set(auth(provider.token)).send({ itemCategory: 'shirt', quantity: 3 });
    expect(itemRes.status).toBe(201);
    const itemId = itemRes.body.data.items[itemRes.body.data.items.length - 1].id as string;

    // Move to received + inspection.
    await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'received_at_facility' });
    const insp = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/inspections`).set(auth(provider.token)).send({
      itemId, result: 'discrepancy', declaredQuantity: 3, receivedQuantity: 2, description: 'One shirt missing', requiresCustomerApproval: true,
    });
    expect(insp.status).toBe(201);
    expect(insp.body.data.status).toBe('awaiting_customer_approval');
    const inspectionId = insp.body.data.inspections[insp.body.data.inspections.length - 1].id as string;

    // Cannot progress while approval pending.
    const blocked = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'processing' });
    expect(blocked.status).toBe(409);

    // Customer rejects the discrepancy (accept the loss) -> can proceed.
    const resolve = await request(app).post(`/api/v1/laundry/orders/${orderId}/inspections/${inspectionId}/resolve`).set(auth(customer.token)).send({ decision: 'approve', notes: 'OK to proceed' });
    expect(resolve.status).toBe(200);

    // Stage skipping: awaiting_customer_approval -> folding (skip washing/drying/ironing).
    const skip = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'folding' });
    expect(skip.status, JSON.stringify(skip.body)).toBe(200);
    expect(skip.body.data.status).toBe('folding');

    await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'ready_for_return' });
    const completion = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/completion`).set(auth(provider.token)).send({ notes: 'Done', outstandingIssue: false, evidenceDocumentIds: [] });
    expect(completion.status).toBe(200);
    expect(completion.body.data.status).toBe('awaiting_customer_confirmation');

    const confirm = await request(app).post(`/api/v1/laundry/orders/${orderId}/confirm-completion`).set(auth(customer.token)).send({ confirm: true });
    expect(confirm.status).toBe(200);
    expect(confirm.body.data.status).toBe('completed');

    const reopen = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'washing' });
    expect(reopen.status).toBe(409);
  });

  it('3. amendment proposal + customer decision updates price', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId, collectionDate });
    const orderId = order.body.data.id as string;

    const amend = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/amendments`).set(auth(provider.token)).send({ reason: 'Extra stain treatment', revisedScope: { notes: 'stain' }, additionalCost: 500 });
    expect(amend.status).toBe(201);
    const amendmentId = amend.body.data.amendments[amend.body.data.amendments.length - 1].id as string;

    const decide = await request(app).post(`/api/v1/laundry/orders/${orderId}/amendments/${amendmentId}/decide`).set(auth(customer.token)).send({ accept: true });
    expect(decide.status).toBe(200);
    expect(decide.body.data.agreedPrice).toBe('2500.00');
  });

  it('4. staff assignment + revocation removes access', async () => {
    const customer = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId, collectionDate });
    const orderId = order.body.data.id as string;

    // A second provider user acts as staff (no org membership required for this test path).
    const staff = await newProvider();
    const assign = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/staff`).set(auth(provider.token)).send({ userId: staff.id, label: 'Sorter' });
    expect(assign.status).toBe(200);

    // Staff can view the order.
    const staffView = await request(app).get(`/api/v1/laundry/provider/orders/${orderId}`).set(auth(staff.token));
    expect(staffView.status).toBe(200);

    // Revoke -> staff loses access.
    const revoke = await request(app).delete(`/api/v1/laundry/provider/orders/${orderId}/staff/${staff.id}`).set(auth(provider.token));
    expect(revoke.status).toBe(200);
    const afterRevoke = await request(app).get(`/api/v1/laundry/provider/orders/${orderId}`).set(auth(staff.token));
    expect(afterRevoke.status).toBe(403);
  });

  it('5. authorization + location privacy + invalid transition', async () => {
    const customer = await newCustomer();
    const other = await newCustomer();
    const provider = await newProvider();
    const { quotationId } = await acceptedQuotation(customer, provider);
    const order = await request(app).post('/api/v1/laundry/provider/orders').set(auth(provider.token)).send({ quotationId, collection: { address: 'Secret home' }, collectionDate });
    const orderId = order.body.data.id as string;

    const forbidden = await request(app).get(`/api/v1/laundry/orders/${orderId}`).set(auth(other.token));
    expect(forbidden.status).toBe(403);

    const otherProvider = await newProvider();
    const pForbidden = await request(app).get(`/api/v1/laundry/provider/orders/${orderId}`).set(auth(otherProvider.token));
    expect(pForbidden.status).toBe(403);

    const detail = await request(app).get(`/api/v1/laundry/provider/orders/${orderId}`).set(auth(provider.token));
    expect(detail.status).toBe(200);
    expect(detail.body.data.canViewLocations).toBe(true);

    // Cannot jump confirmed -> washing.
    const bad = await request(app).post(`/api/v1/laundry/provider/orders/${orderId}/progress`).set(auth(provider.token)).send({ toStatus: 'washing' });
    expect(bad.status).toBe(409);
  });
});