// Service marketplace repository (Task 13.5).
// Scoped SQL for the unified request + quotation engine. All multi-statement
// writes accept the caller's PoolClient so business change, history trigger and
// outbox event share one transaction boundary.
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import { contextHasEligibleOffering } from '../provider/provider.repository.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  ServiceCategory,
  ServiceDomain,
  ServiceQuotation,
  ServiceQuotationItem,
  ServiceRequest,
  ServiceRequestAttachment,
  ServiceRequestDetails,
  ServiceRequestHistoryEntry,
  ServiceRequestStatus,
  ServiceQuotationStatus,
} from './marketplace.types.js';

// ---------------------------------------------------------------------------
// Reference data
// ---------------------------------------------------------------------------
export async function listCategories(domain?: ServiceDomain): Promise<ServiceCategory[]> {
  const params: unknown[] = [];
  let where = '';
  if (domain) {
    params.push(domain);
    where = `WHERE domain = $1::service_domain`;
  }
  const r = await pool.query(
    `SELECT id, domain::text AS domain, name, description, is_active AS "isActive", sort_order AS "sortOrder"
       FROM service_categories ${where}
      ORDER BY domain, sort_order, name`,
    params,
  );
  return r.rows as ServiceCategory[];
}

export async function findCategoryById(id: string): Promise<ServiceCategory | null> {
  const r = await pool.query(
    `SELECT id, domain::text AS domain, name, description, is_active AS "isActive", sort_order AS "sortOrder"
       FROM service_categories WHERE id = $1 AND is_active = TRUE`,
    [id],
  );
  return (r.rows[0] as ServiceCategory) ?? null;
}

// ---------------------------------------------------------------------------
// Requests — create / read
// ---------------------------------------------------------------------------
export interface CreateRequestRow {
  categoryId: string;
  domain: ServiceDomain;
  customerUserId: string;
  title: string | null;
  description: string;
  details: ServiceRequestDetails;
  savedLocationId: string | null;
  serviceAddress: string | null;
  serviceCounty: string | null;
  serviceCity: string | null;
  serviceLatitude: string | null;
  serviceLongitude: string | null;
  preferredDateTime: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  createdBy: string;
}

export async function insertRequest(client: PoolClient, row: CreateRequestRow): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO service_requests
       (category_id, domain, customer_user_id, title, description, details,
        saved_location_id, service_address, service_county, service_city,
        service_latitude, service_longitude, preferred_date_time,
        contact_name, contact_phone, contact_email, created_by)
     VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
     RETURNING id`,
    [
      row.categoryId, row.domain, row.customerUserId, row.title, row.description,
      JSON.stringify(row.details), row.savedLocationId, row.serviceAddress,
      row.serviceCounty, row.serviceCity, row.serviceLatitude, row.serviceLongitude,
      row.preferredDateTime, row.contactName, row.contactPhone, row.contactEmail, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

function mapRequest(row: Record<string, unknown>): ServiceRequest {
  return {
    id: row.id as string,
    categoryId: row.categoryId as string,
    categoryName: row.categoryName as string,
    domain: row.domain as ServiceDomain,
    customerUserId: row.customerUserId as string,
    status: row.status as ServiceRequestStatus,
    title: (row.title as string) ?? null,
    description: row.description as string,
    details: (row.details as ServiceRequestDetails) ?? {},
    savedLocationId: (row.savedLocationId as string) ?? null,
    serviceAddress: (row.serviceAddress as string) ?? null,
    serviceCounty: (row.serviceCounty as string) ?? null,
    serviceCity: (row.serviceCity as string) ?? null,
    serviceLatitude: (row.serviceLatitude as string) ?? null,
    serviceLongitude: (row.serviceLongitude as string) ?? null,
    preferredDateTime: (row.preferredDateTime as string) ?? null,
    contactName: (row.contactName as string) ?? null,
    contactPhone: (row.contactPhone as string) ?? null,
    contactEmail: (row.contactEmail as string) ?? null,
    acceptedQuotationId: (row.acceptedQuotationId as string) ?? null,
    assignedProviderId: (row.assignedProviderId as string) ?? null,
    scheduledAt: (row.scheduledAt as string) ?? null,
    startedAt: (row.startedAt as string) ?? null,
    completedAt: (row.completedAt as string) ?? null,
    cancelledAt: (row.cancelledAt as string) ?? null,
    cancellationReason: (row.cancellationReason as string) ?? null,
    createdBy: row.createdBy as string,
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const REQUEST_SELECT = `
  SELECT sr.id, sr.category_id AS "categoryId", sc.name AS "categoryName",
         sr.domain::text AS domain, sr.customer_user_id AS "customerUserId",
         sr.status::text AS status, sr.title, sr.description, sr.details,
         sr.saved_location_id AS "savedLocationId", sr.service_address AS "serviceAddress",
         sr.service_county AS "serviceCounty", sr.service_city AS "serviceCity",
         sr.service_latitude AS "serviceLatitude", sr.service_longitude AS "serviceLongitude",
         sr.preferred_date_time AS "preferredDateTime", sr.contact_name AS "contactName",
         sr.contact_phone AS "contactPhone", sr.contact_email AS "contactEmail",
         sr.accepted_quotation_id AS "acceptedQuotationId", sr.assigned_provider_id AS "assignedProviderId",
         sr.scheduled_at AS "scheduledAt", sr.started_at AS "startedAt", sr.completed_at AS "completedAt",
         sr.cancelled_at AS "cancelledAt", sr.cancellation_reason AS "cancellationReason",
         sr.created_by AS "createdBy", sr.created_at AS "createdAt", sr.updated_at AS "updatedAt"
  FROM service_requests sr
  JOIN service_categories sc ON sc.id = sr.category_id`;

export async function findRequestById(id: string): Promise<ServiceRequest | null> {
  const r = await pool.query(`${REQUEST_SELECT} WHERE sr.id = $1`, [id]);
  return r.rows[0] ? mapRequest(r.rows[0]) : null;
}

export interface CustomerListFilters {
  status?: ServiceRequestStatus;
  domain?: ServiceDomain;
  limit: number;
  offset: number;
}

export async function listCustomerRequests(
  userId: string,
  filters: CustomerListFilters,
): Promise<{ rows: ServiceRequest[]; total: number }> {
  const where = [`sr.customer_user_id = $1`];
  const params: unknown[] = [userId];
  if (filters.status) {
    params.push(filters.status);
    where.push(`sr.status = $${params.length}::service_request_status`);
  }
  if (filters.domain) {
    params.push(filters.domain);
    where.push(`sr.domain = $${params.length}::service_domain`);
  }
  const whereSql = `WHERE ${where.join(' AND ')}`;
  const countR = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM service_requests sr ${whereSql}`,
    params,
  );
  params.push(filters.limit, filters.offset);
  const r = await pool.query(
    `${REQUEST_SELECT} ${whereSql} ORDER BY sr.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  return { rows: r.rows.map(mapRequest), total: Number(countR.rows[0]!.count) };
}

export async function listQuotationsForRequest(requestId: string): Promise<ServiceQuotation[]> {
  const r = await pool.query(
    `SELECT q.id, q.service_request_id AS "serviceRequestId", q.provider_profile_id AS "providerProfileId",
            sp.business_name AS "providerName", q.version_number AS "versionNumber", q.status::text AS status,
            q.currency, q.subtotal_amount::text AS "subtotalAmount", q.total_amount::text AS "totalAmount",
            q.estimated_start AS "estimatedStart", q.estimated_completion AS "estimatedCompletion",
            q.valid_until AS "validUntil", q.terms, q.notes, q.supersedes_id AS "supersedesId",
            q.created_by AS "createdBy", q.created_at AS "createdAt", q.updated_at AS "updatedAt"
       FROM service_quotations q
       LEFT JOIN specialized_profiles sp ON sp.id = q.provider_profile_id
      WHERE q.service_request_id = $1
      ORDER BY q.created_at ASC`,
    [requestId],
  );
  const quotations = r.rows as unknown as ServiceQuotation[];
  for (const q of quotations) {
    q.items = await listQuotationItems(q.id);
  }
  return quotations;
}

export async function listQuotationItems(quotationId: string): Promise<ServiceQuotationItem[]> {
  const r = await pool.query(
    `SELECT id, description, quantity::text AS quantity, unit_price::text AS "unitPrice",
            amount::text AS amount, sort_order AS "sortOrder"
       FROM service_quotation_items WHERE quotation_id = $1 ORDER BY sort_order, id`,
    [quotationId],
  );
  return r.rows as ServiceQuotationItem[];
}

export async function listAttachments(requestId: string): Promise<ServiceRequestAttachment[]> {
  const r = await pool.query(
    `SELECT id, document_id AS "documentId", kind, uploaded_by AS "uploadedBy", created_at AS "createdAt"
       FROM service_request_attachments WHERE service_request_id = $1 ORDER BY created_at`,
    [requestId],
  );
  return r.rows as ServiceRequestAttachment[];
}

export async function listHistory(requestId: string): Promise<ServiceRequestHistoryEntry[]> {
  const r = await pool.query(
    `SELECT id, action, previous_status AS "previousStatus", new_status::text AS "newStatus",
            changed_by AS "changedBy", change_reason AS "changeReason", metadata, created_at AS "createdAt"
       FROM service_request_history WHERE service_request_id = $1 ORDER BY created_at ASC`,
    [requestId],
  );
  return r.rows as unknown as ServiceRequestHistoryEntry[];
}

export async function getRequestDetail(id: string): Promise<ServiceRequest | null> {
  const request = await findRequestById(id);
  if (!request) return null;
  const [quotations, attachments, history] = await Promise.all([
    listQuotationsForRequest(id),
    listAttachments(id),
    listHistory(id),
  ]);
  return { ...request, quotations, attachments, history };
}

// ---------------------------------------------------------------------------
// Status transitions (concurrency-safe)
// ---------------------------------------------------------------------------
export async function updateRequestStatus(
  client: PoolClient,
  input: {
    requestId: string;
    expectedFrom: ServiceRequestStatus;
    toStatus: ServiceRequestStatus;
    actorUserId: string;
    reason?: string | null;
    extra?: { scheduledAt?: string; startedAt?: string; completedAt?: string };
  },
): Promise<{ id: string; status: ServiceRequestStatus }> {
  const assignments = [`status = $2::service_request_status`, 'updated_by = $3', 'updated_at = NOW()'];
  const values: unknown[] = [input.requestId, input.toStatus, input.actorUserId];
  let idx = 4;
  if (input.reason != null) {
    assignments.push(`cancellation_reason = $${idx++}`);
    values.push(input.reason);
  }
  if (input.toStatus === 'cancelled') {
    assignments.push('cancelled_at = NOW()', 'cancelled_by = $3');
  }
  if (input.extra?.scheduledAt) {
    assignments.push(`scheduled_at = $${idx++}`);
    values.push(input.extra.scheduledAt);
  }
  if (input.extra?.startedAt) {
    assignments.push(`started_at = $${idx++}`);
    values.push(input.extra.startedAt);
  }
  if (input.extra?.completedAt) {
    assignments.push(`completed_at = $${idx++}`);
    values.push(input.extra.completedAt);
  }
  values.push(input.expectedFrom);
  const r = await client.query<{ id: string; status: ServiceRequestStatus }>(
    `UPDATE service_requests SET ${assignments.join(', ')}
      WHERE id = $1 AND status = $${idx}::service_request_status
      RETURNING id, status::text AS status`,
    values,
  );
  if (r.rows.length === 0) {
    const err = new Error('Request status changed concurrently') as Error & { code?: string };
    err.code = 'CONFLICT';
    throw err;
  }
  return r.rows[0]!;
}

export async function insertHistory(
  client: PoolClient,
  input: {
    requestId: string;
    action: string;
    previousStatus: ServiceRequestStatus | null;
    newStatus: ServiceRequestStatus;
    changedBy: string;
    reason?: string | null;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO service_request_history
       (service_request_id, action, previous_status, new_status, changed_by, change_reason, metadata)
     VALUES ($1,$2,$3::service_request_status,$4::service_request_status,$5,$6,$7::jsonb)`,
    [
      input.requestId, input.action, input.previousStatus, input.newStatus,
      input.changedBy, input.reason ?? null, JSON.stringify(input.metadata ?? {}),
    ],
  );
}

// ---------------------------------------------------------------------------
// Quotations
// ---------------------------------------------------------------------------
export async function findLiveQuotation(
  requestId: string,
  providerProfileId: string,
): Promise<{ id: string; versionNumber: number } | null> {
  const r = await pool.query<{ id: string; versionNumber: number }>(
    `SELECT id, version_number AS "versionNumber" FROM service_quotations
      WHERE service_request_id = $1 AND provider_profile_id = $2
        AND status IN ('submitted','revised')`,
    [requestId, providerProfileId],
  );
  return r.rows[0] ?? null;
}

export async function maxQuotationVersion(
  client: PoolClient,
  requestId: string,
  providerProfileId: string,
): Promise<number> {
  const r = await client.query<{ v: string }>(
    `SELECT COALESCE(MAX(version_number), 0)::text AS v FROM service_quotations
      WHERE service_request_id = $1 AND provider_profile_id = $2`,
    [requestId, providerProfileId],
  );
  return Number(r.rows[0]!.v);
}

export interface InsertQuotationRow {
  serviceRequestId: string;
  providerProfileId: string;
  versionNumber: number;
  currency: string;
  subtotalAmount: string;
  totalAmount: string;
  estimatedStart: string | null;
  estimatedCompletion: string | null;
  validUntil: string;
  terms: string | null;
  notes: string | null;
  supersedesId: string | null;
  createdBy: string;
}

export async function insertQuotation(
  client: PoolClient,
  row: InsertQuotationRow,
): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO service_quotations
       (service_request_id, provider_profile_id, version_number, currency,
        subtotal_amount, total_amount, estimated_start, estimated_completion,
        valid_until, terms, notes, supersedes_id, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
     RETURNING id`,
    [
      row.serviceRequestId, row.providerProfileId, row.versionNumber, row.currency,
      row.subtotalAmount, row.totalAmount, row.estimatedStart, row.estimatedCompletion,
      row.validUntil, row.terms, row.notes, row.supersedesId, row.createdBy,
    ],
  );
  return r.rows[0]!;
}

export async function insertQuotationItems(
  client: PoolClient,
  quotationId: string,
  items: Array<{ description: string; quantity: string; unitPrice: string; amount: string; sortOrder: number }>,
): Promise<void> {
  for (const it of items) {
    await client.query(
      `INSERT INTO service_quotation_items (quotation_id, description, quantity, unit_price, amount, sort_order)
       VALUES ($1,$2,$3::numeric,$4::numeric,$5::numeric,$6)`,
      [quotationId, it.description, it.quantity, it.unitPrice, it.amount, it.sortOrder],
    );
  }
}

export async function findQuotationById(
  id: string,
): Promise<{ id: string; serviceRequestId: string; providerProfileId: string; status: ServiceQuotationStatus; versionNumber: number } | null> {
  const r = await pool.query(
    `SELECT id, service_request_id AS "serviceRequestId", provider_profile_id AS "providerProfileId",
            status::text AS status, version_number AS "versionNumber"
       FROM service_quotations WHERE id = $1`,
    [id],
  );
  return (r.rows[0] as never) ?? null;
}

// Provider inbox: open/quoted requests in domains the provider is eligible for,
// optionally narrowed to the provider's service areas.
export async function listProviderInbox(
  context: ProviderContext,
  filters: { domain?: ServiceDomain; limit: number; offset: number },
): Promise<{ rows: ServiceRequest[]; total: number }> {
  const profileIds = context.effectiveProfileIds;
  if (profileIds.length === 0) return { rows: [], total: 0 };

  const params: unknown[] = [profileIds];
  const conditions = [
    `sr.status IN ('open','quoted')`,
    `EXISTS (
        SELECT 1 FROM provider_service_offerings o
         WHERE o.specialized_profile_id = ANY($1::uuid[])
           AND o.domain = sr.domain
           AND (o.status = 'active'
                OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL
                    AND o.temporary_unavailable_to < CURRENT_DATE))
     )`,
    `(
        NOT EXISTS (
          SELECT 1 FROM provider_service_areas psa
           WHERE psa.specialized_profile_id = ANY($1::uuid[]) AND psa.is_active
        )
        OR EXISTS (
          SELECT 1 FROM provider_service_areas psa
           WHERE psa.specialized_profile_id = ANY($1::uuid[]) AND psa.is_active
             AND ((psa.county IS NOT NULL AND psa.county = sr.service_county)
                  OR (psa.city IS NOT NULL AND psa.city = sr.service_city))
        )
     )`,
  ];
  if (filters.domain) {
    params.push(filters.domain);
    conditions.push(`sr.domain = $${params.length}::service_domain`);
  }
  const whereSql = `WHERE ${conditions.join(' AND ')}`;
  const countR = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM service_requests sr ${whereSql}`,
    params,
  );
  params.push(filters.limit, filters.offset);
  const r = await pool.query(
    `${REQUEST_SELECT} ${whereSql} ORDER BY sr.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  return { rows: r.rows.map(mapRequest), total: Number(countR.rows[0]!.count) };
}

// Distinct domains the provider is currently eligible for (for offering checks).
export async function providerEligibleDomains(profileIds: string[]): Promise<Set<string>> {
  if (profileIds.length === 0) return new Set();
  const r = await pool.query<{ domain: string }>(
    `SELECT DISTINCT o.domain::text AS domain
       FROM provider_service_offerings o
      WHERE o.specialized_profile_id = ANY($1::uuid[])
        AND (o.status = 'active'
             OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL
                 AND o.temporary_unavailable_to < CURRENT_DATE))`,
    [profileIds],
  );
  return new Set(r.rows.map((x) => x.domain));
}

export { contextHasEligibleOffering };