// Home Maintenance & Repairs repository (Task 13.12).
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  HomeMaintenanceAmendment,
  HomeMaintenanceAttachment,
  HomeMaintenanceException,
  HomeMaintenanceHistoryEntry,
  HomeMaintenanceInspection,
  HomeMaintenanceJob,
  HomeMaintenanceJobDetail,
  HomeMaintenancePart,
  HomeMaintenanceStaffAssignment,
  HomeMaintenanceStatus,
  HomeMaintenanceWorkPlan,
} from './home-maintenance.types.js';

function mapJob(row: Record<string, unknown>): HomeMaintenanceJob {
  return {
    id: row.id as string,
    serviceRequestId: row.serviceRequestId as string,
    quotationId: row.quotationId as string,
    quotationVersion: row.quotationVersion as number,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    status: row.status as HomeMaintenanceStatus,
    categoryId: row.categoryId as string,
    domain: row.domain as string,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    tenancyId: (row.tenancyId as string) ?? null,
    serviceAddress: (row.serviceAddress as string) ?? null,
    agreedPrice: row.agreedPrice as string,
    currency: row.currency as string,
    scope: (row.scope as Record<string, unknown>) ?? {},
    inspectionRequired: (row.inspectionRequired as boolean) ?? false,
    customerApprovalRequired: (row.customerApprovalRequired as boolean) ?? true,
    completionNotes: (row.completionNotes as string) ?? null,
    completionSubmittedAt: (row.completionSubmittedAt as string) ?? null,
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
         category_id AS "categoryId", domain, property_id AS "propertyId", unit_id AS "unitId",
         tenancy_id AS "tenancyId", service_address AS "serviceAddress",
         agreed_price::text AS "agreedPrice", currency, scope,
         inspection_required AS "inspectionRequired", customer_approval_required AS "customerApprovalRequired",
         completion_notes AS "completionNotes", completion_submitted_at AS "completionSubmittedAt",
         customer_confirmation_status AS "customerConfirmationStatus",
         customer_confirmation_notes AS "customerConfirmationNotes",
         customer_confirmation_at AS "customerConfirmationAt", cancelled_at AS "cancelledAt",
         cancellation_reason AS "cancellationReason", failed_at AS "failedAt",
         failure_reason AS "failureReason", created_at AS "createdAt", updated_at AS "updatedAt"
  FROM home_maintenance_jobs`;

export async function findJobById(id: string): Promise<HomeMaintenanceJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findJobByRequestId(requestId: string): Promise<HomeMaintenanceJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE service_request_id = $1`, [requestId]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findAcceptedQuotation(requestId: string): Promise<{
  id: string; versionNumber: number; providerProfileId: string; totalAmount: string; currency: string; status: string;
} | null> {
  const r = await pool.query(
    `SELECT id, version_number AS "versionNumber", provider_profile_id AS "providerProfileId",
            total_amount::text AS "totalAmount", currency, status::text AS status
       FROM service_quotations WHERE service_request_id = $1 AND status = 'accepted'
      ORDER BY version_number DESC LIMIT 1`,
    [requestId],
  );
  return (r.rows[0] as never) ?? null;
}

export async function listJobs(filter: {
  customerUserId?: string;
  providerProfileId?: string;
  staffUserId?: string;
  status?: string;
  limit: number;
  offset: number;
}): Promise<{ rows: HomeMaintenanceJob[]; total: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  let i = 1;
  if (filter.customerUserId) { where.push(`customer_user_id = $${i++}`); params.push(filter.customerUserId); }
  if (filter.providerProfileId) { where.push(`provider_profile_id = $${i++}`); params.push(filter.providerProfileId); }
  if (filter.staffUserId) {
    where.push(`(assigned_staff_user_id = $${i} OR EXISTS (SELECT 1 FROM home_maintenance_staff_assignments s WHERE s.job_id = home_maintenance_jobs.id AND s.user_id = $${i} AND s.is_active))`);
    params.push(filter.staffUserId); i += 1;
  }
  if (filter.status) { where.push(`status::text = $${i++}`); params.push(filter.status); }
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM home_maintenance_jobs ${clause}`, params);
  const rows = await pool.query(
    `${JOB_SELECT} ${clause} ORDER BY created_at DESC LIMIT $${i++} OFFSET $${i}`,
    [...params, filter.limit, filter.offset],
  );
  return { rows: rows.rows.map((r) => mapJob(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export async function listProviderJobs(filter: {
  profileIds: string[];
  staffUserId: string;
  status?: string;
  limit: number;
  offset: number;
}): Promise<{ rows: HomeMaintenanceJob[]; total: number }> {
  const where: string[] = ['(assigned_staff_user_id = $1 OR EXISTS (SELECT 1 FROM home_maintenance_staff_assignments s WHERE s.job_id = home_maintenance_jobs.id AND s.user_id = $1 AND s.is_active))'];
  const params: unknown[] = [filter.staffUserId];
  let i = 2;
  if (filter.profileIds.length) {
    where.push(`provider_profile_id = ANY($${i++}::uuid[])`);
    params.push(filter.profileIds);
  } else {
    // No owned profiles: restrict to assigned-staff rows only.
    where.push('FALSE');
  }
  if (filter.status) { where.push(`status::text = $${i++}`); params.push(filter.status); }
  const clause = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM home_maintenance_jobs ${clause}`, params);
  const rows = await pool.query(
    `${JOB_SELECT} ${clause} ORDER BY created_at DESC LIMIT $${i++} OFFSET $${i}`,
    [...params, filter.limit, filter.offset],
  );
  return { rows: rows.rows.map((r) => mapJob(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export interface InsertJobRow {
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  categoryId: string;
  domain: string;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  serviceAddress: string | null;
  agreedPrice: string;
  currency: string;
  scope: Record<string, unknown>;
  inspectionRequired: boolean;
  createdBy: string;
}

export async function insertJob(client: PoolClient, row: InsertJobRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO home_maintenance_jobs
       (service_request_id, quotation_id, quotation_version, customer_user_id, provider_profile_id,
        provider_organisation_id, category_id, domain, property_id, unit_id, tenancy_id,
        service_address, agreed_price, currency, scope, inspection_required, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
     RETURNING id`,
    [row.serviceRequestId, row.quotationId, row.quotationVersion, row.customerUserId,
      row.providerProfileId, row.providerOrganisationId, row.categoryId, row.domain,
      row.propertyId, row.unitId, row.tenancyId, row.serviceAddress, row.agreedPrice,
      row.currency, row.scope, row.inspectionRequired, row.createdBy],
  );
  return r.rows[0]!;
}

export async function insertHistory(client: PoolClient, row: {
  jobId: string; action: string; changedBy: string;
  previousStatus?: HomeMaintenanceStatus | null; newStatus?: HomeMaintenanceStatus | null;
  changeReason?: string | null; metadata?: Record<string, unknown>;
}): Promise<void> {
  await client.query(
    `INSERT INTO home_maintenance_job_history
       (job_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [row.jobId, row.action, row.previousStatus ?? null, row.newStatus ?? null,
      row.changedBy, row.changeReason ?? null, row.metadata ?? {}],
  );
}

export async function updateStatus(id: string, status: HomeMaintenanceStatus, extra?: Record<string, unknown>): Promise<void> {
  const fields: string[] = ['status = $2', 'updated_at = NOW()'];
  const params: unknown[] = [id, status];
  let i = 3;
  for (const [k, v] of Object.entries(extra ?? {})) {
    fields.push(`${k} = $${i++}`);
    params.push(v);
  }
  await pool.query(`UPDATE home_maintenance_jobs SET ${fields.join(', ')} WHERE id = $1`, params);
}

export async function setAssignedStaff(id: string, userId: string | null): Promise<void> {
  await pool.query(`UPDATE home_maintenance_jobs SET assigned_staff_user_id = $2, updated_at = NOW() WHERE id = $1`, [id, userId]);
}

// ---- Inspections ----
export async function insertInspection(client: PoolClient, row: {
  jobId: string; technicianUserId: string | null; status: string; scheduledAt: string | null;
  findings: string | null; diagnosis: string | null; recommendedWork: string | null;
  estimatedDurationMinutes: number | null; materialsRequired: string | null; safetyConcerns: string | null;
  customerVisibleReport: string | null; internalNotes: string | null; photoDocumentIds: string[]; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO home_maintenance_inspections
       (job_id, technician_user_id, status, scheduled_at, findings, diagnosis, recommended_work,
        estimated_duration_minutes, materials_required, safety_concerns, customer_visible_report,
        internal_notes, photo_document_ids, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING id`,
    [row.jobId, row.technicianUserId, row.status, row.scheduledAt, row.findings, row.diagnosis,
      row.recommendedWork, row.estimatedDurationMinutes, row.materialsRequired, row.safetyConcerns,
      row.customerVisibleReport, row.internalNotes, row.photoDocumentIds, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listInspections(jobId: string): Promise<HomeMaintenanceInspection[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", technician_user_id AS "technicianUserId", status, scheduled_at AS "scheduledAt",
            findings, diagnosis, recommended_work AS "recommendedWork", estimated_duration_minutes AS "estimatedDurationMinutes",
            materials_required AS "materialsRequired", safety_concerns AS "safetyConcerns",
            customer_visible_report AS "customerVisibleReport", internal_notes AS "internalNotes",
            photo_document_ids AS "photoDocumentIds", created_by AS "createdBy", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM home_maintenance_inspections WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceInspection[];
}

// ---- Work plans ----
export async function insertWorkPlan(client: PoolClient, row: {
  jobId: string; summary: string; steps: unknown[]; scheduledAt: string | null; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO home_maintenance_work_plans (job_id, summary, steps, scheduled_at, created_by)
     VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    [row.jobId, row.summary, JSON.stringify(row.steps), row.scheduledAt, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listWorkPlans(jobId: string): Promise<HomeMaintenanceWorkPlan[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", summary, steps, scheduled_at AS "scheduledAt", status,
            created_by AS "createdBy", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM home_maintenance_work_plans WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceWorkPlan[];
}

// ---- Parts ----
export async function insertPart(client: PoolClient, row: {
  jobId: string; description: string; quantity: string; unit: string; modelSpec: string | null;
  suppliedBy: string; proposedCost: string | null; notes: string | null; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO home_maintenance_parts
       (job_id, description, quantity, unit, model_spec, supplied_by, proposed_cost, notes, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [row.jobId, row.description, row.quantity, row.unit, row.modelSpec, row.suppliedBy, row.proposedCost, row.notes, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listParts(jobId: string): Promise<HomeMaintenancePart[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", description, quantity::text AS quantity, unit, model_spec AS "modelSpec",
            supplied_by AS "suppliedBy", proposed_cost::text AS "proposedCost", approval_status AS "approvalStatus",
            notes, created_by AS "createdBy", created_at AS "createdAt"
       FROM home_maintenance_parts WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenancePart[];
}

export async function setPartApproval(jobId: string, partId: string, status: string): Promise<void> {
  await pool.query(`UPDATE home_maintenance_parts SET approval_status = $3 WHERE id = $1 AND job_id = $2`, [partId, jobId, status]);
}

// ---- Staff ----
export async function insertStaff(client: PoolClient, row: {
  jobId: string; userId: string; label: string | null; assignedBy: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO home_maintenance_staff_assignments (job_id, user_id, label, assigned_by)
     VALUES ($1,$2,$3,$4) ON CONFLICT (job_id, user_id) WHERE is_active DO NOTHING`,
    [row.jobId, row.userId, row.label, row.assignedBy],
  );
}

export async function listStaff(jobId: string): Promise<HomeMaintenanceStaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", label, is_active AS "isActive", assigned_by AS "assignedBy",
            created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM home_maintenance_staff_assignments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceStaffAssignment[];
}

export async function revokeStaff(jobId: string, userId: string, revokedBy: string): Promise<void> {
  await pool.query(
    `UPDATE home_maintenance_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $3
      WHERE job_id = $1 AND user_id = $2 AND is_active`,
    [jobId, userId, revokedBy],
  );
}

// ---- Amendments ----
export async function insertAmendment(client: PoolClient, row: {
  jobId: string; proposedBy: string; reason: string; revisedScope: Record<string, unknown>;
  additionalCost: string; currency: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO home_maintenance_amendments (job_id, proposed_by, reason, revised_scope, additional_cost, currency)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [row.jobId, row.proposedBy, row.reason, row.revisedScope, row.additionalCost, row.currency],
  );
  return r.rows[0]!;
}

export async function listAmendments(jobId: string): Promise<HomeMaintenanceAmendment[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", proposed_by AS "proposedBy", reason, revised_scope AS "revisedScope",
            additional_cost::text AS "additionalCost", currency, status, decided_by AS "decidedBy",
            decided_at AS "decidedAt", created_at AS "createdAt"
       FROM home_maintenance_amendments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceAmendment[];
}

export async function decideAmendment(jobId: string, amendmentId: string, status: string, decidedBy: string): Promise<void> {
  await pool.query(
    `UPDATE home_maintenance_amendments SET status = $3, decided_by = $4, decided_at = NOW()
      WHERE id = $1 AND job_id = $2`,
    [amendmentId, jobId, status, decidedBy],
  );
}

// ---- Exceptions ----
export async function insertException(client: PoolClient, row: {
  jobId: string; reportedBy: string; type: string; description: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO home_maintenance_exceptions (job_id, reported_by, type, description) VALUES ($1,$2,$3,$4)`,
    [row.jobId, row.reportedBy, row.type, row.description],
  );
}

export async function listExceptions(jobId: string): Promise<HomeMaintenanceException[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", reported_by AS "reportedBy", type, description, created_at AS "createdAt"
       FROM home_maintenance_exceptions WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceException[];
}

// ---- Attachments ----
export async function insertAttachment(client: PoolClient, row: {
  jobId: string; documentId: string; kind: string; uploadedBy: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO home_maintenance_attachments (job_id, document_id, kind, uploaded_by) VALUES ($1,$2,$3,$4)`,
    [row.jobId, row.documentId, row.kind, row.uploadedBy],
  );
}

export async function listAttachments(jobId: string): Promise<HomeMaintenanceAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM home_maintenance_attachments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as HomeMaintenanceAttachment[];
}

// ---- Detail ----
export async function getJobDetail(job: HomeMaintenanceJob): Promise<HomeMaintenanceJobDetail> {
  const [history, inspections, workPlans, parts, staff, amendments, exceptions, attachments] = await Promise.all([
    pool.query(
      `SELECT id, action, previous_status AS "previousStatus", new_status AS "newStatus", changed_by AS "changedBy",
              change_reason AS "changeReason", metadata, created_at AS "createdAt"
         FROM home_maintenance_job_history WHERE job_id = $1 ORDER BY created_at`,
      [job.id],
    ),
    listInspections(job.id),
    listWorkPlans(job.id),
    listParts(job.id),
    listStaff(job.id),
    listAmendments(job.id),
    listExceptions(job.id),
    listAttachments(job.id),
  ]);
  return {
    ...job,
    history: history.rows as unknown as HomeMaintenanceHistoryEntry[],
    inspections,
    workPlans,
    parts,
    staff,
    amendments,
    exceptions,
    attachments,
  };
}