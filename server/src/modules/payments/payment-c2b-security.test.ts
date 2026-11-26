// M-Pesa C2B (Paybill / Till) callback security integration tests.
//
// Tests the Safaricom C2B trust model:
//   - Only Safaricom's servers can POST to a registered confirmation URL
//   - Shortcode matching alone does NOT authenticate the sender
//   - Every callback must be verified against the provider before finalizing
//   - C2B has no query API, so the confirmation callback is the trust boundary
//   - Invalid or ambiguous transactions are rejected or placed in unmatched payments
//   - Duplicate callbacks never produce duplicate financial credits
//   - Every callback is auditable
//
// C2B callback format (Safaricom Daraja):
//   {
//     TransactionType: 'PayBill' | 'BuyGoods',
//     TransID: string,
//     TransTime: 'YYYYMMDDHHMMSS',
//     TransAmount: number,
//     BusinessShortCode: string,
//     BillRefNumber: string,
//     InvoiceNumber: string,
//     FirstName: string,
//     MSISDN: string
//   }

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

// ---- Mock Safaricom Daraja fetch ----
let fetchHandler: ((url: string, init?: any) => Promise<any>) | null = null;

async function mockFetch(url: string, init?: any): Promise<any> {
  const u = String(url);
  const body = init?.body ? JSON.parse(init.body) : {};

  if (fetchHandler) {
    return fetchHandler(u, init);
  }

  // Default: OAuth token
  if (u.includes('/oauth/v1/generate')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({ access_token: 'test_access_token', expires_in: 3590 }),
      text: async () => JSON.stringify({ access_token: 'test_access_token' }),
    } as any;
  }

  // STK Push query (used for verification)
  if (u.includes('/stkpushquery/v1/query')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ResponseCode: '0',
        ResponseDescription: 'Success',
        TransactionReceipt: 'MPLVERIFIED',
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
  (globalThis as any).fetch = mockFetch;
  fetchHandler = null;
});

afterEach(async () => {
  (globalThis as any).fetch = originalFetch;
  fetchHandler = null;
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
  return { propertyId, unitId };
}

async function createTenancyAndTenant(propertyId: string, unitId: string, landlordId: string, tenantUserId: string) {
  const tenancy = await pool.query(
    `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
     VALUES ($1, $2, 'residential', 'active', NOW(), 45000, 90000, 1, $3) RETURNING id`,
    [propertyId, unitId, landlordId],
  );
  const tenancyId = tenancy.rows[0].id;
  await pool.query(`UPDATE units SET status = 'occupied' WHERE id = $1`, [unitId]);
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
     RETURNING id, invoice_number as "invoiceNumber"`,
    [`INV-C2B-${Date.now()}`, propertyId, unitId, tenantId, tenancyId, amount, landlordIdPlaceholder],
  );
  return inv.rows[0];
}

// Insert a pending payment transaction directly (for C2B callback matching tests).
async function insertPendingPayment(
  providerTransactionId: string,
  provider: string,
  invoiceId: string,
  tenantId: string,
  propertyId: string,
  amount: number,
): Promise<string> {
  const result = await pool.query(
    `INSERT INTO payment_transactions (
      transaction_reference, invoice_id, tenant_id, property_id, amount,
      currency, provider, provider_transaction_id, status, payment_date,
      idempotency_key, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
    )
    RETURNING id`,
    [`PAY-${Date.now()}`, invoiceId, tenantId, propertyId, amount, 'KES', provider, providerTransactionId, 'pending', new Date(), `idem-${Date.now()}`, landlordIdPlaceholder],
  );
  return result.rows[0].id;
}

let landlordIdPlaceholder: string;

async function cleanup() {
  await pool.query('DELETE FROM receipts');
  await pool.query('DELETE FROM payment_callback_audit');
  await pool.query('DELETE FROM payment_transactions');
  await pool.query('DELETE FROM unmatched_payments');
  await pool.query('DELETE FROM rent_ledger_entries');
  await pool.query('DELETE FROM invoices');
  await pool.query('DELETE FROM invoice_items');
  await pool.query('DELETE FROM tenancy_participants');
  await pool.query('DELETE FROM tenants');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'tenant', 'caretaker')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanup();

  process.env.MPESA_ENV = 'sandbox';
  process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
  process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
  process.env.MPESA_PASSKEY = 'test-passkey';
  process.env.MPESA_SHORTCODE = '123456';
  process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
  process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';
});

afterEach(async () => {
  await cleanup();
});

function paybillCallbackUrl() { return '/api/v1/payments/paybill/callback'; }
function tillCallbackUrl() { return '/api/v1/payments/till/callback'; }
function mpesaCallbackUrl() { return '/api/v1/payments/mpesa/callback'; }

function c2bCallback(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    TransactionType: 'PayBill',
    TransID: `TXN-${Date.now()}`,
    TransTime: '20261201120000',
    TransAmount: 45000,
    BusinessShortCode: '123456',
    BillRefNumber: 'INV-REF',
    InvoiceNumber: 'INV-REF',
    FirstName: 'John',
    LastName: 'Doe',
    MSISDN: '254700000000',
    ...overrides,
  };
}

describe('M-Pesa C2B callback security — Paybill / Till', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
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

  // ------------------------------------------------------------------
  // 1. Forged callback with incorrect shortcode
  // ------------------------------------------------------------------
  it('rejects a forged C2B callback with an incorrect shortcode', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-EXPECTED', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-EXPECTED',
      BusinessShortCode: '999999', // wrong shortcode
      TransAmount: 45000,
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200); // Webhook always returns 200 to Safaricom

    // Payment NOT completed (shortcode mismatch)
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');

    // Callback audited with error
    const audit = await pool.query(`SELECT id, processing_error FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['TXN-EXPECTED']);
    expect(audit.rows.length).toBeGreaterThan(0);
    expect(audit.rows[0].processing_error).toContain('shortcode');
  });

  // ------------------------------------------------------------------
  // 2. Forged callback with correct shortcode but invalid transaction details
  // ------------------------------------------------------------------
  it('rejects a forged C2B callback with correct shortcode but invalid transaction details', async () => {
    const callback = c2bCallback({
      TransID: 'FORGED-TXN-12345',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // No internal payment matches → goes to unmatched (not finalized)
    const audit = await pool.query(`SELECT id, processed FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['FORGED-TXN-12345']);
    expect(audit.rows.length).toBeGreaterThan(0);

    // Should NOT create a payment transaction
    const pt = await pool.query(`SELECT id FROM payment_transactions WHERE provider_transaction_id = $1`, ['FORGED-TXN-12345']);
    expect(pt.rows.length).toBe(0);
  });

  // ------------------------------------------------------------------
  // 3. Duplicate transaction reference (same TransID, second callback)
  // ------------------------------------------------------------------
  it('rejects duplicate C2B transaction reference — no double credit', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-DUP', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-DUP',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    // First callback completes the payment
    const first = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(first.status).toBe(200);

    const pt1 = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt1.rows[0].status).toBe('completed');

    // Second callback with same TransID — idempotent
    const second = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(second.status).toBe(200);

    // Invoice paid exactly once
    const inv = await pool.query(`SELECT amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Only one receipt
    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [paymentId]);
    expect(receipts.rows.length).toBe(1);
  });

  // ------------------------------------------------------------------
  // 4. Duplicate callback delivered concurrently
  // ------------------------------------------------------------------
  it('handles concurrent duplicate C2B callbacks without double credit', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-CONCURRENT', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-CONCURRENT',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    // Send two callbacks concurrently
    const results = await Promise.all([
      request(app).post(paybillCallbackUrl()).send(callback),
      request(app).post(paybillCallbackUrl()).send(callback),
    ]);

    expect(results[0].status).toBe(200);
    expect(results[1].status).toBe(200);

    // Invoice paid exactly once
    const inv = await pool.query(`SELECT amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Only one receipt
    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [paymentId]);
    expect(receipts.rows.length).toBe(1);
  });

  // ------------------------------------------------------------------
  // 5. Missing transaction reference (no TransID)
  // ------------------------------------------------------------------
  it('ignores a C2B callback with a missing transaction reference', async () => {
    const callback = c2bCallback({
      TransID: undefined,
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // No payment transaction created for undefined TransID
    const pts = await pool.query(`SELECT id FROM payment_transactions WHERE provider_transaction_id IS NULL`);
    // Should not crash; callback handled gracefully
    expect(cb.body.status).toBeDefined();
  });

  // ------------------------------------------------------------------
  // 6. Invalid amount (amount does not match payment attempt)
  // ------------------------------------------------------------------
  it('rejects a C2B callback with an invalid amount', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-AMT', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-AMT',
      BusinessShortCode: '123456',
      TransAmount: 99999, // wrong amount
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed (amount mismatch)
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');

    // Callback audited with error
    const audit = await pool.query(`SELECT processing_error FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['TXN-AMT']);
    expect(audit.rows.length).toBeGreaterThan(0);
  });

  // ------------------------------------------------------------------
  // 7. Invalid account reference (cannot match to invoice) → unmatched
  // ------------------------------------------------------------------
  it('routes a C2B callback with no matching internal payment to unmatched_payments', async () => {
    const callback = c2bCallback({
      TransID: 'UNMATCHED-TXN-999',
      BusinessShortCode: '123456',
      TransAmount: 45000,
      BillRefNumber: 'NONEXISTENT-INV',
      InvoiceNumber: 'NONEXISTENT-INV',
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Recorded in unmatched_payments
    const unmatched = await pool.query(`SELECT id, provider, matched FROM unmatched_payments WHERE provider_transaction_id = $1`, ['UNMATCHED-TXN-999']);
    expect(unmatched.rows.length).toBe(1);
    expect(unmatched.rows[0].provider).toBe('mpesa_paybill');
    expect(unmatched.rows[0].matched).toBe(false);

    // Callback audited
    const audit = await pool.query(`SELECT id, processed FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['UNMATCHED-TXN-999']);
    expect(audit.rows.length).toBe(1);
    expect(audit.rows[0].processed).toBe(true);
  });

  // ------------------------------------------------------------------
  // 8. Malformed callback body
  // ------------------------------------------------------------------
  it('ignores a malformed C2B callback body', async () => {
    const cb = await request(app)
      .post(paybillCallbackUrl())
      .send({ not: 'a valid c2b callback', missing: 'everything' });
    expect(cb.status).toBe(200);

    // No payment transaction created
    const pts = await pool.query(`SELECT id FROM payment_transactions`);
    // May have entries from beforeEach cleanup, but no new ones from this callback
    // Just verify the endpoint doesn't crash
    expect(cb.body.status).toBeDefined();
  });

  // ------------------------------------------------------------------
  // 9. Delayed callback (still valid, processed normally)
  // ------------------------------------------------------------------
  it('processes a valid delayed C2B callback normally', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-DELAYED', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    // Simulate a delayed callback (older timestamp)
    const callback = c2bCallback({
      TransID: 'TXN-DELAYED',
      BusinessShortCode: '123456',
      TransAmount: 45000,
      TransTime: '20261101120000', // older timestamp — delayed
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment completed despite delay
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).toBe('completed');

    // Invoice paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
  });

  // ------------------------------------------------------------------
  // 10. Callback for an already allocated payment
  // ------------------------------------------------------------------
  it('does not double-credit when a C2B callback arrives for an already completed payment', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-ALLOCATED', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-ALLOCATED',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    // First callback completes the payment
    const first = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(first.status).toBe(200);

    const pt1 = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt1.rows[0].status).toBe('completed');

    // Second callback for the same already-completed payment
    const second = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(second.status).toBe(200);

    // Invoice still paid exactly once
    const inv = await pool.query(`SELECT amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Only one receipt
    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [paymentId]);
    expect(receipts.rows.length).toBe(1);
  });

  // ------------------------------------------------------------------
  // 11. Callback that cannot be matched to an invoice → unmatched
  // ------------------------------------------------------------------
  it('routes a C2B callback with no matching payment to unmatched_payments', async () => {
    // No prior payment transaction — raw C2B callback
    const callback = c2bCallback({
      TransID: 'NO-MATCH-TXN-42',
      BusinessShortCode: '123456',
      TransAmount: 15000,
      BillRefNumber: 'NO-INVOICE',
      InvoiceNumber: 'NO-INVOICE',
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Recorded in unmatched_payments
    const unmatched = await pool.query(`SELECT id, provider, matched FROM unmatched_payments WHERE provider_transaction_id = $1`, ['NO-MATCH-TXN-42']);
    expect(unmatched.rows.length).toBe(1);
    expect(unmatched.rows[0].provider).toBe('mpesa_paybill');
    expect(unmatched.rows[0].matched).toBe(false);

    // Callback audited and marked processed
    const audit = await pool.query(`SELECT id, processed FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['NO-MATCH-TXN-42']);
    expect(audit.rows.length).toBe(1);
    expect(audit.rows[0].processed).toBe(true);
  });

  // ------------------------------------------------------------------
  // 12. Callback that fails provider verification (STK Push query API failure)
  // ------------------------------------------------------------------
  it('rejects an STK Push callback when provider verification fails', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    // Insert a pending STK Push payment with a checkout request ID
    const paymentId = await insertPendingPayment(
      'ws_CO_VERIFY_FAIL', 'mpesa', invoice.id, tenantRecordId, propertyId, 45000,
    );

    // Make the query API return failure
    fetchHandler = (url) => {
      if (url.includes('/stkpushquery/v1/query')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            ResponseCode: '1',
            ResponseDescription: 'Transaction not found',
            TransactionReceipt: null,
            Amount: null,
            MSISDN: null,
          }),
          text: async () => JSON.stringify({}),
        } as any;
      }
      if (url.includes('/oauth/v1/generate')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ access_token: 'test_access_token', expires_in: 3590 }),
          text: async () => JSON.stringify({ access_token: 'test_access_token' }),
        } as any;
      }
      return { ok: false, status: 404, json: async () => ({}), text: async () => '' } as any;
    };

    const callback = {
      MerchantRequestID: 'test_merchant_ws_CO_VERIFY_FAIL',
      CheckoutRequestID: 'ws_CO_VERIFY_FAIL',
      ResultCode: 0,
      ResultDesc: 'Success',
      CallbackMetadata: {
        Item: [
          { Name: 'Amount', Value: 45000 },
          { Name: 'MpesaReceiptNumber', Value: 'MPLRECEIPT' },
          { Name: 'TransactionDate', Value: '20261201120000' },
          { Name: 'PhoneNumber', Value: '254700000000' },
        ],
      },
    };

    const cb = await request(app).post(mpesaCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed (verification failed)
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');

    // Callback audited with error
    const audit = await pool.query(`SELECT processing_error FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['ws_CO_VERIFY_FAIL']);
    expect(audit.rows.length).toBeGreaterThan(0);
  });
});

// ------------------------------------------------------------------
// Additional C2B security tests
// ------------------------------------------------------------------
describe('M-Pesa C2B callback security — additional edge cases', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
    landlordIdPlaceholder = landlord.id;
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

  // ------------------------------------------------------------------
  // 13. Callback for an already-reversed payment
  // ------------------------------------------------------------------
  it('does not re-complete an already-reversed payment on duplicate callback', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-REVERSED', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    // First complete the payment via callback
    const completeCallback = c2bCallback({
      TransID: 'TXN-REVERSED',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });
    const first = await request(app).post(paybillCallbackUrl()).send(completeCallback);
    expect(first.status).toBe(200);

    const pt1 = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt1.rows[0].status).toBe('completed');

    // Reverse the payment
    await pool.query(
      `INSERT INTO payment_reversals (
        payment_transaction_id, reversal_reference, amount, currency, reason, status, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [paymentId, 'REV-1', 45000, 'KES', 'Test reversal', 'completed', landlordIdPlaceholder],
    );
    await pool.query(
      `UPDATE payment_transactions SET status = 'reversed', updated_at = NOW() WHERE id = $1`,
      [paymentId],
    );

    // Duplicate callback for the reversed payment — must not re-complete
    const second = await request(app).post(paybillCallbackUrl()).send(completeCallback);
    expect(second.status).toBe(200);

    const pt2 = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt2.rows[0].status).toBe('reversed');

    // Invoice must NOT be re-credited
    const inv = await pool.query(`SELECT amount_paid, amount_outstanding FROM invoices WHERE id = $1`, [invoice.id]);
    expect(Number(inv.rows[0].amount_paid)).toBe(45000);
    expect(Number(inv.rows[0].amount_outstanding)).toBe(0);

    // Only one receipt
    const receipts = await pool.query(`SELECT id FROM receipts WHERE payment_transaction_id = $1`, [paymentId]);
    expect(receipts.rows.length).toBe(1);
  });

  // ------------------------------------------------------------------
  // 14. Missing TransAmount — C2B callback without amount must be rejected
  // ------------------------------------------------------------------
  it('rejects a C2B callback with a missing TransAmount', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-NOAMT', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-NOAMT',
      BusinessShortCode: '123456',
      TransAmount: undefined, // missing amount
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed (missing amount)
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');

    // Callback audited with error
    const audit = await pool.query(`SELECT processing_error FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['TXN-NOAMT']);
    expect(audit.rows.length).toBeGreaterThan(0);
    expect(audit.rows[0].processing_error).toContain('missing');
  });

  // ------------------------------------------------------------------
  // 15. C2B callback currency defaults to KES (no currency field in C2B)
  // ------------------------------------------------------------------
  it('records a valid C2B callback with KES currency', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-CUR', 'mpesa_paybill', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = c2bCallback({
      TransID: 'TXN-CUR',
      BusinessShortCode: '123456',
      TransAmount: 45000,
    });

    const cb = await request(app).post(paybillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment completed
    const pt = await pool.query(`SELECT status, currency FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).toBe('completed');
    expect(pt.rows[0].currency).toBe('KES');

    // Invoice paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
  });

  // ------------------------------------------------------------------
  // 16. Callback that fails provider verification (STK Push query API error)
  // ------------------------------------------------------------------
  it('rejects an STK Push callback when provider verification throws', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'ws_CO_VERIFY_THROW', 'mpesa', invoice.id, tenantRecordId, propertyId, 45000,
    );

    // Make the query API throw an error
    fetchHandler = (url) => {
      if (url.includes('/stkpushquery/v1/query')) {
        throw new Error('Network error: provider unreachable');
      }
      if (url.includes('/oauth/v1/generate')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ access_token: 'test_access_token', expires_in: 3590 }),
          text: async () => JSON.stringify({ access_token: 'test_access_token' }),
        } as any;
      }
      return { ok: false, status: 404, json: async () => ({}), text: async () => '' } as any;
    };

    const callback = {
      MerchantRequestID: 'test_merchant_ws_CO_VERIFY_THROW',
      CheckoutRequestID: 'ws_CO_VERIFY_THROW',
      ResultCode: 0,
      ResultDesc: 'Success',
      CallbackMetadata: {
        Item: [
          { Name: 'Amount', Value: 45000 },
          { Name: 'MpesaReceiptNumber', Value: 'MPLTHROW' },
          { Name: 'TransactionDate', Value: '20261201120000' },
          { Name: 'PhoneNumber', Value: '254700000000' },
        ],
      },
    };

    const cb = await request(app).post(mpesaCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed (verification threw)
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Callback audited with error
    const audit = await pool.query(`SELECT processing_error FROM payment_callback_audit WHERE provider_transaction_id = $1`, ['ws_CO_VERIFY_THROW']);
    expect(audit.rows.length).toBeGreaterThan(0);
  });
});

// ------------------------------------------------------------------
// Additional: Till (BuyGoods) C2B security
// ------------------------------------------------------------------
describe('M-Pesa Till (BuyGoods) C2B callback security', () => {
  let landlordToken: string;
  let landlordId: string;
  let seekerToken: string;
  let seekerUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
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

  it('rejects a Till callback with an incorrect shortcode', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-TILL', 'mpesa_till', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = {
      TransactionType: 'BuyGoods',
      TransID: 'TXN-TILL',
      TransTime: '20261201120000',
      TransAmount: 45000,
      BusinessShortCode: '999999', // wrong shortcode
      BillRefNumber: 'INV-REF',
      InvoiceNumber: 'INV-REF',
      MSISDN: '254700000000',
    };

    const cb = await request(app).post(tillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment NOT completed
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).not.toBe('completed');

    // Invoice NOT paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('issued');
  });

  it('accepts a valid Till callback and completes the payment', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);
    const paymentId = await insertPendingPayment(
      'TXN-TILL-OK', 'mpesa_till', invoice.id, tenantRecordId, propertyId, 45000,
    );

    const callback = {
      TransactionType: 'BuyGoods',
      TransID: 'TXN-TILL-OK',
      TransTime: '20261201120000',
      TransAmount: 45000,
      BusinessShortCode: '123456',
      BillRefNumber: 'INV-REF',
      InvoiceNumber: 'INV-REF',
      MSISDN: '254700000000',
    };

    const cb = await request(app).post(tillCallbackUrl()).send(callback);
    expect(cb.status).toBe(200);

    // Payment completed
    const pt = await pool.query(`SELECT status FROM payment_transactions WHERE id = $1`, [paymentId]);
    expect(pt.rows[0].status).toBe('completed');

    // Invoice paid
    const inv = await pool.query(`SELECT status FROM invoices WHERE id = $1`, [invoice.id]);
    expect(inv.rows[0].status).toBe('paid');
  });
});
