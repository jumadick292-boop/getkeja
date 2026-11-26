// Shared operational-resource resolution (Task 13.16).
// Maps the operational domains to their job tables and exposes a uniform
// projection (owner, provider, status, completion, timestamps) so the provider
// dashboard, reporting, reviews and complaints work across all domains without
// duplicating per-domain logic. Read-only; never changes job completion.
import { pool } from '../db/pool.js';

export interface OperationalResourceRef {
  domain: string;
  id: string;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  categoryId: string;
  status: string;
  customerConfirmationStatus: string;
  agreedPrice: string;
  currency: string;
  serviceAddress: string | null;
  createdAt: Date;
  updatedAt: Date;
}

// domain -> table. Only the 7 operational job domains (scheduling's
// garbage_occurrence is not a reviewable/complaint-able job).
export const OPERATIONAL_TABLES: Record<string, string> = {
  moving: 'moving_jobs',
  garbage: 'garbage_jobs',
  laundry: 'laundry_orders',
  home_maintenance: 'home_maintenance_jobs',
  cleaning: 'cleaning_jobs',
  installation: 'installation_jobs',
  finishing: 'finishing_jobs',
};

export const OPERATIONAL_DOMAINS = Object.keys(OPERATIONAL_TABLES);

export function isOperationalDomain(domain: string): boolean {
  return domain in OPERATIONAL_TABLES;
}

const SELECT = (table: string) => `
  SELECT id, customer_user_id AS "customerUserId", provider_profile_id AS "providerProfileId",
         provider_organisation_id AS "providerOrganisationId", category_id AS "categoryId",
         status::text AS status, customer_confirmation_status AS "customerConfirmationStatus",
         agreed_price::text AS "agreedPrice", currency, service_address AS "serviceAddress",
         created_at AS "createdAt", updated_at AS "updatedAt"
    FROM ${table} WHERE id = $1`;

export async function loadOperationalResource(domain: string, id: string): Promise<OperationalResourceRef | null> {
  const table = OPERATIONAL_TABLES[domain];
  if (!table) return null;
  const r = await pool.query(`${SELECT(table)}`, [id]);
  if (!r.rows[0]) return null;
  return { domain, id, ...(r.rows[0] as Record<string, unknown>) } as OperationalResourceRef;
}

// A job is in a valid completed state for review eligibility when its status is
// 'completed' and the customer has confirmed completion.
export function isReviewEligible(ref: OperationalResourceRef): boolean {
  return ref.status === 'completed' && ref.customerConfirmationStatus === 'confirmed';
}