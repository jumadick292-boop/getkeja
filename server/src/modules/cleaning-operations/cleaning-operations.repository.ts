// Cleaning & Property Care repository (Task 13.13).
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  CleaningAmendment,
  CleaningArea,
  CleaningAssessment,
  CleaningAttachment,
  CleaningChecklist,
  CleaningChecklistItem,
  CleaningException,
  CleaningHistoryEntry,
  CleaningJob,
  CleaningJobDetail,
  CleaningMaterial,
  CleaningOperationStatus,
  CleaningStaffAssignment,
} from './cleaning-operations.types.js';

function mapJob(row: Record<string, unknown>): CleaningJob {
  return {
    id: row.id as string,
    serviceRequestId: row.serviceRequestId as string,
    quotationId: row.quotationId as string,
    quotationVersion: row.quotationVersion as number,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    status: row.status as CleaningOperationStatus,
    categoryId: row.categoryId as string,
    domain: row.domain as string,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    tenancyId: (row.tenancyId as string) ?? null,
    serviceAddress: (row.serviceAddress as string) ?? null,
    agreedPrice: row.agreedPrice as string,
    currency: row.currency as string,
    scope: (row.scope as Record<string, unknown>) ?? {},
    assessmentRequired: (row.assessmentRequired as boolean) ?? false,
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
         assessment_required AS "assessmentRequired", customer_approval_required AS "customerApprovalRequired",
         completion_notes AS "completionNotes", completion_submitted_at AS "completionSubmittedAt",
         customer_confirmation_status AS "customerConfirmationStatus",
         customer_confirmation_notes AS "customerConfirmationNotes",
         customer_confirmation_at AS "customerConfirmationAt", cancelled_at AS "cancelledAt",
         cancellation_reason AS "cancellationReason", failed_at AS "failedAt",
         failure_reason AS "failureReason", created_at AS "createdAt", updated_at AS "updatedAt"
  FROM cleaning_jobs`;

export async function findJobById(id: string): Promise<CleaningJob | null> {
  const r = await pool.query(`${JOB_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapJob(r.rows[0]) : null;
}

export async function findJobByRequestId(requestId: string): Promise<CleaningJob | null> {
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
}): Promise<{ rows: CleaningJob[]; total: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  let i = 1;
  if (filter.customerUserId) { where.push(`customer_user_id = $${i++}`); params.push(filter.customerUserId); }
  if (filter.providerProfileId) { where.push(`provider_profile_id = $${i++}`); params.push(filter.providerProfileId); }
  if (filter.staffUserId) {
    where.push(`(assigned_staff_user_id = $${i} OR EXISTS (SELECT 1 FROM cleaning_staff_assignments s WHERE s.job_id = cleaning_jobs.id AND s.user_id = $${i} AND s.is_active))`);
    params.push(filter.staffUserId); i += 1;
  }
  if (filter.status) { where.push(`status::text = $${i++}`); params.push(filter.status); }
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM cleaning_jobs ${clause}`, params);
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
}): Promise<{ rows: CleaningJob[]; total: number }> {
  const where: string[] = ['(assigned_staff_user_id = $1 OR EXISTS (SELECT 1 FROM cleaning_staff_assignments s WHERE s.job_id = cleaning_jobs.id AND s.user_id = $1 AND s.is_active))'];
  const params: unknown[] = [filter.staffUserId];
  let i = 2;
  if (filter.profileIds.length) {
    where.push(`provider_profile_id = ANY($${i++}::uuid[])`);
    params.push(filter.profileIds);
  } else {
    where.push('FALSE');
  }
  if (filter.status) { where.push(`status::text = $${i++}`); params.push(filter.status); }
  const clause = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM cleaning_jobs ${clause}`, params);
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
  assessmentRequired: boolean;
  createdBy: string;
}

export async function insertJob(client: PoolClient, row: InsertJobRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO cleaning_jobs
       (service_request_id, quotation_id, quotation_version, customer_user_id, provider_profile_id,
        provider_organisation_id, category_id, domain, property_id, unit_id, tenancy_id,
        service_address, agreed_price, currency, scope, assessment_required, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
     RETURNING id`,
    [row.serviceRequestId, row.quotationId, row.quotationVersion, row.customerUserId,
      row.providerProfileId, row.providerOrganisationId, row.categoryId, row.domain,
      row.propertyId, row.unitId, row.tenancyId, row.serviceAddress, row.agreedPrice,
      row.currency, row.scope, row.assessmentRequired, row.createdBy],
  );
  return r.rows[0]!;
}

export async function insertHistory(client: PoolClient, row: {
  jobId: string; action: string; changedBy: string;
  previousStatus?: CleaningOperationStatus | null; newStatus?: CleaningOperationStatus | null;
  changeReason?: string | null; metadata?: Record<string, unknown>;
}): Promise<void> {
  await client.query(
    `INSERT INTO cleaning_job_history
       (job_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [row.jobId, row.action, row.previousStatus ?? null, row.newStatus ?? null,
      row.changedBy, row.changeReason ?? null, row.metadata ?? {}],
  );
}

export async function updateStatus(id: string, status: CleaningOperationStatus, extra?: Record<string, unknown>): Promise<void> {
  const fields: string[] = ['status = $2', 'updated_at = NOW()'];
  const params: unknown[] = [id, status];
  let i = 3;
  for (const [k, v] of Object.entries(extra ?? {})) {
    fields.push(`${k} = $${i++}`);
    params.push(v);
  }
  await pool.query(`UPDATE cleaning_jobs SET ${fields.join(', ')} WHERE id = $1`, params);
}

export async function setAssignedStaff(id: string, userId: string | null): Promise<void> {
  await pool.query(`UPDATE cleaning_jobs SET assigned_staff_user_id = $2, updated_at = NOW() WHERE id = $1`, [id, userId]);
}

// ---- Assessments ----
export async function insertAssessment(client: PoolClient, row: {
  jobId: string; assessorUserId: string | null; status: string; scheduledAt: string | null;
  findings: string | null; scopeAssessment: string | null; recommendedTasks: string | null;
  estimatedDurationMinutes: number | null; suppliesRequired: string | null; safetyConcerns: string | null;
  customerVisibleReport: string | null; internalNotes: string | null; photoDocumentIds: string[]; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO cleaning_assessments
       (job_id, assessor_user_id, status, scheduled_at, findings, scope_assessment, recommended_tasks,
        estimated_duration_minutes, supplies_required, safety_concerns, customer_visible_report,
        internal_notes, photo_document_ids, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING id`,
    [row.jobId, row.assessorUserId, row.status, row.scheduledAt, row.findings, row.scopeAssessment,
      row.recommendedTasks, row.estimatedDurationMinutes, row.suppliesRequired, row.safetyConcerns,
      row.customerVisibleReport, row.internalNotes, row.photoDocumentIds, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listAssessments(jobId: string): Promise<CleaningAssessment[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", assessor_user_id AS "assessorUserId", status, scheduled_at AS "scheduledAt",
            findings, scope_assessment AS "scopeAssessment", recommended_tasks AS "recommendedTasks",
            estimated_duration_minutes AS "estimatedDurationMinutes", supplies_required AS "suppliesRequired",
            safety_concerns AS "safetyConcerns", customer_visible_report AS "customerVisibleReport",
            internal_notes AS "internalNotes", photo_document_ids AS "photoDocumentIds",
            created_by AS "createdBy", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM cleaning_assessments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningAssessment[];
}

// ---- Checklists ----
export async function insertChecklist(client: PoolClient, row: {
  jobId: string; title: string; items: CleaningChecklistItem[]; createdBy: string;
}): Promise<{ id: string }> {
  const total = row.items.length;
  const done = row.items.filter((i) => i.done).length;
  const r = await client.query<{ id: string }>(
    `INSERT INTO cleaning_checklists (job_id, title, items, completed_count, total_count, created_by)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [row.jobId, row.title, JSON.stringify(row.items), done, total, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listChecklists(jobId: string): Promise<CleaningChecklist[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", title, items, completed_count AS "completedCount",
            total_count AS "totalCount", status, created_by AS "createdBy",
            created_at AS "createdAt", updated_at AS "updatedAt"
       FROM cleaning_checklists WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningChecklist[];
}

export async function updateChecklistItem(jobId: string, checklistId: string, itemId: string, done: boolean): Promise<void> {
  // Postgres evaluates all SET subqueries against the pre-update snapshot, so the
  // done flag is applied first, then counts are recomputed from the new items.
  await pool.query(
    `UPDATE cleaning_checklists
        SET items = (
              SELECT jsonb_agg(
                CASE WHEN item->>'id' = $3
                  THEN jsonb_set(item, '{done}', to_jsonb($4::boolean))
                  ELSE item END
              )
              FROM jsonb_array_elements(items) AS item
            ),
            updated_at = NOW()
      WHERE id = $1 AND job_id = $2`,
    [checklistId, jobId, itemId, done],
  );
  await pool.query(
    `UPDATE cleaning_checklists
        SET completed_count = (
              SELECT COUNT(*) FROM jsonb_array_elements(items) AS item WHERE (item->>'done')::boolean
            ),
            status = CASE WHEN (
              SELECT COUNT(*) FROM jsonb_array_elements(items) AS item WHERE (item->>'done')::boolean
            ) = total_count THEN 'completed' ELSE 'in_progress' END,
            updated_at = NOW()
      WHERE id = $1 AND job_id = $2`,
    [checklistId, jobId],
  );
}

// ---- Areas ----
export async function insertArea(client: PoolClient, row: {
  jobId: string; name: string; areaType: string; approximateSize: string | null;
  status: string; notes: string | null; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO cleaning_areas (job_id, name, area_type, approximate_size, status, notes, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [row.jobId, row.name, row.areaType, row.approximateSize, row.status, row.notes, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listAreas(jobId: string): Promise<CleaningArea[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", name, area_type AS "areaType", approximate_size AS "approximateSize",
            status, notes, created_by AS "createdBy", created_at AS "createdAt"
       FROM cleaning_areas WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningArea[];
}

// ---- Materials ----
export async function insertMaterial(client: PoolClient, row: {
  jobId: string; description: string; quantity: string; unit: string;
  suppliedBy: string; proposedCost: string | null; notes: string | null; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO cleaning_materials
       (job_id, description, quantity, unit, supplied_by, proposed_cost, notes, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
    [row.jobId, row.description, row.quantity, row.unit, row.suppliedBy, row.proposedCost, row.notes, row.createdBy],
  );
  return r.rows[0]!;
}

export async function listMaterials(jobId: string): Promise<CleaningMaterial[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", description, quantity::text AS quantity, unit,
            supplied_by AS "suppliedBy", proposed_cost::text AS "proposedCost", approval_status AS "approvalStatus",
            notes, created_by AS "createdBy", created_at AS "createdAt"
       FROM cleaning_materials WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningMaterial[];
}

export async function setMaterialApproval(jobId: string, materialId: string, status: string): Promise<void> {
  await pool.query(`UPDATE cleaning_materials SET approval_status = $3 WHERE id = $1 AND job_id = $2`, [materialId, jobId, status]);
}

// ---- Staff ----
export async function insertStaff(client: PoolClient, row: {
  jobId: string; userId: string; label: string | null; assignedBy: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO cleaning_staff_assignments (job_id, user_id, label, assigned_by)
     VALUES ($1,$2,$3,$4) ON CONFLICT (job_id, user_id) WHERE is_active DO NOTHING`,
    [row.jobId, row.userId, row.label, row.assignedBy],
  );
}

export async function listStaff(jobId: string): Promise<CleaningStaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", label, is_active AS "isActive", assigned_by AS "assignedBy",
            created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM cleaning_staff_assignments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningStaffAssignment[];
}

export async function revokeStaff(jobId: string, userId: string, revokedBy: string): Promise<void> {
  await pool.query(
    `UPDATE cleaning_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $3
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
    `INSERT INTO cleaning_amendments (job_id, proposed_by, reason, revised_scope, additional_cost, currency)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
    [row.jobId, row.proposedBy, row.reason, row.revisedScope, row.additionalCost, row.currency],
  );
  return r.rows[0]!;
}

export async function listAmendments(jobId: string): Promise<CleaningAmendment[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", proposed_by AS "proposedBy", reason, revised_scope AS "revisedScope",
            additional_cost::text AS "additionalCost", currency, status, decided_by AS "decidedBy",
            decided_at AS "decidedAt", created_at AS "createdAt"
       FROM cleaning_amendments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningAmendment[];
}

export async function decideAmendment(jobId: string, amendmentId: string, status: string, decidedBy: string): Promise<void> {
  await pool.query(
    `UPDATE cleaning_amendments SET status = $3, decided_by = $4, decided_at = NOW()
      WHERE id = $1 AND job_id = $2`,
    [amendmentId, jobId, status, decidedBy],
  );
}

// ---- Exceptions ----
export async function insertException(client: PoolClient, row: {
  jobId: string; reportedBy: string; type: string; description: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO cleaning_exceptions (job_id, reported_by, type, description) VALUES ($1,$2,$3,$4)`,
    [row.jobId, row.reportedBy, row.type, row.description],
  );
}

export async function listExceptions(jobId: string): Promise<CleaningException[]> {
  const r = await pool.query(
    `SELECT id, job_id AS "jobId", reported_by AS "reportedBy", type, description, created_at AS "createdAt"
       FROM cleaning_exceptions WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningException[];
}

// ---- Attachments ----
export async function insertAttachment(client: PoolClient, row: {
  jobId: string; documentId: string; kind: string; uploadedBy: string;
}): Promise<void> {
  await client.query(
    `INSERT INTO cleaning_attachments (job_id, document_id, kind, uploaded_by) VALUES ($1,$2,$3,$4)`,
    [row.jobId, row.documentId, row.kind, row.uploadedBy],
  );
}

export async function listAttachments(jobId: string): Promise<CleaningAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM cleaning_attachments WHERE job_id = $1 ORDER BY created_at`,
    [jobId],
  );
  return r.rows as unknown as CleaningAttachment[];
}

// ---- Detail ----
export async function getJobDetail(job: CleaningJob): Promise<CleaningJobDetail> {
  const [history, assessments, checklists, areas, materials, staff, amendments, exceptions, attachments] = await Promise.all([
    pool.query(
      `SELECT id, action, previous_status AS "previousStatus", new_status AS "newStatus", changed_by AS "changedBy",
              change_reason AS "changeReason", metadata, created_at AS "createdAt"
         FROM cleaning_job_history WHERE job_id = $1 ORDER BY created_at`,
      [job.id],
    ),
    listAssessments(job.id),
    listChecklists(job.id),
    listAreas(job.id),
    listMaterials(job.id),
    listStaff(job.id),
    listAmendments(job.id),
    listExceptions(job.id),
    listAttachments(job.id),
  ]);
  return {
    ...job,
    history: history.rows as unknown as CleaningHistoryEntry[],
    assessments,
    checklists,
    areas,
    materials,
    staff,
    amendments,
    exceptions,
    attachments,
  };
}