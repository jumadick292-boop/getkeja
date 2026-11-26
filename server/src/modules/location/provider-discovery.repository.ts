import { pool } from '../../db/pool.js';
import type { ProviderDiscoveryQuery } from './provider-discovery.schema.js';

const providerCategories = [
  'moving_service_provider',
  'garbage_collection_provider',
  'laundry_service_provider',
];

export async function findProviders(query: ProviderDiscoveryQuery) {
  // Backward-compatible offering gate: a profile with no offerings remains
  // eligible (legacy); a catalogue-managed profile must have an active offering
  // in the requested domain (or any domain when no category is specified).
  const domain = query.category ? query.category.replace(/_service_provider$/, '') : null;
  const gate = domain
    ? `(NOT EXISTS (SELECT 1 FROM provider_service_offerings o WHERE o.specialized_profile_id = sp.id)
        OR EXISTS (SELECT 1 FROM provider_service_offerings o
                    WHERE o.specialized_profile_id = sp.id AND o.domain = '${domain}'::service_domain
                      AND (o.status = 'active'
                           OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL AND o.temporary_unavailable_to < CURRENT_DATE))))`
    : `(NOT EXISTS (SELECT 1 FROM provider_service_offerings o WHERE o.specialized_profile_id = sp.id)
        OR EXISTS (SELECT 1 FROM provider_service_offerings o
                    WHERE o.specialized_profile_id = sp.id
                      AND (o.status = 'active'
                           OR (o.status = 'unavailable' AND o.temporary_unavailable_to IS NOT NULL AND o.temporary_unavailable_to < CURRENT_DATE))))`;
  const result = await pool.query(
    `SELECT sp.id AS "profileId", sp.profile_category AS "profileCategory",
            sp.business_name AS "businessName", sp.description,
            round(coverage."distanceKm"::numeric, 1)::double precision AS "distanceKm",
            coverage.city, coverage.county, coverage."areaDescription"
       FROM specialized_profiles sp
       JOIN LATERAL (
         SELECT distance."distanceKm",
                area.city, area.county, area.area_description AS "areaDescription"
           FROM provider_service_areas area
           CROSS JOIN LATERAL (
             SELECT 6371 * acos(LEAST(1, GREATEST(-1,
                      cos(radians($1)) * cos(radians(area.latitude::double precision)) *
                      cos(radians(area.longitude::double precision) - radians($2)) +
                      sin(radians($1)) * sin(radians(area.latitude::double precision))
                    ))) AS "distanceKm"
           ) distance
          WHERE area.specialized_profile_id = sp.id AND area.is_active = TRUE
            AND area.latitude IS NOT NULL AND area.longitude IS NOT NULL
            AND area.radius_km IS NOT NULL
            AND distance."distanceKm" <= area.radius_km
          ORDER BY "distanceKm" ASC
          LIMIT 1
       ) coverage ON TRUE
      WHERE sp.verification_status = 'approved'
        AND sp.profile_category = ANY($3::profile_category[])
        AND ($4::profile_category IS NULL OR sp.profile_category = $4)
        AND ${gate}
      ORDER BY coverage."distanceKm" ASC, sp.business_name ASC
      LIMIT $5`,
    [
      query.latitude,
      query.longitude,
      providerCategories,
      query.category ?? null,
      query.limit,
    ],
  );
  return result.rows;
}
