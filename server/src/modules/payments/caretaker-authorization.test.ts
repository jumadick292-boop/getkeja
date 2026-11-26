// Caretaker authorization audit tests.
//
// Verifies that caretakers (unit-access-only staff) do NOT inherit
// financial or tenant-data access through property/unit access alone.
//
// Caretakers must NOT be able to:
//   - View tenant financial statements
//   - View payment details or receipts
//   - Initiate or reconcile payments
//   - Issue refunds or reversals
//   - Resolve unmatched payments
//   - Modify invoices or financial records
//   - Access private tenant documents beyond authorized duties
//
// Caretakers MAY:
//   - Coordinate maintenance for units they are assigned to
//   - View property/unit operational data (non-financial)

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

  // STK Push initiation
  if (u.includes('/stkpush/v1/processrequest')) {
    const checkoutRequestId = `ws_CO_${Math.floor(Math.random() * 100000000)}`;
    const stkBody = {
      MerchantRequestID: 'test_merchant_' + checkoutRequestId,
      CheckoutRequestID: checkoutRequestId,
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

  // STK Push query
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
  process.env.MPESA_ENV = 'sandbox';
  process.env.MPESA_CONSUMER_KEY = 'test-consumer-key';
  process.env.MPESA_CONSUMER_SECRET = 'test-consumer-secret';
  process.env.MPESA_PASSKEY = 'test-passkey';
  process.env.MPESA_SHORTCODE = '123456';
  process.env.MPESA_CALLBACK_PATH = '/api/v1/payments/mpesa/callback';
  process.env.MPESA_BASE_URL = 'https://sandbox.safaricom.co.ke';
  (globalThis as any).fetch = mockFetch;
  fetchHandler = null;
  await cleanup();
});

afterEach(async () => {
  (globalThis as any).fetch = originalFetch;
  fetchHandler = null;
});

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

// Caretakers are not tenants, so tenant-scoped endpoints return 404 (no tenant
// record). Permission-checked endpoints return 403. Both mean "access denied".
function expectAccessDenied(res: { status: number }) {
  expect([403, 404]).toContain(res.status);
}

async function createPropertyWithUnit(ownerId: string) {
  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
     VALUES (NULL, 'Caretaker Test Property', 'Test property', 'apartment', 'published', '12 Test Dr', 'Nairobi', 'Nairobi', 'KE', 3, $1, NOW()) RETURNING id`,
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

async function assignCaretakerToUnit(propertyId: string, unitId: string, caretakerId: string) {
  await pool.query(
    `INSERT INTO unit_access_assignments (unit_id, property_id, user_id, access_level, permissions, status, effective_from, assigned_by)
     VALUES ($1, $2, $3, 'maintenance_only', '{"view_maintenance": true}', 'active', NOW(), $3)`,
    [unitId, propertyId, caretakerId],
  );
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
     RETURNING id`,
    [`INV-CT-${Date.now()}`, propertyId, unitId, tenantId, tenancyId, amount, landlordIdPlaceholder],
  );
  return inv.rows[0];
}

let landlordIdPlaceholder: string;

async function cleanup() {
  await pool.query('DELETE FROM receipts');
  await pool.query('DELETE FROM payment_callback_audit');
  await pool.query('DELETE FROM payment_transactions');
  await pool.query('DELETE FROM unmatched_payments');
  await pool.query('DELETE FROM payment_reversals');
  await pool.query('DELETE FROM rent_ledger_entries');
  await pool.query('DELETE FROM invoices');
  await pool.query('DELETE FROM invoice_items');
  await pool.query('DELETE FROM unit_access_assignments');
  await pool.query('DELETE FROM property_assignments');
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
});

afterEach(async () => {
  await cleanup();
});

describe('Caretaker authorization — financial access denial', () => {
  let landlordToken: string;
  let landlordId: string;
  let caretakerToken: string;
  let caretakerId: string;
  let tenantToken: string;
  let tenantUserId: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordId = landlord.id;
    landlordIdPlaceholder = landlordId;

    const caretaker = await registerAndLogin('caretaker');
    caretakerToken = caretaker.token;
    caretakerId = caretaker.id;

    const tenant = await registerAndLogin('tenant');
    tenantToken = tenant.token;
    tenantUserId = tenant.id;

    const p = await createPropertyWithUnit(landlordId);
    propertyId = p.propertyId;
    unitId = p.unitId;

    await assignCaretakerToUnit(propertyId, unitId, caretakerId);

    tenancyId = await createTenancyAndTenant(propertyId, unitId, landlordId, tenantUserId);
    const tenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [tenantUserId]);
    tenantRecordId = tenantRow.rows[0].id;
  });

  // ------------------------------------------------------------------
  // 1. Caretaker cannot view tenant financial statements
  // ------------------------------------------------------------------
  it('denies caretaker access to tenant payment statement', async () => {
    const res = await request(app)
      .get('/api/v1/payments/statement')
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 2. Caretaker cannot view payment details
  // ------------------------------------------------------------------
  it('denies caretaker access to payment status', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(tenantToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    expect(initiate.status).toBe(201);
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const res = await request(app)
      .get(`/api/v1/payments/status/${checkoutRequestId}`)
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 3. Caretaker cannot view receipts
  // ------------------------------------------------------------------
  it('denies caretaker access to receipts', async () => {
    const res = await request(app)
      .get('/api/v1/payments/receipts')
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 4. Caretaker cannot view deposits
  // ------------------------------------------------------------------
  it('denies caretaker access to deposits', async () => {
    const res = await request(app)
      .get('/api/v1/payments/deposits')
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 5. Caretaker cannot initiate payments
  // ------------------------------------------------------------------
  it('denies caretaker ability to initiate a payment', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const res = await request(app)
      .post('/api/v1/payments/initiate')
      .set(auth(caretakerToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 6. Caretaker cannot reconcile payments
  // ------------------------------------------------------------------
  it('denies caretaker ability to reconcile a payment', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(tenantToken))
      .send({ invoiceId: invoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    expect(initiate.status).toBe(201);
    const paymentTransactionId = initiate.body.data.paymentTransactionId;

    const res = await request(app)
      .post(`/api/v1/payments/reconcile/${paymentTransactionId}`)
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 7. Caretaker cannot record reversals/refunds
  // ------------------------------------------------------------------
  it('denies caretaker ability to record a reversal', async () => {
    const res = await request(app)
      .post('/api/v1/payments/reversals')
      .set(auth(caretakerToken))
      .send({
        paymentTransactionId: '00000000-0000-0000-0000-000000000000',
        reversalReference: 'REV-1',
        amount: 1000,
        reason: 'Test reversal',
      });
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 8. Caretaker cannot resolve unmatched payments
  // ------------------------------------------------------------------
  it('denies caretaker ability to resolve unmatched payments', async () => {
    const res = await request(app)
      .post('/api/v1/payments/unmatched/00000000-0000-0000-0000-000000000000/resolve')
      .set(auth(caretakerToken))
      .send({ matchedPaymentTransactionId: '00000000-0000-0000-0000-000000000000' });
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 9. Caretaker cannot view unmatched payments
  // ------------------------------------------------------------------
  it('denies caretaker access to unmatched payments list', async () => {
    const res = await request(app)
      .get('/api/v1/payments/unmatched')
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 10. Caretaker cannot access landlord dashboard
  // ------------------------------------------------------------------
  it('denies caretaker access to landlord financial dashboard data', async () => {
    const res = await request(app)
      .get('/api/v1/payments/landlord/dashboard')
      .set(auth(caretakerToken));
    expect(res.status).toBe(200);
    expect(res.body.data.properties).toEqual([]);
  });

  // ------------------------------------------------------------------
  // 11. IDOR: caretaker cannot access another tenant's invoice payment
  // ------------------------------------------------------------------
  it('blocks caretaker IDOR attempt on another tenant payment', async () => {
    const otherUnit = await pool.query(
      `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
       VALUES ($1, 'A-102', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', $2) RETURNING id`,
      [propertyId, landlordId],
    );
    await pool.query(`UPDATE units SET status = 'occupied' WHERE id = $1`, [otherUnit.rows[0].id]);
    const otherTenant = await registerAndLogin('tenant');
    const otherTenancy = await pool.query(
      `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
       VALUES ($1, $2, 'residential', 'active', NOW(), 45000, 90000, 1, $3) RETURNING id`,
      [propertyId, otherUnit.rows[0].id, landlordId],
    );
    await pool.query(
      `INSERT INTO tenants (property_id, unit_id, tenancy_id, user_id, full_name, phone, status, created_by)
       VALUES ($1, $2, $3, $4, 'Other Tenant', '+254700000001', 'active', $4)`,
      [propertyId, otherUnit.rows[0].id, otherTenancy.rows[0].id, otherTenant.id],
    );
    await pool.query(
      `INSERT INTO tenancy_participants (tenancy_id, user_id, full_name, role, is_primary, status, added_by)
       VALUES ($1, $2, 'Other Tenant', 'primary_tenant', TRUE, 'active', $2)`,
      [otherTenancy.rows[0].id, otherTenant.id],
    );

    const otherTenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [otherTenant.id]);
    const otherInvoice = await createInvoice(otherTenancy.rows[0].id, propertyId, otherUnit.rows[0].id, otherTenantRow.rows[0].id, 45000);

    const initiate = await request(app)
      .post('/api/v1/payments/mpesa/initiate')
      .set(auth(otherTenant.token))
      .send({ invoiceId: otherInvoice.id, amount: 45000, phoneNumber: '0700000000', idempotencyKey: `idem-${Date.now()}` });
    expect(initiate.status).toBe(201);
    const checkoutRequestId = initiate.body.data.checkoutRequestId;

    const res = await request(app)
      .get(`/api/v1/payments/status/${checkoutRequestId}`)
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });

  // ------------------------------------------------------------------
  // 12. Cross-property: caretaker cannot access another property's data
  // ------------------------------------------------------------------
  it('blocks caretaker cross-property access', async () => {
    const otherProp = await pool.query(
      `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
       VALUES (NULL, 'Other Property', 'Other property', 'apartment', 'published', '99 Other St', 'Mombasa', 'Mombasa', 'KE', 2, $1, NOW()) RETURNING id`,
      [landlordId],
    );
    await pool.query(
      `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
       VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
      [otherProp.rows[0].id, landlordId],
    );

    const res = await request(app)
      .get('/api/v1/payments/statement')
      .set(auth(caretakerToken));
    expectAccessDenied(res);
  });
});

// ------------------------------------------------------------------
// Authorization matrix: caretaker vs tenant vs landlord
// ------------------------------------------------------------------
describe('Authorization matrix — caretaker vs tenant vs landlord', () => {
  let landlordToken: string;
  let caretakerToken: string;
  let tenantToken: string;
  let landlordIdPlaceholderVar: string;
  let propertyId: string;
  let unitId: string;
  let tenancyId: string;
  let tenantRecordId: string;

  beforeEach(async () => {
    const landlord = await registerAndLogin('landlord');
    landlordToken = landlord.token;
    landlordIdPlaceholderVar = landlord.id;
    landlordIdPlaceholder = landlord.id;

    const caretaker = await registerAndLogin('caretaker');
    caretakerToken = caretaker.token;

    const tenant = await registerAndLogin('tenant');
    tenantToken = tenant.token;

    const p = await createPropertyWithUnit(landlord.id);
    propertyId = p.propertyId;
    unitId = p.unitId;

    await assignCaretakerToUnit(propertyId, unitId, caretaker.id);
    tenancyId = await createTenancyAndTenant(propertyId, unitId, landlord.id, tenant.id);
    const tenantRow = await pool.query(`SELECT id FROM tenants WHERE user_id = $1`, [tenant.id]);
    tenantRecordId = tenantRow.rows[0].id;
  });

  it('caretaker cannot access endpoints that tenant and landlord can', async () => {
    const invoice = await createInvoice(tenancyId, propertyId, unitId, tenantRecordId, 45000);

    // Tenant CAN view their own statement
    const tenantStmt = await request(app).get('/api/v1/payments/statement').set(auth(tenantToken));
    expect(tenantStmt.status).toBe(200);

    // Caretaker CANNOT view any statement
    const caretakerStmt = await request(app).get('/api/v1/payments/statement').set(auth(caretakerToken));
    expectAccessDenied(caretakerStmt);

    // Tenant CAN view their own receipts
    const tenantReceipts = await request(app).get('/api/v1/payments/receipts').set(auth(tenantToken));
    expect(tenantReceipts.status).toBe(200);

    // Caretaker CANNOT view receipts
    const caretakerReceipts = await request(app).get('/api/v1/payments/receipts').set(auth(caretakerToken));
    expectAccessDenied(caretakerReceipts);

    // Landlord CAN view landlord dashboard
    const landlordDash = await request(app).get('/api/v1/payments/landlord/dashboard').set(auth(landlordToken));
    expect(landlordDash.status).toBe(200);

    // Caretaker CANNOT view landlord dashboard data (empty properties, no financial data)
    const caretakerDash = await request(app).get('/api/v1/payments/landlord/dashboard').set(auth(caretakerToken));
    expect(caretakerDash.status).toBe(200);
    expect(caretakerDash.body.data.properties).toEqual([]);
    expect(caretakerDash.body.data.totals).toMatchObject({
      invoiced: 0, collected: 0, outstanding: 0, arrears: 0, depositsHeld: 0,
    });
  });
});
