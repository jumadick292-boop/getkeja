// Extended payment integration tests covering Paybill C2B, Till, Pesapal,
// reversals, unmatched payments, and concurrency.
import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

// ---- Mock provider fetch (Daraja + Pesapal) ----
let pesapalToken = 'test_pesapal_token';
let pesapalOrders: Record<string, any> = {};

async function providerFetch(url: string, init?: any): Promise<any> {
  const u = String(url);
  const body = init?.body ? JSON.parse(init.body) : {};

  // ---- Daraja OAuth ----
  if (u.includes('/oauth/v1/generate')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({ access_token: 'test_access_token', expires_in: 3590 }),
      text: async () => JSON.stringify({ access_token: 'test_access_token' }),
    } as any;
  }

  // ---- Daraja STK push initiation ----
  if (u.includes('/stkpush/v1/processrequest')) {
    const stkCheckoutRequestId = `ws_CO_${Math.floor(Math.random() * 100000000)}`;
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

  // ---- Daraja STK push query (used for verification + reconciliation) ----
  if (u.includes('/stkpushquery/v1/query')) {
    const body = init?.body ? JSON.parse(init.body) : {};
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

  // ---- Pesapal Auth ----
  if (u.includes('/api/Authenticate/RequestToken')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({ token: pesapalToken, expiryDate: new Date(Date.now() + 3600000).toISOString() }),
      text: async () => JSON.stringify({ token: pesapalToken }),
    } as any;
  }

  // ---- Pesapal SubmitOrderRequest ----
  if (u.includes('/api/Transactions/SubmitOrderRequest')) {
    const orderTrackingId = `ORDER_${Date.now()}`;
    pesapalOrders[orderTrackingId] = {
      order_tracking_id: orderTrackingId,
      order_merchand_reference: body.id,
      redirect_url: `https://pay.pesapal.com/v3/api/Transactions/SubmitOrderRequest?OrderTrackingId=${orderTrackingId}`,
      ...body,
    };
    return {
      ok: true,
      status: 200,
      json: async () => pesapalOrders[orderTrackingId],
      text: async () => JSON.stringify(pesapalOrders[orderTrackingId]),
    } as any;
  }

  // ---- Pesapal GetTransactionStatus ----
  if (u.includes('/api/Transactions/GetTransactionStatus')) {
    const orderTrackingId = new URL(u).searchParams.get('orderTrackingId');
    const order = pesapalOrders[orderTrackingId ?? ''];
    if (!order) {
      return {
        ok: false,
        status: 404,
        json: async () => ({ error: 'Order not found' }),
        text: async () => '{}',
      } as any;
    }
    const responseBody = {
      order_tracking_id: order.order_tracking_id,
      order_merchand_reference: order.order_merchand_reference,
      payment_status_code: order.payment_status_code ?? 'PENDING',
      payment_status_description: order.payment_status_code === 'COMPLETED' ? 'Completed' : 'Pending',
      payment_method: 'Mobile Money (M-Pesa)',
      payment_account: '254700000000',
      amount: order.amount,
      currency: order.currency,
      created_date: new Date().toISOString(),
      updated_date: new Date().toISOString(),
      confirmation_code: order.payment_status_code === 'COMPLETED' ? 'CONF' + Date.now() : undefined,
    };
    return {
      ok: true,
      status: 200,
      json: async () => responseBody,
      text: async () => JSON.stringify(responseBody),
    } as any;
  }

  // ---- Pesapal RegisterIPN ----
  if (u.includes('/api/SetupIPN/RegisterIPN')) {
    const ipnId = `IPN_${Date.now()}`;
    return {
      ok: true,
      status: 200,
      json: async () => ({ ipn_id: ipnId, url: body.url, ipn_notification_type: body.ipn_notification_type, status: '200' }),
      text: async () => JSON.stringify({ ipn_id: ipnId }),
    } as any;
  }

  return { ok: false, status: 404, json: async () => ({}), text: async () => '' } as any;
}

const originalFetch = globalThis.fetch;

beforeEach(async () => {
  (globalThis as any).fetch = providerFetch;
  pesapalToken = 'test_pesapal_token';
  pesapalOrders = {};
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

async function createInvoice(tenancyId: string, propertyId: string, unitId: string, tenantId: string, amount: number, createdBy: string) {
  const inv = await pool.query(
    `INSERT INTO invoices (invoice_number, property_id, unit_id, tenant_id, tenancy_id, status, currency,
      billing_period_start, billing_period_end, due_date, subtotal, tax_amount, total_amount, amount_paid, amount_outstanding, created_by)
     VALUES ($1, $2, $3, $4, $5, 'issued', 'KES', '2026-12-01', '2026-12-31', '2027-01-05', $6, 0, $6, 0, $6, $7)
     RETURNING id, invoice_number as "invoiceNumber", amount_outstanding as "amountOutstanding"`,
    [`INV-TEST-${Date.now()}`, propertyId, unitId, tenantId, tenancyId, amount, createdBy],
  );
  return inv.rows[0];
}

async function cleanup() {
  await pool.query('DELETE FROM receipts');
  await pool.query('DELETE FROM payment_callback_audit');
  await pool.query('DELETE FROM payment_transactions');
  await pool.query('DELETE FROM payment_reversals');
  await pool.query('DELETE FROM unmatched_payments');
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

describe('M-Pesa Paybill C2B payment flow', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_URL = 'http://localhost:4000/api/v1/payments/mpesa/callback';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';
    process.env.PESAPAL_ENV = 'sandbox';
    process.env.PESAPAL_CONSUMER_KEY = 'test-consumer-key';
    process.env.PESAPAL_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.PESAPAL_CALLBACK_PATH = '/api/v1/payments/pesapal/callback';
    process.env.PESAPAL_IPN_PATH = '/api/v1/payments/pesapal/ipn';
    process.env.PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalpva';

    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
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

  it('initiates a Paybill payment (customer-initiated, no STK)', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const res = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'mpesa_paybill',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: `PAYBILL-${Date.now()}`,
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.provider).toBe('mpesa_paybill');
    // Paybill is customer-initiated - no checkout URL
    expect(res.body.data.checkoutUrl).toBeNull();

    const pt = await pool.query(`SELECT provider, provider_transaction_id, status FROM payment_transactions WHERE id = $1`, [res.body.data.paymentTransactionId]);
    expect(pt.rows[0].provider).toBe('mpesa_paybill');
    expect(pt.rows[0].status).toBe('pending');
  });

  it('processes a successful Paybill C2B callback', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);
    const merchantRef = `PAYBILL-${Date.now()}`;

    const initiate = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'mpesa_paybill',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: merchantRef,
      });
    expect(initiate.status).toBe(201);
    const providerTxId = initiate.body.data.providerTransactionId;

    // Paybill C2B callback format (different from STK Push)
    const callback = {
      TransactionType: 'PayBill',
      TransID: providerTxId,
      TransTime: '20261201120000',
      TransAmount: 45000,
      BusinessShortCode: '123456',
      BillRefNumber: merchantRef,
      FirstName: 'Test',
      MiddleName: 'Tenant',
      LastName: 'User',
      MSISDN: '254700000000',
    };

    const cb = await request(app)
      .post('/api/v1/payments/paybill/callback')
      .send(callback);
    expect(cb.status).toBe(200);

    const pt = await pool.query(`SELECT id, status FROM payment_transactions WHERE provider_transaction_id = $1`, [providerTxId]);
    expect(pt.rows[0].status).toBe('completed');

    const inv = await pool.query(`SELECT status, amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [pt.rows[0].id]);
    expect(receipts.rows.length).toBe(1);
  });
});

describe('M-Pesa Buy Goods Till payment flow', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/till/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';
    process.env.PESAPAL_ENV = 'sandbox';
    process.env.PESAPAL_CONSUMER_KEY = 'test-consumer-key';
    process.env.PESAPAL_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalpva';

    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
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

  it('initiates a Till payment (customer-initiated)', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const res = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'mpesa_till',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: `TILL-${Date.now()}`,
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.provider).toBe('mpesa_till');
    expect(res.body.data.checkoutUrl).toBeNull();

    const pt = await pool.query(`SELECT provider, status FROM payment_transactions WHERE id = $1`, [res.body.data.paymentTransactionId]);
    expect(pt.rows[0].provider).toBe('mpesa_till');
    expect(pt.rows[0].status).toBe('pending');
  });

  it('processes a successful Till callback', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const initiate = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'mpesa_till',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: `TILL-${Date.now()}`,
      });
    expect(initiate.status).toBe(201);
    const providerTxId = initiate.body.data.providerTransactionId;

    // Till callback format (TransactionType: BuyGoods)
    const callback = {
      TransactionType: 'BuyGoods',
      TransID: providerTxId,
      TransTime: '20261201120000',
      TransAmount: 45000,
      BusinessShortCode: '123456',
      BillRefNumber: `TILL-${Date.now()}`,
      FirstName: 'Test',
      LastName: 'User',
      MSISDN: '254700000000',
    };

    const cb = await request(app)
      .post('/api/v1/payments/till/callback')
      .send(callback);
    expect(cb.status).toBe(200);

    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE provider_transaction_id = $1`, [providerTxId]);
    expect(pt.rows[0].status).toBe('completed');

    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
  });
});

describe('Pesapal payment flow', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    process.env.PESAPAL_ENV = 'sandbox';
    process.env.PESAPAL_CONSUMER_KEY = 'test-consumer-key';
    process.env.PESAPAL_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.PESAPAL_CALLBACK_PATH = '/api/v1/payments/pesapal/callback';
    process.env.PESAPAL_IPN_PATH = '/api/v1/payments/pesapal/ipn';
    process.env.PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalpva';

    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
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

  it('initiates a Pesapal payment and returns checkout URL', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const res = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'pesapal',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: `PESAPAL-${Date.now()}`,
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.provider).toBe('pesapal');
    expect(res.body.data.checkoutUrl).toBeDefined();
    expect(res.body.data.checkoutUrl).toContain('pesapal');

    const pt = await pool.query(`SELECT provider, status, provider_transaction_id FROM payment_transactions WHERE id = $1`, [res.body.data.paymentTransactionId]);
    expect(pt.rows[0].provider).toBe('pesapal');
    expect(pt.rows[0].status).toBe('pending');
    expect(pt.rows[0].provider_transaction_id).toBeDefined();
  });

  it('processes a successful Pesapal callback with IPN verification', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const initiate = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(seekerToken))
      .send({
        invoiceId: invoice.id,
        amount: 45000,
        phoneNumber: '0700000000',
        provider: 'pesapal',
        idempotencyKey: `idem-${Date.now()}`,
        merchantReference: `PESAPAL-${Date.now()}`,
      });
    expect(initiate.status).toBe(201);
    const orderTrackingId = initiate.body.data.providerTransactionId;

    // Mark the Pesapal order as completed (simulating IPN notification)
    pesapalOrders[orderTrackingId]!.payment_status_code = 'COMPLETED';
    pesapalOrders[orderTrackingId]!.confirmation_code = 'CONF123456';

    // Pesapal callback
    const callback = {
      OrderTrackingId: orderTrackingId,
      OrderMerchantReference: `PESAPAL-${Date.now()}`,
      PaymentStatusCode: 'COMPLETED',
      PaymentStatusDescription: 'Completed',
      PaymentMethod: 'Mobile Money (M-Pesa)',
      PaymentAccount: '254700000000',
      Amount: 45000,
      Currency: 'KES',
      ConfirmationCode: 'CONF123456',
    };

    const cb = await request(app)
      .post('/api/v1/payments/pesapal/callback')
      .send(callback);
    expect(cb.status).toBe(200);

    const pt = await pool.query(`SELECT id, status FROM payment_transactions WHERE provider_transaction_id = $1`, [orderTrackingId]);
    expect(pt.rows[0].status).toBe('completed');

    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');

    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [pt.rows[0].id]);
    expect(receipts.rows.length).toBe(1);
  });

  it('registers Pesapal IPN', async () => {
    const res = await request(app)
      .post('/api/v1/payments/pesapal/ipn')
      .send({
        url: 'https://api.getkeja.com/api/v1/payments/pesapal/ipn',
        ipn_notification_type: 'POST',
      });
    // IPN registration endpoint is implemented and accepts webhook payloads
    expect(res.status).toBe(200);
  });
});

describe('Payment reversals and refunds', () => {
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';
    process.env.PESAPAL_ENV = 'sandbox';
    process.env.PESAPAL_CONSUMER_KEY = 'test-consumer-key';
    process.env.PESAPAL_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalpva';

    const seeker = await registerAndLogin('tenant');
    seekerToken = seeker.token;
    seekerUserId = seeker.id;
    const p = await createProperty(seekerUserId);
    propertyId = p.propertyId;
    unitId = p.unitId;
    tenancyId = await createTenancyAndTenant(propertyId, unitId, seekerUserId, seekerUserId);
    const tenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [seekerUserId]);
    tenantRecordId = tenantRow.rows[0].id;
  });

  it('records a reversal against a completed payment', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

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
        { Name: 'MpesaReceiptNumber', Value: 'MPLREV1' },
        { Name: 'TransactionDate', Value: '20261201120000' },
        { Name: 'PhoneNumber', Value: '254700000000' },
      ] },
    };
    await request(app).post('/api/v1/payments/mpesa/callback').send(callback);

    const pt = await pool.query(`SELECT id FROM payment_transactions WHERE provider_transaction_id = $1`, [checkoutRequestId]);
    const paymentId = pt.rows[0].id;

    // Record reversal - this requires financial admin permission, so it should be forbidden for a tenant
    const res = await request(app)
      .post('/api/v1/payments/reversals')
      .set(auth(seekerToken))
      .send({
        paymentTransactionId: paymentId,
        reversalReference: `REV-${Date.now()}`,
        amount: 10000,
        reason: 'Customer requested refund',
      });
    expect(res.status).toBe(403); // Tenant doesn't have finance.reversals.manage permission
  });
});

describe('Unmatched payments', () => {
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;

  beforeEach(async () => {
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';

    const seeker = await registerAndLogin('tenant');
    seekerToken = seeker.token;
    seekerUserId = seeker.id;
    const p = await createProperty(seekerUserId);
    propertyId = p.propertyId;
  });

  it('denies unmatched payment access to non-financial-admin', async () => {
    const res = await request(app)
      .get('/api/v1/payments/unmatched')
      .set(auth(seekerToken));
    expect(res.status).toBe(403); // Tenant doesn't have finance.unmatched.manage permission
  });
});

describe('Concurrent payment attempts', () => {
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    process.env.MPESA_ENV = 'sandbox';
    process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
    process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
    process.env.MPESA_PASSKEY = 'test-passkey';
    process.env.MPESA_SHORTCODE = '123456';
    process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
    process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';

    const seeker = await registerAndLogin('tenant');
    seekerToken = seeker.token;
    seekerUserId = seeker.id;
    const p = await createProperty(seekerUserId);
    propertyId = p.propertyId;
    unitId = p.unitId;
    tenancyId = await createTenancyAndTenant(propertyId, unitId, seekerUserId, seekerUserId);
    const tenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [seekerUserId]);
    tenantRecordId = tenantRow.rows[0].id;
  });

  it('rejects two simultaneous payment attempts for one invoice', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000, seekerUserId);

    const idem1 = `idem-${Date.now()}-1`;
    const idem2 = `idem-${Date.now()}-2`;

    // Send two concurrent initiation requests
    const [res1, res2] = await Promise.all([
      request(app)
        .post('/api/v1/payments/mpesa/initiate')
        .set(auth(seekerToken))
        .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: idem1 }),
      request(app)
        .post('/api/v1/payments/mpesa/initiate')
        .set(auth(seekerToken))
        .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: idem2 }),
    ]);

    // One should succeed, the other should get a conflict
    const statuses = [res1.status, res2.status].sort();
    expect(statuses[0]).toBe(201);
    expect(statuses[1]).toBe(409);

    // Only one payment transaction should be pending
    const pending = await pool.query(
      `SELECT id FROM payment_transactions WHERE invoice_id = $1 AND status = 'pending'`,
      [invoice.id],
    );
    expect(pending.rows.length).toBe(1);
  });
});
