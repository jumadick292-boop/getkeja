// Garbage collection operations repository (Task 13.7).
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import type { PoolClient } from 'pg';
import type {
  GarbageCollectionStatus,
  GarbageJob,
  GarbageJobDetail,
  GarbageJobException,
  GarbageJobHistoryEntry,
  GarbageJobScope,
  GarbageJobStaffAssignment,
  GarbageJobAttachment,
  GarbageRecurringAgreement,
  GarbageRecurringOccurrence,
} from './garbage.types.js';

function mapJob(row: Record<string, unknown>): GarbageJob {
  return {
    id: row.id as string,
    serviceRequestId: (row.serviceRequestId as string) ?? null,
    recurringOccurrenceId: (row.recurringOccurrenceId as string) ?? null,
    agreementId: (row.agreementId as string) ?? null,
    quotationId: (row.quotationId as string) ?? null,
    quotationVersion: (row.quotationVersion as number) ?? null,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    status: row.status as GarbageCollectionStatus,
    collectionLocationId: (row.collectionLocationId as string) ?? null,
    collectionAddress: (row.collectionAddress as string) ?? null,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    tenancyId: (row.tenancyId as string) ?? null,
    wasteCategory: (row.wasteCategory as string) ?? null,
    estimatedQuantity: (row.estimatedQuantity as string) ?? null,
    binCount: (row.binCount as number) ?? null,
    agreedPrice: row.agreedPrice as string,
    currency: row.currency as string,
    scope: (row.scope as GarbageJobScope) ?? {},
    checklist: (row.checklist as Record<string, boolean>) ?? {},
    scheduledDate: (row.scheduledDate as string) ?? null,
    windowStart: (row.windowStart as string) ?? null,
    windowEnd: (row.windowEnd as string) ?? null,
    completionNotes: (row.completionNotes as string) ?? null,
    completionSubmittedAt: (row.completionSubmittedAt as string) ?? null,
    completionOutstandingIssue: (row.completionOutstandingIssue as boolean) ?? false,
    customerConfirmationStatus: (row.customerConfirmationStatus as string) ?? 'pending',
    customerConfirmationNotes: (row.customerConfirmationNotes as string) ?? null,
    customerConfirmationAt: (row.customerConfirmationAt as string) ?? null,
    cancelledAt: (row.cancelledAt as string) ?? null,
    cancellationReason: (row.cancellationReason as string) ?? null,
    missedAt: (row.missedAt as string) ?? null,
    missedReason: (row.missedReason as string) ?? null,
    failedAt: (row.failedAt as string) ?? null,
    failureReason: (row.failureReason as string) ?? null,
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const JOB_SELECT = `
  SELECT id, service_request_id AS "serviceRequestId", recurring_occurrence_id AS "recurringOccurrenceId",
         agreement_id AS "agreementId", quotation_id AS "quotationId", quotation_version AS "quotationVersion",
         customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId",
         provider_organisation_id AS "providerOrganisationId", assigned_staff_user_id AS "assignedStaffUserId",
         status::text AS status, collection_location_id AS "collectionLocationId", collection_address AS "collectionAddress",
         property_id AS "propertyId", unit_id AS "unitId", tenancy_id AS "tenancyId",
         waste_category AS "wasteCategory", estimated_quantity AS "estimatedQuantity", bin_count AS "binCount",
         agreed_price::text AS "agreedPrice", currency, scope, checklist,
         scheduled_date AS "scheduledDate", window_start AS "windowStart", window_end AS "windowEnd",
         completion_notes AS "completionNotes", completion_submitted_at AS "completionSubmittedAt",
         completion_outstanding_issue AS "completionOutstandingIssue",
         customer_confirmation_status AS "customerConfirmationStatus", customer_confirmation_notes AS "customerConfirmationNotes",
         customer_confirmation_at AS "customerConfirmationAt", cancelled_at AS "cancelledAt",
         cancellation_reason AS "cancellationReason", missed_at AS "missedAt", missed_reason AS "missedReason",
         failed_at AS "failedAt", failure_reason AS "failureReason", created_at AS "createdAt", updated_at AS "updatedAt"
  FROM garbage_jobs`;

export async function findJobById(id: string): Promise<GarbageJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findJobByRequestId(requestId: string): Promise<GarbageJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE service_request_id = $1`, [requestId]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findJobByOccurrenceId(occurrenceId: string): Promise<GarbageJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE recurring_occurrence_id = $1`, [occurrenceId]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findAcceptedQuotation(requestId: string): Promise<{ id: string; versionNumber: number; providerProfileId: string; totalAmount: string; currency: string; status: string } | null> {
  const r = await pool.query(
    `SELECT id, version_number AS "versionNumber", provider_profile_id AS "providerProfileId",
            total_amount::text AS "totalAmount", currency, status::text AS status
       FROM service_quotations WHERE service_request_id = $1 AND status = 'accepted'
      ORDER BY version_number DESC LIMIT 1`,
    [requestId],
  );
  return (r.rows[0] as never) ?? null;
}

export interface InsertGarbageJobRow {
  serviceRequestId: string | null;
  recurringOccurrenceId: string | null;
  agreementId: string | null;
  quotationId: string | null;
  quotationVersion: number | null;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  collectionLocationId: string | null;
  collectionAddress: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  wasteCategory: string | null;
  estimatedQuantity: string | null;
  binCount: number | null;
  agreedPrice: string;
  currency: string;
  scope: GarbageJobScope;
  checklist: Record<string, boolean>;
  scheduledDate: string | null;
  windowStart: string | null;
  windowEnd: string | null;
  createdBy: string;
}

export async function insertJob(client: PoolClient, row: InsertGarbageJobRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO garbage_jobs
       (service_request_id, recurring_occurrence_id, agreement_id, quotation_id, quotation_version,
        customer_user_id, provider_profile_id, provider_organisation_id, collection_location_id, collection_address,
        property_id, unit_id, tenancy_id, waste_category, estimated_quantity, bin_count, agreed_price, currency,
        scope, checklist, scheduled_date, window_start, window_end, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19::jsonb,$20::jsonb,$21,$22,$23,$24)
     RETURNING id`,
    [
      row.serviceRequestId, row.recurringOccurrenceId, row.agreementId, row.quotationId, row.quotationVersion,
      row.customerUserId, row.providerProfileId, row.providerOrganisationId, row.collectionLocationId, row.collectionAddress,
      row.propertyId, row.unitId, row.tenancyId, row.wasteCategory, row.estimatedQuantity, row.binCount,
      row.agreedPrice, row.currency, JSON.stringify(row.scope), JSON.stringify(row.checklist),
      row.scheduledDate, row.windowStart, row.windowEnd, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function listJobsByCustomer(userId: string, filters: { status?: GarbageCollectionStatus; limit: number; offset: number }): Promise<{ rows: GarbageJob[]; total: number }> {
  const where = [`customer_user_id = $1`];
  const params: unknown[] = [userId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::garbage_collection_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(`SELECT COUNT(*)::text AS count FROM garbage_jobs ${whereSql}`, params);
  params.push(filters.limit, filters.offset);
  const r = await pool.query(`${JOB_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows: r.rows.map(mapJob), total: Number(count.rows[0]!.count) };
}

export async function listJobsForProvider(profileIds: string[], staffUserId: string, filters: { status?: GarbageCollectionStatus; limit: number; offset: number }): Promise<{ rows: GarbageJob[]; total: number }> {
  if (profileIds.length === 0) return { rows: [], total: 0 };
  const where = [
    `(provider_profile_id = ANY($1::uuid[]) OR assigned_staff_user_id = $2
       OR EXISTS (SELECT 1 FROM garbage_job_staff_assignments s WHERE s.garbage_job_id = garbage_jobs.id AND s.user_id = $2 AND s.is_active))`,
  ];
  const params: unknown[] = [profileIds, staffUserId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::garbage_collection_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(`SELECT COUNT(*)::text AS count FROM garbage_jobs ${whereSql}`, params);
  params.push(filters.limit, filters.offset);
  const r = await pool.query(`${JOB_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows: r.rows.map(mapJob), total: Number(count.rows[0]!.count) };
}

export async function updateJobStatus(client: PoolClient, input: { jobId: string; expectedFrom: GarbageCollectionStatus; toStatus: GarbageCollectionStatus; actorUserId: string; reason?: string | null; extra?: Record<string, unknown> }): Promise<{ id: string; status: GarbageCollectionStatus }> {
  const assignments = [`status = $2::garbage_collection_status`, 'updated_by = $3', 'updated_at = NOW()'];
  const values: unknown[] = [input.jobId, input.toStatus, input.actorUserId];
  let idx = 4;
  if (input.toStatus === 'cancelled') {
    assignments.push('cancelled_at = NOW()', 'cancelled_by = $3');
    if (input.reason != null) { assignments.push(`cancellation_reason = $${idx++}`); values.push(input.reason); }
  } else if (input.toStatus === 'missed') {
    assignments.push('missed_at = NOW()');
    if (input.reason != null) { assignments.push(`missed_reason = $${idx++}`); values.push(input.reason); }
  } else if (input.toStatus === 'failed') {
    assignments.push('failed_at = NOW()');
    if (input.reason != null) { assignments.push(`failure_reason = $${idx++}`); values.push(input.reason); }
  } else if (input.reason != null) {
    assignments.push(`cancellation_reason = $${idx++}`);
    values.push(input.reason);
  }
  for (const [key, value] of Object.entries(input.extra ?? {})) {
    assignments.push(`${key} = $${idx++}`);
    values.push(value);
  }
  values.push(input.expectedFrom);
  const r = await client.query<{ id: string; status: GarbageCollectionStatus }>(
    `UPDATE garbage_jobs SET ${assignments.join(', ')} WHERE id = $1 AND status = $${idx}::garbage_collection_status RETURNING id, status::text AS status`,
    values,
  );
  if (r.rows.length === 0) {
    const err = new Error('Collection status changed concurrently') as Error & { code?: string };
    err.code = 'CONFLICT';
    throw err;
  }
  return r.rows[0]!;
}

export async function insertHistory(client: PoolClient, input: { jobId: string; action: string; changedBy: string; previousStatus?: GarbageCollectionStatus | null; newStatus?: GarbageCollectionStatus | null; reason?: string | null; metadata?: Record<string, unknown> }): Promise<void> {
  await client.query(
    `INSERT INTO garbage_job_history (garbage_job_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3::garbage_collection_status,$4::garbage_collection_status,$5,$6,$7::jsonb)`,
    [input.jobId, input.action, input.previousStatus ?? null, input.newStatus ?? null, input.changedBy, input.reason ?? null, JSON.stringify(input.metadata ?? {})],
  );
}

export async function listHistory(jobId: string): Promise<GarbageJobHistoryEntry[]> {
  const r = await pool.query(
    `SELECT id, action, previous_status AS "previousStatus", new_status::text AS "newStatus", changed_by AS "changedBy",
            change_reason AS "changeReason", metadata, created_at AS "createdAt"
       FROM garbage_job_history WHERE garbage_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as GarbageJobHistoryEntry[];
}

export async function listStaff(jobId: string): Promise<GarbageJobStaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", label, is_active AS "isActive", created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM garbage_job_staff_assignments WHERE garbage_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as GarbageJobStaffAssignment[];
}

export async function listExceptions(jobId: string): Promise<GarbageJobException[]> {
  const r = await pool.query(
    `SELECT id, reported_by AS "reportedBy", type, description, created_at AS "createdAt"
       FROM garbage_job_exceptions WHERE garbage_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as GarbageJobException[];
}

export async function listAttachments(jobId: string): Promise<GarbageJobAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM garbage_job_attachments WHERE garbage_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as GarbageJobAttachment[];
}

export async function getJobDetail(id: string): Promise<GarbageJobDetail | null> {
  const job = await findJobById(id);
  if (!job) return null;
  const [history, staff, exceptions, attachments] = await Promise.all([
    listHistory(id), listStaff(id), listExceptions(id), listAttachments(id),
  ]);
  return { ...job, history, staff, exceptions, attachments };
}

export async function mergeChecklist(client: PoolClient, jobId: string, items: Record<string, boolean>): Promise<void> {
  await client.query(`UPDATE garbage_jobs SET checklist = (COALESCE(checklist, '{}'::jsonb) || $2::jsonb) WHERE id = $1`, [jobId, JSON.stringify(items)]);
}

export async function insertAttachments(client: PoolClient, jobId: string, documentIds: string[], kind: string, uploadedBy: string): Promise<void> {
  for (const docId of documentIds) {
    await client.query(`INSERT INTO garbage_job_attachments (garbage_job_id, document_id, kind, uploaded_by) VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`, [jobId, docId, kind, uploadedBy]);
  }
}

export async function insertException(client: PoolClient, jobId: string, reportedBy: string, type: string, description: string): Promise<void> {
  await client.query(`INSERT INTO garbage_job_exceptions (garbage_job_id, reported_by, type, description) VALUES ($1,$2,$3,$4)`, [jobId, reportedBy, type, description]);
}

export async function submitCompletion(client: PoolClient, jobId: string, input: { notes: string | null; outstandingIssue: boolean; checklist?: Record<string, boolean>; wasteCategory?: string | null; estimatedQuantity?: string | null; binCount?: number | null }): Promise<void> {
  await client.query(
    `UPDATE garbage_jobs SET completion_notes = $2, completion_outstanding_issue = $3, completion_submitted_at = NOW(),
        checklist = COALESCE(checklist, '{}'::jsonb) || $4::jsonb,
        waste_category = COALESCE($5, waste_category), estimated_quantity = COALESCE($6, estimated_quantity), bin_count = COALESCE($7, bin_count)
      WHERE id = $1`,
    [jobId, input.notes, input.outstandingIssue, JSON.stringify(input.checklist ?? {}), input.wasteCategory ?? null, input.estimatedQuantity ?? null, input.binCount ?? null],
  );
}

export async function recordCustomerConfirmation(client: PoolClient, jobId: string, input: { confirm: boolean; notes: string | null }): Promise<void> {
  await client.query(
    `UPDATE garbage_jobs SET customer_confirmation_status = $2, customer_confirmation_notes = $3, customer_confirmation_at = NOW() WHERE id = $1`,
    [jobId, input.confirm ? 'confirmed' : 'exception', input.notes],
  );
}

export async function applyReschedule(client: PoolClient, jobId: string, date: string, start: string | null, end: string | null): Promise<void> {
  await client.query(`UPDATE garbage_jobs SET scheduled_date = $2, window_start = $3, window_end = $4 WHERE id = $1`, [jobId, date, start, end]);
}

// ---- Recurring agreements ----
function mapAgreement(row: Record<string, unknown>): GarbageRecurringAgreement {
  return {
    id: row.id as string,
    serviceRequestId: (row.serviceRequestId as string) ?? null,
    quotationId: (row.quotationId as string) ?? null,
    providerProfileId: row.providerProfileId as string,
    customerUserId: row.customerUserId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    tenancyId: (row.tenancyId as string) ?? null,
    status: row.status as GarbageRecurringAgreement['status'],
    frequency: row.frequency as string,
    intervalDays: (row.intervalDays as number) ?? null,
    daysOfWeek: (row.daysOfWeek as number[]) ?? [],
    windowStart: (row.windowStart as string) ?? null,
    windowEnd: (row.windowEnd as string) ?? null,
    startDate: row.startDate as string,
    endDate: (row.endDate as string) ?? null,
    agreedAmount: row.agreedAmount as string,
    currency: row.currency as string,
    billingFrequency: (row.billingFrequency as string) ?? null,
    wasteCategory: (row.wasteCategory as string) ?? null,
    scope: (row.scope as Record<string, unknown>) ?? {},
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const AGREEMENT_SELECT = `
  SELECT id, service_request_id AS "serviceRequestId", quotation_id AS "quotationId", provider_profile_id AS "providerProfileId",
         customer_user_id AS "customerUserId", provider_organisation_id AS "providerOrganisationId", property_id AS "propertyId",
         unit_id AS "unitId", tenancy_id AS "tenancyId", status::text AS status, frequency, interval_days AS "intervalDays",
         days_of_week AS "daysOfWeek", window_start AS "windowStart", window_end AS "windowEnd", start_date AS "startDate",
         end_date AS "endDate", agreed_amount::text AS "agreedAmount", currency, billing_frequency AS "billingFrequency",
         waste_category AS "wasteCategory", scope, created_at AS "createdAt", updated_at AS "updatedAt"
  FROM garbage_recurring_agreements`;

export async function insertAgreement(client: PoolClient, row: Omit<GarbageRecurringAgreement, 'id' | 'createdAt' | 'updatedAt'> & { createdBy: string }): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO garbage_recurring_agreements
       (service_request_id, quotation_id, provider_profile_id, customer_user_id, provider_organisation_id,
        property_id, unit_id, tenancy_id, status, frequency, interval_days, days_of_week, window_start, window_end,
        start_date, end_date, agreed_amount, currency, billing_frequency, waste_category, scope, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::garbage_agreement_status,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21::jsonb,$22)
     RETURNING id`,
    [
      row.serviceRequestId, row.quotationId, row.providerProfileId, row.customerUserId, row.providerOrganisationId,
      row.propertyId, row.unitId, row.tenancyId, row.status, row.frequency, row.intervalDays, row.daysOfWeek,
      row.windowStart, row.windowEnd, row.startDate, row.endDate, row.agreedAmount, row.currency,
      row.billingFrequency, row.wasteCategory, JSON.stringify(row.scope), row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function findAgreement(id: string): Promise<GarbageRecurringAgreement | null> {
  const r = await pool.query(`${AGREEMENT_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapAgreement(r.rows[0]) : null;
}

export async function listAgreementsByCustomer(userId: string): Promise<GarbageRecurringAgreement[]> {
  const r = await pool.query(`${AGREEMENT_SELECT} WHERE customer_user_id = $1 ORDER BY created_at DESC`, [userId]);
  return r.rows.map(mapAgreement);
}

export async function listAgreementsByProvider(profileIds: string[]): Promise<GarbageRecurringAgreement[]> {
  if (profileIds.length === 0) return [];
  const r = await pool.query(`${AGREEMENT_SELECT} WHERE provider_profile_id = ANY($1::uuid[]) ORDER BY created_at DESC`, [profileIds]);
  return r.rows.map(mapAgreement);
}

export async function updateAgreementStatus(client: PoolClient, id: string, status: GarbageRecurringAgreement['status']): Promise<void> {
  await client.query(`UPDATE garbage_recurring_agreements SET status = $2::garbage_agreement_status, updated_by = $3, updated_at = NOW() WHERE id = $1`, [id, status, null]);
}

export async function listOccurrences(agreementId: string): Promise<GarbageRecurringOccurrence[]> {
  const r = await pool.query(
    `SELECT id, agreement_id AS "agreementId", period_key AS "periodKey", scheduled_date AS "scheduledDate",
            window_start AS "windowStart", window_end AS "windowEnd", status::text AS status, generated_at AS "generatedAt"
       FROM garbage_recurring_occurrences WHERE agreement_id = $1 ORDER BY scheduled_date ASC`,
    [agreementId],
  );
  return r.rows as unknown as GarbageRecurringOccurrence[];
}

// Idempotent occurrence insert; returns true only when a new row was created.
export async function insertOccurrenceIfAbsent(client: PoolClient, agreementId: string, periodKey: string, scheduledDate: string, windowStart: string | null, windowEnd: string | null): Promise<boolean> {
  const r = await client.query(
    `INSERT INTO garbage_recurring_occurrences (agreement_id, period_key, scheduled_date, window_start, window_end)
     VALUES ($1,$2,$3,$4,$5) ON CONFLICT (agreement_id, period_key) DO NOTHING RETURNING id`,
    [agreementId, periodKey, scheduledDate, windowStart, windowEnd],
  );
  return r.rows.length > 0;
}

// ---- Recurring occurrence generation (idempotent, missed-run safe) ----
function nairobiToday(): string {
  // en-CA yields YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Nairobi' }).format(new Date());
}

function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function weekday(dateStr: string): number {
  return new Date(`${dateStr}T00:00:00Z`).getUTCDay();
}

function dayDiff(a: string, b: string): number {
  return Math.round((new Date(`${a}T00:00:00Z`).getTime() - new Date(`${b}T00:00:00Z`).getTime()) / 86400000);
}

function isCandidateDate(agreement: GarbageRecurringAgreement, date: string): boolean {
  const start = agreement.startDate;
  if (date < start) return false;
  if (agreement.endDate && date > agreement.endDate) return false;
  switch (agreement.frequency) {
    case 'weekly': {
      const days = agreement.daysOfWeek.length > 0 ? agreement.daysOfWeek : [weekday(start)];
      return days.includes(weekday(date));
    }
    case 'biweekly':
      return dayDiff(date, start) % 14 === 0;
    case 'monthly': {
      const startDate = new Date(`${start}T00:00:00Z`);
      const d = new Date(`${date}T00:00:00Z`);
      return d.getUTCDate() === startDate.getUTCDate();
    }
    case 'custom': {
      const step = agreement.intervalDays && agreement.intervalDays > 0 ? agreement.intervalDays : 7;
      return dayDiff(date, start) % step === 0;
    }
    default:
      return false;
  }
}

export interface RecurringGenerationResult {
  occurrencesCreated: number;
  jobsCreated: number;
}

// Materialise due occurrences into one-time jobs. Safe to run repeatedly: each
// occurrence is created once (unique agreement_id + period_key) and each job is
// claimed under a row lock so concurrent workers cannot double-create.
export async function generateRecurringWork(options?: { lookbackDays?: number; horizonDays?: number }): Promise<RecurringGenerationResult> {
  const lookback = options?.lookbackDays ?? 7;
  const horizon = options?.horizonDays ?? 14;
  const today = nairobiToday();
  const windowStart = addDays(today, -lookback);
  const windowEnd = addDays(today, horizon);

  const agreements = await pool.query<{ id: string }>(
    `SELECT id FROM garbage_recurring_agreements WHERE status = 'active'`,
  );

  let occurrencesCreated = 0;
  let jobsCreated = 0;

  for (const { id: agreementId } of agreements.rows) {
    const agreement = await findAgreement(agreementId);
    if (!agreement || agreement.status !== 'active') continue;

    // System-generated jobs are attributed to the provider account's owner.
    const owner = await pool.query<{ user_id: string }>(
      `SELECT user_id FROM specialized_profiles WHERE id = $1`,
      [agreement.providerProfileId],
    );
    const createdBy = owner.rows[0]?.user_id;
    if (!createdBy) continue;

    // Bound the iteration window to the agreement's own active range.
    const rangeStart = agreement.startDate > windowStart ? agreement.startDate : windowStart;
    const rangeEnd = agreement.endDate && agreement.endDate < windowEnd ? agreement.endDate : windowEnd;
    if (rangeStart > rangeEnd) continue;

    let cursor = rangeStart;
    let guard = 0;
    while (cursor <= rangeEnd && guard < 800) {
      guard += 1;
      if (isCandidateDate(agreement, cursor)) {
        // eslint-disable-next-line no-await-in-loop
        await transaction(async (client) => {
          const inserted = await insertOccurrenceIfAbsent(client, agreementId, cursor, cursor, agreement.windowStart, agreement.windowEnd);
          if (inserted) occurrencesCreated += 1;

          // Claim the occurrence row to serialise job creation across workers.
          const occ = await client.query<{ id: string; status: string }>(
            `SELECT id, status::text AS status FROM garbage_recurring_occurrences
              WHERE agreement_id = $1 AND period_key = $2 FOR UPDATE`,
            [agreementId, cursor],
          );
          if (!occ.rows[0]) return;
          // Only materialise occurrences that are due (scheduled on/before today)
          // and still in the 'scheduled' state with no job yet.
          if (occ.rows[0].status !== 'scheduled' || cursor > today) return;
          const existing = await findJobByOccurrenceId(occ.rows[0].id);
          if (existing) return;

          const created = await insertJob(client, {
            serviceRequestId: agreement.serviceRequestId,
            recurringOccurrenceId: occ.rows[0].id,
            agreementId: agreement.id,
            quotationId: agreement.quotationId,
            quotationVersion: null,
            customerUserId: agreement.customerUserId,
            providerProfileId: agreement.providerProfileId,
            providerOrganisationId: agreement.providerOrganisationId,
            collectionLocationId: null,
            collectionAddress: null,
            propertyId: agreement.propertyId,
            unitId: agreement.unitId,
            tenancyId: agreement.tenancyId,
            wasteCategory: agreement.wasteCategory,
            estimatedQuantity: null,
            binCount: null,
            agreedPrice: agreement.agreedAmount,
            currency: agreement.currency,
            scope: { ...agreement.scope, recurring: true },
            checklist: {},
            scheduledDate: cursor,
            windowStart: agreement.windowStart,
            windowEnd: agreement.windowEnd,
            createdBy,
          });
          jobsCreated += 1;
          await insertHistory(client, {
            jobId: created.id,
            action: 'confirmed',
            changedBy: createdBy,
            newStatus: 'confirmed',
            metadata: { agreementId: agreement.id, occurrenceId: occ.rows[0].id, scheduledDate: cursor },
          });
        });
      }
      cursor = addDays(cursor, 1);
    }
  }

  return { occurrencesCreated, jobsCreated };
}