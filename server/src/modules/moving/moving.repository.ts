// Moving & relocation operations repository (Task 13.6).
// All writes accept the caller's PoolClient so job change + history + outbox
// share one transaction. Reads are scoped by the service layer.
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  MovingJob,
  MovingJobAmendment,
  MovingJobAssessment,
  MovingJobAttachment,
  MovingJobDetail,
  MovingJobHistoryEntry,
  MovingJobScheduleChange,
  MovingJobScope,
  MovingJobStaffAssignment,
  MovingJobStatus,
  MovingJobChecklist,
} from './moving.types.js';

function mapJob(row: Record<string, unknown>): MovingJob {
  return {
    id: row.id as string,
    serviceRequestId: row.serviceRequestId as string,
    quotationId: row.quotationId as string,
    quotationVersion: (row.quotationVersion as number) ?? 1,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    status: row.status as MovingJobStatus,
    originLocationId: (row.originLocationId as string) ?? null,
    destinationLocationId: (row.destinationLocationId as string) ?? null,
    originAddress: (row.originAddress as string) ?? null,
    destinationAddress: (row.destinationAddress as string) ?? null,
    originContactInstructions: (row.originContactInstructions as string) ?? null,
    destinationContactInstructions: (row.destinationContactInstructions as string) ?? null,
    originBuildingName: (row.originBuildingName as string) ?? null,
    originFloor: (row.originFloor as string) ?? null,
    originLiftAvailable: (row.originLiftAvailable as boolean) ?? null,
    originAccessNotes: (row.originAccessNotes as string) ?? null,
    destinationBuildingName: (row.destinationBuildingName as string) ?? null,
    destinationFloor: (row.destinationFloor as string) ?? null,
    destinationLiftAvailable: (row.destinationLiftAvailable as boolean) ?? null,
    destinationAccessNotes: (row.destinationAccessNotes as string) ?? null,
    agreedMoveDate: (row.agreedMoveDate as string) ?? null,
    agreedWindowStart: (row.agreedWindowStart as string) ?? null,
    agreedWindowEnd: (row.agreedWindowEnd as string) ?? null,
    scope: (row.scope as MovingJobScope) ?? { serviceCategories: [], capabilities: [] },
    agreedPrice: row.agreedPrice as string,
    currency: row.currency as string,
    checklist: (row.checklist as MovingJobChecklist) ?? {},
    tenancyId: (row.tenancyId as string) ?? null,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    completionNotes: (row.completionNotes as string) ?? null,
    completionSubmittedAt: (row.completionSubmittedAt as string) ?? null,
    completionOutstandingIssue: (row.completionOutstandingIssue as boolean) ?? false,
    customerConfirmationStatus: (row.customerConfirmationStatus as string) ?? 'pending',
    customerConfirmationNotes: (row.customerConfirmationNotes as string) ?? null,
    customerConfirmationAt: (row.customerConfirmationAt as string) ?? null,
    cancelledAt: (row.cancelledAt as string) ?? null,
    cancellationReason: (row.cancellationReason as string) ?? null,
    failedAt: (row.failedAt as string) ?? null,
    failureReason: (row.failureReason as string) ?? null,
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const JOB_SELECT = `
  SELECT id, service_request_id AS "serviceRequestId", quotation_id AS "quotationId",
         quotation_version AS "quotationVersion", customer_user_id AS "customerUserId",
         provider_profile_id AS "providerProfileId", provider_organisation_id AS "providerOrganisationId",
         assigned_staff_user_id AS "assignedStaffUserId", status::text AS status,
         origin_location_id AS "originLocationId", destination_location_id AS "destinationLocationId",
         origin_address AS "originAddress", destination_address AS "destinationAddress",
         origin_contact_instructions AS "originContactInstructions",
         destination_contact_instructions AS "destinationContactInstructions",
         origin_building_name AS "originBuildingName", origin_floor AS "originFloor",
         origin_lift_available AS "originLiftAvailable", origin_access_notes AS "originAccessNotes",
         destination_building_name AS "destinationBuildingName", destination_floor AS "destinationFloor",
         destination_lift_available AS "destinationLiftAvailable", destination_access_notes AS "destinationAccessNotes",
         agreed_move_date AS "agreedMoveDate", agreed_window_start AS "agreedWindowStart",
         agreed_window_end AS "agreedWindowEnd", scope,
         agreed_price::text AS "agreedPrice", currency, checklist,
         tenancy_id AS "tenancyId", property_id AS "propertyId", unit_id AS "unitId",
         completion_notes AS "completionNotes", completion_submitted_at AS "completionSubmittedAt",
         completion_outstanding_issue AS "completionOutstandingIssue",
         customer_confirmation_status AS "customerConfirmationStatus",
         customer_confirmation_notes AS "customerConfirmationNotes",
         customer_confirmation_at AS "customerConfirmationAt",
         cancelled_at AS "cancelledAt", cancellation_reason AS "cancellationReason",
         failed_at AS "failedAt", failure_reason AS "failureReason",
         created_at AS "createdAt", updated_at AS "updatedAt"
  FROM moving_jobs`;

export async function findJobById(id: string): Promise<MovingJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findJobByRequestId(requestId: string): Promise<MovingJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE service_request_id = $1`, [requestId]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

// The accepted quotation + exact revision for a request (contractual snapshot).
export async function findAcceptedQuotation(
  requestId: string,
): Promise<{ id: string; versionNumber: number; providerProfileId: string; totalAmount: string; currency: string; status: string } | null> {
  const r = await pool.query(
    `SELECT id, version_number AS "versionNumber", provider_profile_id AS "providerProfileId",
            total_amount::text AS "totalAmount", currency, status::text AS status
       FROM service_quotations
      WHERE service_request_id = $1 AND status = 'accepted'
      ORDER BY version_number DESC
      LIMIT 1`,
    [requestId],
  );
  return (r.rows[0] as never) ?? null;
}

export interface InsertJobRow {
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  agreedPrice: string;
  currency: string;
  scope: MovingJobScope;
  originLocationId: string | null;
  destinationLocationId: string | null;
  originAddress: string | null;
  destinationAddress: string | null;
  agreedMoveDate: string | null;
  agreedWindowStart: string | null;
  agreedWindowEnd: string | null;
  checklist: MovingJobChecklist;
  tenancyId: string | null;
  propertyId: string | null;
  unitId: string | null;
  createdBy: string;
}

export async function insertJob(client: PoolClient, row: InsertJobRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO moving_jobs
       (service_request_id, quotation_id, quotation_version, customer_user_id,
        provider_profile_id, provider_organisation_id, agreed_price, currency, scope,
        origin_location_id, destination_location_id, origin_address, destination_address,
        agreed_move_date, agreed_window_start, agreed_window_end, checklist,
        tenancy_id, property_id, unit_id, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11,$12,$13,$14,$15,$16,$17::jsonb,$18,$19,$20,$21)
     RETURNING id`,
    [
      row.serviceRequestId, row.quotationId, row.quotationVersion, row.customerUserId,
      row.providerProfileId, row.providerOrganisationId, row.agreedPrice, row.currency,
      JSON.stringify(row.scope), row.originLocationId, row.destinationLocationId,
      row.originAddress, row.destinationAddress, row.agreedMoveDate,
      row.agreedWindowStart, row.agreedWindowEnd, JSON.stringify(row.checklist),
      row.tenancyId, row.propertyId, row.unitId, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function listJobsByCustomer(
  userId: string,
  filters: { status?: MovingJobStatus; limit: number; offset: number },
): Promise<{ rows: MovingJob[]; total: number }> {
  const where = [`customer_user_id = $1`];
  const params: unknown[] = [userId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::moving_job_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM moving_jobs ${whereSql}`,
    params,
  );
  params.push(filters.limit, filters.offset);
  const r = await pool.query(
    `${JOB_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  return { rows: r.rows.map(mapJob), total: Number(count.rows[0]!.count) };
}

// Provider inbox: jobs assigned to the provider's profiles (or org) or to an
// active assigned staff member.
export async function listJobsForProvider(
  profileIds: string[],
  staffUserId: string,
  filters: { status?: MovingJobStatus; limit: number; offset: number },
): Promise<{ rows: MovingJob[]; total: number }> {
  if (profileIds.length === 0) return { rows: [], total: 0 };
  const where = [
    `(provider_profile_id = ANY($1::uuid[])
       OR assigned_staff_user_id = $2
       OR EXISTS (SELECT 1 FROM moving_job_staff_assignments s
                   WHERE s.moving_job_id = moving_jobs.id AND s.user_id = $2 AND s.is_active))`,
  ];
  const params: unknown[] = [profileIds, staffUserId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::moving_job_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM moving_jobs ${whereSql}`,
    params,
  );
  params.push(filters.limit, filters.offset);
  const r = await pool.query(
    `${JOB_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  return { rows: r.rows.map(mapJob), total: Number(count.rows[0]!.count) };
}

export async function updateJobStatus(
  client: PoolClient,
  input: {
    jobId: string;
    expectedFrom: MovingJobStatus;
    toStatus: MovingJobStatus;
    actorUserId: string;
    reason?: string | null;
    extra?: Record<string, unknown>;
  },
): Promise<{ id: string; status: MovingJobStatus }> {
  const assignments = [`status = $2::moving_job_status`, 'updated_by = $3', 'updated_at = NOW()'];
  const values: unknown[] = [input.jobId, input.toStatus, input.actorUserId];
  let idx = 4;
  if (input.reason != null) {
    assignments.push(`cancellation_reason = $${idx++}`);
    values.push(input.reason);
  }
  if (input.toStatus === 'cancelled') {
    assignments.push('cancelled_at = NOW()', 'cancelled_by = $3');
  }
  if (input.toStatus === 'failed') {
    assignments.push('failed_at = NOW()');
    if (input.reason != null) assignments.push(`failure_reason = $${idx - 1}`);
  }
  for (const [key, value] of Object.entries(input.extra ?? {})) {
    assignments.push(`${key} = $${idx++}`);
    values.push(value);
  }
  values.push(input.expectedFrom);
  const r = await client.query<{ id: string; status: MovingJobStatus }>(
    `UPDATE moving_jobs SET ${assignments.join(', ')}
      WHERE id = $1 AND status = $${idx}::moving_job_status
      RETURNING id, status::text AS status`,
    values,
  );
  if (r.rows.length === 0) {
    const err = new Error('Job status changed concurrently') as Error & { code?: string };
    err.code = 'CONFLICT';
    throw err;
  }
  return r.rows[0]!;
}

export async function insertHistory(
  client: PoolClient,
  input: {
    jobId: string;
    action: string;
    changedBy: string;
    previousStatus?: MovingJobStatus | null;
    newStatus?: MovingJobStatus | null;
    reason?: string | null;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO moving_job_history (moving_job_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3::moving_job_status,$4::moving_job_status,$5,$6,$7::jsonb)`,
    [
      input.jobId, input.action, input.previousStatus ?? null, input.newStatus ?? null,
      input.changedBy, input.reason ?? null, JSON.stringify(input.metadata ?? {}),
    ],
  );
}

// ---- Detail sub-resources ----
export async function listHistory(jobId: string): Promise<MovingJobHistoryEntry[]> {
  const r = await pool.query(
    `SELECT id, action, previous_status AS "previousStatus", new_status::text AS "newStatus",
            changed_by AS "changedBy", change_reason AS "changeReason", metadata, created_at AS "createdAt"
       FROM moving_job_history WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobHistoryEntry[];
}

export async function listStaff(jobId: string): Promise<MovingJobStaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", label, is_active AS "isActive", assigned_by AS "assignedBy",
            created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM moving_job_staff_assignments WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobStaffAssignment[];
}

export async function listAssessments(jobId: string): Promise<MovingJobAssessment[]> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", requested_by AS "requestedBy",
            assigned_staff_user_id AS "assignedStaffUserId", status::text AS status,
            proposed_at AS "proposedAt", location_id AS "locationId", location_address AS "locationAddress",
            provider_notes AS "providerNotes", customer_notes AS "customerNotes", outcome,
            created_at AS "createdAt", updated_at AS "updatedAt"
       FROM moving_job_assessments WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobAssessment[];
}

export async function listScheduleChanges(jobId: string): Promise<MovingJobScheduleChange[]> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", requested_by AS "requestedBy",
            previous_date AS "previousDate", proposed_date AS "proposedDate",
            proposed_window_start AS "proposedWindowStart", proposed_window_end AS "proposedWindowEnd",
            reason, status::text AS status, decided_by AS "decidedBy", decided_at AS "decidedAt",
            created_at AS "createdAt"
       FROM moving_job_schedule_changes WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobScheduleChange[];
}

export async function listAmendments(jobId: string): Promise<MovingJobAmendment[]> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", proposed_by AS "proposedBy", reason,
            revised_scope AS "revisedScope", additional_cost::text AS "additionalCost", currency,
            status::text AS status, decided_by AS "decidedBy", decided_at AS "decidedAt", created_at AS "createdAt"
       FROM moving_job_amendments WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobAmendment[];
}

export async function listAttachments(jobId: string): Promise<MovingJobAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM moving_job_attachments WHERE moving_job_id = $1 ORDER BY created_at ASC`,
    [jobId],
  );
  return r.rows as unknown as MovingJobAttachment[];
}

export async function getJobDetail(id: string): Promise<MovingJobDetail | null> {
  const job = await findJobById(id);
  if (!job) return null;
  const [history, staff, assessments, scheduleChanges, amendments, attachments] = await Promise.all([
    listHistory(id),
    listStaff(id),
    listAssessments(id),
    listScheduleChanges(id),
    listAmendments(id),
    listAttachments(id),
  ]);
  return { ...job, history, staff, assessments, scheduleChanges, amendments, attachments };
}

// ---- Assessments ----
export async function insertAssessment(
  client: PoolClient,
  input: {
    jobId: string;
    requestedBy: string;
    proposedAt: string | null;
    locationId: string | null;
    locationAddress: string | null;
    providerNotes: string | null;
  },
): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO moving_job_assessments (moving_job_id, requested_by, proposed_at, location_id, location_address, provider_notes)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [input.jobId, input.requestedBy, input.proposedAt, input.locationId, input.locationAddress, input.providerNotes],
  );
  return r.rows[0]!;
}

export async function findAssessment(id: string): Promise<{ id: string; movingJobId: string; status: string } | null> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", status::text AS status FROM moving_job_assessments WHERE id = $1`,
    [id],
  );
  return (r.rows[0] as never) ?? null;
}

export async function updateAssessment(
  client: PoolClient,
  id: string,
  fields: { status: string; customerNotes?: string | null; outcome?: string | null; providerNotes?: string | null },
): Promise<void> {
  await client.query(
    `UPDATE moving_job_assessments
        SET status = $2::moving_assessment_status,
            customer_notes = COALESCE($3, customer_notes),
            outcome = COALESCE($4, outcome),
            provider_notes = COALESCE($5, provider_notes)
      WHERE id = $1`,
    [id, fields.status, fields.customerNotes ?? null, fields.outcome ?? null, fields.providerNotes ?? null],
  );
}

// ---- Schedule changes ----
export async function insertScheduleChange(
  client: PoolClient,
  input: {
    jobId: string;
    requestedBy: string;
    previousDate: string | null;
    previousWindowStart: string | null;
    previousWindowEnd: string | null;
    proposedDate: string;
    proposedWindowStart: string | null;
    proposedWindowEnd: string | null;
    reason: string | null;
  },
): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO moving_job_schedule_changes
       (moving_job_id, requested_by, previous_date, previous_window_start, previous_window_end,
        proposed_date, proposed_window_start, proposed_window_end, reason)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [
      input.jobId, input.requestedBy, input.previousDate, input.previousWindowStart,
      input.previousWindowEnd, input.proposedDate, input.proposedWindowStart,
      input.proposedWindowEnd, input.reason,
    ],
  );
  return r.rows[0]!;
}

export async function findScheduleChange(id: string): Promise<{ id: string; movingJobId: string; status: string; proposedDate: string; proposedWindowStart: string | null; proposedWindowEnd: string | null } | null> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", status::text AS status, proposed_date AS "proposedDate",
            proposed_window_start AS "proposedWindowStart", proposed_window_end AS "proposedWindowEnd"
       FROM moving_job_schedule_changes WHERE id = $1`,
    [id],
  );
  return (r.rows[0] as never) ?? null;
}

export async function resolveScheduleChange(
  client: PoolClient,
  id: string,
  accept: boolean,
  decidedBy: string,
): Promise<void> {
  await client.query(
    `UPDATE moving_job_schedule_changes
        SET status = $2::moving_change_status, decided_by = $3, decided_at = NOW()
      WHERE id = $1 AND status = 'pending'`,
    [id, accept ? 'accepted' : 'rejected', decidedBy],
  );
  if (accept) {
    // Apply the new agreed schedule (previous schedule is preserved in history row).
    const sc = await findScheduleChange(id);
    if (sc) {
      await client.query(
        `UPDATE moving_jobs SET agreed_move_date = $2, agreed_window_start = $3, agreed_window_end = $4 WHERE id = $1`,
        [sc.movingJobId, sc.proposedDate, sc.proposedWindowStart, sc.proposedWindowEnd],
      );
    }
  }
}

// ---- Amendments ----
export async function insertAmendment(
  client: PoolClient,
  input: {
    jobId: string;
    proposedBy: string;
    reason: string;
    revisedScope: Record<string, unknown>;
    additionalCost: string;
    currency: string;
  },
): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO moving_job_amendments (moving_job_id, proposed_by, reason, revised_scope, additional_cost, currency)
     VALUES ($1,$2,$3,$4::jsonb,$5,$6) RETURNING id`,
    [input.jobId, input.proposedBy, input.reason, JSON.stringify(input.revisedScope), input.additionalCost, input.currency],
  );
  return r.rows[0]!;
}

export async function findAmendment(id: string): Promise<{ id: string; movingJobId: string; status: string; revisedScope: Record<string, unknown>; additionalCost: string; currency: string } | null> {
  const r = await pool.query(
    `SELECT id, moving_job_id AS "movingJobId", status::text AS status, revised_scope AS "revisedScope",
            additional_cost::text AS "additionalCost", currency
       FROM moving_job_amendments WHERE id = $1`,
    [id],
  );
  return (r.rows[0] as never) ?? null;
}

export async function resolveAmendment(
  client: PoolClient,
  id: string,
  accept: boolean,
  decidedBy: string,
): Promise<void> {
  await client.query(
    `UPDATE moving_job_amendments
        SET status = $2::moving_change_status, decided_by = $3, decided_at = NOW()
      WHERE id = $1 AND status = 'pending'`,
    [id, accept ? 'accepted' : 'rejected', decidedBy],
  );
  if (accept) {
    const am = await findAmendment(id);
    if (am) {
      const current = await client.query<{ scope: Record<string, unknown>; price: string }>(
        `SELECT scope, agreed_price::text AS price FROM moving_jobs WHERE id = $1`,
        [am.movingJobId],
      );
      const mergedScope = { ...(current.rows[0]?.scope ?? {}), ...am.revisedScope };
      const newPrice = (Number(current.rows[0]?.price ?? 0) + Number(am.additionalCost)).toFixed(2);
      await client.query(`UPDATE moving_jobs SET scope = $2::jsonb, agreed_price = $3 WHERE id = $1`, [
        am.movingJobId,
        JSON.stringify(mergedScope),
        newPrice,
      ]);
    }
  }
}

// ---- Checklist ----
export async function mergeChecklist(client: PoolClient, jobId: string, items: Record<string, boolean>): Promise<void> {
  await client.query(
    `UPDATE moving_jobs SET checklist = (COALESCE(checklist, '{}'::jsonb) || $2::jsonb) WHERE id = $1`,
    [jobId, JSON.stringify(items)],
  );
}

// ---- Attachments ----
export async function insertAttachments(
  client: PoolClient,
  jobId: string,
  documentIds: string[],
  kind: string,
  uploadedBy: string,
): Promise<void> {
  for (const docId of documentIds) {
    await client.query(
      `INSERT INTO moving_job_attachments (moving_job_id, document_id, kind, uploaded_by)
       VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
      [jobId, docId, kind, uploadedBy],
    );
  }
}

// ---- Completion ----
export async function submitCompletion(
  client: PoolClient,
  jobId: string,
  input: { notes: string | null; outstandingIssue: boolean; checklist?: Record<string, boolean> },
): Promise<void> {
  await client.query(
    `UPDATE moving_jobs
        SET completion_notes = $2, completion_outstanding_issue = $3,
            completion_submitted_at = NOW(),
            checklist = COALESCE(checklist, '{}'::jsonb) || $4::jsonb
      WHERE id = $1`,
    [jobId, input.notes, input.outstandingIssue, JSON.stringify(input.checklist ?? {})],
  );
}

export async function recordCustomerConfirmation(
  client: PoolClient,
  jobId: string,
  input: { confirm: boolean; notes: string | null },
): Promise<void> {
  await client.query(
    `UPDATE moving_jobs
        SET customer_confirmation_status = $2,
            customer_confirmation_notes = $3,
            customer_confirmation_at = NOW()
      WHERE id = $1`,
    [jobId, input.confirm ? 'confirmed' : 'exception', input.notes],
  );
}