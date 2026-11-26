// Task 14.1 — recurring rent billing integration tests.
// Exercises: schedule creation, idempotent monthly generation, proration,
// rent-term versioning, invoice voiding, billing runs, outbox events,
// authorization (cross-property) and tenant invoice isolation.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../../app.js';
import { pool } from '../../../db/pool.js';
import * as repo from './billing.repository.js';

const app = createApp({ nodeEnv: 'test' });
const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

interface Session { id: string; token: string }

async function registerUser(role: string): Promise<Session> {
  const email = `bl_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Bl', lastName: 'Tester', email, password, role, termsAccepted: true,
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

const created = { users: [] as string[], properties: [] as string[], schedules: [] as string[] };

afterAll(async () => {
  for (const sid of created.schedules) {
    await pool.query(`DELETE FROM billing_runs WHERE billing_schedule_id = $1`, [sid]);
  }
  await pool.query(`DELETE FROM invoice_items WHERE invoice_id IN (SELECT id FROM invoices WHERE billing_schedule_id = ANY($1::uuid[]))`, [created.schedules]);
  await pool.query(`DELETE FROM rent_ledger_entries WHERE invoice_id IN (SELECT id FROM invoices WHERE billing_schedule_id = ANY($1::uuid[]))`, [created.schedules]);
  await pool.query(`DELETE FROM notification_outbox WHERE resource_type = 'invoice' AND resource_id::text IN (SELECT id::text FROM invoices WHERE billing_schedule_id = ANY($1::uuid[]))`, [created.schedules]);
  await pool.query(`DELETE FROM invoices WHERE billing_schedule_id = ANY($1::uuid[])`, [created.schedules]);
  await pool.query(`DELETE FROM rent_term_versions WHERE billing_schedule_id = ANY($1::uuid[])`, [created.schedules]);
  await pool.query(`DELETE FROM rental_billing_schedules WHERE id = ANY($1::uuid[])`, [created.schedules]);
  await pool.query(`DELETE FROM tenancy_participants WHERE tenancy_id IN (SELECT id FROM tenancies WHERE property_id = ANY($1::uuid[]))`, [created.properties]);
  await pool.query(`DELETE FROM tenants WHERE property_id = ANY($1::uuid[])`, [created.properties]);
  await pool.query(`DELETE FROM tenancies WHERE property_id = ANY($1::uuid[])`, [created.properties]);
  await pool.query(`DELETE FROM units WHERE property_id = ANY($1::uuid[])`, [created.properties]);
  await pool.query(`DELETE FROM property_ownerships WHERE property_id = ANY($1::uuid[])`, [created.properties]);
  await pool.query(`DELETE FROM properties WHERE id = ANY($1::uuid[])`, [created.properties]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function seedTenancy(opts: {
  landlordId: string;
  tenantUserId: string;
  startDate: string;
  rentAmount: number;
}): Promise<{ propertyId: string; unitId: string; tenancyId: string; tenantId: string }> {
  const prop = await pool.query<{ id: string }>(
    `INSERT INTO properties (title, property_type, address, city, county, created_by)
     VALUES ('Bl Test Property','apartment','1 Test Rd','Nairobi','Nairobi',$1) RETURNING id`,
    [opts.landlordId],
  );
  const propertyId = prop.rows[0]!.id;
  created.properties.push(propertyId);
  await pool.query(
    `INSERT INTO property_ownerships (property_id, user_id, owner_type, status, created_by)
     VALUES ($1,$2,'individual','active',$2)`,
    [propertyId, opts.landlordId],
  );
  const unit = await pool.query<{ id: string }>(
    `INSERT INTO units (property_id, unit_number, unit_type, rent_amount, created_by)
     VALUES ($1,'A1','1_bedroom',$2,$3) RETURNING id`,
    [propertyId, opts.rentAmount, opts.landlordId],
  );
  const unitId = unit.rows[0]!.id;
  const ten = await pool.query<{ id: string }>(
    `INSERT INTO tenancies (property_id, unit_id, status, start_date, rent_amount, rent_due_day, managed_by_user_id, created_by)
     VALUES ($1,$2,'active',$3,$4,1,$5,$5) RETURNING id`,
    [propertyId, unitId, opts.startDate, opts.rentAmount, opts.landlordId],
  );
  const tenancyId = ten.rows[0]!.id;
  const t = await pool.query<{ id: string }>(
    `INSERT INTO tenants (user_id, property_id, unit_id, tenancy_id, full_name, phone, status, created_by)
     VALUES ($1,$2,$3,$4,'Bl Tenant','0700000000','active',$5) RETURNING id`,
    [opts.tenantUserId, propertyId, unitId, tenancyId, opts.landlordId],
  );
  // Register the tenant user as an active participant so tenancy access checks pass.
  await pool.query(
    `INSERT INTO tenancy_participants (tenancy_id, user_id, role, is_primary, status, added_by)
     VALUES ($1,$2,'primary_tenant',TRUE,'active',$3)`,
    [tenancyId, opts.tenantUserId, opts.landlordId],
  );
  return { propertyId, unitId, tenancyId, tenantId: t.rows[0]!.id };
}

async function makeSchedule(userId: string, s: {
  propertyId: string; unitId: string; tenancyId: string; tenantId: string; rentAmount: number; firstBillingDate: string;
}): Promise<repo.BillingSchedule> {
  const schedule = await repo.createSchedule({
    propertyId: s.propertyId, unitId: s.unitId, tenancyId: s.tenancyId, tenantId: s.tenantId,
    leaseAgreementId: null, rentAmount: s.rentAmount, currency: 'KES', billingFrequency: 'monthly',
    billingDay: 1, firstBillingDate: s.firstBillingDate, dueDayOfMonth: null, gracePeriodDays: 0,
    status: 'active', createdBy: userId, approvedBy: userId,
  });
  created.schedules.push(schedule.id);
  return schedule;
}

describe('Task 14.1 recurring rent billing', () => {
  it('generates monthly invoices idempotently with ledger + outbox records', async () => {
    const landlord = await registerUser('landlord');
    const tenant = await registerUser('tenant');
    created.users.push(landlord.id, tenant.id);
    const seed = await seedTenancy({ landlordId: landlord.id, tenantUserId: tenant.id, startDate: '2026-01-01', rentAmount: 3100 });
    const schedule = await makeSchedule(landlord.id, { ...seed, rentAmount: 3100, firstBillingDate: '2026-01-01' });

    const now = new Date('2026-01-01T12:00:00Z');
    const first = await repo.generateDueInvoices({ now });
    expect(first.invoicesCreated).toBe(1);

    // Idempotent: a second run creates nothing new.
    const second = await repo.generateDueInvoices({ now });
    expect(second.invoicesCreated).toBe(0);

    const invoices = await repo.listInvoices({ billingScheduleId: schedule.id });
    expect(invoices).toHaveLength(1);
    const inv = invoices[0]!;
    expect(inv.source).toBe('recurring');
    expect(Number(inv.totalAmount)).toBe(3100);
    expect(inv.status).toBe('issued');

    const items = await repo.findInvoiceLineItems(inv.id);
    expect(items).toHaveLength(1);
    expect((items[0] as { chargeType: string }).chargeType).toBe('rent');

    const ledger = await pool.query(`SELECT 1 FROM rent_ledger_entries WHERE invoice_id = $1 AND entry_type = 'charge'`, [inv.id]);
    expect(ledger.rows).toHaveLength(1);
    const runs = await pool.query(`SELECT 1 FROM billing_runs WHERE billing_schedule_id = $1`, [schedule.id]);
    expect(runs.rows).toHaveLength(1);
    const outbox = await pool.query(`SELECT 1 FROM notification_outbox WHERE idempotency_key = $1`, [`invoice.issued:${inv.id}`]);
    expect(outbox.rows).toHaveLength(1);
  }, 30_000);

  it('prorates the first partial period and bills full months thereafter', async () => {
    const landlord = await registerUser('landlord');
    const tenant = await registerUser('tenant');
    created.users.push(landlord.id, tenant.id);
    const seed = await seedTenancy({ landlordId: landlord.id, tenantUserId: tenant.id, startDate: '2026-01-16', rentAmount: 3100 });
    const schedule = await makeSchedule(landlord.id, { ...seed, rentAmount: 3100, firstBillingDate: '2026-01-01' });

    await repo.generateDueInvoices({ now: new Date('2026-02-15T12:00:00Z') });
    const invoices = await repo.listInvoices({ billingScheduleId: schedule.id });
    expect(invoices).toHaveLength(2);
    const jan = invoices.find((i) => i.billingPeriodStart.startsWith('2026-01'))!;
    const feb = invoices.find((i) => i.billingPeriodStart.startsWith('2026-02'))!;
    expect(Number(jan.totalAmount)).toBe(1600); // 16/31 of 3100
    expect(Number(feb.totalAmount)).toBe(3100);
  }, 30_000);

  it('versions rent terms and applies the new rent from its effective date', async () => {
    const landlord = await registerUser('landlord');
    const tenant = await registerUser('tenant');
    created.users.push(landlord.id, tenant.id);
    const seed = await seedTenancy({ landlordId: landlord.id, tenantUserId: tenant.id, startDate: '2026-01-01', rentAmount: 3100 });
    const schedule = await makeSchedule(landlord.id, { ...seed, rentAmount: 3100, firstBillingDate: '2026-01-01' });

    await repo.generateDueInvoices({ now: new Date('2026-02-15T12:00:00Z') });
    await repo.changeRent(schedule, { rentAmount: 4000, effectiveDate: '2026-03-01', userId: landlord.id });
    await repo.generateDueInvoices({ now: new Date('2026-03-15T12:00:00Z') });

    const invoices = await repo.listInvoices({ billingScheduleId: schedule.id });
    const mar = invoices.find((i) => i.billingPeriodStart.startsWith('2026-03'))!;
    expect(Number(mar.totalAmount)).toBe(4000);
    const terms = await repo.listRentTerms(schedule.tenancyId);
    expect(terms.length).toBeGreaterThanOrEqual(2);
  }, 30_000);

  it('voids an issued invoice and blocks cross-property access', async () => {
    const landlord = await registerUser('landlord');
    const otherLandlord = await registerUser('landlord');
    const tenant = await registerUser('tenant');
    created.users.push(landlord.id, otherLandlord.id, tenant.id);
    const seed = await seedTenancy({ landlordId: landlord.id, tenantUserId: tenant.id, startDate: '2026-01-01', rentAmount: 3100 });
    const schedule = await makeSchedule(landlord.id, { ...seed, rentAmount: 3100, firstBillingDate: '2026-01-01' });
    await repo.generateDueInvoices({ now: new Date('2026-01-01T12:00:00Z') });
    const [inv] = await repo.listInvoices({ billingScheduleId: schedule.id });

    // Owner can void.
    const voided = await repo.voidInvoice(inv!.id, 'Duplicate charge', landlord.id);
    expect(voided?.status).toBe('void');

    // A different landlord cannot read the schedule.
    const forbidden = await request(app).get(`/api/v1/rms/billing/schedules/${schedule.id}`).set(auth(otherLandlord.token));
    expect(forbidden.status).toBe(403);

    // Owner can read it.
    const ok = await request(app).get(`/api/v1/rms/billing/schedules/${schedule.id}`).set(auth(landlord.token));
    expect(ok.status).toBe(200);
  }, 30_000);

  it('isolates tenant invoice history to the caller own tenancy', async () => {
    const landlord = await registerUser('landlord');
    const tenantA = await registerUser('tenant');
    const tenantB = await registerUser('tenant');
    created.users.push(landlord.id, tenantA.id, tenantB.id);
    const seed = await seedTenancy({ landlordId: landlord.id, tenantUserId: tenantA.id, startDate: '2026-01-01', rentAmount: 3100 });
    const schedule = await makeSchedule(landlord.id, { ...seed, rentAmount: 3100, firstBillingDate: '2026-01-01' });
    await repo.generateDueInvoices({ now: new Date('2026-01-01T12:00:00Z') });

    const mine = await request(app).get('/api/v1/tenant/invoices').set(auth(tenantA.token));
    expect(mine.status).toBe(200);
    expect((mine.body.data as unknown[]).length).toBeGreaterThanOrEqual(1);

    const other = await request(app).get('/api/v1/tenant/invoices').set(auth(tenantB.token));
    expect(other.status).toBe(200);
    expect((other.body.data as unknown[]).length).toBe(0);
  }, 30_000);
});