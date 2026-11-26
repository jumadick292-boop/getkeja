// Laundry operations repository (Task 13.8).
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import type { PoolClient } from 'pg';
import type {
  LaundryCollectionStatus,
  LaundryOrder,
  LaundryOrderAmendment,
  LaundryOrderAttachment,
  LaundryOrderDetail,
  LaundryOrderException,
  LaundryOrderHandover,
  LaundryOrderHistoryEntry,
  LaundryOrderInspection,
  LaundryOrderItem,
  LaundryOrderScope,
  LaundryOrderStaffAssignment,
} from './laundry.types.js';

function mapOrder(row: Record<string, unknown>): LaundryOrder {
  return {
    id: row.id as string,
    serviceRequestId: row.serviceRequestId as string,
    quotationId: row.quotationId as string,
    quotationVersion: row.quotationVersion as number,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    assignedStaffUserId: (row.assignedStaffUserId as string) ?? null,
    status: row.status as LaundryCollectionStatus,
    fulfilmentMode: row.fulfilmentMode as LaundryOrder['fulfilmentMode'],
    collectionLocationId: (row.collectionLocationId as string) ?? null,
    collectionAddress: (row.collectionAddress as string) ?? null,
    returnLocationId: (row.returnLocationId as string) ?? null,
    returnAddress: (row.returnAddress as string) ?? null,
    propertyId: (row.propertyId as string) ?? null,
    unitId: (row.unitId as string) ?? null,
    tenancyId: (row.tenancyId as string) ?? null,
    agreedPrice: row.agreedPrice as string,
    currency: row.currency as string,
    scope: (row.scope as LaundryOrderScope) ?? {},
    checklist: (row.checklist as Record<string, boolean>) ?? {},
    collectionDate: (row.collectionDate as string) ?? null,
    collectionWindowStart: (row.collectionWindowStart as string) ?? null,
    collectionWindowEnd: (row.collectionWindowEnd as string) ?? null,
    returnDate: (row.returnDate as string) ?? null,
    returnWindowStart: (row.returnWindowStart as string) ?? null,
    returnWindowEnd: (row.returnWindowEnd as string) ?? null,
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

const ORDER_SELECT = `
  SELECT id, service_request_id AS "serviceRequestId", quotation_id AS "quotationId",
         quotation_version AS "quotationVersion", customer_user_id AS "customerUserId",
         provider_profile_id AS "providerProfileId", provider_organisation_id AS "providerOrganisationId",
         assigned_staff_user_id AS "assignedStaffUserId", status::text AS status,
         fulfilment_mode AS "fulfilmentMode", collection_location_id AS "collectionLocationId",
         collection_address AS "collectionAddress", return_location_id AS "returnLocationId",
         return_address AS "returnAddress", property_id AS "propertyId", unit_id AS "unitId",
         tenancy_id AS "tenancyId", agreed_price::text AS "agreedPrice", currency, scope, checklist,
         collection_date AS "collectionDate", collection_window_start AS "collectionWindowStart",
         collection_window_end AS "collectionWindowEnd", return_date AS "returnDate",
         return_window_start AS "returnWindowStart", return_window_end AS "returnWindowEnd",
         completion_notes AS "completionNotes", completion_submitted_at AS "completionSubmittedAt",
         completion_outstanding_issue AS "completionOutstandingIssue",
         customer_confirmation_status AS "customerConfirmationStatus",
         customer_confirmation_notes AS "customerConfirmationNotes",
         customer_confirmation_at AS "customerConfirmationAt", cancelled_at AS "cancelledAt",
         cancellation_reason AS "cancellationReason", failed_at AS "failedAt",
         failure_reason AS "failureReason", created_at AS "createdAt", updated_at AS "updatedAt"
  FROM laundry_orders`;

export async function findOrderById(id: string): Promise<LaundryOrder | null> {
  const r = await pool.query(`${ORDER_SELECT} WHERE id = $1`, [id]);
  return r.rows[0] ? mapOrder(r.rows[0]) : null;
}

export async function findOrderByRequestId(requestId: string): Promise<LaundryOrder | null> {
  const r = await pool.query(`${ORDER_SELECT} WHERE service_request_id = $1`, [requestId]);
  return r.rows[0] ? mapOrder(r.rows[0]) : null;
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

export interface InsertLaundryOrderRow {
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  fulfilmentMode: string;
  collectionLocationId: string | null;
  collectionAddress: string | null;
  returnLocationId: string | null;
  returnAddress: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  agreedPrice: string;
  currency: string;
  scope: LaundryOrderScope;
  checklist: Record<string, boolean>;
  collectionDate: string | null;
  collectionWindowStart: string | null;
  collectionWindowEnd: string | null;
  returnDate: string | null;
  returnWindowStart: string | null;
  returnWindowEnd: string | null;
  createdBy: string;
}

export async function insertOrder(client: PoolClient, row: InsertLaundryOrderRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO laundry_orders
       (service_request_id, quotation_id, quotation_version, customer_user_id, provider_profile_id,
        provider_organisation_id, fulfilment_mode, collection_location_id, collection_address,
        return_location_id, return_address, property_id, unit_id, tenancy_id, agreed_price, currency,
        scope, checklist, collection_date, collection_window_start, collection_window_end,
        return_date, return_window_start, return_window_end, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17::jsonb,$18::jsonb,$19,$20,$21,$22,$23,$24,$25)
     RETURNING id`,
    [
      row.serviceRequestId, row.quotationId, row.quotationVersion, row.customerUserId, row.providerProfileId,
      row.providerOrganisationId, row.fulfilmentMode, row.collectionLocationId, row.collectionAddress,
      row.returnLocationId, row.returnAddress, row.propertyId, row.unitId, row.tenancyId, row.agreedPrice,
      row.currency, JSON.stringify(row.scope), JSON.stringify(row.checklist), row.collectionDate,
      row.collectionWindowStart, row.collectionWindowEnd, row.returnDate, row.returnWindowStart,
      row.returnWindowEnd, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function listOrdersByCustomer(userId: string, filters: { status?: LaundryCollectionStatus; limit: number; offset: number }): Promise<{ rows: LaundryOrder[]; total: number }> {
  const where = [`customer_user_id = $1`];
  const params: unknown[] = [userId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::laundry_collection_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(`SELECT COUNT(*)::text AS count FROM laundry_orders ${whereSql}`, params);
  params.push(filters.limit, filters.offset);
  const r = await pool.query(`${ORDER_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows: r.rows.map(mapOrder), total: Number(count.rows[0]!.count) };
}

export async function listOrdersForProvider(profileIds: string[], staffUserId: string, filters: { status?: LaundryCollectionStatus; limit: number; offset: number }): Promise<{ rows: LaundryOrder[]; total: number }> {
  if (profileIds.length === 0) return { rows: [], total: 0 };
  const where = [
    `(provider_profile_id = ANY($1::uuid[]) OR assigned_staff_user_id = $2
       OR EXISTS (SELECT 1 FROM laundry_order_staff_assignments s WHERE s.laundry_order_id = laundry_orders.id AND s.user_id = $2 AND s.is_active))`,
  ];
  const params: unknown[] = [profileIds, staffUserId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}::laundry_collection_status`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query<{ count: string }>(`SELECT COUNT(*)::text AS count FROM laundry_orders ${whereSql}`, params);
  params.push(filters.limit, filters.offset);
  const r = await pool.query(`${ORDER_SELECT} ${whereSql} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows: r.rows.map(mapOrder), total: Number(count.rows[0]!.count) };
}

export async function updateOrderStatus(client: PoolClient, input: { orderId: string; expectedFrom: LaundryCollectionStatus; toStatus: LaundryCollectionStatus; actorUserId: string; reason?: string | null; extra?: Record<string, unknown> }): Promise<{ id: string; status: LaundryCollectionStatus }> {
  const assignments = [`status = $2::laundry_collection_status`, 'updated_by = $3', 'updated_at = NOW()'];
  const values: unknown[] = [input.orderId, input.toStatus, input.actorUserId];
  let idx = 4;
  if (input.toStatus === 'cancelled') {
    assignments.push('cancelled_at = NOW()', 'cancelled_by = $3');
    if (input.reason != null) { assignments.push(`cancellation_reason = $${idx++}`); values.push(input.reason); }
  } else if (input.toStatus === 'failed') {
    assignments.push('failed_at = NOW()');
    if (input.reason != null) { assignments.push(`failure_reason = $${idx++}`); values.push(input.reason); }
  }
  for (const [key, value] of Object.entries(input.extra ?? {})) {
    assignments.push(`${key} = $${idx++}`);
    values.push(value);
  }
  values.push(input.expectedFrom);
  const r = await client.query<{ id: string; status: LaundryCollectionStatus }>(
    `UPDATE laundry_orders SET ${assignments.join(', ')} WHERE id = $1 AND status = $${idx}::laundry_collection_status RETURNING id, status::text AS status`,
    values,
  );
  if (r.rows.length === 0) {
    const err = new Error('Laundry order status changed concurrently') as Error & { code?: string };
    err.code = 'CONFLICT';
    throw err;
  }
  return r.rows[0]!;
}

export async function insertHistory(client: PoolClient, input: { orderId: string; action: string; changedBy: string; previousStatus?: LaundryCollectionStatus | null; newStatus?: LaundryCollectionStatus | null; reason?: string | null; metadata?: Record<string, unknown> }): Promise<void> {
  await client.query(
    `INSERT INTO laundry_order_history (laundry_order_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3::laundry_collection_status,$4::laundry_collection_status,$5,$6,$7::jsonb)`,
    [input.orderId, input.action, input.previousStatus ?? null, input.newStatus ?? null, input.changedBy, input.reason ?? null, JSON.stringify(input.metadata ?? {})],
  );
}

async function listHistory(orderId: string): Promise<LaundryOrderHistoryEntry[]> {
  const r = await pool.query(
    `SELECT id, action, previous_status AS "previousStatus", new_status::text AS "newStatus", changed_by AS "changedBy",
            change_reason AS "changeReason", metadata, created_at AS "createdAt"
       FROM laundry_order_history WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderHistoryEntry[];
}

async function listItems(orderId: string): Promise<LaundryOrderItem[]> {
  const r = await pool.query(
    `SELECT id, laundry_order_id AS "laundryOrderId", item_category AS "itemCategory", description, quantity,
            customer_reference AS "customerReference", condition_at_intake AS "conditionAtIntake",
            stains_damage_notes AS "stainsDamageNotes", special_handling AS "specialHandling",
            processing_instructions AS "processingInstructions", item_status AS "itemStatus",
            return_condition_notes AS "returnConditionNotes", handover_notes AS "handoverNotes",
            photo_document_ids AS "photoDocumentIds", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM laundry_order_items WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderItem[];
}

async function listInspections(orderId: string): Promise<LaundryOrderInspection[]> {
  const r = await pool.query(
    `SELECT id, laundry_order_id AS "laundryOrderId", item_id AS "itemId", reported_by AS "reportedBy", result,
            declared_quantity AS "declaredQuantity", received_quantity AS "receivedQuantity", description,
            requires_customer_approval AS "requiresCustomerApproval", approval_status AS "approvalStatus",
            decided_by AS "decidedBy", decided_at AS "decidedAt", created_at AS "createdAt"
       FROM laundry_order_inspections WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderInspection[];
}

async function listStaff(orderId: string): Promise<LaundryOrderStaffAssignment[]> {
  const r = await pool.query(
    `SELECT id, user_id AS "userId", label, is_active AS "isActive", assigned_by AS "assignedBy",
            created_at AS "createdAt", revoked_at AS "revokedAt"
       FROM laundry_order_staff_assignments WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderStaffAssignment[];
}

async function listHandovers(orderId: string): Promise<LaundryOrderHandover[]> {
  const r = await pool.query(
    `SELECT id, laundry_order_id AS "laundryOrderId", kind, status, location_id AS "locationId", address,
            scheduled_at AS "scheduledAt", window_start AS "windowStart", window_end AS "windowEnd", notes,
            proof_document_ids AS "proofDocumentIds", confirmed_by AS "confirmedBy", confirmed_at AS "confirmedAt",
            created_at AS "createdAt"
       FROM laundry_order_handovers WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderHandover[];
}

async function listAmendments(orderId: string): Promise<LaundryOrderAmendment[]> {
  const r = await pool.query(
    `SELECT id, laundry_order_id AS "laundryOrderId", proposed_by AS "proposedBy", reason,
            revised_scope AS "revisedScope", additional_cost::text AS "additionalCost", currency, status,
            decided_by AS "decidedBy", decided_at AS "decidedAt", created_at AS "createdAt"
       FROM laundry_order_amendments WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderAmendment[];
}

async function listExceptions(orderId: string): Promise<LaundryOrderException[]> {
  const r = await pool.query(
    `SELECT id, laundry_order_id AS "laundryOrderId", reported_by AS "reportedBy", type, description, created_at AS "createdAt"
       FROM laundry_order_exceptions WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderException[];
}

async function listAttachments(orderId: string): Promise<LaundryOrderAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM laundry_order_attachments WHERE laundry_order_id = $1 ORDER BY created_at ASC`,
    [orderId],
  );
  return r.rows as unknown as LaundryOrderAttachment[];
}

export async function getOrderDetail(id: string): Promise<LaundryOrderDetail | null> {
  const order = await findOrderById(id);
  if (!order) return null;
  const [history, items, inspections, staff, handovers, amendments, exceptions, attachments] = await Promise.all([
    listHistory(id), listItems(id), listInspections(id), listStaff(id),
    listHandovers(id), listAmendments(id), listExceptions(id), listAttachments(id),
  ]);
  return { ...order, history, items, inspections, staff, handovers, amendments, exceptions, attachments };
}

export async function mergeChecklist(client: PoolClient, orderId: string, items: Record<string, boolean>): Promise<void> {
  await client.query(`UPDATE laundry_orders SET checklist = (COALESCE(checklist, '{}'::jsonb) || $2::jsonb) WHERE id = $1`, [orderId, JSON.stringify(items)]);
}

export async function insertAttachments(client: PoolClient, orderId: string, documentIds: string[], kind: string, uploadedBy: string): Promise<void> {
  for (const docId of documentIds) {
    await client.query(`INSERT INTO laundry_order_attachments (laundry_order_id, document_id, kind, uploaded_by) VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`, [orderId, docId, kind, uploadedBy]);
  }
}

export async function insertException(client: PoolClient, orderId: string, reportedBy: string, type: string, description: string): Promise<void> {
  await client.query(`INSERT INTO laundry_order_exceptions (laundry_order_id, reported_by, type, description) VALUES ($1,$2,$3,$4)`, [orderId, reportedBy, type, description]);
}

// ---- Items ----
export async function insertItem(client: PoolClient, orderId: string, row: {
  itemCategory: string; description?: string | null; quantity: number; customerReference?: string | null;
  conditionAtIntake?: string | null; stainsDamageNotes?: string | null; specialHandling?: string | null;
  processingInstructions?: string | null; photoDocumentIds: string[]; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO laundry_order_items
       (laundry_order_id, item_category, description, quantity, customer_reference, condition_at_intake,
        stains_damage_notes, special_handling, processing_instructions, photo_document_ids, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11) RETURNING id`,
    [orderId, row.itemCategory, row.description ?? null, row.quantity, row.customerReference ?? null,
      row.conditionAtIntake ?? null, row.stainsDamageNotes ?? null, row.specialHandling ?? null,
      row.processingInstructions ?? null, JSON.stringify(row.photoDocumentIds), row.createdBy],
  );
  return r.rows[0]!;
}

export async function updateItem(client: PoolClient, orderId: string, itemId: string, patch: Record<string, unknown>): Promise<void> {
  const keys = Object.keys(patch);
  if (keys.length === 0) return;
  const set = keys.map((k, i) => `${k} = $${i + 3}`).join(', ');
  await client.query(`UPDATE laundry_order_items SET ${set}, updated_at = NOW() WHERE id = $1 AND laundry_order_id = $2`, [itemId, orderId, ...keys.map((k) => patch[k])]);
}

export async function findItem(orderId: string, itemId: string): Promise<LaundryOrderItem | null> {
  const items = await listItems(orderId);
  return items.find((i) => i.id === itemId) ?? null;
}

// ---- Inspections ----
export async function insertInspection(client: PoolClient, orderId: string, row: {
  itemId: string | null; reportedBy: string; result: string; declaredQuantity: number | null;
  receivedQuantity: number | null; description: string; requiresCustomerApproval: boolean;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO laundry_order_inspections
       (laundry_order_id, item_id, reported_by, result, declared_quantity, received_quantity, description, requires_customer_approval, approval_status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [orderId, row.itemId, row.reportedBy, row.result, row.declaredQuantity, row.receivedQuantity, row.description, row.requiresCustomerApproval, row.requiresCustomerApproval ? 'pending' : 'not_required'],
  );
  return r.rows[0]!;
}

export async function findInspection(orderId: string, inspectionId: string): Promise<LaundryOrderInspection | null> {
  const list = await listInspections(orderId);
  return list.find((i) => i.id === inspectionId) ?? null;
}

export async function resolveInspection(client: PoolClient, inspectionId: string, decision: string, decidedBy: string): Promise<void> {
  await client.query(
    `UPDATE laundry_order_inspections SET approval_status = $2, decided_by = $3, decided_at = NOW() WHERE id = $1`,
    [inspectionId, decision === 'approve' ? 'approved' : 'rejected', decidedBy],
  );
}

export async function hasPendingApprovals(orderId: string): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM laundry_order_inspections WHERE laundry_order_id = $1 AND requires_customer_approval AND approval_status = 'pending' LIMIT 1`,
    [orderId],
  );
  return (r.rowCount ?? 0) > 0;
}

// ---- Handovers ----
export async function insertHandover(client: PoolClient, orderId: string, row: {
  kind: string; locationId: string | null; address: string | null; scheduledAt: string | null;
  windowStart: string | null; windowEnd: string | null; notes: string | null; createdBy: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO laundry_order_handovers (laundry_order_id, kind, location_id, address, scheduled_at, window_start, window_end, notes, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [orderId, row.kind, row.locationId, row.address, row.scheduledAt, row.windowStart, row.windowEnd, row.notes, row.createdBy],
  );
  return r.rows[0]!;
}

export async function confirmHandover(client: PoolClient, handoverId: string, confirmedBy: string, proofDocumentIds: string[], notes: string | null): Promise<void> {
  await client.query(
    `UPDATE laundry_order_handovers SET status = 'confirmed', confirmed_by = $2, confirmed_at = NOW(),
        proof_document_ids = COALESCE(proof_document_ids, '[]'::jsonb) || $3::jsonb,
        notes = COALESCE($4, notes) WHERE id = $1`,
    [handoverId, confirmedBy, JSON.stringify(proofDocumentIds), notes],
  );
}

export async function findHandover(orderId: string, handoverId: string): Promise<LaundryOrderHandover | null> {
  const list = await listHandovers(orderId);
  return list.find((h) => h.id === handoverId) ?? null;
}

// ---- Amendments ----
export async function insertAmendment(client: PoolClient, orderId: string, row: {
  proposedBy: string; reason: string; revisedScope: Record<string, unknown>; additionalCost: string; currency: string;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO laundry_order_amendments (laundry_order_id, proposed_by, reason, revised_scope, additional_cost, currency)
     VALUES ($1,$2,$3,$4::jsonb,$5,$6) RETURNING id`,
    [orderId, row.proposedBy, row.reason, JSON.stringify(row.revisedScope), row.additionalCost, row.currency],
  );
  return r.rows[0]!;
}

export async function findAmendment(orderId: string, amendmentId: string): Promise<LaundryOrderAmendment | null> {
  const list = await listAmendments(orderId);
  return list.find((a) => a.id === amendmentId) ?? null;
}

export async function resolveAmendment(client: PoolClient, amendmentId: string, accept: boolean, decidedBy: string): Promise<void> {
  await client.query(
    `UPDATE laundry_order_amendments SET status = $2, decided_by = $3, decided_at = NOW() WHERE id = $1`,
    [amendmentId, accept ? 'accepted' : 'rejected', decidedBy],
  );
}

// ---- Background: overdue order checks (idempotent) ----
export interface OverdueResult { flagged: number }

// Flag orders stuck in an active processing state past their return date as
// 'exception' (idempotent: only transitions orders not already terminal/exception).
export async function flagOverdueOrders(): Promise<OverdueResult> {
  return transaction(async (client) => {
    const r = await client.query<{ id: string }>(
      `UPDATE laundry_orders
          SET status = 'exception', updated_by = created_by, updated_at = NOW()
        WHERE return_date IS NOT NULL
          AND return_date < CURRENT_DATE
          AND status NOT IN ('completed','cancelled','failed','exception','awaiting_customer_confirmation','delivered')
        RETURNING id`,
    );
    return { flagged: r.rows.length };
  });
}