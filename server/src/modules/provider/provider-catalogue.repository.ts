// Provider service-catalogue repository (Task 13.4).
// All monetary values are stored as NUMERIC and handled as strings in TS
// (never floating point). Capability/pricing/area writes are transactional.
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type {
  OfferingCapability,
  OfferingPricing,
  OfferingStatus,
  ProviderAvailabilityException,
  ProviderLocation,
  ProviderOperatingHours,
  ProviderServiceArea,
  ProviderServiceOffering,
  ServiceCapability,
  ServiceCategory,
  ServiceDomain,
} from './provider-catalogue.types.js';

type Row = Record<string, unknown>;

function money(value: number | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  return value.toFixed(2);
}

// ---------------------------------------------------------------------------
// Reference data
// ---------------------------------------------------------------------------
export async function listCategories(domain?: ServiceDomain): Promise<ServiceCategory[]> {
  const result = await pool.query<Row>(
    `SELECT id, domain, name, description, is_active AS "isActive", sort_order AS "sortOrder"
       FROM service_categories
      WHERE ($1::service_domain IS NULL OR domain = $1)
        AND is_active = TRUE
      ORDER BY domain, sort_order, name`,
    [domain ?? null],
  );
  return result.rows as unknown as ServiceCategory[];
}

export async function listCapabilities(domain?: ServiceDomain): Promise<ServiceCapability[]> {
  const result = await pool.query<Row>(
    `SELECT id, domain, name, description, is_active AS "isActive", sort_order AS "sortOrder"
       FROM service_capabilities
      WHERE ($1::service_domain IS NULL OR domain = $1)
        AND is_active = TRUE
      ORDER BY domain, sort_order, name`,
    [domain ?? null],
  );
  return result.rows as unknown as ServiceCapability[];
}

export async function findCategoryById(id: string): Promise<{ id: string; domain: ServiceDomain } | null> {
  const r = await pool.query<{ id: string; domain: ServiceDomain }>(
    `SELECT id, domain FROM service_categories WHERE id = $1 AND is_active = TRUE`,
    [id],
  );
  return r.rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// Offerings
// ---------------------------------------------------------------------------
const OFFERING_SELECT = `
  SELECT o.id, o.specialized_profile_id AS "specializedProfileId", o.domain,
         o.category_id AS "categoryId", c.name AS "categoryName",
         o.title, o.description, o.service_type AS "serviceType", o.status,
         o.config, o.temporary_unavailable_from::text AS "temporaryUnavailableFrom",
         o.temporary_unavailable_to::text AS "temporaryUnavailableTo",
         o.created_by AS "createdBy", o.updated_by AS "updatedBy",
         o.created_at AS "createdAt", o.updated_at AS "updatedAt"
    FROM provider_service_offerings o
    JOIN service_categories c ON c.id = o.category_id`;

export async function listOfferings(
  profileIds: string[],
  filters: { domain?: ServiceDomain; status?: OfferingStatus },
): Promise<ProviderServiceOffering[]> {
  if (profileIds.length === 0) return [];
  const result = await pool.query<Row>(
    `${OFFERING_SELECT}
      WHERE o.specialized_profile_id = ANY($1::uuid[])
        AND ($2::service_domain IS NULL OR o.domain = $2)
        AND ($3::provider_offering_status IS NULL OR o.status = $3)
      ORDER BY o.created_at DESC`,
    [profileIds, filters.domain ?? null, filters.status ?? null],
  );
  return result.rows as unknown as ProviderServiceOffering[];
}

export async function findOfferingById(id: string): Promise<ProviderServiceOffering | null> {
  const r = await pool.query<Row>(`${OFFERING_SELECT} WHERE o.id = $1`, [id]);
  return (r.rows[0] as unknown as ProviderServiceOffering) ?? null;
}

export interface CreateOfferingData {
  specializedProfileId: string;
  domain: ServiceDomain;
  categoryId: string;
  title: string;
  description: string | null;
  serviceType: string | null;
  status: OfferingStatus;
  config: Record<string, unknown>;
  createdBy: string;
  capabilities?: Array<{ capabilityId: string; enabled: boolean; detail?: string | null }>;
  pricing?: {
    pricingModel: string;
    currency: string;
    baseAmount?: number | null;
    minimumCharge?: number | null;
    unitLabel?: string | null;
    quotationRequired: boolean;
    isIndicative: boolean;
    priceNotes?: string | null;
  };
}

export async function createOffering(data: CreateOfferingData): Promise<ProviderServiceOffering> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const ins = await client.query<{ id: string }>(
      `INSERT INTO provider_service_offerings
         (specialized_profile_id, domain, category_id, title, description, service_type, status, config, created_by, updated_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$9)
       RETURNING id`,
      [
        data.specializedProfileId,
        data.domain,
        data.categoryId,
        data.title,
        data.description,
        data.serviceType,
        data.status,
        JSON.stringify(data.config ?? {}),
        data.createdBy,
      ],
    );
    const offeringId = ins.rows[0]!.id;
    if (data.capabilities && data.capabilities.length) {
      for (const cap of data.capabilities) {
        await client.query(
          `INSERT INTO provider_service_offering_capabilities (offering_id, capability_id, enabled, detail)
           VALUES ($1,$2,$3,$4)
           ON CONFLICT (offering_id, capability_id) DO UPDATE SET enabled = EXCLUDED.enabled, detail = EXCLUDED.detail`,
          [offeringId, cap.capabilityId, cap.enabled, cap.detail],
        );
      }
    }
    if (data.pricing) {
      await client.query(
        `INSERT INTO provider_service_pricing
           (offering_id, pricing_model, currency, base_amount, minimum_charge, unit_label, quotation_required, is_indicative, price_notes)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         ON CONFLICT (offering_id) DO UPDATE SET
           pricing_model = EXCLUDED.pricing_model, currency = EXCLUDED.currency,
           base_amount = EXCLUDED.base_amount, minimum_charge = EXCLUDED.minimum_charge,
           unit_label = EXCLUDED.unit_label, quotation_required = EXCLUDED.quotation_required,
           is_indicative = EXCLUDED.is_indicative, price_notes = EXCLUDED.price_notes`,
        [
          offeringId,
          data.pricing.pricingModel,
          data.pricing.currency,
          money(data.pricing.baseAmount),
          money(data.pricing.minimumCharge),
          data.pricing.unitLabel,
          data.pricing.quotationRequired,
          data.pricing.isIndicative,
          data.pricing.priceNotes,
        ],
      );
    }
    await client.query('COMMIT');
    const created = await findOfferingById(offeringId);
    if (!created) throw new Error('Offering not found after create');
    return created;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function updateOffering(
  id: string,
  data: { title?: string; description?: string | null; serviceType?: string | null; categoryId?: string; config?: Record<string, unknown> },
  userId: string,
): Promise<ProviderServiceOffering | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let i = 1;
  if (data.title !== undefined) {
    fields.push(`title = $${i++}`);
    values.push(data.title);
  }
  if (data.description !== undefined) {
    fields.push(`description = $${i++}`);
    values.push(data.description);
  }
  if (data.serviceType !== undefined) {
    fields.push(`service_type = $${i++}`);
    values.push(data.serviceType);
  }
  if (data.categoryId !== undefined) {
    fields.push(`category_id = $${i++}`);
    values.push(data.categoryId);
  }
  if (data.config !== undefined) {
    fields.push(`config = $${i++}`);
    values.push(JSON.stringify(data.config));
  }
  if (fields.length === 0) return findOfferingById(id);
  fields.push(`updated_by = $${i++}`);
  values.push(userId);
  values.push(id);
  await pool.query(`UPDATE provider_service_offerings SET ${fields.join(', ')} WHERE id = $${i}`, values);
  return findOfferingById(id);
}

export async function setOfferingStatus(
  id: string,
  status: OfferingStatus,
  userId: string,
  temp?: { from: string | null; to: string | null },
): Promise<ProviderServiceOffering | null> {
  await pool.query(
    `UPDATE provider_service_offerings
        SET status = $2,
            temporary_unavailable_from = $3,
            temporary_unavailable_to = $4,
            updated_by = $5
      WHERE id = $1`,
    [id, status, temp?.from ?? null, temp?.to ?? null, userId],
  );
  return findOfferingById(id);
}

// Effective status: an 'unavailable' offering whose temporary window has
// expired is treated as active for discovery (does not permanently disable).
export async function listActiveOfferingProfileIds(domain: ServiceDomain): Promise<string[]> {
  const r = await pool.query<{ id: string }>(
    `SELECT DISTINCT specialized_profile_id AS id
       FROM provider_service_offerings
      WHERE domain = $1
        AND (
          status = 'active'
          OR (status = 'unavailable' AND temporary_unavailable_to IS NOT NULL AND temporary_unavailable_to < CURRENT_DATE)
        )`,
    [domain],
  );
  return r.rows.map((x) => x.id);
}

export async function profileHasActiveOffering(profileId: string, domain: ServiceDomain): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM provider_service_offerings
      WHERE specialized_profile_id = $1 AND domain = $2
        AND (
          status = 'active'
          OR (status = 'unavailable' AND temporary_unavailable_to IS NOT NULL AND temporary_unavailable_to < CURRENT_DATE)
        )
      LIMIT 1`,
    [profileId, domain],
  );
  return r.rowCount !== null && r.rowCount > 0;
}

export async function profileHasAnyOffering(profileId: string): Promise<boolean> {
  const r = await pool.query(`SELECT 1 FROM provider_service_offerings WHERE specialized_profile_id = $1 LIMIT 1`, [profileId]);
  return r.rowCount !== null && r.rowCount > 0;
}

// Worker: reset expired temporary closures back to active.
export async function expireTemporaryClosures(): Promise<number> {
  const r = await pool.query(
    `UPDATE provider_service_offerings
        SET status = 'active', temporary_unavailable_from = NULL, temporary_unavailable_to = NULL, updated_at = NOW()
      WHERE status = 'unavailable'
        AND temporary_unavailable_to IS NOT NULL
        AND temporary_unavailable_to < CURRENT_DATE`,
  );
  return r.rowCount ?? 0;
}

// ---------------------------------------------------------------------------
// Capabilities & pricing
// ---------------------------------------------------------------------------
export async function getOfferingCapabilities(offeringId: string): Promise<OfferingCapability[]> {
  const r = await pool.query<Row>(
    `SELECT pc.id, pc.capability_id AS "capabilityId", sc.name, pc.enabled, pc.detail
       FROM provider_service_offering_capabilities pc
       JOIN service_capabilities sc ON sc.id = pc.capability_id
      WHERE pc.offering_id = $1
      ORDER BY sc.sort_order`,
    [offeringId],
  );
  return r.rows as unknown as OfferingCapability[];
}

export async function replaceOfferingCapabilities(
  offeringId: string,
  caps: Array<{ capabilityId: string; enabled: boolean; detail?: string | null }>,
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM provider_service_offering_capabilities WHERE offering_id = $1`, [offeringId]);
    for (const cap of caps) {
      await client.query(
        `INSERT INTO provider_service_offering_capabilities (offering_id, capability_id, enabled, detail)
         VALUES ($1,$2,$3,$4)`,
        [offeringId, cap.capabilityId, cap.enabled, cap.detail],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function getOfferingPricing(offeringId: string): Promise<OfferingPricing | null> {
  const r = await pool.query<Row>(
    `SELECT id, offering_id AS "offeringId", pricing_model AS "pricingModel", currency,
            base_amount AS "baseAmount", minimum_charge AS "minimumCharge", unit_label AS "unitLabel",
            quotation_required AS "quotationRequired", is_indicative AS "isIndicative", price_notes AS "priceNotes"
       FROM provider_service_pricing WHERE offering_id = $1`,
    [offeringId],
  );
  return (r.rows[0] as unknown as OfferingPricing) ?? null;
}

export async function upsertOfferingPricing(
  offeringId: string,
  data: {
    pricingModel: string;
    currency: string;
    baseAmount?: number | null;
    minimumCharge?: number | null;
    unitLabel?: string | null;
    quotationRequired: boolean;
    isIndicative: boolean;
    priceNotes?: string | null;
  },
): Promise<OfferingPricing> {
  await pool.query(
    `INSERT INTO provider_service_pricing
       (offering_id, pricing_model, currency, base_amount, minimum_charge, unit_label, quotation_required, is_indicative, price_notes)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     ON CONFLICT (offering_id) DO UPDATE SET
       pricing_model = EXCLUDED.pricing_model, currency = EXCLUDED.currency,
       base_amount = EXCLUDED.base_amount, minimum_charge = EXCLUDED.minimum_charge,
       unit_label = EXCLUDED.unit_label, quotation_required = EXCLUDED.quotation_required,
       is_indicative = EXCLUDED.is_indicative, price_notes = EXCLUDED.price_notes`,
    [
      offeringId,
      data.pricingModel,
      data.currency,
      money(data.baseAmount),
      money(data.minimumCharge),
      data.unitLabel,
      data.quotationRequired,
      data.isIndicative,
      data.priceNotes,
    ],
  );
  const pricing = await getOfferingPricing(offeringId);
  if (!pricing) throw new Error('Pricing not found after upsert');
  return pricing;
}

// ---------------------------------------------------------------------------
// Locations (saved_locations extended)
// ---------------------------------------------------------------------------
const LOCATION_SELECT = `
  SELECT id, user_id AS "userId", specialized_profile_id AS "specializedProfileId",
         organisation_id AS "organisationId", location_type AS "locationType", label,
         latitude, longitude, formatted_address AS "formattedAddress", place_id AS "placeId",
         country, county, city, neighbourhood, street, building_name AS "buildingName",
         location_source AS "locationSource", is_public AS "isPublic", visibility,
         is_primary AS "isPrimary", is_active AS "isActive", created_at AS "createdAt", updated_at AS "updatedAt"
    FROM saved_locations`;

export async function listLocations(
  userId: string,
  organisationId: string | null,
): Promise<ProviderLocation[]> {
  const r = await pool.query<Row>(
    `${LOCATION_SELECT}
      WHERE is_active = TRUE
        AND (
          (organisation_id IS NULL AND user_id = $1)
          OR ($2::uuid IS NOT NULL AND organisation_id = $2)
        )
      ORDER BY is_primary DESC, created_at ASC`,
    [userId, organisationId],
  );
  return r.rows as unknown as ProviderLocation[];
}

export interface LocationData {
  userId: string;
  specializedProfileId: string | null;
  organisationId: string | null;
  locationType: string;
  label: string | null;
  latitude: number;
  longitude: number;
  formattedAddress: string | null;
  placeId: string | null;
  country: string | null;
  county: string | null;
  city: string | null;
  neighbourhood: string | null;
  street: string | null;
  buildingName: string | null;
  locationSource: string;
  isPublic: boolean;
  visibility: string;
  isPrimary: boolean;
}

export async function createLocation(data: LocationData): Promise<ProviderLocation> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (data.isPrimary) await clearPrimary(client, data.userId, data.organisationId);
    const ins = await client.query<{ id: string }>(
      `INSERT INTO saved_locations
         (user_id, specialized_profile_id, organisation_id, location_type, label, latitude, longitude,
          formatted_address, place_id, country, county, city, neighbourhood, street, building_name,
          location_source, is_public, visibility, is_primary, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,TRUE)
       RETURNING id`,
      [
        data.userId, data.specializedProfileId, data.organisationId, data.locationType, data.label,
        data.latitude, data.longitude, data.formattedAddress, data.placeId, data.country, data.county,
        data.city, data.neighbourhood, data.street, data.buildingName, data.locationSource,
        data.isPublic, data.visibility, data.isPrimary,
      ],
    );
    await client.query('COMMIT');
    const loc = await findLocationById(ins.rows[0]!.id);
    if (!loc) throw new Error('Location not found after create');
    return loc;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function clearPrimary(client: PoolClient, userId: string, organisationId: string | null): Promise<void> {
  if (organisationId) {
    await client.query(`UPDATE saved_locations SET is_primary = FALSE WHERE organisation_id = $1 AND is_active = TRUE`, [organisationId]);
  } else {
    await client.query(`UPDATE saved_locations SET is_primary = FALSE WHERE user_id = $1 AND organisation_id IS NULL AND is_active = TRUE`, [userId]);
  }
}

export async function findLocationById(id: string): Promise<ProviderLocation | null> {
  const r = await pool.query<Row>(`${LOCATION_SELECT} WHERE id = $1`, [id]);
  return (r.rows[0] as unknown as ProviderLocation) ?? null;
}

export async function updateLocation(
  id: string,
  data: Partial<LocationData>,
  userId: string,
): Promise<ProviderLocation | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const current = await findLocationById(id);
    if (!current) {
      await client.query('ROLLBACK');
      return null;
    }
    if (data.isPrimary) await clearPrimary(client, current.userId, current.organisationId);
    const fields: string[] = [];
    const values: unknown[] = [];
    let i = 1;
    const map: Array<[keyof LocationData, string]> = [
      ['locationType', 'location_type'],
      ['label', 'label'],
      ['latitude', 'latitude'],
      ['longitude', 'longitude'],
      ['formattedAddress', 'formatted_address'],
      ['placeId', 'place_id'],
      ['country', 'country'],
      ['county', 'county'],
      ['city', 'city'],
      ['neighbourhood', 'neighbourhood'],
      ['street', 'street'],
      ['buildingName', 'building_name'],
      ['locationSource', 'location_source'],
      ['isPublic', 'is_public'],
      ['visibility', 'visibility'],
      ['isPrimary', 'is_primary'],
    ];
    for (const [key, col] of map) {
      if (data[key] !== undefined) {
        fields.push(`${col} = $${i++}`);
        values.push(data[key]);
      }
    }
    if (fields.length) {
      values.push(id);
      await client.query(`UPDATE saved_locations SET ${fields.join(', ')} WHERE id = $${i}`, values);
    }
    await client.query('COMMIT');
    return findLocationById(id);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function deleteLocation(id: string): Promise<boolean> {
  const r = await pool.query(`UPDATE saved_locations SET is_active = FALSE, is_primary = FALSE WHERE id = $1`, [id]);
  return (r.rowCount ?? 0) > 0;
}

export async function setPrimaryLocation(id: string, userId: string): Promise<ProviderLocation | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const current = await findLocationById(id);
    if (!current) {
      await client.query('ROLLBACK');
      return null;
    }
    await clearPrimary(client, current.userId, current.organisationId);
    await client.query(`UPDATE saved_locations SET is_primary = TRUE WHERE id = $1`, [id]);
    await client.query('COMMIT');
    return findLocationById(id);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Service areas
// ---------------------------------------------------------------------------
const AREA_SELECT = `
  SELECT id, specialized_profile_id AS "specializedProfileId", offering_id AS "offeringId",
         country, county, city, neighbourhood, area_description AS "areaDescription",
         latitude, longitude, radius_km AS "radiusKm", is_active AS "isActive",
         created_at AS "createdAt", updated_at AS "updatedAt"
    FROM provider_service_areas`;

export async function listServiceAreas(
  profileIds: string[],
  offeringId?: string | null,
): Promise<ProviderServiceArea[]> {
  if (profileIds.length === 0) return [];
  const r = await pool.query<Row>(
    `${AREA_SELECT}
      WHERE specialized_profile_id = ANY($1::uuid[])
        AND ($2::uuid IS NULL OR offering_id = $2)
      ORDER BY created_at ASC`,
    [profileIds, offeringId ?? null],
  );
  return r.rows as unknown as ProviderServiceArea[];
}

export interface ServiceAreaData {
  specializedProfileId: string;
  offeringId: string | null;
  country: string | null;
  county: string | null;
  city: string | null;
  neighbourhood: string | null;
  areaDescription: string | null;
  latitude: number | null;
  longitude: number | null;
  radiusKm: number | null;
  isActive: boolean;
}

export async function createServiceArea(data: ServiceAreaData): Promise<ProviderServiceArea> {
  const ins = await pool.query<{ id: string }>(
    `INSERT INTO provider_service_areas
       (specialized_profile_id, offering_id, country, county, city, neighbourhood, area_description,
        latitude, longitude, radius_km, is_active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING id`,
    [
      data.specializedProfileId, data.offeringId, data.country, data.county, data.city, data.neighbourhood,
      data.areaDescription, data.latitude, data.longitude, data.radiusKm, data.isActive,
    ],
  );
  const r = await pool.query<Row>(`${AREA_SELECT} WHERE id = $1`, [ins.rows[0]!.id]);
  return r.rows[0] as unknown as ProviderServiceArea;
}

export async function findServiceAreaById(id: string): Promise<ProviderServiceArea | null> {
  const r = await pool.query<Row>(`${AREA_SELECT} WHERE id = $1`, [id]);
  return (r.rows[0] as unknown as ProviderServiceArea) ?? null;
}

export async function updateServiceArea(id: string, data: Partial<ServiceAreaData>): Promise<ProviderServiceArea | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let i = 1;
  const map: Array<[keyof ServiceAreaData, string]> = [
    ['offeringId', 'offering_id'],
    ['country', 'country'],
    ['county', 'county'],
    ['city', 'city'],
    ['neighbourhood', 'neighbourhood'],
    ['areaDescription', 'area_description'],
    ['latitude', 'latitude'],
    ['longitude', 'longitude'],
    ['radiusKm', 'radius_km'],
    ['isActive', 'is_active'],
  ];
  for (const [key, col] of map) {
    if (data[key] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(data[key]);
    }
  }
  if (fields.length) {
    values.push(id);
    await pool.query(`UPDATE provider_service_areas SET ${fields.join(', ')} WHERE id = $${i}`, values);
  }
  return findServiceAreaById(id);
}

export async function deleteServiceArea(id: string): Promise<boolean> {
  const r = await pool.query(`DELETE FROM provider_service_areas WHERE id = $1`, [id]);
  return (r.rowCount ?? 0) > 0;
}

// ---------------------------------------------------------------------------
// Operating hours & exceptions
// ---------------------------------------------------------------------------
export async function listOperatingHours(
  profileId: string | null,
  offeringId: string | null,
): Promise<ProviderOperatingHours[]> {
  const r = await pool.query<Row>(
    `SELECT id, specialized_profile_id AS "specializedProfileId", offering_id AS "offeringId",
            day_of_week AS "dayOfWeek", open_time AS "openTime", close_time AS "closeTime",
            is_closed AS "isClosed", time_zone AS "timeZone"
       FROM provider_operating_hours
      WHERE ($1::uuid IS NULL OR specialized_profile_id = $1)
        AND ($2::uuid IS NULL OR offering_id = $2)
      ORDER BY day_of_week, open_time`,
    [profileId, offeringId],
  );
  return r.rows as unknown as ProviderOperatingHours[];
}

export async function replaceOperatingHours(
  profileId: string | null,
  offeringId: string | null,
  timeZone: string,
  hours: Array<{ dayOfWeek: number; openTime: string; closeTime: string; isClosed: boolean }>,
): Promise<ProviderOperatingHours[]> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `DELETE FROM provider_operating_hours
        WHERE ($1::uuid IS NULL OR specialized_profile_id = $1)
          AND ($2::uuid IS NULL OR offering_id = $2)`,
      [profileId, offeringId],
    );
    for (const h of hours) {
      await client.query(
        `INSERT INTO provider_operating_hours
           (specialized_profile_id, offering_id, day_of_week, open_time, close_time, is_closed, time_zone)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [profileId, offeringId, h.dayOfWeek, h.openTime, h.closeTime, h.isClosed, timeZone],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  return listOperatingHours(profileId, offeringId);
}

export async function listExceptions(
  profileId: string,
  offeringId: string | null,
): Promise<ProviderAvailabilityException[]> {
  const r = await pool.query<Row>(
    `SELECT id, specialized_profile_id AS "specializedProfileId", offering_id AS "offeringId",
            exception_date AS "exceptionDate", is_unavailable AS "isUnavailable",
            start_time AS "startTime", end_time AS "endTime", reason, time_zone AS "timeZone"
       FROM provider_availability_exceptions
      WHERE specialized_profile_id = $1
        AND ($2::uuid IS NULL OR offering_id = $2)
      ORDER BY exception_date DESC`,
    [profileId, offeringId ?? null],
  );
  return r.rows as unknown as ProviderAvailabilityException[];
}

export interface ExceptionData {
  specializedProfileId: string;
  offeringId: string | null;
  exceptionDate: string;
  isUnavailable: boolean;
  startTime: string | null;
  endTime: string | null;
  reason: string | null;
  timeZone: string;
}

export async function createException(data: ExceptionData): Promise<ProviderAvailabilityException> {
  const ins = await pool.query<{ id: string }>(
    `INSERT INTO provider_availability_exceptions
       (specialized_profile_id, offering_id, exception_date, is_unavailable, start_time, end_time, reason, time_zone)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING id`,
    [
      data.specializedProfileId, data.offeringId, data.exceptionDate, data.isUnavailable,
      data.startTime, data.endTime, data.reason, data.timeZone,
    ],
  );
  const created = await findExceptionById(ins.rows[0]!.id);
  if (!created) throw new Error('Exception not found after create');
  return created;
}

export async function findExceptionById(id: string): Promise<ProviderAvailabilityException | null> {
  const r = await pool.query<Row>(
    `SELECT id, specialized_profile_id AS "specializedProfileId", offering_id AS "offeringId",
            exception_date AS "exceptionDate", is_unavailable AS "isUnavailable",
            start_time AS "startTime", end_time AS "endTime", reason, time_zone AS "timeZone"
       FROM provider_availability_exceptions WHERE id = $1`,
    [id],
  );
  return (r.rows[0] as unknown as ProviderAvailabilityException) ?? null;
}

export async function updateException(id: string, data: Partial<ExceptionData>): Promise<ProviderAvailabilityException | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let i = 1;
  const map: Array<[keyof ExceptionData, string]> = [
    ['offeringId', 'offering_id'],
    ['exceptionDate', 'exception_date'],
    ['isUnavailable', 'is_unavailable'],
    ['startTime', 'start_time'],
    ['endTime', 'end_time'],
    ['reason', 'reason'],
    ['timeZone', 'time_zone'],
  ];
  for (const [key, col] of map) {
    if (data[key] !== undefined) {
      fields.push(`${col} = $${i++}`);
      values.push(data[key]);
    }
  }
  if (fields.length) {
    values.push(id);
    await pool.query(`UPDATE provider_availability_exceptions SET ${fields.join(', ')} WHERE id = $${i}`, values);
  }
  return findExceptionById(id);
}

export async function deleteException(id: string): Promise<boolean> {
  const r = await pool.query(`DELETE FROM provider_availability_exceptions WHERE id = $1`, [id]);
  return (r.rowCount ?? 0) > 0;
}