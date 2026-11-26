// Provider complaints repository (Task 13.16).
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  Complaint,
  ComplaintCorrectiveAction,
  ComplaintDetail,
  ComplaintHistoryEntry,
  ComplaintInternalNote,
  ComplaintMessage,
  ComplaintStatus,
} from './complaints.types.js';

function mapComplaint(row: Record<string, unknown>): Complaint {
  return {
    id: row.id as string,
    resourceDomain: row.resourceDomain as string,
    resourceId: row.resourceId as string,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    reasonId: row.reasonId as string,
    description: row.description as string,
    status: row.status as ComplaintStatus,
    assignedAdminUserId: (row.assignedAdminUserId as string) ?? null,
    resolutionSummary: (row.resolutionSummary as string) ?? null,
    resolvedAt: (row.resolvedAt as string) ?? null,
    closedAt: (row.closedAt as string) ?? null,
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const SELECT = `
  SELECT id, resource_domain AS "resourceDomain", resource_id AS "resourceId",
         customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId",
         provider_organisation_id AS "providerOrganisationId", reason_id AS "reasonId", description,
         status::text AS status, assigned_admin_user_id AS "assignedAdminUserId",
         resolution_summary AS "resolutionSummary", resolved_at AS "resolvedAt", closed_at AS "closedAt",
         created_at AS "createdAt", updated_at AS "updatedAt"
    FROM complaints`;

export async function findById(id: string): Promise<Complaint | null> {
  const r = await pool.query(`${SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapComplaint(r.rows[0]) : null;
}

export async function insertComplaint(client: PoolClient, row: {
  domain: string; resourceId: string; customerUserId: string; providerProfileId: string;
  providerOrganisationId: string | null; reasonId: string; description: string; documentIds: string[];
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO complaints
       (resource_domain, resource_id, customer_user_id, provider_profile_id, provider_organisation_id, reason_id, description)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [row.domain, row.resourceId, row.customerUserId, row.providerProfileId, row.providerOrganisationId, row.reasonId, row.description],
  );
  const id = r.rows[0]!.id;
  if (row.documentIds.length) {
    await client.query(
      `INSERT INTO complaint_messages (complaint_id, author_user_id, author_role, body, document_ids)
       VALUES ($1,$2,'customer',$3,$4)`,
      [id, row.customerUserId, row.description, row.documentIds],
    );
  }
  return { id };
}

export async function listReasons() {
  const r = await pool.query(`SELECT id, label FROM complaint_reasons WHERE is_active ORDER BY sort_order`);
  return r.rows;
}

export async function listCustomerComplaints(customerUserId: string, status: string | undefined, limit: number, offset: number) {
  const where = ['customer_user_id = $1'];
  const params: unknown[] = [customerUserId];
  let i = 2;
  if (status) { where.push(`status::text = $${i++}`); params.push(status); }
  const clause = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM complaints ${clause}`, params);
  const rows = await pool.query(`${SELECT} ${clause} ORDER BY created_at DESC LIMIT $${i++} OFFSET $${i}`, [...params, limit, offset]);
  return { rows: rows.rows.map((r) => mapComplaint(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export async function listProviderComplaints(profileIds: string[], status: string | undefined, limit: number, offset: number) {
  const where = ['provider_profile_id = ANY($1::uuid[])'];
  const params: unknown[] = [profileIds];
  let i = 2;
  if (status) { where.push(`status::text = $${i++}`); params.push(status); }
  const clause = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM complaints ${clause}`, params);
  const rows = await pool.query(`${SELECT} ${clause} ORDER BY created_at DESC LIMIT $${i++} OFFSET $${i}`, [...params, limit, offset]);
  return { rows: rows.rows.map((r) => mapComplaint(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export async function listAdminQueue(status: string | undefined, limit: number, offset: number) {
  const where = status ? ['status::text = $1'] : [];
  const params: unknown[] = status ? [status] : [];
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM complaints ${clause}`, params);
  const rows = await pool.query(`${SELECT} ${clause} ORDER BY created_at ASC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`, [...params, limit, offset]);
  return { rows: rows.rows.map((r) => mapComplaint(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export async function updateStatus(id: string, status: ComplaintStatus, extra?: Record<string, unknown>): Promise<void> {
  const fields = ['status = $2', 'updated_at = NOW()'];
  const params: unknown[] = [id, status];
  let i = 3;
  for (const [k, v] of Object.entries(extra ?? {})) { fields.push(`${k} = $${i++}`); params.push(v); }
  await pool.query(`UPDATE complaints SET ${fields.join(', ')} WHERE id = $1`, params);
}

export async function insertHistory(client: PoolClient, row: {
  complaintId: string; previous: ComplaintStatus | null; next: ComplaintStatus; changedBy: string; reason: string | null;
}): Promise<void> {
  await client.query(
    `INSERT INTO complaint_status_history (complaint_id, previous_status, new_status, changed_by, reason)
     VALUES ($1,$2,$3,$4,$5)`,
    [row.complaintId, row.previous, row.next, row.changedBy, row.reason],
  );
}

export async function insertMessage(client: PoolClient, row: {
  complaintId: string; authorUserId: string; authorRole: string; body: string; documentIds: string[];
}): Promise<void> {
  await client.query(
    `INSERT INTO complaint_messages (complaint_id, author_user_id, author_role, body, document_ids)
     VALUES ($1,$2,$3,$4,$5)`,
    [row.complaintId, row.authorUserId, row.authorRole, row.body, row.documentIds],
  );
}

export async function insertCorrectiveAction(client: PoolClient, complaintId: string, recordedBy: string, action: string): Promise<void> {
  await client.query(
    `INSERT INTO complaint_corrective_actions (complaint_id, recorded_by, action) VALUES ($1,$2,$3)`,
    [complaintId, recordedBy, action],
  );
}

export async function insertInternalNote(client: PoolClient, complaintId: string, authorUserId: string, body: string): Promise<void> {
  await client.query(
    `INSERT INTO complaint_internal_notes (complaint_id, author_user_id, body) VALUES ($1,$2,$3)`,
    [complaintId, authorUserId, body],
  );
}

export async function setAssignee(id: string, adminUserId: string): Promise<void> {
  await pool.query(`UPDATE complaints SET assigned_admin_user_id = $2, updated_at = NOW() WHERE id = $1`, [id, adminUserId]);
}

export async function getDetail(complaint: Complaint, includeInternal: boolean): Promise<ComplaintDetail> {
  const [messages, actions, history, notes] = await Promise.all([
    pool.query(
      `SELECT id, complaint_id AS "complaintId", author_user_id AS "authorUserId", author_role AS "authorRole", body, document_ids AS "documentIds", created_at AS "createdAt"
         FROM complaint_messages WHERE complaint_id = $1 ORDER BY created_at`, [complaint.id]),
    pool.query(
      `SELECT id, complaint_id AS "complaintId", recorded_by AS "recordedBy", action, created_at AS "createdAt"
         FROM complaint_corrective_actions WHERE complaint_id = $1 ORDER BY created_at`, [complaint.id]),
    pool.query(
      `SELECT id, previous_status AS "previousStatus", new_status AS "newStatus", changed_by AS "changedBy", reason, created_at AS "createdAt"
         FROM complaint_status_history WHERE complaint_id = $1 ORDER BY created_at`, [complaint.id]),
    includeInternal
      ? pool.query(
          `SELECT id, complaint_id AS "complaintId", author_user_id AS "authorUserId", body, created_at AS "createdAt"
             FROM complaint_internal_notes WHERE complaint_id = $1 ORDER BY created_at`, [complaint.id])
      : Promise.resolve({ rows: [] }),
  ]);
  return {
    ...complaint,
    messages: messages.rows as unknown as ComplaintMessage[],
    correctiveActions: actions.rows as unknown as ComplaintCorrectiveAction[],
    history: history.rows as unknown as ComplaintHistoryEntry[],
    ...(includeInternal ? { internalNotes: notes.rows as unknown as ComplaintInternalNote[] } : {}),
  };
}