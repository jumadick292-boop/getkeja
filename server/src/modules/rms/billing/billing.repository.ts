// Recurring billing repository (Task 14.1).
//
// Data access + the idempotent recurring billing engine. Reuses the existing
// invoices / invoice_items / rent_ledger_entries tables (migration 078) and the
// additive billing tables (migration 131). Monetary math is delegated to
// billing.calculations (integer cents); this layer only moves strings/numbers
// across the pg boundary.
import { pool } from '../../../db/pool.js';
import { transaction } from '../../../db/tx.js';
import type { PoolClient } from 'pg';
import {
  addDays,
  centsToNumber,
  computeDueDate,
  enumeratePeriodStarts,
  nextPeriodStart,
  periodEnd,
  prorateRentCents,
  toCents,
  type BillingFrequency,
} from './billing.calculations.js';
import { enqueueOutboxEventTransactional } from '../../auth/transactional-outbox.service.js';

export type ScheduleStatus = 'pending' | 'active' | 'suspended' | 'cancelled';

export interface BillingSchedule {
  id: string;
  propertyId: string;
  unitId: string;
  tenancyId: string;
  tenantId: string;
  leaseAgreementId: string | null;
  rentAmount: string;
  currency: string;
  billingFrequency: BillingFrequency;
  billingDay: number;
  firstBillingDate: string;
  nextBillingDate: string;
  dueDayOfMonth: number | null;
  gracePeriodDays: number;
  status: ScheduleStatus;
  effectiveDate: string;
  suspendedAt: Date | null;
  cancelledAt: Date | null;
  cancellationReason: string | null;
  createdBy: string;
  approvedBy: string | null;
  approvedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface RentTermVersion {
  id: string;
  tenancyId: string;
  billingScheduleId: string | null;
  rentAmount: string;
  currency: string;
  billingFrequency: BillingFrequency;
  dueDayOfMonth: number | null;
  gracePeriodDays: number;
  effectiveDate: string;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
  supersededAt: Date | null;
}

export interface TenancyBillingContext {
  id: string;
  status: string;
  propertyId: string;
  unitId: string;
  startDate: string;
  endDate: string | null;
  managedByUserId: string | null;
  rentAmount: string;
  currency: string;
  rentDueDay: number;
}

export interface GeneratedInvoiceRow {
  id: string;
  invoiceNumber: string;
  propertyId: string;
  billingPeriodStart: string;
  billingPeriodEnd: string;
  dueDate: string;
  totalAmount: string;
  currency: string;
  status: string;
  issuedAt: Date;
  unitId: string;
  tenancyId: string;
}

const SCHEDULE_COLUMNS = `
  id, property_id AS "propertyId", unit_id AS "unitId", tenancy_id AS "tenancyId",
  tenant_id AS "tenantId", lease_agreement_id AS "leaseAgreementId",
  rent_amount AS "rentAmount", currency, billing_frequency AS "billingFrequency",
  billing_day AS "billingDay", first_billing_date::text AS "firstBillingDate",
  next_billing_date::text AS "nextBillingDate", due_day_of_month AS "dueDayOfMonth",
  grace_period_days AS "gracePeriodDays", status, effective_date::text AS "effectiveDate",
  suspended_at AS "suspendedAt", cancelled_at AS "cancelledAt",
  cancellation_reason AS "cancellationReason", created_by AS "createdBy",
  approved_by AS "approvedBy", approved_at AS "approvedAt",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

const INVOICE_COLUMNS = `
  id, invoice_number AS "invoiceNumber", property_id AS "propertyId",
  unit_id AS "unitId", tenant_id AS "tenantId", tenancy_id AS "tenancyId",
  billing_schedule_id AS "billingScheduleId", source, status, currency,
  billing_period_start::text AS "billingPeriodStart", billing_period_end::text AS "billingPeriodEnd",
  due_date::text AS "dueDate", subtotal, tax_amount AS "taxAmount",
  total_amount AS "totalAmount", amount_paid AS "amountPaid",
  amount_outstanding AS "amountOutstanding", description, notes,
  issued_at AS "issuedAt", created_by AS "createdBy",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

function nairobiToday(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Nairobi' }).format(new Date());
}

// ---- Validation lookups ----

export async function findTenancyBillingContext(tenancyId: string): Promise<TenancyBillingContext | null> {
  const r = await pool.query<TenancyBillingContext>(
    `SELECT id, status, property_id AS "propertyId", unit_id AS "unitId",
            start_date::text AS "startDate", end_date::text AS "endDate",
            managed_by_user_id AS "managedByUserId", rent_amount AS "rentAmount",
            'KES' AS currency, rent_due_day AS "rentDueDay"
       FROM tenancies WHERE id = $1`,
    [tenancyId],
  );
  return r.rows[0] ?? null;
}

export async function unitBelongsToProperty(unitId: string, propertyId: string): Promise<boolean> {
  const r = await pool.query(`SELECT 1 FROM units WHERE id = $1 AND property_id = $2`, [unitId, propertyId]);
  return r.rows.length > 0;
}

export async function tenantBelongsToTenancy(tenantId: string, tenancyId: string): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM tenants WHERE id = $1 AND tenancy_id = $2
     UNION
     SELECT 1 FROM tenancy_participants WHERE user_id = (SELECT user_id FROM tenants WHERE id = $1) AND tenancy_id = $2 AND status = 'active'`,
    [tenantId, tenancyId],
  );
  return r.rows.length > 0;
}

export async function resolveCreatedBy(tenancy: TenancyBillingContext): Promise<string | null> {
  if (tenancy.managedByUserId) return tenancy.managedByUserId;
  const owner = await pool.query<{ user_id: string }>(
    `SELECT user_id FROM property_ownerships
      WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
      ORDER BY effective_from DESC LIMIT 1`,
    [tenancy.propertyId],
  );
  return owner.rows[0]?.user_id ?? null;
}

// ---- Schedule CRUD ----

export async function createSchedule(data: {
  propertyId: string;
  unitId: string;
  tenancyId: string;
  tenantId: string;
  leaseAgreementId: string | null;
  rentAmount: number;
  currency: string;
  billingFrequency: BillingFrequency;
  billingDay: number;
  firstBillingDate: string;
  dueDayOfMonth: number | null;
  gracePeriodDays: number;
  status: ScheduleStatus;
  createdBy: string;
  approvedBy: string | null;
}): Promise<BillingSchedule> {
  return transaction(async (client) => {
    const next = nextPeriodStart(data.firstBillingDate, data.billingFrequency, data.billingDay);
    const r = await client.query<BillingSchedule>(
      `INSERT INTO rental_billing_schedules (
        property_id, unit_id, tenancy_id, tenant_id, lease_agreement_id,
        rent_amount, currency, billing_frequency, billing_day,
        first_billing_date, next_billing_date, due_day_of_month, grace_period_days,
        status, created_by, approved_by, approved_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::billing_schedule_status,$15,$16,
        CASE WHEN $14::billing_schedule_status = 'active' THEN NOW() ELSE NULL END)
      RETURNING ${SCHEDULE_COLUMNS}`,
      [
        data.propertyId, data.unitId, data.tenancyId, data.tenantId, data.leaseAgreementId,
        data.rentAmount, data.currency, data.billingFrequency, data.billingDay,
        data.firstBillingDate, next, data.dueDayOfMonth, data.gracePeriodDays,
        data.status, data.createdBy, data.approvedBy,
      ],
    );
    const schedule = r.rows[0]!;
    // Seed the initial rent term version.
    await client.query(
      `INSERT INTO rent_term_versions (
        tenancy_id, billing_schedule_id, rent_amount, currency, billing_frequency,
        due_day_of_month, grace_period_days, effective_date, created_by
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        data.tenancyId, schedule.id, data.rentAmount, data.currency, data.billingFrequency,
        data.dueDayOfMonth, data.gracePeriodDays, data.firstBillingDate, data.createdBy,
      ],
    );
    return schedule;
  });
}

export async function findScheduleById(id: string): Promise<BillingSchedule | undefined> {
  const r = await pool.query<BillingSchedule>(`SELECT ${SCHEDULE_COLUMNS} FROM rental_billing_schedules WHERE id = $1`, [id]);
  return r.rows[0];
}

export async function listSchedules(filters: {
  propertyId?: string;
  unitId?: string;
  tenantId?: string;
  tenancyId?: string;
  status?: ScheduleStatus;
  limit?: number;
  offset?: number;
}): Promise<BillingSchedule[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let i = 1;
  for (const [col, val] of [
    ['property_id', filters.propertyId],
    ['unit_id', filters.unitId],
    ['tenant_id', filters.tenantId],
    ['tenancy_id', filters.tenancyId],
    ['status', filters.status],
  ] as const) {
    if (val) {
      conditions.push(`${col} = $${i++}`);
      values.push(val);
    }
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(filters.limit ?? 20, filters.offset ?? 0);
  const r = await pool.query<BillingSchedule>(
    `SELECT ${SCHEDULE_COLUMNS} FROM rental_billing_schedules ${where}
     ORDER BY created_at DESC LIMIT $${i++} OFFSET $${i++}`,
    values,
  );
  return r.rows;
}

export async function setScheduleStatus(
  id: string,
  status: ScheduleStatus,
  opts: { userId: string; reason?: string | null },
): Promise<BillingSchedule | undefined> {
  const r = await pool.query<BillingSchedule>(
    `UPDATE rental_billing_schedules SET
        status = $2,
        suspended_at = CASE WHEN $2 = 'suspended' THEN NOW() ELSE suspended_at END,
        cancelled_at = CASE WHEN $2 = 'cancelled' THEN NOW() ELSE cancelled_at END,
        cancellation_reason = CASE WHEN $2 = 'cancelled' THEN $4 ELSE cancellation_reason END,
        approved_by = CASE WHEN $2 = 'active' THEN $3 ELSE approved_by END,
        approved_at = CASE WHEN $2 = 'active' THEN NOW() ELSE approved_at END,
        updated_by = $3
      WHERE id = $1
      RETURNING ${SCHEDULE_COLUMNS}`,
    [id, status, opts.userId, opts.reason ?? null],
  );
  return r.rows[0];
}

/** Insert a new rent term version (history preserved) and update the schedule. */
export async function changeRent(
  schedule: BillingSchedule,
  data: { rentAmount: number; currency?: string; effectiveDate: string; notes?: string | null; userId: string },
): Promise<{ schedule: BillingSchedule; term: RentTermVersion }> {
  return transaction(async (client) => {
    await client.query(
      `UPDATE rent_term_versions SET superseded_at = NOW()
        WHERE billing_schedule_id = $1 AND superseded_at IS NULL AND effective_date < $2`,
      [schedule.id, data.effectiveDate],
    );
    const termRes = await client.query<RentTermVersion>(
      `INSERT INTO rent_term_versions (
        tenancy_id, billing_schedule_id, rent_amount, currency, billing_frequency,
        due_day_of_month, grace_period_days, effective_date, notes, created_by
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      RETURNING id, tenancy_id AS "tenancyId", billing_schedule_id AS "billingScheduleId",
        rent_amount AS "rentAmount", currency, billing_frequency AS "billingFrequency",
        due_day_of_month AS "dueDayOfMonth", grace_period_days AS "gracePeriodDays",
        effective_date::text AS "effectiveDate", notes, created_by AS "createdBy",
        created_at AS "createdAt", superseded_at AS "supersededAt"`,
      [
        schedule.tenancyId, schedule.id, data.rentAmount, data.currency ?? schedule.currency,
        schedule.billingFrequency, schedule.dueDayOfMonth, schedule.gracePeriodDays,
        data.effectiveDate, data.notes ?? null, data.userId,
      ],
    );
    const schedRes = await client.query<BillingSchedule>(
      `UPDATE rental_billing_schedules SET
          rent_amount = $2, currency = $3, effective_date = $4, updated_by = $5
        WHERE id = $1 RETURNING ${SCHEDULE_COLUMNS}`,
      [schedule.id, data.rentAmount, data.currency ?? schedule.currency, data.effectiveDate, data.userId],
    );
    return { schedule: schedRes.rows[0]!, term: termRes.rows[0]! };
  });
}

export async function listRentTerms(tenancyId: string): Promise<RentTermVersion[]> {
  const r = await pool.query<RentTermVersion>(
    `SELECT id, tenancy_id AS "tenancyId", billing_schedule_id AS "billingScheduleId",
            rent_amount AS "rentAmount", currency, billing_frequency AS "billingFrequency",
            due_day_of_month AS "dueDayOfMonth", grace_period_days AS "gracePeriodDays",
            effective_date::text AS "effectiveDate", notes, created_by AS "createdBy",
            created_at AS "createdAt", superseded_at AS "supersededAt"
       FROM rent_term_versions WHERE tenancy_id = $1 ORDER BY effective_date DESC, created_at DESC`,
    [tenancyId],
  );
  return r.rows;
}

async function findApplicableRentTerm(client: PoolClient, tenancyId: string, periodStart: string): Promise<RentTermVersion | null> {
  const r = await client.query<RentTermVersion>(
    `SELECT id, tenancy_id AS "tenancyId", billing_schedule_id AS "billingScheduleId",
            rent_amount AS "rentAmount", currency, billing_frequency AS "billingFrequency",
            due_day_of_month AS "dueDayOfMonth", grace_period_days AS "gracePeriodDays",
            effective_date::text AS "effectiveDate", notes, created_by AS "createdBy",
            created_at AS "createdAt", superseded_at AS "supersededAt"
       FROM rent_term_versions
      WHERE tenancy_id = $1 AND effective_date <= $2
      ORDER BY effective_date DESC, created_at DESC LIMIT 1`,
    [tenancyId, periodStart],
  );
  return r.rows[0] ?? null;
}

// ---- Invoices ----

export async function findInvoiceById(id: string): Promise<GeneratedInvoiceRow | undefined> {
  const r = await pool.query<GeneratedInvoiceRow>(
    `SELECT ${INVOICE_COLUMNS} FROM invoices WHERE id = $1`,
    [id],
  );
  return r.rows[0];
}

export async function findInvoiceLineItems(invoiceId: string): Promise<Array<Record<string, unknown>>> {
  const r = await pool.query(
    `SELECT id, charge_type AS "chargeType", description, amount, currency,
            billing_period_start::text AS "billingPeriodStart",
            billing_period_end::text AS "billingPeriodEnd", quantity,
            unit_price AS "unitPrice", created_at AS "createdAt"
       FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at`,
    [invoiceId],
  );
  return r.rows;
}

export async function listInvoices(filters: {
  propertyId?: string;
  unitId?: string;
  tenantId?: string;
  tenancyId?: string;
  billingScheduleId?: string;
  status?: string;
  source?: string;
  fromDate?: string;
  toDate?: string;
  limit?: number;
  offset?: number;
}): Promise<GeneratedInvoiceRow[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let i = 1;
  const add = (cond: string, val: unknown) => {
    conditions.push(cond.replace('?', `$${i++}`));
    values.push(val);
  };
  if (filters.propertyId) add('property_id = ?', filters.propertyId);
  if (filters.unitId) add('unit_id = ?', filters.unitId);
  if (filters.tenantId) add('tenant_id = ?', filters.tenantId);
  if (filters.tenancyId) add('tenancy_id = ?', filters.tenancyId);
  if (filters.billingScheduleId) add('billing_schedule_id = ?', filters.billingScheduleId);
  if (filters.status) add('status = ?::invoice_status', filters.status);
  if (filters.source) add('source = ?', filters.source);
  if (filters.fromDate) add('billing_period_start >= ?', filters.fromDate);
  if (filters.toDate) add('billing_period_start <= ?', filters.toDate);
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(filters.limit ?? 20, filters.offset ?? 0);
  const r = await pool.query<GeneratedInvoiceRow>(
    `SELECT ${INVOICE_COLUMNS} FROM invoices ${where}
     ORDER BY billing_period_start DESC, created_at DESC LIMIT $${i++} OFFSET $${i++}`,
    values,
  );
  return r.rows;
}

export async function voidInvoice(id: string, reason: string, userId: string): Promise<GeneratedInvoiceRow | undefined> {
  return transaction(async (client) => {
    const r = await client.query<GeneratedInvoiceRow>(
      `UPDATE invoices SET status = 'void', notes = COALESCE(notes,'') || $2, updated_by = $3
        WHERE id = $1 AND status NOT IN ('paid','void','refunded')
        RETURNING ${INVOICE_COLUMNS}`,
      [id, `\n[VOID ${new Date().toISOString()}] ${reason}`, userId],
    );
    return r.rows[0];
  });
}

/** Flip overdue invoices (past due with outstanding > 0) to 'overdue'. */
export async function markOverdueInvoices(asOf: string): Promise<number> {
  const r = await pool.query(
    `UPDATE invoices SET status = 'overdue'
      WHERE status IN ('issued','partially_paid') AND due_date < $1 AND amount_outstanding > 0`,
    [asOf],
  );
  return r.rowCount ?? 0;
}

// ---- Preview ----

export interface InvoicePreview {
  billingPeriodStart: string;
  billingPeriodEnd: string;
  dueDate: string;
  rentAmount: string;
  proratedAmount: string;
  currency: string;
  fullPeriod: boolean;
  invoiceNumber: string;
}

export async function previewScheduleInvoice(schedule: BillingSchedule, periodStart?: string): Promise<InvoicePreview> {
  const tenancy = await findTenancyBillingContext(schedule.tenancyId);
  if (!tenancy) throw new Error('Tenancy not found for schedule');
  const start = periodStart ?? schedule.nextBillingDate;
  const end = periodEnd(start, schedule.billingFrequency);
  const rentCents = toCents(schedule.rentAmount);
  const prorated = prorateRentCents(rentCents, { start, end }, tenancy.startDate, tenancy.endDate);
  const dueDate = computeDueDate(start, schedule.billingDay, schedule.dueDayOfMonth, schedule.gracePeriodDays);
  return {
    billingPeriodStart: start,
    billingPeriodEnd: end,
    dueDate,
    rentAmount: schedule.rentAmount,
    proratedAmount: centsToNumber(prorated).toFixed(2),
    currency: schedule.currency,
    fullPeriod: prorated === rentCents,
    invoiceNumber: buildInvoiceNumber(start, schedule.id),
  };
}

function buildInvoiceNumber(periodStart: string, scheduleId: string): string {
  const ym = periodStart.slice(0, 7).replace('-', '');
  return `INV-${ym}-${scheduleId.replace(/-/g, '').slice(0, 8).toUpperCase()}`;
}

// ---- Recurring billing engine (idempotent, missed-run safe) ----

export interface GenerationResult {
  schedulesProcessed: number;
  invoicesCreated: number;
  invoicesSkipped: number;
  overdueMarked: number;
}

/**
 * Generate due invoices for all active schedules. Idempotent: the partial
 * unique index uq_invoices_schedule_period guarantees at most one invoice per
 * (schedule, period); concurrent workers serialise on the schedule row lock.
 */
export async function generateDueInvoices(options?: { lookbackDays?: number; now?: Date }): Promise<GenerationResult> {
  const today = options?.now
    ? new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Nairobi' }).format(options.now)
    : nairobiToday();
  const result: GenerationResult = { schedulesProcessed: 0, invoicesCreated: 0, invoicesSkipped: 0, overdueMarked: 0 };

  const schedules = await pool.query<{ id: string }>(
    `SELECT id FROM rental_billing_schedules WHERE status = 'active' ORDER BY next_billing_date ASC`,
  );

  for (const { id } of schedules.rows) {
    // eslint-disable-next-line no-await-in-loop
    const outcome = await processSchedule(id, today);
    result.invoicesCreated += outcome.created;
    result.invoicesSkipped += outcome.skipped;
    if (outcome.processed) result.schedulesProcessed += 1;
  }

  result.overdueMarked = await markOverdueInvoices(today);
  return result;
}

async function processSchedule(
  scheduleId: string,
  today: string,
): Promise<{ created: number; skipped: number; processed: boolean }> {
  return transaction(async (client) => {
    // Lock the schedule so concurrent workers do not double-advance.
    const schedRes = await client.query<BillingSchedule>(
      `SELECT ${SCHEDULE_COLUMNS} FROM rental_billing_schedules WHERE id = $1 FOR UPDATE`,
      [scheduleId],
    );
    const schedule = schedRes.rows[0];
    if (!schedule || schedule.status !== 'active') return { created: 0, skipped: 0, processed: false };

    const tenancy = await findTenancyBillingContext(schedule.tenancyId);
    if (!tenancy || tenancy.status !== 'active') {
      // Tenancy no longer active — suspend billing to avoid future charges.
      await client.query(`UPDATE rental_billing_schedules SET status = 'suspended', updated_at = NOW() WHERE id = $1`, [scheduleId]);
      return { created: 0, skipped: 0, processed: false };
    }

    const createdBy = await resolveCreatedBy(tenancy);
    if (!createdBy) return { created: 0, skipped: 0, processed: false };

    const toDate = tenancy.endDate && tenancy.endDate < today ? tenancy.endDate : today;
    if (schedule.firstBillingDate > toDate) return { created: 0, skipped: 0, processed: false };

    const starts = enumeratePeriodStarts(schedule.firstBillingDate, schedule.billingDay, schedule.billingFrequency, schedule.firstBillingDate, toDate);

    let created = 0;
    let skipped = 0;
    let lastStart: string | null = null;

    for (const start of starts) {
      const end = periodEnd(start, schedule.billingFrequency);
      const term = await findApplicableRentTerm(client, schedule.tenancyId, start);
      const rentAmount = term?.rentAmount ?? schedule.rentAmount;
      const currency = term?.currency ?? schedule.currency;
      const rentCents = toCents(rentAmount);
      const prorated = prorateRentCents(rentCents, { start, end }, tenancy.startDate, tenancy.endDate);
      lastStart = start;

      if (prorated <= 0n) {
        skipped += 1;
        continue;
      }

      const dueDate = computeDueDate(
        start,
        schedule.billingDay,
        term?.dueDayOfMonth ?? schedule.dueDayOfMonth,
        term?.gracePeriodDays ?? schedule.gracePeriodDays,
      );
      const invoiceNumber = buildInvoiceNumber(start, schedule.id);
      const amount = centsToNumber(prorated);

      // Insert invoice; the partial unique index enforces idempotency.
      const ins = await client.query<{ id: string }>(
        `INSERT INTO invoices (
          invoice_number, property_id, unit_id, tenant_id, tenancy_id,
          billing_schedule_id, source, status, currency,
          billing_period_start, billing_period_end, due_date,
          subtotal, tax_amount, total_amount, amount_paid, amount_outstanding,
          description, issued_at, created_by
        ) VALUES (
          $1,$2,$3,$4,$5,$6,'recurring','issued',$7,$8,$9,$10,
          $11,0,$11,0,$11,$12,NOW(),$13
        ) ON CONFLICT DO NOTHING RETURNING id`,
        [
          invoiceNumber, schedule.propertyId, schedule.unitId, schedule.tenantId, schedule.tenancyId,
          schedule.id, currency, start, end, dueDate,
          amount, `Rent for ${start} – ${end}`, createdBy,
        ],
      );

      const newInvoice = ins.rows[0];
      if (newInvoice) {
        await client.query(
          `INSERT INTO invoice_items (invoice_id, charge_type, description, amount, currency, billing_period_start, billing_period_end, quantity, unit_price)
           VALUES ($1,'rent',$2,$3,$4,$5,$6,1,$3)`,
          [newInvoice.id, `Monthly rent (${start} – ${end})`, amount, currency, start, end],
        );
        await client.query(
          `INSERT INTO rent_ledger_entries (
            tenancy_id, tenant_id, property_id, unit_id, invoice_id, entry_type,
            amount, currency, billing_period_start, billing_period_end, due_date, reference, created_by
          ) VALUES ($1,$2,$3,$4,$5,'charge',$6,$7,$8,$9,$10,$11,$12)`,
          [schedule.tenancyId, schedule.tenantId, schedule.propertyId, schedule.unitId, newInvoice.id, amount, currency, start, end, dueDate, invoiceNumber, createdBy],
        );
        await recordBillingRun(client, schedule.id, start, end, 'succeeded', newInvoice.id, null);
        await enqueueInvoiceIssued(client, {
          invoiceId: newInvoice.id,
          scheduleId: schedule.id,
          tenancyId: schedule.tenancyId,
          tenantId: schedule.tenantId,
          propertyId: schedule.propertyId,
          invoiceNumber,
          amount,
          currency,
          dueDate,
          periodStart: start,
          periodEnd: end,
        });
        created += 1;
      } else {
        // Already generated (retry/concurrent) — ensure a run record exists.
        await recordBillingRun(client, schedule.id, start, end, 'succeeded', null, null, true);
        skipped += 1;
      }
    }

    // Advance next_billing_date beyond the last processed period.
    if (lastStart) {
      const advanced = nextPeriodStart(lastStart, schedule.billingFrequency, schedule.billingDay);
      if (advanced > schedule.nextBillingDate) {
        await client.query(`UPDATE rental_billing_schedules SET next_billing_date = $2, updated_at = NOW() WHERE id = $1`, [scheduleId, advanced]);
      }
    }

    return { created, skipped, processed: true };
  });
}

async function recordBillingRun(
  client: PoolClient,
  scheduleId: string,
  periodStart: string,
  periodEnd: string,
  status: 'succeeded' | 'failed',
  invoiceId: string | null,
  errorMessage: string | null,
  alreadyExists = false,
): Promise<void> {
  await client.query(
    `INSERT INTO billing_runs (billing_schedule_id, billing_period_start, billing_period_end, status, invoice_id, error_message)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (billing_schedule_id, billing_period_start) DO UPDATE
       SET status = EXCLUDED.status,
           invoice_id = COALESCE(EXCLUDED.invoice_id, billing_runs.invoice_id),
           error_message = EXCLUDED.error_message,
           updated_at = NOW()`,
    [scheduleId, periodStart, periodEnd, status, invoiceId, errorMessage],
  );
  void alreadyExists;
}

async function enqueueInvoiceIssued(
  client: PoolClient,
  e: {
    invoiceId: string;
    scheduleId: string;
    tenancyId: string;
    tenantId: string;
    propertyId: string;
    invoiceNumber: string;
    amount: number;
    currency: string;
    dueDate: string;
    periodStart: string;
    periodEnd: string;
  },
): Promise<void> {
  // Resolve the tenant's user account for notification delivery.
  const userRes = await client.query<{ user_id: string | null }>(
    `SELECT user_id FROM tenants WHERE id = $1`,
    [e.tenantId],
  );
  const recipient = userRes.rows[0]?.user_id;
  await enqueueOutboxEventTransactional(client, {
    idempotencyKey: `invoice.issued:${e.invoiceId}`,
    eventType: 'invoice.issued',
    category: 'billing',
    priority: 'high',
    recipientUserIds: recipient ? [recipient] : [],
    organisationId: null,
    resourceType: 'invoice',
    resourceId: e.invoiceId,
    payload: {
      invoiceId: e.invoiceId,
      invoiceNumber: e.invoiceNumber,
      amount: e.amount,
      currency: e.currency,
      dueDate: e.dueDate,
      billingPeriodStart: e.periodStart,
      billingPeriodEnd: e.periodEnd,
      deepLink: `/tenant/invoices/${e.invoiceId}`,
    },
    channels: ['in_app', 'push'],
    classification: 'critical',
  });
}

export { nairobiToday, buildInvoiceNumber };