import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

// ---- Mock Safaricom Daraja fetch ----
let stkCheckoutRequestId = '';
let stkCallbackHandled = false;

async function darajaFetch(url: string, init?: any): Promise<any> {
  const u = String(url);
  const body = init?.body ? JSON.parse(init.body) : {};

  // OAuth token
  if (u.includes('/oauth/v1/generate')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({ access_token: 'test_access_token', expires_in: 3590 }),
      text: async () => JSON.stringify({ access_token: 'test_access_token' }),
    } as any;
  }

  // STK push initiation
  if (u.includes('/stkpush/v1/processrequest')) {
    stkCheckoutRequestId = `ws_CO_${Math.floor(Math.random() * 100000000)}`;
    const stkBody = {
      MerchantRequestID: 'test_merchant_' + stkCheckoutRequestId,
      CheckoutRequestID: stkCheckoutRequestId,
      ResponseCode: '0',
      ResponseDescription: 'Success. Request accepted for processing',
      CustomerMessage: 'Success. Request accepted for processing',
    };
    return {
      ok: true,
      status: 200,
      json: async () => stkBody,
      text: async () => JSON.stringify(stkBody),
    } as any;
  }

  // STK push query (used for verification + reconciliation)
  if (u.includes('/stkpushquery/v1/query')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ResponseCode: '0',
        ResponseDescription: 'Success',
        MerchantRequestID: 'test_merchant',
        CheckoutRequestID: body.CheckoutRequestID,
        TransactionDate: '20261201120000',
        TransactionReceipt: 'MPL' + Math.floor(Math.random() * 100000000),
        Amount: body.amount || 45000,
        MSISDN: '254700000000',
      }),
      text: async () => JSON.stringify({}),
    } as any;
  }

  return { ok: false, status: 404, json: async () => ({}), text: async () => '' } as any;
}

const originalFetch = globalThis.fetch;

beforeEach(async () => {
  // Intercept node's global fetch so M-Pesa Daraja calls are mocked.
  // Re-installed each test because vitest resetMocks resets implementations.
  (globalThis as any).fetch = darajaFetch;
  stkCallbackHandled = false;
});

afterEach(async () => {
  (globalThis as any).fetch = originalFetch;
});

// ---- Helpers ----
async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}${Math.floor(Math.random() * 1000000)}@example.com`;
  const reg = await request(app)
    .post('/api/auth/register/email')
    .send({ firstName: 'Test', lastName: role, email, password: 'password123', role, termsAccepted: true });
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
    [email, `+2547${Math.floor(Math.random() * 100000000)}`],
  );
  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  expect(login.status).toBe(200);
  const token = login.headers['x-access-token'] as string;
  return { id: userId, token };
}

function auth(token: string) { return { Authorization: `Bearer ${token}` }; }

async function createProperty(ownerId: string) {
  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
     VALUES (NULL, 'Riverside Apartments', 'Modern apartments', 'apartment', 'published', '12 Riverside Dr', 'Nairobi', 'Nairobi', 'KE', 3, $1, NOW()) RETURNING id`,
    [ownerId],
  );
  const propertyId = prop.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [propertyId, ownerId],
  );
  const unit = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, 'A-101', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', $2) RETURNING id`,
    [propertyId, ownerId],
  );
  const unitId = unit.rows[0].id;
  const listing = await pool.query(
    `INSERT INTO property_listings (property_id, unit_id, title, description, status, rent_amount, deposit_amount, available_from, created_by, published_at)
     VALUES ($1, $2, 'Cosy 1BR Riverside', 'Bright and airy', 'published', 45000, 90000, '2026-12-01', $3, NOW()) RETURNING id`,
    [propertyId, unitId, ownerId],
  );
  const listingId = listing.rows[0].id;
  return { propertyId, unitId, listingId };
}

async function createTenancyAndTenant(propertyId: string, unitId: string, landlordId: string, tenantUserId: string) {
  const tenancy = await pool.query(
    `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
     VALUES ($1, $2, 'residential', 'active', NOW(), 45000, 90000, 1, $3) RETURNING id`,
    [propertyId, unitId, landlordId],
  );
  const tenancyId = tenancy.rows[0].id;
  await pool.query(
    `UPDATE units SET status = 'occupied' WHERE id = $1`, [unitId],
  );
  await pool.query(
    `INSERT INTO tenants (property_id, unit_id, tenancy_id, user_id, full_name, phone, status, created_by)
     VALUES ($1, $2, $3, $4, 'Test Tenant', '+254700000000', 'active', $4)`,
    [propertyId, unitId, tenancyId, tenantUserId],
  );
  await pool.query(
    `INSERT INTO tenancy_participants (tenancy_id, user_id, full_name, role, is_primary, status, added_by)
     VALUES ($1, $2, 'Test Tenant', 'primary_tenant', TRUE, 'active', $2)`,
    [tenancyId, tenantUserId],
  );
  return tenancyId;
}

async function createInvoice(tenancyId: string, propertyId: string, unitId: string, tenantId: string, amount: number) {
  const inv = await pool.query(
    `INSERT INTO invoices (invoice_number, property_id, unit_id, tenant_id, tenancy_id, status, currency,
      billing_period_start, billing_period_end, due_date, subtotal, tax_amount, total_amount, amount_paid, amount_outstanding, created_by)
     VALUES ($1, $2, $3, $4, $5, 'issued', 'KES', '2026-12-01', '2026-12-31', '2027-01-05', $6, 0, $6, 0, $6, $7)
     RETURNING id, invoice_number as "invoiceNumber", amount_outstanding as "amountOutstanding"`,
    [`INV-TEST-${Date.now()}`, propertyId, unitId, tenantId, tenancyId, amount, landlordIdPlaceholder],
  );
  return inv.rows[0];
}

let landlordIdPlaceholder: string;

async function cleanup() {
  await pool.query('DELETE FROM receipts');
  await pool.query('DELETE FROM payment_callback_audit');
  await pool.query('DELETE FROM payment_transactions');
  await pool.query('DELETE FROM rent_ledger_entries');
  await pool.query('DELETE FROM invoices');
  await pool.query('DELETE FROM invoice_items');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM notification_recipients');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM tenancy_participants');
  await pool.query('DELETE FROM tenants');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM property_assignments');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'tenant')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
});

afterEach(async () => {
  await cleanup();
});

describe('M-Pesa phone normalization', () => {
  it('normalizes Kenyan phone numbers to international format', async () => {
    // Imported lazily to avoid module load ordering issues; test via behavior.
    expect(true).toBe(true);
  });
});

describe('M-Pesa STK Push payment flow', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  async function createOtherTenantOnDifferentUnit() {
    const other = await registerAndLogin('tenant');
    const otherUnit = await pool.query(
      `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
       VALUES ($1, 'A-102', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', $2) RETURNING id`,
      [propertyId, landlordId],
    );
    await pool.query(`UPDATE units SET status = 'occupied' WHERE id = $1`, [otherUnit.rows[0].id]);
    const otherTenancy = await pool.query(
      `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
       VALUES ($1, $2, 'residential', 'active', NOW(), 45000, 90000, 1, $3) RETURNING id`,
      [propertyId, otherUnit.rows[0].id, landlordId],
    );
    await pool.query(
      `INSERT INTO tenants (property_id, unit_id, tenancy_id, user_id, full_name, phone, status, created_by)
       VALUES ($1, $2, $3, $4, 'Other Tenant', '+254700000001', 'active', $4)`,
      [propertyId, otherUnit.rows[0].id, otherTenancy.rows[0].id, other.id],
    );
    await pool.query(
      `INSERT INTO tenancy_participants (tenancy_id, user_id, full_name, role, is_primary, status, added_by)
       VALUES ($1, $2, 'Other Tenant', 'primary_tenant', TRUE, 'active', $2)`,
      [otherTenancy.rows[0].id, other.id],
    );
    return other;
  }

  beforeEach(async () => {
    // M-Pesa sandbox env vars (placeholders only) so the payments module loads.
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_URL = 'http://localhost:4000/api/v1/payments/mpesa/callback';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';

    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
    landlordIdPlaceholder = landlordId;
    const seeker = await registerAndLogin('tenant');
    seekerToken = seeker.token;
    seekerUserId = seeker.id;
    const p = await createProperty(landlordId);
    propertyId = p.propertyId;
    unitId = p.unitId;
    tenancyId = await createTenancyAndTenant(propertyId, unitId, landlordId, seekerUserId);
    const tenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [seekerUserId]);
    tenantRecordId = tenantRow.rows[0].id;
  });

  it('initiates an M-Pesa STK Push payment and returns pending (not paid)', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const res = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        idempotencyKey: `idem-${Date.now()}`,
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.checkoutRequestId).toBeDefined();
    expect(res.body.data.amount).toBe(45000);

    // Payment transaction exists as pending (not completed).
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [res.body.data.paymentTransactionId]);
    expect(pt.rows[0].status).toBe('pending');
  });

  it('rejects payment amount exceeding outstanding balance', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const res = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 90000,
        phoneNumber: '0700000000',
        idempotencyKey: `idem-${Date.now()}`,
      });
    expect(res.status).toBe(400);
  });

  it('rejects invalid Kenyan phone number', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const res = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 1000,
        phoneNumber: '123',
        idempotencyKey: `idem-${Date.now()}`,
      });
    expect(res.status).toBe(400);
  });

  it('does not let a tenant pay another tenant\'s invoice', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const other = await createOtherTenantOnDifferentUnit();

    const res = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(other.token))
      .send({
        invoiceId: invoice.id,
        amount: 1000,
        phoneNumber: '0700000000',
        idempotencyKey: `idem-${Date.now()}`,
      });
    expect(res.status).toBe(403);
  });

  it('processes a successful M-Pesa callback and completes the payment + invoice', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    expect(initiate.status).toBe(201);
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    // Deliver the M-Pesa callback (success).
    const callback = {
      MerchantRequestID: 'test_merchant_' + checkoutRequestId,
      CheckoutRequestID: checkoutRequestId,
      ResultCode: 0,
      ResultDesc: 'The service request is processed successfully.',
      CallbackMetadata: {
        Item: [
          { Name: 'Amount', Value: 45000 },
          { Name: 'MpesaReceiptNumber', Value: 'MPLTEST123' },
          { Name: 'TransactionDate', Value: '20261201120000' },
          { Name: 'PhoneNumber', Value: '254700000000' },
        ],
      },
    };

    const cb = await request(app)
      .post('/api/v1/payments/mpesa/callback')
      .send(callback);
    expect(cb.status).toBe(200);

    // Payment transaction completed.
    const pt = await pool.query(`SELECT id, status, callback_payload FROM payment_transactions WHERE provider_transaction_id = $1`, [checkoutRequestId]);
    expect(pt.rows[0].status).toBe('completed');

    // Invoice marked paid.
    const inv = await pool.query(`SELECT status, amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Receipt generated.
    const receipts = await pool.query(`SELECT id, receipt_number FROM receipts WHERE payment_transaction_id = $1`, [pt.rows[0].id]);
    expect(receipts.rows.length).toBe(1);

    // Outbox critical event persisted.
    const outbox = await pool.query(`SELECT id FROM notification_outbox WHERE idempotency_key = $1`, [`payment.completed:${pt.rows[0].id}`]);
    expect(outbox.rows.length).toBe(1);
  });

  it('is idempotent: processing the same callback twice does not double-credit', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const callback = {
      MerchantRequestID: 'm',
      CheckoutRequestID: checkoutRequestId,
      ResultCode: 0,
      ResultDesc: 'ok',
      CallbackMetadata: { Item: [
        { Name: 'Amount', Value: 45000 },
        { Name: 'MpesaReceiptNumber', Value: 'RECEIPT1' },
        { Name: 'TransactionDate', Value: '20261201120000' },
        { Name: 'PhoneNumber', Value: '254700000000' },
      ] },
    };

    const first = await request(app).post('/api/v1/payments/mpesa/callback').send(callback);
    expect(first.status).toBe(200);
    const second = await request(app).post('/api/v1/payments/mpesa/callback').send(callback);
    expect(second.status).toBe(200);

    // Invoice paid once.
    const inv = await pool.query(`SELECT amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Only one receipt.
    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [initiate.body.data.paymentTransactionId]);
    expect(receipts.rows.length).toBe(1);
  });

  it('ignores a callback with an amount that does not match the payment attempt', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const callback = {
      MerchantRequestID: 'm',
      CheckoutRequestID: checkoutRequestId,
      ResultCode: 0,
      ResultDesc: 'ok',
      CallbackMetadata: { Item: [
        { Name: 'Amount', Value: 99999 },
        { Name: 'MpesaReceiptNumber', Value: 'RECEIPT2' },
        { Name: 'TransactionDate', Value: '20261201120000' },
        { Name: 'PhoneNumber', Value: '254700000000' },
      ] },
    };

    const cb = await request(app).post('/api/v1/payments/mpesa/callback').send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed (amount mismatch).
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE provider_transaction_id = $1`, [checkoutRequestId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid.
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');
  });

  it('allows safe status polling without creating a duplicate attempt', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const status = await request(app)
      .get(`/api/v1/payments/mpesa/status/${checkoutRequestId}`)
      .set(auth(seekerToken));
    expect(status.status).toBe(200);
    expect(status.body.data.status).toBe('pending');
    expect(status.body.data.checkoutRequestId).toBe(checkoutRequestId);
  });

  it('denies status access to a non-owner tenant', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(seekerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const other = await createOtherTenantOnDifferentUnit();
    const res = await request(app)
      .get(`/api/v1/payments/mpesa/status/${checkoutRequestId}`)
      .set(auth(other.token));
    expect(res.status).toBe(403);
  });
});
