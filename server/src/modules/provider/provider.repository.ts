// Provider repository — scoped queries for the provider inbox, request detail
// and dashboard. Uses a single UNION ALL across the three domain tables to
// avoid N+1 queries and to keep pagination correct across service types.
import { pool } from '../../db/pool.js';
import type {
  ProviderContext,
  ProviderDashboardCounts,
  ProviderRequestRow,
} from './provider.types.js';

export interface InboxFilters {
  serviceType?: 'moving' | 'garbage' | 'laundry';
  status?: string;
  limit: number;
  offset: number;
}

// Backward-compatible offering gate: a profile is eligible for a domain when it
// has NO offerings at all (legacy providers) OR at least one active (or
// temporarily-unavailable-but-not-expired) offering in that domain. This keeps
// existing providers working while ensuring catalogue-managed providers only
// receive requests for services they actually offer.
function offeringGate(profileIdExpr: string, domain: string): string {
  return `(NOT EXISTS (SELECT 1 FROM provider_service_offerings o WHERE o.specialized_profile_id = ${profileIdExpr})
       OR EXISTS (SELECT 1 FROM provider_service_offerings o
                   WHERE o.specialized_profile_id = ${profileIdExpr}
                     AND o.domain = '${domain}'::service_domain
                     AND (o.status = 'active'
                          OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL AND o.temporary_unavailable_to < CURRENT_DATE))))`;
}

export function offeringGateForProfile(profileIdExpr: string, domain: string): string {
  return offeringGate(profileIdExpr, domain);
}

// Context-level eligibility: at least one of the given profiles is offering-
// eligible for the domain (legacy no-offering profile OR active offering).
export async function contextHasEligibleOffering(profileIds: string[], domain: string): Promise<boolean> {
  if (profileIds.length === 0) return false;
  const r = await pool.query(
    `SELECT 1 FROM specialized_profiles sp
      WHERE sp.id = ANY($1::uuid[]) AND ${offeringGate('sp.id', domain)}
      LIMIT 1`,
    [profileIds],
  );
  return (r.rowCount ?? 0) > 0;
}

const UNION_SQL = `
  SELECT t.* FROM (
    SELECT mr.id, 'moving'::text AS "serviceType", mr.status::text AS status,
           mr.provider_id AS "providerId", mr.property_id AS "propertyId", mr.unit_id AS "unitId",
           mr.preferred_date_time AS "preferredAt", mr.created_at AS "createdAt",
           mr.item_description AS summary, mr.service_type::text AS category,
           sp.business_name AS "providerName",
           (mr.provider_id IS NOT NULL AND mr.provider_id = ANY($1::uuid[])) AS assigned,
           p.city AS "propertyCity", p.county AS "propertyCounty"
      FROM moving_requests mr
      LEFT JOIN specialized_profiles sp ON sp.id = mr.provider_id
      LEFT JOIN properties p ON p.id = mr.property_id
     WHERE mr.provider_id = ANY($1::uuid[])
         OR (mr.provider_id IS NULL AND mr.status::text = 'submitted'
             AND EXISTS (
               SELECT 1 FROM provider_service_areas psa
                WHERE psa.specialized_profile_id = ANY($2::uuid[])
                  AND psa.is_active
                  AND ${offeringGate('psa.specialized_profile_id', 'moving')}
                  AND ((psa.county IS NOT NULL AND psa.county = p.county)
                       OR (psa.city IS NOT NULL AND psa.city = p.city))))
    UNION ALL
    SELECT lr.id, 'laundry'::text AS "serviceType", lr.status::text AS status,
           lr.provider_id AS "providerId", lr.property_id AS "propertyId", lr.unit_id AS "unitId",
           lr.preferred_date_time AS "preferredAt", lr.created_at AS "createdAt",
           lr.special_instructions AS summary, lr.service_category::text AS category,
           sp.business_name AS "providerName",
           (lr.provider_id IS NOT NULL AND lr.provider_id = ANY($1::uuid[])) AS assigned,
           p.city AS "propertyCity", p.county AS "propertyCounty"
      FROM laundry_requests lr
      LEFT JOIN specialized_profiles sp ON sp.id = lr.provider_id
      LEFT JOIN properties p ON p.id = lr.property_id
     WHERE lr.provider_id = ANY($1::uuid[])
         OR (lr.provider_id IS NULL AND lr.status::text = 'submitted'
             AND EXISTS (
               SELECT 1 FROM provider_service_areas psa
                WHERE psa.specialized_profile_id = ANY($3::uuid[])
                  AND psa.is_active
                  AND ${offeringGate('psa.specialized_profile_id', 'laundry')}
                  AND ((psa.county IS NOT NULL AND psa.county = p.county)
                       OR (psa.city IS NOT NULL AND psa.city = p.city))))
    UNION ALL
    SELECT gcr.id, 'garbage'::text AS "serviceType", gcr.status::text AS status,
           gcr.garbage_provider_id AS "providerId", gcr.property_id AS "propertyId", gcr.unit_id AS "unitId",
           gcr.scheduled_at AS "preferredAt", gcr.created_at AS "createdAt",
           gcr.notes AS summary, gcr.request_type::text AS category,
           gp.name AS "providerName",
           (gcr.garbage_provider_id IS NOT NULL AND gcr.garbage_provider_id = ANY($4::uuid[])) AS assigned,
           p.city AS "propertyCity", p.county AS "propertyCounty"
      FROM garbage_collection_requests gcr
      LEFT JOIN garbage_providers gp ON gp.id = gcr.garbage_provider_id
      LEFT JOIN properties p ON p.id = gcr.property_id
     WHERE gcr.garbage_provider_id = ANY($4::uuid[])
  ) t
  WHERE ($5::text IS NULL OR t."serviceType" = $5)
    AND ($6::text IS NULL OR t.status = $6)
`;

export async function listProviderInbox(
  context: ProviderContext,
  filters: InboxFilters,
): Promise<{ rows: ProviderRequestRow[]; total: number }> {
  const params: unknown[] = [
    context.effectiveProfileIds,
    context.approvedByCategory.moving_service_provider,
    context.approvedByCategory.laundry_service_provider,
    context.garbageProviderIds,
    filters.serviceType ?? null,
    filters.status ?? null,
  ];

  const totalResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::int as count FROM ( ${UNION_SQL} ) c`,
    params,
  );
  const total = Number(totalResult.rows[0]?.count ?? 0);

  const result = await pool.query<ProviderRequestRow>(
    `${UNION_SQL} ORDER BY t."createdAt" DESC LIMIT $7 OFFSET $8`,
    [...params, filters.limit, filters.offset],
  );
  return { rows: result.rows, total };
}

export interface ProviderRequestDetail {
  serviceType: 'moving' | 'garbage' | 'laundry';
  id: string;
  status: string;
  providerId: string | null;
  propertyId: string;
  unitId: string | null;
  propertyCity: string | null;
  propertyCounty: string | null;
  preferredAt: Date | null;
  summary: string | null;
  category: string | null;
  providerName: string | null;
  pickupLocation: string | null;
  destinationLocation: string | null;
  pickupLatitude: number | null;
  pickupLongitude: number | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  createdAt: Date;
  createdBy: string;
}

export async function fetchProviderRequestDetail(
  serviceType: 'moving' | 'garbage' | 'laundry',
  requestId: string,
): Promise<ProviderRequestDetail | null> {
  if (serviceType === 'moving') {
    const r = await pool.query<ProviderRequestDetail>(
      `SELECT 'moving'::text AS "serviceType", mr.id, mr.status::text AS status,
              mr.provider_id AS "providerId", mr.property_id AS "propertyId", mr.unit_id AS "unitId",
              p.city AS "propertyCity", p.county AS "propertyCounty",
              mr.preferred_date_time AS "preferredAt", mr.item_description AS summary,
              mr.service_type::text AS category, sp.business_name AS "providerName",
              mr.pickup_location AS "pickupLocation", mr.destination_location AS "destinationLocation",
              mr.pickup_latitude AS "pickupLatitude", mr.pickup_longitude AS "pickupLongitude",
              mr.contact_name AS "contactName", mr.contact_phone AS "contactPhone", mr.contact_email AS "contactEmail",
              mr.created_at AS "createdAt", mr.created_by AS "createdBy"
         FROM moving_requests mr
         LEFT JOIN specialized_profiles sp ON sp.id = mr.provider_id
         LEFT JOIN properties p ON p.id = mr.property_id
        WHERE mr.id = $1`,
      [requestId],
    );
    return r.rows[0] ?? null;
  }
  if (serviceType === 'laundry') {
    const r = await pool.query<ProviderRequestDetail>(
      `SELECT 'laundry'::text AS "serviceType", lr.id, lr.status::text AS status,
              lr.provider_id AS "providerId", lr.property_id AS "propertyId", lr.unit_id AS "unitId",
              p.city AS "propertyCity", p.county AS "propertyCounty",
              lr.preferred_date_time AS "preferredAt", lr.special_instructions AS summary,
              lr.service_category::text AS category, sp.business_name AS "providerName",
              NULL::text AS "pickupLocation", NULL::text AS "destinationLocation",
              NULL::double precision AS "pickupLatitude", NULL::double precision AS "pickupLongitude",
              lr.contact_name AS "contactName", lr.contact_phone AS "contactPhone", lr.contact_email AS "contactEmail",
              lr.created_at AS "createdAt", lr.created_by AS "createdBy"
         FROM laundry_requests lr
         LEFT JOIN specialized_profiles sp ON sp.id = lr.provider_id
         LEFT JOIN properties p ON p.id = lr.property_id
        WHERE lr.id = $1`,
      [requestId],
    );
    return r.rows[0] ?? null;
  }
  const r = await pool.query<ProviderRequestDetail>(
    `SELECT 'garbage'::text AS "serviceType", gcr.id, gcr.status::text AS status,
            gcr.garbage_provider_id AS "providerId", gcr.property_id AS "propertyId", gcr.unit_id AS "unitId",
            p.city AS "propertyCity", p.county AS "propertyCounty",
            gcr.scheduled_at AS "preferredAt", gcr.notes AS summary,
            gcr.request_type::text AS category, gp.name AS "providerName",
            NULL::text AS "pickupLocation", NULL::text AS "destinationLocation",
            NULL::double precision AS "pickupLatitude", NULL::double precision AS "pickupLongitude",
            NULL::text AS "contactName", NULL::text AS "contactPhone", NULL::text AS "contactEmail",
            gcr.created_at AS "createdAt", gcr.created_by AS "createdBy"
       FROM garbage_collection_requests gcr
       LEFT JOIN garbage_providers gp ON gp.id = gcr.garbage_provider_id
       LEFT JOIN properties p ON p.id = gcr.property_id
      WHERE gcr.id = $1`,
    [requestId],
  );
  return r.rows[0] ?? null;
}

export async function findProvidersByText(query: {
  category?: string;
  county?: string;
  city?: string;
  limit: number;
}) {
  const conditions: string[] = [
    `sp.verification_status = 'approved'`,
    `sp.profile_category = ANY($1::profile_category[])`,
    `EXISTS (SELECT 1 FROM provider_service_areas psa WHERE psa.specialized_profile_id = sp.id AND psa.is_active)`,
  ];
  const values: unknown[] = [
    ['moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider'],
  ];
  let i = 2;
  if (query.category) {
    conditions.push(`sp.profile_category = $${i++}::profile_category`);
    values.push(query.category);
  }
  if (query.county) {
    conditions.push(
      `EXISTS (SELECT 1 FROM provider_service_areas psa WHERE psa.specialized_profile_id = sp.id AND psa.is_active AND psa.county = $${i++})`,
    );
    values.push(query.county);
  }
  if (query.city) {
    conditions.push(
      `EXISTS (SELECT 1 FROM provider_service_areas psa WHERE psa.specialized_profile_id = sp.id AND psa.is_active AND psa.city = $${i++})`,
    );
    values.push(query.city);
  }
  // Offering gate (backward compatible): if a category is supplied, require an
  // active offering in that domain (or no offerings at all); otherwise require
  // an active offering in any domain (or no offerings at all).
  if (query.category) {
    const domain = query.category.replace(/_service_provider$/, '');
    conditions.push(offeringGate('sp.id', domain));
  } else {
    conditions.push(
      `(NOT EXISTS (SELECT 1 FROM provider_service_offerings o WHERE o.specialized_profile_id = sp.id)
        OR EXISTS (SELECT 1 FROM provider_service_offerings o
                    WHERE o.specialized_profile_id = sp.id
                      AND (o.status = 'active'
                           OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL AND o.temporary_unavailable_to < CURRENT_DATE))))`,
    );
  }
  values.push(query.limit);
  const result = await pool.query(
    `SELECT sp.id AS "profileId", sp.profile_category AS "profileCategory",
            sp.business_name AS "businessName", sp.description,
            NULL::double precision AS "distanceKm",
            area.city, area.county, area.area_description AS "areaDescription"
       FROM specialized_profiles sp
       JOIN LATERAL (
         SELECT psa.city, psa.county, psa.area_description
           FROM provider_service_areas psa
          WHERE psa.specialized_profile_id = sp.id AND psa.is_active
          ORDER BY psa.created_at ASC
          LIMIT 1
       ) area ON TRUE
      WHERE ${conditions.join(' AND ')}
      ORDER BY sp.business_name ASC
      LIMIT $${i}`,
    values,
  );
  return result.rows;
}

export async function getProviderDashboardCounts(
  context: ProviderContext,
): Promise<ProviderDashboardCounts> {
  // Assigned counts per status across moving + laundry (specialized profiles)
  // and garbage (garbage providers).
  const assigned = await pool.query<{ status: string; cnt: string }>(
    `SELECT status, COUNT(*)::int AS cnt FROM (
        SELECT mr.status::text AS status FROM moving_requests mr
         WHERE mr.provider_id = ANY($1::uuid[])
        UNION ALL
        SELECT lr.status::text FROM laundry_requests lr
         WHERE lr.provider_id = ANY($1::uuid[])
        UNION ALL
        SELECT gcr.status::text FROM garbage_collection_requests gcr
         WHERE gcr.garbage_provider_id = ANY($2::uuid[])
     ) s GROUP BY status`,
    [context.effectiveProfileIds, context.garbageProviderIds],
  );

  const byStatus = new Map<string, number>();
  for (const row of assigned.rows) byStatus.set(row.status, Number(row.cnt));

  // New eligible (discoverable) requests = unassigned + submitted + area match.
  const eligible = await pool.query<{ cnt: string }>(
    `SELECT COUNT(*)::int AS cnt FROM (
        SELECT mr.id FROM moving_requests mr
         JOIN properties p ON p.id = mr.property_id
         WHERE mr.provider_id IS NULL AND mr.status::text = 'submitted'
           AND EXISTS (SELECT 1 FROM provider_service_areas psa
                        WHERE psa.specialized_profile_id = ANY($1::uuid[]) AND psa.is_active
                          AND ${offeringGate('psa.specialized_profile_id', 'moving')}
                          AND ((psa.county IS NOT NULL AND psa.county = p.county)
                               OR (psa.city IS NOT NULL AND psa.city = p.city)))
        UNION ALL
        SELECT lr.id FROM laundry_requests lr
         JOIN properties p ON p.id = lr.property_id
         WHERE lr.provider_id IS NULL AND lr.status::text = 'submitted'
           AND EXISTS (SELECT 1 FROM provider_service_areas psa
                        WHERE psa.specialized_profile_id = ANY($2::uuid[]) AND psa.is_active
                          AND ${offeringGate('psa.specialized_profile_id', 'laundry')}
                          AND ((psa.county IS NOT NULL AND psa.county = p.county)
                               OR (psa.city IS NOT NULL AND psa.city = p.city)))
     ) e`,
    [
      context.approvedByCategory.moving_service_provider,
      context.approvedByCategory.laundry_service_provider,
    ],
  );

  return {
    newEligibleRequests: Number(eligible.rows[0]?.cnt ?? 0),
    assignedRequests: [...byStatus.values()].reduce((a, b) => a + b, 0),
    pendingResponses: (byStatus.get('submitted') ?? 0) + (byStatus.get('pending_confirmation') ?? 0) + (byStatus.get('pending') ?? 0),
    acceptedJobs: byStatus.get('accepted') ?? 0,
    upcomingJobs: byStatus.get('scheduled') ?? 0,
    activeJobs: (byStatus.get('in_progress') ?? 0) + (byStatus.get('assigned') ?? 0),
    completedJobs: byStatus.get('completed') ?? 0,
    cancelledJobs: (byStatus.get('cancelled') ?? 0) + (byStatus.get('declined') ?? 0),
    pendingQuotations: 0,
  };
}