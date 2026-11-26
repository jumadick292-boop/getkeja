// Rental application repository: SQL helpers for the lifecycle service.
//
// Reuses the existing `rental_applications` table (migrations 048 + 093) and
// its history/notes/documents side tables. All status changes flow through the
// service layer so the history trigger (migration 093) and notifications fire
// consistently.

import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import { pool } from '../../db/pool.js';

export const APPLICATION_COLUMNS = `id, property_id as "propertyId", unit_id as "unitId",
  user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail",
  applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber",
  applicant_id_type as "applicantIdType", status,
  preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate",
  proposed_rent_amount as "proposedRentAmount", documents,
  employer_name as "employerName", employer_contact as "employerContact",
  monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName",
  previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName",
  guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone",
  guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship",
  reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes",
  rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt",
  approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount",
  approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate",
  tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"`;

// Same projection qualified with the `a` alias for joins against properties.
const APPLICATION_COLUMNS_A = `a.id, a.property_id as "propertyId", a.unit_id as "unitId",
  a.user_id as "userId", a.applicant_name as "applicantName", a.applicant_email as "applicantEmail",
  a.applicant_phone as "applicantPhone", a.applicant_id_number as "applicantIdNumber",
  a.applicant_id_type as "applicantIdType", a.status,
  a.preferred_start_date as "preferredStartDate", a.preferred_end_date as "preferredEndDate",
  a.proposed_rent_amount as "proposedRentAmount", a.documents,
  a.employer_name as "employerName", a.employer_contact as "employerContact",
  a.monthly_income as "monthlyIncome", a.previous_landlord_name as "previousLandlordName",
  a.previous_landlord_contact as "previousLandlordContact", a.guarantor_name as "guarantorName",
  a.guarantor_email as "guarantorEmail", a.guarantor_phone as "guarantorPhone",
  a.guarantor_id_number as "guarantorIdNumber", a.guarantor_relationship as "guarantorRelationship",
  a.reviewed_by as "reviewedBy", a.reviewed_at as "reviewedAt", a.review_notes as "reviewNotes",
  a.rejection_reason as "rejectionReason", a.approved_by as "approvedBy", a.approved_at as "approvedAt",
  a.approved_rent_amount as "approvedRentAmount", a.approved_deposit_amount as "approvedDepositAmount",
  a.approved_start_date as "approvedStartDate", a.approved_end_date as "approvedEndDate",
  a.tenancy_id as "tenancyId", a.created_at as "createdAt", a.updated_at as "updatedAt"`;

export type Executor = PoolClient | typeof pool;

export interface ApplicationRow {
  id: string;
  propertyId: string;
  unitId: string | null;
  userId: string | null;
  applicantName: string;
  applicantEmail: string;
  applicantPhone: string;
  applicantIdNumber: string | null;
  applicantIdType: string | null;
  status: string;
  preferredStartDate: Date | null;
  preferredEndDate: Date | null;
  proposedRentAmount: number | null;
  documents: Record<string, unknown> | null;
  employerName: string | null;
  employerContact: string | null;
  monthlyIncome: number | null;
  previousLandlordName: string | null;
  previousLandlordContact: string | null;
  guarantorName: string | null;
  guarantorEmail: string | null;
  guarantorPhone: string | null;
  guarantorIdNumber: string | null;
  guarantorRelationship: string | null;
  reviewedBy: string | null;
  reviewedAt: Date | null;
  reviewNotes: string | null;
  rejectionReason: string | null;
  approvedBy: string | null;
  approvedAt: Date | null;
  approvedRentAmount: number | null;
  approvedDepositAmount: number | null;
  approvedStartDate: Date | null;
  approvedEndDate: Date | null;
  tenancyId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function findApplication(
  executor: Executor,
  applicationId: string,
  forUpdate = false,
): Promise<ApplicationRow | undefined> {
  const result = await executor.query<ApplicationRow>(
    `SELECT ${APPLICATION_COLUMNS} FROM rental_applications WHERE id = $1${forUpdate ? ' FOR UPDATE' : ''}`,
    [applicationId],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Creation (client-aware, supports draft + submitted)
// ---------------------------------------------------------------------------

export interface InsertApplicationData {
  propertyId: string;
  unitId: string | null;
  userId: string;
  applicantName: string;
  applicantEmail: string;
  applicantPhone: string;
  status: 'draft' | 'submitted';
  preferredStartDate?: Date | null;
  preferredEndDate?: Date | null;
  proposedRentAmount?: number | null;
  employerName?: string | null;
  employerContact?: string | null;
  monthlyIncome?: number | null;
  previousLandlordName?: string | null;
  previousLandlordContact?: string | null;
  guarantorName?: string | null;
  guarantorEmail?: string | null;
  guarantorPhone?: string | null;
  guarantorRelationship?: string | null;
  documents?: Record<string, unknown> | null;
}

export async function insertApplication(
  executor: Executor,
  data: InsertApplicationData,
): Promise<ApplicationRow> {
  const result = await executor.query<ApplicationRow>(
    `INSERT INTO rental_applications
       (id, property_id, unit_id, user_id, applicant_name, applicant_email, applicant_phone,
        status, preferred_start_date, preferred_end_date, proposed_rent_amount,
        employer_name, employer_contact, monthly_income,
        previous_landlord_name, previous_landlord_contact,
        guarantor_name, guarantor_email, guarantor_phone, guarantor_relationship,
        documents, updated_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8::application_status,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$4)
     RETURNING ${APPLICATION_COLUMNS}`,
    [
      randomUUID(),
      data.propertyId,
      data.unitId,
      data.userId,
      data.applicantName,
      data.applicantEmail,
      data.applicantPhone,
      data.status,
      data.preferredStartDate ?? null,
      data.preferredEndDate ?? null,
      data.proposedRentAmount ?? null,
      data.employerName ?? null,
      data.employerContact ?? null,
      data.monthlyIncome ?? null,
      data.previousLandlordName ?? null,
      data.previousLandlordContact ?? null,
      data.guarantorName ?? null,
      data.guarantorEmail ?? null,
      data.guarantorPhone ?? null,
      data.guarantorRelationship ?? null,
      data.documents ?? null,
    ],
  );
  return result.rows[0]!;
}

export interface ManagerScope {
  isApplicant: boolean;
  isOwner: boolean;
  /** Active assignment types for this user on the property (e.g. property_manager). */
  assignmentTypes: string[];
  /** True when the user may perform manager-class actions (approve/reject/shortlist). */
  isManager: boolean;
}

// Assignment types that count as application-review authority. Caretakers,
// maintenance and security staff are intentionally excluded.
const APPROVAL_ASSIGNMENT_TYPES = new Set(['property_manager', 'letting_agent']);

export async function getManagerScope(
  executor: Executor,
  userId: string,
  application: Pick<ApplicationRow, 'propertyId' | 'userId'>,
): Promise<ManagerScope> {
  const isApplicant = application.userId === userId;

  const ownership = await executor.query<{ user_id: string }>(
    `SELECT user_id FROM property_ownerships
      WHERE property_id = $1 AND status = 'active' AND user_id = $2
        AND (effective_to IS NULL OR effective_to > NOW())`,
    [application.propertyId, userId],
  );
  const isOwner = ownership.rows.length > 0;

  const assignments = await executor.query<{ assignment_type: string }>(
    `SELECT assignment_type FROM property_assignments
      WHERE property_id = $1 AND status = 'active' AND user_id = $2
        AND (effective_to IS NULL OR effective_to > NOW())`,
    [application.propertyId, userId],
  );
  const assignmentTypes = assignments.rows.map((r) => r.assignment_type);

  const isManager =
    isOwner || assignmentTypes.some((t) => APPROVAL_ASSIGNMENT_TYPES.has(t));

  return { isApplicant, isOwner, assignmentTypes, isManager };
}

// ---------------------------------------------------------------------------
// Duplicate / competing application detection
// ---------------------------------------------------------------------------

/**
 * Whether the applicant already has an open (active) application for the same
 * property + unit. Used to prevent duplicate active applications.
 */
export async function hasActiveApplication(
  executor: Executor,
  userId: string,
  propertyId: string,
  unitId: string | null,
  excludeId?: string,
): Promise<boolean> {
  const params: unknown[] = [userId, propertyId];
  let unitClause = '';
  if (unitId) {
    params.push(unitId);
    unitClause = `AND unit_id = $${params.length}`;
  } else {
    unitClause = `AND unit_id IS NULL`;
  }
  let excludeClause = '';
  if (excludeId) {
    params.push(excludeId);
    excludeClause = `AND id <> $${params.length}`;
  }
  const result = await executor.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM rental_applications
      WHERE user_id = $1 AND property_id = $2 ${unitClause} ${excludeClause}
        AND status NOT IN ('withdrawn', 'rejected', 'expired', 'cancelled')`,
    params,
  );
  return Number(result.rows[0]?.count ?? '0') > 0;
}

/**
 * Whether another application (not `excludeId`) is already approved for the
 * same unit. This is the competing-approval guard: under a unit row lock two
 * concurrent approvals serialise and the second sees the first's approval.
 */
export async function hasCompetingApproved(
  executor: Executor,
  unitId: string,
  excludeId: string,
): Promise<boolean> {
  const result = await executor.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM rental_applications
      WHERE unit_id = $1 AND status = 'approved' AND id <> $2`,
    [unitId, excludeId],
  );
  return Number(result.rows[0]?.count ?? '0') > 0;
}

export async function findApprovedTenancyForUnit(
  executor: Executor,
  unitId: string,
): Promise<{ id: string } | undefined> {
  const result = await executor.query<{ id: string }>(
    `SELECT id FROM tenancies WHERE unit_id = $1 AND status = 'active' LIMIT 1`,
    [unitId],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// History / notes / documents
// ---------------------------------------------------------------------------

export interface HistoryRow {
  id: string;
  action: string;
  previousStatus: string | null;
  newStatus: string | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: Date;
}

export async function listApplicationHistory(
  applicationId: string,
): Promise<HistoryRow[]> {
  const result = await pool.query<HistoryRow>(
    `SELECT id, action, previous_status as "previousStatus", new_status as "newStatus",
            changed_by as "changedBy", change_reason as "changeReason", metadata, created_at as "createdAt"
       FROM rental_application_history
      WHERE application_id = $1
      ORDER BY created_at ASC`,
    [applicationId],
  );
  return result.rows;
}

export interface NoteRow {
  id: string;
  applicationId: string;
  authorId: string;
  note: string;
  isInternal: boolean;
  createdAt: Date;
}

export async function addApplicationNote(
  executor: Executor,
  applicationId: string,
  authorId: string,
  note: string,
  isInternal = true,
): Promise<NoteRow> {
  const result = await executor.query<NoteRow>(
    `INSERT INTO rental_application_notes (application_id, author_id, note, is_internal)
     VALUES ($1, $2, $3, $4)
     RETURNING id, application_id as "applicationId", author_id as "authorId", note,
               is_internal as "isInternal", created_at as "createdAt"`,
    [applicationId, authorId, note, isInternal],
  );
  return result.rows[0]!;
}

/**
 * List notes. When `internalOnly` is false, only applicant-visible notes are
 * returned (never internal staff notes). When omitted/true for managers, all
 * notes are returned.
 */
export async function listApplicationNotes(
  applicationId: string,
  opts?: { applicantView?: boolean },
): Promise<NoteRow[]> {
  const clause = opts?.applicantView ? `AND is_internal = FALSE` : '';
  const result = await pool.query<NoteRow>(
    `SELECT id, application_id as "applicationId", author_id as "authorId", note,
            is_internal as "isInternal", created_at as "createdAt"
       FROM rental_application_notes
      WHERE application_id = $1 ${clause}
      ORDER BY created_at ASC`,
    [applicationId],
  );
  return result.rows;
}

export interface ApplicationDocumentRow {
  id: string;
  applicationId: string;
  uploadedBy: string;
  storageKey: string;
  fileName: string;
  mimeType: string | null;
  fileSizeBytes: number | null;
  category: string;
  verificationStatus: string;
  createdAt: Date;
}

export async function insertApplicationDocument(
  executor: Executor,
  data: {
    applicationId: string;
    uploadedBy: string;
    storageKey: string;
    fileName: string;
    mimeType: string | null;
    fileSizeBytes: number | null;
    category: string;
  },
): Promise<ApplicationDocumentRow> {
  const result = await executor.query<ApplicationDocumentRow>(
    `INSERT INTO rental_application_documents
       (id, application_id, uploaded_by, storage_key, file_name, mime_type, file_size_bytes, category)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, application_id as "applicationId", uploaded_by as "uploadedBy",
               storage_key as "storageKey", file_name as "fileName", mime_type as "mimeType",
               file_size_bytes as "fileSizeBytes", category, verification_status as "verificationStatus",
               created_at as "createdAt"`,
    [
      randomUUID(),
      data.applicationId,
      data.uploadedBy,
      data.storageKey,
      data.fileName,
      data.mimeType,
      data.fileSizeBytes,
      data.category,
    ],
  );
  return result.rows[0]!;
}

export async function listApplicationDocuments(
  applicationId: string,
): Promise<Omit<ApplicationDocumentRow, 'storageKey'>[]> {
  const result = await pool.query<Omit<ApplicationDocumentRow, 'storageKey'>>(
    `SELECT id, application_id as "applicationId", uploaded_by as "uploadedBy",
            file_name as "fileName", mime_type as "mimeType", file_size_bytes as "fileSizeBytes",
            category, verification_status as "verificationStatus", created_at as "createdAt"
       FROM rental_application_documents
      WHERE application_id = $1
      ORDER BY created_at ASC`,
    [applicationId],
  );
  return result.rows;
}

export async function findApplicationDocument(
  documentId: string,
): Promise<ApplicationDocumentRow | undefined> {
  const result = await pool.query<ApplicationDocumentRow>(
    `SELECT id, application_id as "applicationId", uploaded_by as "uploadedBy",
            storage_key as "storageKey", file_name as "fileName", mime_type as "mimeType",
            file_size_bytes as "fileSizeBytes", category, verification_status as "verificationStatus",
            created_at as "createdAt"
       FROM rental_application_documents WHERE id = $1`,
    [documentId],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Inbox (landlord/manager)
// ---------------------------------------------------------------------------

export interface InboxFilters {
  propertyId?: string;
  unitId?: string;
  status?: string;
  fromDate?: Date;
  toDate?: Date;
  limit: number;
  offset: number;
}

/**
 * List applications for properties the user is an active owner or holds an
 * approval-class assignment on. Organization membership alone does not grant
 * access (the join requires explicit ownership/assignment rows).
 */
export async function listManagedApplications(
  managerUserId: string,
  filters: InboxFilters,
): Promise<{ items: Array<ApplicationRow & { propertyTitle: string; city: string | null; county: string | null }>; total: number }> {
  const conditions: string[] = [
    `(EXISTS (SELECT 1 FROM property_ownerships po WHERE po.property_id = a.property_id AND po.status = 'active' AND po.user_id = $1 AND (po.effective_to IS NULL OR po.effective_to > NOW()))
       OR EXISTS (SELECT 1 FROM property_assignments pa WHERE pa.property_id = a.property_id AND pa.status = 'active' AND pa.user_id = $1 AND pa.assignment_type IN ('property_manager','letting_agent') AND (pa.effective_to IS NULL OR pa.effective_to > NOW())))`,
  ];
  const values: unknown[] = [managerUserId];
  let idx = 2;
  if (filters.propertyId) {
    conditions.push(`a.property_id = $${idx++}`);
    values.push(filters.propertyId);
  }
  if (filters.unitId) {
    conditions.push(`a.unit_id = $${idx++}`);
    values.push(filters.unitId);
  }
  if (filters.status) {
    conditions.push(`a.status = $${idx++}::application_status`);
    values.push(filters.status);
  }
  if (filters.fromDate) {
    conditions.push(`a.created_at >= $${idx++}`);
    values.push(filters.fromDate);
  }
  if (filters.toDate) {
    conditions.push(`a.created_at <= $${idx++}`);
    values.push(filters.toDate);
  }
  const where = `WHERE ${conditions.join(' AND ')}`;

  const count = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM rental_applications a ${where}`,
    values,
  );

  values.push(filters.limit, filters.offset);
  const result = await pool.query<ApplicationRow & { propertyTitle: string; city: string | null; county: string | null }>(
    `SELECT ${APPLICATION_COLUMNS_A},
            p.title as "propertyTitle", p.city, p.county
       FROM rental_applications a
       JOIN properties p ON p.id = a.property_id
       ${where}
      ORDER BY a.created_at DESC
      LIMIT $${idx++} OFFSET $${idx++}`,
    values,
  );
  return { items: result.rows, total: Number(count.rows[0]?.count ?? '0') };
}