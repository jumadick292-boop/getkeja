import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import { enqueueSearchAlert } from '../house-seeker/search-alert.worker.js';

// ============================================================================
// LISTING REPOSITORY
// ============================================================================

export interface Listing {
  id: string;
  propertyId: string;
  unitId: string | null;
  title: string;
  description: string | null;
  status: string;
  rentAmount: number | null;
  depositAmount: number;
  availableFrom: Date | null;
  availableTo: Date | null;
  furnished: boolean;
  petPolicy: string | null;
  smokingAllowed: boolean;
  features: Record<string, unknown> | null;
  amenities: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  floorPlanUrl: string | null;
  virtualTourUrl: string | null;
  createdBy: string;
  updatedBy: string | null;
  publishedAt: Date | null;
  pausedAt: Date | null;
  withdrawnAt: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createListing(data: {
  propertyId: string;
  unitId: string | null;
  title: string;
  description: string | null;
  rentAmount: number;
  depositAmount: number;
  availableFrom: Date | null;
  availableTo: Date | null;
  furnished: boolean;
  petPolicy: string | null;
  smokingAllowed: boolean;
  features: Record<string, unknown> | null;
  amenities: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  floorPlanUrl: string | null;
  virtualTourUrl: string | null;
  createdBy: string;
}): Promise<Listing> {
  const result = await pool.query<Listing>(
    `INSERT INTO property_listings (
      property_id, unit_id, title, description, status, rent_amount, deposit_amount,
      available_from, available_to, furnished, pet_policy, smoking_allowed,
      features, amenities, images, floor_plan_url, virtual_tour_url, created_by
    ) VALUES (
      $1, $2, $3, $4, 'draft', $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", title, description, status,
      rent_amount as "rentAmount", deposit_amount as "depositAmount",
      available_from as "availableFrom", available_to as "availableTo", furnished,
      pet_policy as "petPolicy", smoking_allowed as "smokingAllowed",
      features, amenities, images, floor_plan_url as "floorPlanUrl",
      virtual_tour_url as "virtualTourUrl", created_by as "createdBy",
      updated_by as "updatedBy", published_at as "publishedAt",
      paused_at as "pausedAt", withdrawn_at as "withdrawnAt",
      archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.title, data.description ?? null,
      data.rentAmount, data.depositAmount, data.availableFrom ?? null,
      data.availableTo ?? null, data.furnished, data.petPolicy ?? null,
      data.smokingAllowed, data.features ?? null, data.amenities ?? null,
      data.images ?? null, data.floorPlanUrl ?? null, data.virtualTourUrl ?? null,
      data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findListingById(listingId: string): Promise<Listing | undefined> {
  const result = await pool.query<Listing>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", title, description, status,
      rent_amount as "rentAmount", deposit_amount as "depositAmount",
      available_from as "availableFrom", available_to as "availableTo", furnished,
      pet_policy as "petPolicy", smoking_allowed as "smokingAllowed",
      features, amenities, images, floor_plan_url as "floorPlanUrl",
      virtual_tour_url as "virtualTourUrl", created_by as "createdBy",
      updated_by as "updatedBy", published_at as "publishedAt",
      paused_at as "pausedAt", withdrawn_at as "withdrawnAt",
      archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"
    FROM property_listings WHERE id = $1`,
    [listingId],
  );
  return result.rows[0];
}

export async function updateListing(
  listingId: string,
  data: Partial<{
    title: string;
    description: string | null;
    rentAmount: number;
    depositAmount: number;
    availableFrom: Date | null;
    availableTo: Date | null;
    furnished: boolean;
    petPolicy: string | null;
    smokingAllowed: boolean;
    features: Record<string, unknown> | null;
    amenities: Record<string, unknown> | null;
    images: Record<string, unknown> | null;
    floorPlanUrl: string | null;
    virtualTourUrl: string | null;
  }>,
  updatedBy: string,
): Promise<Listing | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    title: 'title',
    description: 'description',
    rentAmount: 'rent_amount',
    depositAmount: 'deposit_amount',
    availableFrom: 'available_from',
    availableTo: 'available_to',
    furnished: 'furnished',
    petPolicy: 'pet_policy',
    smokingAllowed: 'smoking_allowed',
    features: 'features',
    amenities: 'amenities',
    images: 'images',
    floorPlanUrl: 'floor_plan_url',
    virtualTourUrl: 'virtual_tour_url',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const val = (data as Record<string, unknown>)[key];
    if (val !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(val);
    }
  }

  if (fields.length === 0) return findListingById(listingId);

  fields.push(`updated_by = $${paramIndex++}`, `updated_at = NOW()`);
  values.push(updatedBy, listingId);

  const result = await pool.query<Listing>(
    `UPDATE property_listings SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", title, description, status,
      rent_amount as "rentAmount", deposit_amount as "depositAmount",
      available_from as "availableFrom", available_to as "availableTo", furnished,
      pet_policy as "petPolicy", smoking_allowed as "smokingAllowed",
      features, amenities, images, floor_plan_url as "floorPlanUrl",
      virtual_tour_url as "virtualTourUrl", created_by as "createdBy",
      updated_by as "updatedBy", published_at as "publishedAt",
      paused_at as "pausedAt", withdrawn_at as "withdrawnAt",
      archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteListing(listingId: string): Promise<void> {
  await pool.query('DELETE FROM property_listings WHERE id = $1', [listingId]);
}

export async function setListingStatus(
  listingId: string,
  status: string,
  updatedBy: string,
  timestampField: 'published_at' | 'paused_at' | 'withdrawn_at' | 'archived_at' | null = null,
): Promise<Listing | undefined> {
  const fields: string[] = ['status = $1', 'updated_by = $2', 'updated_at = NOW()'];
  const values: unknown[] = [status, updatedBy];
  let paramIndex = 3;

  if (timestampField) {
    fields.push(`${timestampField} = $${paramIndex++}`);
    values.push(new Date());
  }

  values.push(listingId);

  const result = await pool.query<Listing>(
    `UPDATE property_listings SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", title, description, status,
      rent_amount as "rentAmount", deposit_amount as "depositAmount",
      available_from as "availableFrom", available_to as "availableTo", furnished,
      pet_policy as "petPolicy", smoking_allowed as "smokingAllowed",
      features, amenities, images, floor_plan_url as "floorPlanUrl",
      virtual_tour_url as "virtualTourUrl", created_by as "createdBy",
      updated_by as "updatedBy", published_at as "publishedAt",
      paused_at as "pausedAt", withdrawn_at as "withdrawnAt",
      archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  const listing = result.rows[0];

  // Trigger search-alert matching when a listing is published.
  if (status === 'published' && listing) {
    await enqueueSearchAlert(listing.id).catch((err) => {
      // Non-fatal: listing was published; alert processing failure should not block publication.
      console.error(`Failed to enqueue search alert for listing ${listing.id}:`, err);
    });
  }

  return listing;
}

// ============================================================================
// LISTING REPOSITORY (continued - findListings)
// ============================================================================

export async function findListings(query: {
  propertyId?: string;
  unitId?: string;
  status?: string;
  propertyType?: string;
  city?: string;
  county?: string;
  rentMin?: number;
  rentMax?: number;
  bedrooms?: number;
  furnished?: boolean;
  limit: number;
  offset: number;
}): Promise<Listing[]> {
  let sql = `
    SELECT
      pl.id, pl.property_id as "propertyId", pl.unit_id as "unitId", pl.title, pl.description,
      pl.status, pl.rent_amount as "rentAmount", pl.deposit_amount as "depositAmount",
      pl.available_from as "availableFrom", pl.available_to as "availableTo", pl.furnished,
      pl.pet_policy as "petPolicy", pl.smoking_allowed as "smokingAllowed",
      pl.features, pl.amenities, pl.images, pl.floor_plan_url as "floorPlanUrl",
      pl.virtual_tour_url as "virtualTourUrl", pl.created_by as "createdBy",
      pl.updated_by as "updatedBy", pl.published_at as "publishedAt",
      pl.paused_at as "pausedAt", pl.withdrawn_at as "withdrawnAt",
      pl.archived_at as "archivedAt", pl.created_at as "createdAt", pl.updated_at as "updatedAt"
    FROM property_listings pl
    JOIN properties p ON p.id = pl.property_id
    WHERE 1 = 1`;
  const params: unknown[] = [];
  let paramIndex = 1;

  if (query.propertyId) {
    sql += ` AND pl.property_id = $${paramIndex++}`;
    params.push(query.propertyId);
  }
  if (query.unitId) {
    sql += ` AND pl.unit_id = $${paramIndex++}`;
    params.push(query.unitId);
  }
  if (query.status) {
    sql += ` AND pl.status = $${paramIndex++}`;
    params.push(query.status);
  }
  if (query.propertyType) {
    sql += ` AND p.property_type = $${paramIndex++}`;
    params.push(query.propertyType);
  }
  if (query.city) {
    sql += ` AND p.city = $${paramIndex++}`;
    params.push(query.city);
  }
  if (query.county) {
    sql += ` AND p.county = $${paramIndex++}`;
    params.push(query.county);
  }
  if (query.rentMin !== undefined) {
    sql += ` AND pl.rent_amount >= $${paramIndex++}`;
    params.push(query.rentMin);
  }
  if (query.rentMax !== undefined) {
    sql += ` AND pl.rent_amount <= $${paramIndex++}`;
    params.push(query.rentMax);
  }
  if (query.bedrooms !== undefined) {
    sql += ` AND EXISTS (
      SELECT 1 FROM units u WHERE u.property_id = pl.property_id AND u.bedrooms >= $${paramIndex++}
    )`;
    params.push(query.bedrooms);
  }
  if (query.furnished !== undefined) {
    sql += ` AND pl.furnished = $${paramIndex++}`;
    params.push(query.furnished);
  }

  sql += ` ORDER BY pl.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(query.limit, query.offset);

  const result = await pool.query<Listing>(sql, params);
  return result.rows;
}

// ============================================================================
// SITE VISIT STATUS TRANSITIONS
// ============================================================================

export interface SiteVisit {
  id: string;
  propertyId: string;
  unitId: string | null;
  userId: string | null;
  visitorName: string;
  visitorEmail: string | null;
  visitorPhone: string;
  scheduledAt: Date;
  durationMinutes: number;
  status: string;
  hostedByUserId: string | null;
  hostedByOrganisationId: string | null;
  visitorNotes: string | null;
  hostNotes: string | null;
  outcome: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function findSiteVisitById(visitId: string): Promise<SiteVisit | undefined> {
  const result = await pool.query<SiteVisit>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", user_id as "userId",
      visitor_name as "visitorName", visitor_email as "visitorEmail",
      visitor_phone as "visitorPhone", scheduled_at as "scheduledAt",
      duration_minutes as "durationMinutes", status,
      hosted_by_user_id as "hostedByUserId",
      hosted_by_organisation_id as "hostedByOrganisationId",
      visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome,
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM site_visits WHERE id = $1`,
    [visitId],
  );
  return result.rows[0];
}

export async function updateSiteVisitStatus(
  visitId: string,
  status: string,
  updatedBy: string,
  updates: Partial<{
    hostNotes: string | null;
    outcome: string | null;
    scheduledAt: Date | null;
    durationMinutes: number | null;
  }> = {},
): Promise<SiteVisit | undefined> {
  const fields: string[] = ['status = $1', 'updated_by = $2', 'updated_at = NOW()'];
  const values: unknown[] = [status, updatedBy];
  let paramIndex = 3;

  if (updates.hostNotes !== undefined) {
    fields.push(`host_notes = $${paramIndex++}`);
    values.push(updates.hostNotes);
  }
  if (updates.outcome !== undefined) {
    fields.push(`outcome = $${paramIndex++}`);
    values.push(updates.outcome);
  }
  if (updates.scheduledAt !== undefined) {
    fields.push(`scheduled_at = $${paramIndex++}`);
    values.push(updates.scheduledAt);
  }
  if (updates.durationMinutes !== undefined) {
    fields.push(`duration_minutes = $${paramIndex++}`);
    values.push(updates.durationMinutes);
  }

  values.push(visitId);

  const result = await pool.query<SiteVisit>(
    `UPDATE site_visits SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", user_id as "userId",
      visitor_name as "visitorName", visitor_email as "visitorEmail",
      visitor_phone as "visitorPhone", scheduled_at as "scheduledAt",
      duration_minutes as "durationMinutes", status,
      hosted_by_user_id as "hostedByUserId",
      hosted_by_organisation_id as "hostedByOrganisationId",
      visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome,
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function insertSiteVisitHistory(
  visitId: string,
  action: string,
  previousStatus: string | null,
  newStatus: string,
  changedBy: string,
  changeReason: string | null = null,
): Promise<void> {
  await pool.query(
    `INSERT INTO site_visit_history (visit_id, action, previous_status, new_status, changed_by, change_reason)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [visitId, action, previousStatus, newStatus, changedBy, changeReason],
  );
}

// ---------------------------------------------------------------------------
// Availability rules and exceptions (landlord managed)
// ---------------------------------------------------------------------------

export interface AvailabilityRule {
  id: string;
  propertyId: string;
  dayOfWeek: string;
  startTime: string;
  endTime: string;
  slotDurationMinutes: number;
  bufferMinutes: number;
  maxBookingsPerSlot: number;
  isActive: boolean;
}

export interface AvailabilityException {
  id: string;
  propertyId: string;
  exceptionDate: string;
  reason: string | null;
  isUnavailable: boolean;
  startTime: string | null;
  endTime: string | null;
}

export async function listAvailabilityRules(propertyId: string): Promise<AvailabilityRule[]> {
  const result = await pool.query<AvailabilityRule>(
    `SELECT id, property_id AS "propertyId",
            day_of_week::text AS "dayOfWeek",
            to_char(start_time, 'HH24:MI') AS "startTime",
            to_char(end_time, 'HH24:MI') AS "endTime",
            slot_duration_minutes AS "slotDurationMinutes",
            buffer_minutes AS "bufferMinutes",
            max_bookings_per_slot AS "maxBookingsPerSlot",
            is_active AS "isActive"
       FROM site_visit_availability_rules
      WHERE property_id = $1
      ORDER BY day_of_week, start_time`,
    [propertyId],
  );
  return result.rows;
}

export async function upsertAvailabilityRule(
  propertyId: string,
  data: {
    dayOfWeek: string;
    startTime: string;
    endTime: string;
    slotDurationMinutes: number;
    bufferMinutes: number;
    maxBookingsPerSlot: number;
    isActive: boolean;
  },
): Promise<AvailabilityRule> {
  const result = await pool.query<AvailabilityRule>(
    `INSERT INTO site_visit_availability_rules
       (property_id, day_of_week, start_time, end_time, slot_duration_minutes,
        buffer_minutes, max_bookings_per_slot, is_active)
     VALUES ($1, $2::availability_day_of_week, $3::time, $4::time, $5, $6, $7, $8)
     ON CONFLICT (property_id, day_of_week) DO UPDATE
       SET start_time = EXCLUDED.start_time,
           end_time = EXCLUDED.end_time,
           slot_duration_minutes = EXCLUDED.slot_duration_minutes,
           buffer_minutes = EXCLUDED.buffer_minutes,
           max_bookings_per_slot = EXCLUDED.max_bookings_per_slot,
           is_active = EXCLUDED.is_active,
           updated_at = NOW()
     RETURNING id, property_id AS "propertyId",
               day_of_week::text AS "dayOfWeek",
               to_char(start_time, 'HH24:MI') AS "startTime",
               to_char(end_time, 'HH24:MI') AS "endTime",
               slot_duration_minutes AS "slotDurationMinutes",
               buffer_minutes AS "bufferMinutes",
               max_bookings_per_slot AS "maxBookingsPerSlot",
               is_active AS "isActive"`,
    [
      propertyId,
      data.dayOfWeek,
      data.startTime,
      data.endTime,
      data.slotDurationMinutes,
      data.bufferMinutes,
      data.maxBookingsPerSlot,
      data.isActive,
    ],
  );
  const row = result.rows[0]!;
  return row;
}

export async function deleteAvailabilityRule(propertyId: string, ruleId: string): Promise<boolean> {
  const result = await pool.query(
    `DELETE FROM site_visit_availability_rules WHERE id = $1 AND property_id = $2`,
    [ruleId, propertyId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function listAvailabilityExceptions(propertyId: string): Promise<AvailabilityException[]> {
  const result = await pool.query<AvailabilityException>(
    `SELECT id, property_id AS "propertyId",
            to_char(exception_date, 'YYYY-MM-DD') AS "exceptionDate",
            reason, is_unavailable AS "isUnavailable",
            to_char(start_time, 'HH24:MI') AS "startTime",
            to_char(end_time, 'HH24:MI') AS "endTime"
       FROM site_visit_availability_exceptions
      WHERE property_id = $1
      ORDER BY exception_date DESC`,
    [propertyId],
  );
  return result.rows;
}

export async function upsertAvailabilityException(
  propertyId: string,
  data: {
    exceptionDate: string;
    reason: string | null;
    isUnavailable: boolean;
    startTime: string | null;
    endTime: string | null;
  },
): Promise<AvailabilityException> {
  const result = await pool.query<AvailabilityException>(
    `INSERT INTO site_visit_availability_exceptions
       (property_id, exception_date, reason, is_unavailable, start_time, end_time)
     VALUES ($1, $2::date, $3, $4, $5::time, $6::time)
     ON CONFLICT (property_id, exception_date) DO UPDATE
       SET reason = EXCLUDED.reason,
           is_unavailable = EXCLUDED.is_unavailable,
           start_time = EXCLUDED.start_time,
           end_time = EXCLUDED.end_time,
           updated_at = NOW()
     RETURNING id, property_id AS "propertyId",
               to_char(exception_date, 'YYYY-MM-DD') AS "exceptionDate",
               reason, is_unavailable AS "isUnavailable",
               to_char(start_time, 'HH24:MI') AS "startTime",
               to_char(end_time, 'HH24:MI') AS "endTime"`,
    [
      propertyId,
      data.exceptionDate,
      data.reason ?? null,
      data.isUnavailable,
      data.startTime ?? null,
      data.endTime ?? null,
    ],
  );
  return result.rows[0]!;
}

export async function deleteAvailabilityException(
  propertyId: string,
  exceptionId: string,
): Promise<boolean> {
  const result = await pool.query(
    `DELETE FROM site_visit_availability_exceptions WHERE id = $1 AND property_id = $2`,
    [exceptionId, propertyId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function findSiteVisitsByLandlord(
  landlordUserId: string,
  options?: { status?: string; propertyId?: string; limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const conditions: string[] = [`sv.property_id IN (
    SELECT property_id FROM property_ownerships WHERE user_id = $1 AND status = 'active'
    UNION
    SELECT property_id FROM property_assignments WHERE user_id = $1 AND status = 'active'
  )`];
  const values: unknown[] = [landlordUserId];
  let paramIndex = 2;

  if (options?.status) {
    conditions.push(`sv.status = $${paramIndex++}`);
    values.push(options.status);
  }
  if (options?.propertyId) {
    conditions.push(`sv.property_id = $${paramIndex++}`);
    values.push(options.propertyId);
  }

  values.push(limit, offset);

  const result = await pool.query(
    `SELECT
      sv.id, sv.property_id as "propertyId", sv.unit_id as "unitId", sv.user_id as "userId",
      sv.visitor_name as "visitorName", sv.visitor_email as "visitorEmail",
      sv.visitor_phone as "visitorPhone", sv.scheduled_at as "scheduledAt",
      sv.duration_minutes as "durationMinutes", sv.status,
      sv.hosted_by_user_id as "hostedByUserId",
      sv.hosted_by_organisation_id as "hostedByOrganisationId",
      sv.visitor_notes as "visitorNotes", sv.host_notes as "hostNotes", sv.outcome,
      sv.created_by as "createdBy", sv.updated_by as "updatedBy",
      sv.created_at as "createdAt", sv.updated_at as "updatedAt",
      sv.enquiry_id as "enquiryId", sv.assigned_to_user_id as "assignedToUserId"
    FROM site_visits sv
    WHERE ${conditions.join(' AND ')}
    ORDER BY sv.scheduled_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

// ============================================================================
// TENANT REPOSITORY
// ============================================================================

export interface Tenant {
  id: string;
  userId: string | null;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  fullName: string;
  email: string | null;
  phone: string;
  idNumber: string | null;
  idType: string | null;
  emergencyContactName: string | null;
  emergencyContactPhone: string | null;
  employerName: string | null;
  employerContact: string | null;
  monthlyIncome: number | null;
  previousLandlordName: string | null;
  previousLandlordContact: string | null;
  moveInDate: Date | null;
  moveOutDate: Date | null;
  status: string;
  notes: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createTenant(data: {
  userId: string | null;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  fullName: string;
  email: string | null;
  phone: string;
  idNumber: string | null;
  idType: string | null;
  emergencyContactName: string | null;
  emergencyContactPhone: string | null;
  employerName: string | null;
  employerContact: string | null;
  monthlyIncome: number | null;
  previousLandlordName: string | null;
  previousLandlordContact: string | null;
  moveInDate: Date | null;
  moveOutDate: Date | null;
  status: string;
  notes: string | null;
  createdBy: string;
}): Promise<Tenant> {
  const result = await pool.query<Tenant>(
    `INSERT INTO tenants (
      user_id, property_id, unit_id, tenancy_id, full_name, email, phone,
      id_number, id_type, emergency_contact_name, emergency_contact_phone,
      employer_name, employer_contact, monthly_income, previous_landlord_name,
      previous_landlord_contact, move_in_date, move_out_date, status, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21
    )
    RETURNING
      id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone,
      id_number as "idNumber", id_type as "idType",
      emergency_contact_name as "emergencyContactName",
      emergency_contact_phone as "emergencyContactPhone",
      employer_name as "employerName", employer_contact as "employerContact",
      monthly_income as "monthlyIncome",
      previous_landlord_name as "previousLandlordName",
      previous_landlord_contact as "previousLandlordContact",
      move_in_date as "moveInDate", move_out_date as "moveOutDate",
      status, notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.userId, data.propertyId, data.unitId, data.tenancyId,
      data.fullName, data.email, data.phone, data.idNumber, data.idType,
      data.emergencyContactName, data.emergencyContactPhone,
      data.employerName, data.employerContact, data.monthlyIncome,
      data.previousLandlordName, data.previousLandlordContact,
      data.moveInDate, data.moveOutDate, data.status, data.notes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findActiveTenantOnUnit(unitId: string): Promise<Tenant | undefined> {
  const result = await pool.query<Tenant>(
    `SELECT id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone, status
     FROM tenants WHERE unit_id = $1 AND status = 'active' LIMIT 1`,
    [unitId],
  );
  return result.rows[0];
}

export async function findActiveTenantOnUnitWithClient(
  client: PoolClient,
  unitId: string,
): Promise<Tenant | undefined> {
  const result = await client.query<Tenant>(
    `SELECT id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone, status
     FROM tenants WHERE unit_id = $1 AND status = 'active' LIMIT 1`,
    [unitId],
  );
  return result.rows[0];
}

export async function findTenantById(tenantId: string): Promise<Tenant | undefined> {
  const result = await pool.query<Tenant>(
    `SELECT
      id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone,
      id_number as "idNumber", id_type as "idType",
      emergency_contact_name as "emergencyContactName",
      emergency_contact_phone as "emergencyContactPhone",
      employer_name as "employerName", employer_contact as "employerContact",
      monthly_income as "monthlyIncome",
      previous_landlord_name as "previousLandlordName",
      previous_landlord_contact as "previousLandlordContact",
      move_in_date as "moveInDate", move_out_date as "moveOutDate",
      status, notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM tenants WHERE id = $1`,
    [tenantId],
  );
  return result.rows[0];
}

export async function updateTenant(
  tenantId: string,
  data: Partial<{
    unitId: string | null;
    tenancyId: string | null;
    fullName: string;
    email: string | null;
    phone: string;
    idNumber: string | null;
    idType: string | null;
    emergencyContactName: string | null;
    emergencyContactPhone: string | null;
    employerName: string | null;
    employerContact: string | null;
    monthlyIncome: number | null;
    previousLandlordName: string | null;
    previousLandlordContact: string | null;
    moveInDate: Date | null;
    moveOutDate: Date | null;
    status: string;
    notes: string | null;
  }>,
  updatedBy: string,
): Promise<Tenant | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    unitId: 'unit_id',
    tenancyId: 'tenancy_id',
    fullName: 'full_name',
    email: 'email',
    phone: 'phone',
    idNumber: 'id_number',
    idType: 'id_type',
    emergencyContactName: 'emergency_contact_name',
    emergencyContactPhone: 'emergency_contact_phone',
    employerName: 'employer_name',
    employerContact: 'employer_contact',
    monthlyIncome: 'monthly_income',
    previousLandlordName: 'previous_landlord_name',
    previousLandlordContact: 'previous_landlord_contact',
    moveInDate: 'move_in_date',
    moveOutDate: 'move_out_date',
    status: 'status',
    notes: 'notes',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const val = (data as Record<string, unknown>)[key];
    if (val !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(val);
    }
  }

  if (fields.length === 0) return findTenantById(tenantId);

  fields.push(`updated_by = $${paramIndex++}`, `updated_at = NOW()`);
  values.push(updatedBy, tenantId);

  const result = await pool.query<Tenant>(
    `UPDATE tenants SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone,
      id_number as "idNumber", id_type as "idType",
      emergency_contact_name as "emergencyContactName",
      emergency_contact_phone as "emergencyContactPhone",
      employer_name as "employerName", employer_contact as "employerContact",
      monthly_income as "monthlyIncome",
      previous_landlord_name as "previousLandlordName",
      previous_landlord_contact as "previousLandlordContact",
      move_in_date as "moveInDate", move_out_date as "moveOutDate",
      status, notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteTenant(tenantId: string): Promise<void> {
  await pool.query('DELETE FROM tenants WHERE id = $1', [tenantId]);
}

export async function findTenants(query: {
  propertyId?: string;
  unitId?: string;
  tenancyId?: string;
  status?: string;
  limit: number;
  offset: number;
}): Promise<Tenant[]> {
  let sql = `
    SELECT
      id, user_id as "userId", property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", full_name as "fullName", email, phone,
      id_number as "idNumber", id_type as "idType",
      emergency_contact_name as "emergencyContactName",
      emergency_contact_phone as "emergencyContactPhone",
      employer_name as "employerName", employer_contact as "employerContact",
      monthly_income as "monthlyIncome",
      previous_landlord_name as "previousLandlordName",
      previous_landlord_contact as "previousLandlordContact",
      move_in_date as "moveInDate", move_out_date as "moveOutDate",
      status, notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM tenants WHERE 1 = 1`;
  const params: unknown[] = [];
  let paramIndex = 1;

  if (query.propertyId) {
    sql += ` AND property_id = $${paramIndex++}`;
    params.push(query.propertyId);
  }
  if (query.unitId) {
    sql += ` AND unit_id = $${paramIndex++}`;
    params.push(query.unitId);
  }
  if (query.tenancyId) {
    sql += ` AND tenancy_id = $${paramIndex++}`;
    params.push(query.tenancyId);
  }
  if (query.status) {
    sql += ` AND status = $${paramIndex++}`;
    params.push(query.status);
  }

  sql += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(query.limit, query.offset);

  const result = await pool.query<Tenant>(sql, params);
  return result.rows;
}

// ============================================================================
// GARBAGE PROVIDER REPOSITORY
// ============================================================================

export interface GarbageProvider {
  id: string;
  organisationId: string | null;
  name: string;
  contactPerson: string | null;
  contactPhone: string;
  contactEmail: string | null;
  address: string | null;
  serviceAreas: Record<string, unknown>[];
  status: string;
  rating: number | null;
  totalCollections: number;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createGarbageProvider(data: {
  organisationId: string | null;
  name: string;
  contactPerson: string | null;
  contactPhone: string;
  contactEmail: string | null;
  address: string | null;
  serviceAreas: Record<string, unknown>[];
  status: string;
  rating: number | null;
  createdBy: string;
}): Promise<GarbageProvider> {
  const result = await pool.query<GarbageProvider>(
    `INSERT INTO garbage_providers (
      organisation_id, name, contact_person, contact_phone, contact_email,
      address, service_areas, status, rating, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
    )
    RETURNING
      id, organisation_id as "organisationId", name, contact_person as "contactPerson",
      contact_phone as "contactPhone", contact_email as "contactEmail", address,
      service_areas as "serviceAreas", status, rating,
      total_collections as "totalCollections",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.organisationId, data.name, data.contactPerson, data.contactPhone,
      data.contactEmail, data.address, JSON.stringify(data.serviceAreas),
      data.status, data.rating, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findGarbageProviderById(providerId: string): Promise<GarbageProvider | undefined> {
  const result = await pool.query<GarbageProvider>(
    `SELECT
      id, organisation_id as "organisationId", name, contact_person as "contactPerson",
      contact_phone as "contactPhone", contact_email as "contactEmail", address,
      service_areas as "serviceAreas", status, rating,
      total_collections as "totalCollections",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_providers WHERE id = $1`,
    [providerId],
  );
  return result.rows[0];
}

export async function updateGarbageProvider(
  providerId: string,
  data: Partial<{
    name: string;
    contactPerson: string | null;
    contactPhone: string;
    contactEmail: string | null;
    address: string | null;
    serviceAreas: Record<string, unknown>[];
    status: string;
    rating: number | null;
  }>,
  updatedBy: string,
): Promise<GarbageProvider | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    name: 'name',
    contactPerson: 'contact_person',
    contactPhone: 'contact_phone',
    contactEmail: 'contact_email',
    address: 'address',
    serviceAreas: 'service_areas',
    status: 'status',
    rating: 'rating',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const val = (data as Record<string, unknown>)[key];
    if (val !== undefined) {
      if (column === 'service_areas') {
        fields.push(`${column} = $${paramIndex++}`);
        values.push(JSON.stringify(val));
      } else {
        fields.push(`${column} = $${paramIndex++}`);
        values.push(val);
      }
    }
  }

  if (fields.length === 0) return findGarbageProviderById(providerId);

  fields.push(`updated_by = $${paramIndex++}`, `updated_at = NOW()`);
  values.push(updatedBy, providerId);

  const result = await pool.query<GarbageProvider>(
    `UPDATE garbage_providers SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, organisation_id as "organisationId", name, contact_person as "contactPerson",
      contact_phone as "contactPhone", contact_email as "contactEmail", address,
      service_areas as "serviceAreas", status, rating,
      total_collections as "totalCollections",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteGarbageProvider(providerId: string): Promise<void> {
  await pool.query('DELETE FROM garbage_providers WHERE id = $1', [providerId]);
}

export async function findGarbageProviders(query: {
  status?: string;
  limit: number;
  offset: number;
}): Promise<GarbageProvider[]> {
  let sql = `
    SELECT
      id, organisation_id as "organisationId", name, contact_person as "contactPerson",
      contact_phone as "contactPhone", contact_email as "contactEmail", address,
      service_areas as "serviceAreas", status, rating,
      total_collections as "totalCollections",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_providers WHERE 1 = 1`;
  const params: unknown[] = [];
  let paramIndex = 1;

  if (query.status) {
    sql += ` AND status = $${paramIndex++}`;
    params.push(query.status);
  }

  sql += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(query.limit, query.offset);

  const result = await pool.query<GarbageProvider>(sql, params);
  return result.rows;
}

// ============================================================================
// GARBAGE ASSIGNMENT REPOSITORY
// ============================================================================

export interface GarbageAssignment {
  id: string;
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string;
  assignmentType: string;
  frequency: string;
  dayOfWeek: number | null;
  timeSlot: string | null;
  status: string;
  assignedBy: string;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createGarbageAssignment(data: {
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string;
  assignmentType: string;
  frequency: string;
  dayOfWeek: number | null;
  timeSlot: string | null;
  status: string;
  assignedBy: string;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  notes: string | null;
}): Promise<GarbageAssignment> {
  const result = await pool.query<GarbageAssignment>(
    `INSERT INTO garbage_provider_assignments (
      property_id, unit_id, garbage_provider_id, assignment_type, frequency,
      day_of_week, time_slot, status, assigned_by, effective_from, effective_to, notes
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", assignment_type as "assignmentType",
      frequency, day_of_week as "dayOfWeek", time_slot as "timeSlot", status,
      assigned_by as "assignedBy", effective_from as "effectiveFrom",
      effective_to as "effectiveTo", notes, created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.garbageProviderId, data.assignmentType,
      data.frequency, data.dayOfWeek, data.timeSlot, data.status, data.assignedBy,
      data.effectiveFrom, data.effectiveTo, data.notes,
    ],
  );
  return result.rows[0]!;
}

export async function findGarbageAssignmentById(assignmentId: string): Promise<GarbageAssignment | undefined> {
  const result = await pool.query<GarbageAssignment>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", assignment_type as "assignmentType",
      frequency, day_of_week as "dayOfWeek", time_slot as "timeSlot", status,
      assigned_by as "assignedBy", effective_from as "effectiveFrom",
      effective_to as "effectiveTo", notes, created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_provider_assignments WHERE id = $1`,
    [assignmentId],
  );
  return result.rows[0];
}

export async function updateGarbageAssignment(
  assignmentId: string,
  data: Partial<{
    unitId: string | null;
    garbageProviderId: string;
    assignmentType: string;
    frequency: string;
    dayOfWeek: number | null;
    timeSlot: string | null;
    status: string;
    effectiveFrom: Date;
    effectiveTo: Date | null;
    notes: string | null;
  }>,
): Promise<GarbageAssignment | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    unitId: 'unit_id',
    garbageProviderId: 'garbage_provider_id',
    assignmentType: 'assignment_type',
    frequency: 'frequency',
    dayOfWeek: 'day_of_week',
    timeSlot: 'time_slot',
    status: 'status',
    effectiveFrom: 'effective_from',
    effectiveTo: 'effective_to',
    notes: 'notes',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const val = (data as Record<string, unknown>)[key];
    if (val !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(val);
    }
  }

  if (fields.length === 0) return findGarbageAssignmentById(assignmentId);

  fields.push(`updated_at = NOW()`);
  values.push(assignmentId);

  const result = await pool.query<GarbageAssignment>(
    `UPDATE garbage_provider_assignments SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", assignment_type as "assignmentType",
      frequency, day_of_week as "dayOfWeek", time_slot as "timeSlot", status,
      assigned_by as "assignedBy", effective_from as "effectiveFrom",
      effective_to as "effectiveTo", notes, created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteGarbageAssignment(assignmentId: string): Promise<void> {
  await pool.query('DELETE FROM garbage_provider_assignments WHERE id = $1', [assignmentId]);
}

export async function findGarbageAssignments(query: {
  propertyId?: string;
  unitId?: string;
  garbageProviderId?: string;
  status?: string;
  limit: number;
  offset: number;
}): Promise<GarbageAssignment[]> {
  let sql = `
    SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", assignment_type as "assignmentType",
      frequency, day_of_week as "dayOfWeek", time_slot as "timeSlot", status,
      assigned_by as "assignedBy", effective_from as "effectiveFrom",
      effective_to as "effectiveTo", notes, created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_provider_assignments WHERE 1 = 1`;
  const params: unknown[] = [];
  let paramIndex = 1;

  if (query.propertyId) {
    sql += ` AND property_id = $${paramIndex++}`;
    params.push(query.propertyId);
  }
  if (query.unitId) {
    sql += ` AND unit_id = $${paramIndex++}`;
    params.push(query.unitId);
  }
  if (query.garbageProviderId) {
    sql += ` AND garbage_provider_id = $${paramIndex++}`;
    params.push(query.garbageProviderId);
  }
  if (query.status) {
    sql += ` AND status = $${paramIndex++}`;
    params.push(query.status);
  }

  sql += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(query.limit, query.offset);

  const result = await pool.query<GarbageAssignment>(sql, params);
  return result.rows;
}

// ============================================================================
// GARBAGE COLLECTION REQUEST REPOSITORY
// ============================================================================

export interface GarbageCollectionRequest {
  id: string;
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string | null;
  requestType: string;
  status: string;
  scheduledAt: Date | null;
  completedAt: Date | null;
  notes: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createGarbageCollectionRequest(data: {
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string | null;
  requestType: string;
  status: string;
  scheduledAt: Date | null;
  notes: string | null;
  createdBy: string;
}): Promise<GarbageCollectionRequest> {
  const result = await pool.query<GarbageCollectionRequest>(
    `INSERT INTO garbage_collection_requests (
      property_id, unit_id, garbage_provider_id, request_type, status,
      scheduled_at, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.garbageProviderId, data.requestType,
      data.status, data.scheduledAt, data.notes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findGarbageCollectionRequestById(
  requestId: string,
): Promise<GarbageCollectionRequest | undefined> {
  const result = await pool.query<GarbageCollectionRequest>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_collection_requests WHERE id = $1`,
    [requestId],
  );
  return result.rows[0];
}

export async function updateGarbageCollectionRequest(
  requestId: string,
  data: Partial<{
    garbageProviderId: string | null;
    requestType: string;
    status: string;
    scheduledAt: Date | null;
    completedAt: Date | null;
    notes: string | null;
  }>,
  updatedBy: string,
): Promise<GarbageCollectionRequest | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    garbageProviderId: 'garbage_provider_id',
    requestType: 'request_type',
    status: 'status',
    scheduledAt: 'scheduled_at',
    completedAt: 'completed_at',
    notes: 'notes',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const val = (data as Record<string, unknown>)[key];
    if (val !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(val);
    }
  }

  if (fields.length === 0) return findGarbageCollectionRequestById(requestId);

  fields.push(`updated_by = $${paramIndex++}`, `updated_at = NOW()`);
  values.push(updatedBy, requestId);

  const result = await pool.query<GarbageCollectionRequest>(
    `UPDATE garbage_collection_requests SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteGarbageCollectionRequest(requestId: string): Promise<void> {
  await pool.query('DELETE FROM garbage_collection_requests WHERE id = $1', [requestId]);
}

export async function findGarbageCollectionRequests(query: {
  propertyId?: string;
  unitId?: string;
  garbageProviderId?: string;
  status?: string;
  requestType?: string;
  fromDate?: Date;
  toDate?: Date;
  limit: number;
  offset: number;
}): Promise<GarbageCollectionRequest[]> {
  let sql = `
    SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_collection_requests WHERE 1 = 1`;
  const params: unknown[] = [];
  let paramIndex = 1;

  if (query.propertyId) {
    sql += ` AND property_id = $${paramIndex++}`;
    params.push(query.propertyId);
  }
  if (query.unitId) {
    sql += ` AND unit_id = $${paramIndex++}`;
    params.push(query.unitId);
  }
  if (query.garbageProviderId) {
    sql += ` AND garbage_provider_id = $${paramIndex++}`;
    params.push(query.garbageProviderId);
  }
  if (query.status) {
    sql += ` AND status = $${paramIndex++}`;
    params.push(query.status);
  }
  if (query.requestType) {
    sql += ` AND request_type = $${paramIndex++}`;
    params.push(query.requestType);
  }
  if (query.fromDate) {
    sql += ` AND scheduled_at >= $${paramIndex++}`;
    params.push(query.fromDate);
  }
  if (query.toDate) {
    sql += ` AND scheduled_at <= $${paramIndex++}`;
    params.push(query.toDate);
  }

  sql += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(query.limit, query.offset);

  const result = await pool.query<GarbageCollectionRequest>(sql, params);
  return result.rows;
}

// ============================================================================
// DASHBOARD REPOSITORY
// ============================================================================

export interface DashboardStats {
  totalProperties: number;
  totalListings: number;
  publishedListings: number;
  totalUnits: number;
  vacantUnits: number;
  occupiedUnits: number;
  activeTenancies: number;
  totalTenants: number;
  pendingSiteVisits: number;
  activeGarbageAssignments: number;
  pendingGarbageRequests: number;
}
export async function getDashboardStats(
  propertyId?: string,
): Promise<DashboardStats> {
  const propertyFilter = propertyId ? `AND property_id = $1` : '';
  const idFilter = propertyId ? `AND id = $1` : '';
  const params: unknown[] = propertyId ? [propertyId] : [];

  const propertyResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM properties WHERE 1 = 1 ${idFilter}`,
    params,
  );
  const listingResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_listings WHERE 1 = 1 ${propertyFilter}`,
    params,
  );
  const publishedListingsResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_listings WHERE status = 'published' ${propertyFilter}`,
    params,
  );
  const unitResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE 1 = 1 ${propertyFilter}`,
    params,
  );
  const vacantUnitsResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE status = 'vacant' ${propertyFilter}`,
    params,
  );
  const occupiedUnitsResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE status = 'occupied' ${propertyFilter}`,
    params,
  );
  const tenancyResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM tenancies WHERE status = 'active' ${propertyFilter}`,
    params,
  );
  const tenantResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM tenants WHERE 1 = 1 ${propertyFilter}`,
    params,
  );
  const siteVisitResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM site_visits WHERE status = 'scheduled' ${propertyFilter}`,
    params,
  );
  const garbageAssignmentResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM garbage_provider_assignments WHERE status = 'active' ${propertyFilter}`,
    params,
  );
  const garbageRequestResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM garbage_collection_requests WHERE status = 'pending' ${propertyFilter}`,
    params,
  );

  return {
    totalProperties: parseInt(propertyResult.rows[0]?.count || '0', 10),
    totalListings: parseInt(listingResult.rows[0]?.count || '0', 10),
    publishedListings: parseInt(publishedListingsResult.rows[0]?.count || '0', 10),
    totalUnits: parseInt(unitResult.rows[0]?.count || '0', 10),
    vacantUnits: parseInt(vacantUnitsResult.rows[0]?.count || '0', 10),
    occupiedUnits: parseInt(occupiedUnitsResult.rows[0]?.count || '0', 10),
    activeTenancies: parseInt(tenancyResult.rows[0]?.count || '0', 10),
    totalTenants: parseInt(tenantResult.rows[0]?.count || '0', 10),
    pendingSiteVisits: parseInt(siteVisitResult.rows[0]?.count || '0', 10),
    activeGarbageAssignments: parseInt(garbageAssignmentResult.rows[0]?.count || '0', 10),
    pendingGarbageRequests: parseInt(garbageRequestResult.rows[0]?.count || '0', 10),
  };
}

// ============================================================================
// PROPERTY REPOSITORY
// ============================================================================

export interface Property {
  id: string;
  organisationId: string | null;
  title: string;
  description: string | null;
  propertyType: string;
  status: string;
  address: string;
  city: string;
  county: string;
  country: string;
  latitude: number | null;
  longitude: number | null;
  totalUnits: number;
  amenities: Record<string, unknown> | null;
  features: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  createdBy: string;
  updatedBy: string | null;
  publishedAt: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createProperty(data: {
  title: string;
  description: string | null;
  propertyType: string;
  address: string;
  city: string;
  county: string;
  country: string;
  latitude: number | null;
  longitude: number | null;
  totalUnits: number;
  amenities: Record<string, unknown> | null;
  features: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  status: string;
  createdBy: string;
}): Promise<Property> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query<Property>(
      `INSERT INTO properties (
        title, description, property_type, status, address, city, county, country,
        latitude, longitude, total_units, amenities, features, images, created_by
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
      )
      RETURNING
        id, organisation_id as "organisationId", title, description, property_type as "propertyType",
        status, address, city, county, country, latitude, longitude, total_units as "totalUnits",
        amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
        published_at as "publishedAt", archived_at as "archivedAt",
        created_at as "createdAt", updated_at as "updatedAt"`,
      [
        data.title, data.description, data.propertyType, data.status, data.address,
        data.city, data.county, data.country, data.latitude, data.longitude,
        data.totalUnits, data.amenities, data.features, data.images, data.createdBy,
      ],
    );
    const property = result.rows[0]!;
    await client.query(
      `INSERT INTO property_ownerships (
        id, property_id, owner_type, user_id, ownership_share, status, created_by
      ) VALUES ($1, $2, 'individual', $3, 100.00, 'active', $3)`,
      [randomUUID(), property.id, data.createdBy],
    );
    await client.query('COMMIT');
    return property;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findPropertyById(propertyId: string): Promise<Property | undefined> {
  const result = await pool.query<Property>(
    `SELECT
      id, organisation_id as "organisationId", title, description, property_type as "propertyType",
      status, address, city, county, country, latitude, longitude, total_units as "totalUnits",
      amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
      published_at as "publishedAt", archived_at as "archivedAt",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM properties WHERE id = $1`,
    [propertyId],
  );
  return result.rows[0];
}

export async function findProperties({
  status,
  propertyType,
  city,
  county,
  limit = 20,
  offset = 0,
}: {
  status?: string;
  propertyType?: string;
  city?: string;
  county?: string;
  limit?: number;
  offset?: number;
}): Promise<Property[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }
  if (propertyType) {
    conditions.push(`property_type = $${paramIndex++}`);
    values.push(propertyType);
  }
  if (city) {
    conditions.push(`city ILIKE $${paramIndex++}`);
    values.push(`%${city}%`);
  }
  if (county) {
    conditions.push(`county ILIKE $${paramIndex++}`);
    values.push(`%${county}%`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<Property>(
    `SELECT
      id, organisation_id as "organisationId", title, description, property_type as "propertyType",
      status, address, city, county, country, latitude, longitude, total_units as "totalUnits",
      amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
      published_at as "publishedAt", archived_at as "archivedAt",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM properties ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateProperty(
  propertyId: string,
  data: Partial<{
    title: string;
    description: string | null;
    propertyType: string;
    address: string;
    city: string;
    county: string;
    country: string;
    latitude: number | null;
    longitude: number | null;
    totalUnits: number;
    amenities: Record<string, unknown> | null;
    features: Record<string, unknown> | null;
    images: Record<string, unknown> | null;
    status: string;
  }>,
  updatedBy: string,
): Promise<Property | undefined> {
  const fields: string[] = ['updated_by = $1', 'updated_at = NOW()'];
  const values: unknown[] = [updatedBy];
  let paramIndex = 2;

  const fieldMap: Record<string, string> = {
    title: 'title', description: 'description', propertyType: 'property_type',
    status: 'status', address: 'address', city: 'city', county: 'county',
    country: 'country', latitude: 'latitude', longitude: 'longitude',
    totalUnits: 'total_units', amenities: 'amenities', features: 'features',
    images: 'images',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(propertyId);
  const result = await pool.query<Property>(
    `UPDATE properties SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, organisation_id as "organisationId", title, description, property_type as "propertyType",
      status, address, city, county, country, latitude, longitude, total_units as "totalUnits",
      amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
      published_at as "publishedAt", archived_at as "archivedAt",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteProperty(propertyId: string): Promise<void> {
  await pool.query('DELETE FROM properties WHERE id = $1', [propertyId]);
}

// ============================================================================
// UNIT REPOSITORY
// ============================================================================

export interface Unit {
  id: string;
  propertyId: string;
  unitNumber: string;
  building: string | null;
  floor: number | null;
  unitType: string;
  bedrooms: number | null;
  bathrooms: number | null;
  areaSqm: number | null;
  rentAmount: number | null;
  depositAmount: number;
  amenities: Record<string, unknown> | null;
  description: string | null;
  status: string;
  hasSeparateMeter: boolean;
  meterNumber: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createUnit(data: {
  propertyId: string;
  unitNumber: string;
  building: string | null;
  floor: number | null;
  unitType: string;
  bedrooms: number | null;
  bathrooms: number | null;
  areaSqm: number | null;
  rentAmount: number | null;
  depositAmount: number;
  amenities: Record<string, unknown> | null;
  description: string | null;
  status: string;
  hasSeparateMeter: boolean;
  meterNumber: string | null;
  createdBy: string;
}): Promise<Unit> {
  const result = await pool.query<Unit>(
    `INSERT INTO units (
      property_id, unit_number, building, floor_number, unit_type, bedrooms, bathrooms,
      area_sqm, rent_amount, deposit_amount, amenities, description, status,
      has_separate_meter, meter_number, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
    )
    RETURNING
      id, property_id as "propertyId", unit_number as "unitNumber", building, floor_number as "floor",
      unit_type as "unitType", bedrooms, bathrooms, area_sqm as "areaSqm",
      rent_amount as "rentAmount", deposit_amount as "depositAmount", amenities, description,
      status, has_separate_meter as "hasSeparateMeter", meter_number as "meterNumber",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitNumber, data.building, data.floor, data.unitType,
      data.bedrooms, data.bathrooms, data.areaSqm, data.rentAmount, data.depositAmount,
      data.amenities, data.description, data.status, data.hasSeparateMeter,
      data.meterNumber, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findUnitById(unitId: string): Promise<Unit | undefined> {
  const result = await pool.query<Unit>(
    `SELECT
      id, property_id as "propertyId", unit_number as "unitNumber", building, floor_number as "floor",
      unit_type as "unitType", bedrooms, bathrooms, area_sqm as "areaSqm",
      rent_amount as "rentAmount", deposit_amount as "depositAmount", amenities, description,
      status, has_separate_meter as "hasSeparateMeter", meter_number as "meterNumber",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM units WHERE id = $1`,
    [unitId],
  );
  return result.rows[0];
}

export async function findUnits({
  propertyId,
  status,
  unitType,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  status?: string;
  unitType?: string;
  limit?: number;
  offset?: number;
}): Promise<Unit[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }
  if (unitType) {
    conditions.push(`unit_type = $${paramIndex++}`);
    values.push(unitType);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<Unit>(
    `SELECT
      id, property_id as "propertyId", unit_number as "unitNumber", building, floor_number as "floor",
      unit_type as "unitType", bedrooms, bathrooms, area_sqm as "areaSqm",
      rent_amount as "rentAmount", deposit_amount as "depositAmount", amenities, description,
      status, has_separate_meter as "hasSeparateMeter", meter_number as "meterNumber",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM units ${whereClause}
    ORDER BY unit_number
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateUnit(
  unitId: string,
  data: Partial<{
    unitNumber: string;
    building: string | null;
    floor: number | null;
    unitType: string;
    bedrooms: number | null;
    bathrooms: number | null;
    areaSqm: number | null;
    rentAmount: number | null;
    depositAmount: number;
    amenities: Record<string, unknown> | null;
    description: string | null;
    status: string;
    hasSeparateMeter: boolean;
    meterNumber: string | null;
  }>,
  updatedBy: string,
): Promise<Unit | undefined> {
  const fields: string[] = ['updated_by = $1', 'updated_at = NOW()'];
  const values: unknown[] = [updatedBy];
  let paramIndex = 2;

  const fieldMap: Record<string, string> = {
    unitNumber: 'unit_number', building: 'building', floor: 'floor_number',
    unitType: 'unit_type', bedrooms: 'bedrooms', bathrooms: 'bathrooms',
    areaSqm: 'area_sqm', rentAmount: 'rent_amount', depositAmount: 'deposit_amount',
    amenities: 'amenities', description: 'description', status: 'status',
    hasSeparateMeter: 'has_separate_meter', meterNumber: 'meter_number',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(unitId);
  const result = await pool.query<Unit>(
    `UPDATE units SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_number as "unitNumber", building, floor_number as "floor",
      unit_type as "unitType", bedrooms, bathrooms, area_sqm as "areaSqm",
      rent_amount as "rentAmount", deposit_amount as "depositAmount", amenities, description,
      status, has_separate_meter as "hasSeparateMeter", meter_number as "meterNumber",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteUnit(unitId: string): Promise<void> {
  await pool.query('DELETE FROM units WHERE id = $1', [unitId]);
}

// ============================================================================
// PROPERTY DOCUMENT REPOSITORY
// ============================================================================

export interface PropertyDocument {
  id: string;
  propertyId: string;
  unitId: string | null;
  category: string;
  title: string;
  description: string | null;
  fileName: string;
  filePath: string;
  fileSizeBytes: number | null;
  mimeType: string | null;
  visibility: string;
  uploadedBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export async function createPropertyDocument(data: {
  propertyId: string;
  unitId: string | null;
  category: string;
  title: string;
  description: string | null;
  fileName: string;
  filePath: string;
  fileSizeBytes: number | null;
  mimeType: string | null;
  visibility: string;
  uploadedBy: string;
}): Promise<PropertyDocument> {
  const result = await pool.query<PropertyDocument>(
    `INSERT INTO property_documents (
      property_id, unit_id, category, title, description, file_name, file_path,
      file_size_bytes, mime_type, visibility, uploaded_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", category, title, description,
      file_name as "fileName", file_path as "filePath", file_size_bytes as "fileSizeBytes",
      mime_type as "mimeType", visibility, uploaded_by as "uploadedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.category, data.title, data.description,
      data.fileName, data.filePath, data.fileSizeBytes, data.mimeType, data.visibility,
      data.uploadedBy,
    ],
  );
  return result.rows[0]!;
}

export async function findPropertyDocuments({
  propertyId,
  unitId,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  unitId?: string;
  limit?: number;
  offset?: number;
}): Promise<PropertyDocument[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<PropertyDocument>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", category, title, description,
      file_name as "fileName", file_path as "filePath", file_size_bytes as "fileSizeBytes",
      mime_type as "mimeType", visibility, uploaded_by as "uploadedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM property_documents ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

// ============================================================================
// ENQUIRY REPOSITORY
// ============================================================================

export interface Enquiry {
  id: string;
  propertyId: string;
  unitId: string | null;
  listingId: string | null;
  prospectiveRenterId: string | null;
  prospectiveRenterName: string;
  prospectiveRenterEmail: string | null;
  prospectiveRenterPhone: string;
  enquirySource: string;
  message: string | null;
  status: string;
  assignedToUserId: string | null;
  assignedToOrganisationId: string | null;
  followUpDate: Date | null;
  internalNotes: string | null;
  lastContactAt: Date | null;
  convertedToTenantId: string | null;
  convertedToTenancyId: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createEnquiry(data: {
  propertyId: string;
  unitId: string | null;
  listingId: string | null;
  prospectiveRenterId: string | null;
  prospectiveRenterName: string;
  prospectiveRenterEmail: string | null;
  prospectiveRenterPhone: string;
  enquirySource: string;
  message: string | null;
  assignedToUserId: string | null;
  followUpDate: Date | null;
  internalNotes: string | null;
  createdBy: string;
}): Promise<Enquiry> {
  const result = await pool.query<Enquiry>(
    `INSERT INTO property_enquiries (
      property_id, unit_id, listing_id, prospective_renter_id, prospective_renter_name,
      prospective_renter_email, prospective_renter_phone, enquiry_source, message, status,
      assigned_to_user_id, follow_up_date, internal_notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, 'new', $10, $11, $12, $13
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", listing_id as "listingId",
      prospective_renter_id as "prospectiveRenterId", prospective_renter_name as "prospectiveRenterName",
      prospective_renter_email as "prospectiveRenterEmail", prospective_renter_phone as "prospectiveRenterPhone",
      enquiry_source as "enquirySource", message, status,
      assigned_to_user_id as "assignedToUserId", assigned_to_organisation_id as "assignedToOrganisationId",
      follow_up_date as "followUpDate", internal_notes as "internalNotes",
      last_contact_at as "lastContactAt", converted_to_tenant_id as "convertedToTenantId",
      converted_to_tenancy_id as "convertedToTenancyId", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.listingId, data.prospectiveRenterId,
      data.prospectiveRenterName, data.prospectiveRenterEmail, data.prospectiveRenterPhone,
      data.enquirySource, data.message, data.assignedToUserId, data.followUpDate,
      data.internalNotes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findEnquiryById(enquiryId: string): Promise<Enquiry | undefined> {
  const result = await pool.query<Enquiry>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", listing_id as "listingId",
      prospective_renter_id as "prospectiveRenterId", prospective_renter_name as "prospectiveRenterName",
      prospective_renter_email as "prospectiveRenterEmail", prospective_renter_phone as "prospectiveRenterPhone",
      enquiry_source as "enquirySource", message, status,
      assigned_to_user_id as "assignedToUserId", assigned_to_organisation_id as "assignedToOrganisationId",
      follow_up_date as "followUpDate", internal_notes as "internalNotes",
      last_contact_at as "lastContactAt", converted_to_tenant_id as "convertedToTenantId",
      converted_to_tenancy_id as "convertedToTenancyId", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
    FROM property_enquiries WHERE id = $1`,
    [enquiryId],
  );
  return result.rows[0];
}

export async function findEnquiries({
  propertyId,
  unitId,
  listingId,
  status,
  source,
  assignedToUserId,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  unitId?: string;
  listingId?: string;
  status?: string;
  source?: string;
  assignedToUserId?: string;
  limit?: number;
  offset?: number;
}): Promise<Enquiry[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }
  if (listingId) {
    conditions.push(`listing_id = $${paramIndex++}`);
    values.push(listingId);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }
  if (source) {
    conditions.push(`enquiry_source = $${paramIndex++}`);
    values.push(source);
  }
  if (assignedToUserId) {
    conditions.push(`assigned_to_user_id = $${paramIndex++}`);
    values.push(assignedToUserId);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<Enquiry>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", listing_id as "listingId",
      prospective_renter_id as "prospectiveRenterId", prospective_renter_name as "prospectiveRenterName",
      prospective_renter_email as "prospectiveRenterEmail", prospective_renter_phone as "prospectiveRenterPhone",
      enquiry_source as "enquirySource", message, status,
      assigned_to_user_id as "assignedToUserId", assigned_to_organisation_id as "assignedToOrganisationId",
      follow_up_date as "followUpDate", internal_notes as "internalNotes",
      last_contact_at as "lastContactAt", converted_to_tenant_id as "convertedToTenantId",
      converted_to_tenancy_id as "convertedToTenancyId", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
    FROM property_enquiries ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateEnquiry(
  enquiryId: string,
  data: Partial<{
    unitId: string | null;
    listingId: string | null;
    prospectiveRenterName: string;
    prospectiveRenterEmail: string | null;
    prospectiveRenterPhone: string;
    enquirySource: string;
    message: string | null;
    status: string;
    assignedToUserId: string | null;
    followUpDate: Date | null;
    internalNotes: string | null;
  }>,
  updatedBy: string,
): Promise<Enquiry | undefined> {
  const fields: string[] = ['updated_by = $1', 'updated_at = NOW()'];
  const values: unknown[] = [updatedBy];
  let paramIndex = 2;

  const fieldMap: Record<string, string> = {
    unitId: 'unit_id', listingId: 'listing_id', prospectiveRenterName: 'prospective_renter_name',
    prospectiveRenterEmail: 'prospective_renter_email', prospectiveRenterPhone: 'prospective_renter_phone',
    enquirySource: 'enquiry_source', message: 'message', status: 'status',
    assignedToUserId: 'assigned_to_user_id', followUpDate: 'follow_up_date',
    internalNotes: 'internal_notes',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(enquiryId);
  const result = await pool.query<Enquiry>(
    `UPDATE property_enquiries SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", listing_id as "listingId",
      prospective_renter_id as "prospectiveRenterId", prospective_renter_name as "prospectiveRenterName",
      prospective_renter_email as "prospectiveRenterEmail", prospective_renter_phone as "prospectiveRenterPhone",
      enquiry_source as "enquirySource", message, status,
      assigned_to_user_id as "assignedToUserId", assigned_to_organisation_id as "assignedToOrganisationId",
      follow_up_date as "followUpDate", internal_notes as "internalNotes",
      last_contact_at as "lastContactAt", converted_to_tenant_id as "convertedToTenantId",
      converted_to_tenancy_id as "convertedToTenancyId", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function createEnquiryNote(data: {
  enquiryId: string;
  userId: string;
  note: string;
  isInternal: boolean;
}): Promise<void> {
  await pool.query(
    `INSERT INTO enquiry_notes (enquiry_id, user_id, note, is_internal)
     VALUES ($1, $2, $3, $4)`,
    [data.enquiryId, data.userId, data.note, data.isInternal],
  );
}

export async function findEnquiryNotes(enquiryId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT id, enquiry_id as "enquiryId", user_id as "userId", note, is_internal as "isInternal", created_at as "createdAt"
     FROM enquiry_notes WHERE enquiry_id = $1 ORDER BY created_at ASC`,
    [enquiryId],
  );
  return result.rows;
}

// ============================================================================
// CONVERSATION REPOSITORY
// ============================================================================

export interface Conversation {
  id: string;
  type: string;
  subject: string | null;
  propertyId: string | null;
  unitId: string | null;
  enquiryId: string | null;
  rentalProposalId: string | null;
  tenancyId: string | null;
  siteVisitId: string | null;
  createdBy: string;
  status: string;
  lastMessageAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createConversation(data: {
  type: string;
  subject: string | null;
  propertyId: string | null;
  unitId: string | null;
  enquiryId: string | null;
  participantUserIds: string[];
  createdBy: string;
}): Promise<Conversation> {
  const result = await pool.query<Conversation>(
    `INSERT INTO conversations (type, subject, property_id, unit_id, enquiry_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING
       id, type, subject, property_id as "propertyId", unit_id as "unitId",
       enquiry_id as "enquiryId", rental_proposal_id as "rentalProposalId",
       tenancy_id as "tenancyId", site_visit_id as "siteVisitId", created_by as "createdBy",
       status, last_message_at as "lastMessageAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [data.type, data.subject, data.propertyId, data.unitId, data.enquiryId, data.createdBy],
  );
  const conversation = result.rows[0]!;

  // Add participants (creator + others)
  const allParticipants = new Set([data.createdBy, ...data.participantUserIds]);
  for (const userId of allParticipants) {
    await pool.query(
      `INSERT INTO conversation_participants (conversation_id, user_id, role)
       VALUES ($1, $2, $3)
       ON CONFLICT (conversation_id, user_id) DO NOTHING`,
      [conversation.id, userId, userId === data.createdBy ? 'owner' : 'participant'],
    );
  }

  return conversation;
}

export async function findConversations({
  type,
  propertyId,
  enquiryId,
  limit = 20,
  offset = 0,
}: {
  type?: string;
  propertyId?: string;
  enquiryId?: string;
  limit?: number;
  offset?: number;
}): Promise<Conversation[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (type) {
    conditions.push(`type = $${paramIndex++}`);
    values.push(type);
  }
  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (enquiryId) {
    conditions.push(`enquiry_id = $${paramIndex++}`);
    values.push(enquiryId);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<Conversation>(
    `SELECT
      id, type, subject, property_id as "propertyId", unit_id as "unitId",
      enquiry_id as "enquiryId", rental_proposal_id as "rentalProposalId",
      tenancy_id as "tenancyId", site_visit_id as "siteVisitId", created_by as "createdBy",
      status, last_message_at as "lastMessageAt", created_at as "createdAt", updated_at as "updatedAt"
    FROM conversations ${whereClause}
    ORDER BY COALESCE(last_message_at, created_at) DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function findConversationById(conversationId: string): Promise<Conversation | undefined> {
  const result = await pool.query<Conversation>(
    `SELECT
      id, type, subject, property_id as "propertyId", unit_id as "unitId",
      enquiry_id as "enquiryId", rental_proposal_id as "rentalProposalId",
      tenancy_id as "tenancyId", site_visit_id as "siteVisitId", created_by as "createdBy",
      status, last_message_at as "lastMessageAt", created_at as "createdAt", updated_at as "updatedAt"
    FROM conversations WHERE id = $1`,
    [conversationId],
  );
  return result.rows[0];
}

export async function getConversationParticipants(conversationId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT cp.id, cp.conversation_id as "conversationId", cp.user_id as "userId",
            cp.role, cp.joined_at as "joinedAt", cp.left_at as "leftAt",
            cp.is_muted as "isMuted", cp.last_read_at as "lastReadAt",
            u.email, u.name, u.first_name as "firstName", u.last_name as "lastName"
     FROM conversation_participants cp
     JOIN users u ON u.id = cp.user_id
     WHERE cp.conversation_id = $1 AND cp.left_at IS NULL
     ORDER BY cp.joined_at ASC`,
    [conversationId],
  );
  return result.rows;
}

// ============================================================================
// MESSAGE REPOSITORY
// ============================================================================

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  type: string;
  content: string;
  status: string;
  replyToId: string | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

export async function createMessage(data: {
  conversationId: string;
  senderId: string;
  type: string;
  content: string;
  replyToId: string | null;
}): Promise<Message> {
  const result = await pool.query<Message>(
    `INSERT INTO messages (conversation_id, sender_id, type, content, reply_to_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING
       id, conversation_id as "conversationId", sender_id as "senderId", type, content,
       status, reply_to_id as "replyToId", created_at as "createdAt",
       updated_at as "updatedAt", deleted_at as "deletedAt"`,
    [data.conversationId, data.senderId, data.type, data.content, data.replyToId],
  );
  return result.rows[0]!;
}

export async function findMessages({
  conversationId,
  limit = 50,
  offset = 0,
}: {
  conversationId: string;
  limit?: number;
  offset?: number;
}): Promise<Message[]> {
  const result = await pool.query<Message>(
    `SELECT
      id, conversation_id as "conversationId", sender_id as "senderId", type, content,
      status, reply_to_id as "replyToId", created_at as "createdAt",
      updated_at as "updatedAt", deleted_at as "deletedAt"
    FROM messages
    WHERE conversation_id = $1 AND deleted_at IS NULL
    ORDER BY created_at ASC
    LIMIT $2 OFFSET $3`,
    [conversationId, limit, offset],
  );
  return result.rows;
}

export async function markMessageAsRead(messageId: string, userId: string): Promise<void> {
  await pool.query(
    `INSERT INTO message_read_states (message_id, user_id)
     VALUES ($1, $2)
     ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = NOW()`,
    [messageId, userId],
  );
}

export async function getUnreadMessageCount(conversationId: string, userId: string): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM messages m
     WHERE m.conversation_id = $1 AND m.deleted_at IS NULL
     AND NOT EXISTS (
       SELECT 1 FROM message_read_states mrs
       WHERE mrs.message_id = m.id AND mrs.user_id = $2
     )`,
    [conversationId, userId],
  );
  return parseInt(result.rows[0]?.count || '0', 10);
}

// ============================================================================
// RENTAL PROPOSAL REPOSITORY
// ============================================================================

export interface RentalProposal {
  id: string;
  enquiryId: string | null;
  conversationId: string | null;
  rentalApplicationId: string | null;
  propertyId: string;
  unitId: string | null;
  prospectiveRenterId: string;
  landlordUserId: string;
  type: string;
  status: string;
  proposedRentAmount: number;
  proposedDepositAmount: number;
  proposedStartDate: Date;
  proposedEndDate: Date | null;
  proposedRentDueDay: number;
  specialConditions: string | null;
  notes: string | null;
  expiresAt: Date;
  acceptedAt: Date | null;
  declinedAt: Date | null;
  withdrawnAt: Date | null;
  confirmedAt: Date | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createRentalProposal(data: {
  enquiryId: string | null;
  rentalApplicationId: string | null;
  propertyId: string;
  unitId: string | null;
  prospectiveRenterId: string;
  landlordUserId: string;
  type: string;
  proposedRentAmount: number;
  proposedDepositAmount: number;
  proposedStartDate: Date;
  proposedEndDate: Date | null;
  proposedRentDueDay: number;
  specialConditions: string | null;
  notes: string | null;
  expiresAt: Date;
  createdBy: string;
}): Promise<RentalProposal> {
  const result = await pool.query<RentalProposal>(
    `INSERT INTO rental_proposals (
      enquiry_id, rental_application_id, property_id, unit_id, prospective_renter_id, landlord_user_id,
      type, status, proposed_rent_amount, proposed_deposit_amount, proposed_start_date,
      proposed_end_date, proposed_rent_due_day, special_conditions, notes, expires_at, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, 'draft', $8, $9, $10, $11, $12, $13, $14, $15, $16
    )
    RETURNING
      id, enquiry_id as "enquiryId", conversation_id as "conversationId",
      rental_application_id as "rentalApplicationId",
      property_id as "propertyId", unit_id as "unitId",
      prospective_renter_id as "prospectiveRenterId", landlord_user_id as "landlordUserId",
      type, status, proposed_rent_amount as "proposedRentAmount",
      proposed_deposit_amount as "proposedDepositAmount",
      proposed_start_date as "proposedStartDate", proposed_end_date as "proposedEndDate",
      proposed_rent_due_day as "proposedRentDueDay", special_conditions as "specialConditions",
      notes, expires_at as "expiresAt", accepted_at as "acceptedAt",
      declined_at as "declinedAt", withdrawn_at as "withdrawnAt",
      confirmed_at as "confirmedAt", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.enquiryId, data.rentalApplicationId, data.propertyId, data.unitId, data.prospectiveRenterId,
      data.landlordUserId, data.type, data.proposedRentAmount, data.proposedDepositAmount,
      data.proposedStartDate, data.proposedEndDate, data.proposedRentDueDay,
      data.specialConditions, data.notes, data.expiresAt, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findRentalProposalById(proposalId: string): Promise<RentalProposal | undefined> {
  const result = await pool.query<RentalProposal>(
    `SELECT
      id, enquiry_id as "enquiryId", conversation_id as "conversationId",
      rental_application_id as "rentalApplicationId",
      property_id as "propertyId", unit_id as "unitId",
      prospective_renter_id as "prospectiveRenterId", landlord_user_id as "landlordUserId",
      type, status, proposed_rent_amount as "proposedRentAmount",
      proposed_deposit_amount as "proposedDepositAmount",
      proposed_start_date as "proposedStartDate", proposed_end_date as "proposedEndDate",
      proposed_rent_due_day as "proposedRentDueDay", special_conditions as "specialConditions",
      notes, expires_at as "expiresAt", accepted_at as "acceptedAt",
      declined_at as "declinedAt", withdrawn_at as "withdrawnAt",
      confirmed_at as "confirmedAt", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
    FROM rental_proposals WHERE id = $1`,
    [proposalId],
  );
  return result.rows[0];
}

export async function findRentalProposals({
  propertyId,
  unitId,
  prospectiveRenterId,
  status,
  type,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  unitId?: string;
  prospectiveRenterId?: string;
  status?: string;
  type?: string;
  limit?: number;
  offset?: number;
}): Promise<RentalProposal[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }
  if (prospectiveRenterId) {
    conditions.push(`prospective_renter_id = $${paramIndex++}`);
    values.push(prospectiveRenterId);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }
  if (type) {
    conditions.push(`type = $${paramIndex++}`);
    values.push(type);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<RentalProposal>(
    `SELECT
      id, enquiry_id as "enquiryId", conversation_id as "conversationId",
      rental_application_id as "rentalApplicationId",
      property_id as "propertyId", unit_id as "unitId",
      prospective_renter_id as "prospectiveRenterId", landlord_user_id as "landlordUserId",
      type, status, proposed_rent_amount as "proposedRentAmount",
      proposed_deposit_amount as "proposedDepositAmount",
      proposed_start_date as "proposedStartDate", proposed_end_date as "proposedEndDate",
      proposed_rent_due_day as "proposedRentDueDay", special_conditions as "specialConditions",
      notes, expires_at as "expiresAt", accepted_at as "acceptedAt",
      declined_at as "declinedAt", withdrawn_at as "withdrawnAt",
      confirmed_at as "confirmedAt", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
    FROM rental_proposals ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateRentalProposal(
  proposalId: string,
  data: Partial<{
    proposedRentAmount: number;
    proposedDepositAmount: number;
    proposedStartDate: Date;
    proposedEndDate: Date | null;
    proposedRentDueDay: number;
    specialConditions: string | null;
    notes: string | null;
    expiresAt: Date;
  }>,
  updatedBy: string,
): Promise<RentalProposal | undefined> {
  const fields: string[] = ['updated_by = $1', 'updated_at = NOW()'];
  const values: unknown[] = [updatedBy];
  let paramIndex = 2;

  const fieldMap: Record<string, string> = {
    proposedRentAmount: 'proposed_rent_amount', proposedDepositAmount: 'proposed_deposit_amount',
    proposedStartDate: 'proposed_start_date', proposedEndDate: 'proposed_end_date',
    proposedRentDueDay: 'proposed_rent_due_day', specialConditions: 'special_conditions',
    notes: 'notes', expiresAt: 'expires_at',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(proposalId);
  const result = await pool.query<RentalProposal>(
    `UPDATE rental_proposals SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, enquiry_id as "enquiryId", conversation_id as "conversationId",
      rental_application_id as "rentalApplicationId",
      property_id as "propertyId", unit_id as "unitId",
      prospective_renter_id as "prospectiveRenterId", landlord_user_id as "landlordUserId",
      type, status, proposed_rent_amount as "proposedRentAmount",
      proposed_deposit_amount as "proposedDepositAmount",
      proposed_start_date as "proposedStartDate", proposed_end_date as "proposedEndDate",
      proposed_rent_due_day as "proposedRentDueDay", special_conditions as "specialConditions",
      notes, expires_at as "expiresAt", accepted_at as "acceptedAt",
      declined_at as "declinedAt", withdrawn_at as "withdrawnAt",
      confirmed_at as "confirmedAt", created_by as "createdBy",
      updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

/**
 * Resolve the authorized participants for a rental proposal: the landlord /
 * property managers (owners + assigned staff) and the prospective renter.
 * Used to target transactional outbox notifications for proposal events.
 */
async function resolveProposalRecipients(
  client: PoolClient | typeof pool,
  proposal: { propertyId: string | null; prospectiveRenterId: string | null; landlordUserId: string | null },
): Promise<string[]> {
  const recipients = new Set<string>();
  if (proposal.landlordUserId) recipients.add(proposal.landlordUserId);
  if (proposal.prospectiveRenterId) recipients.add(proposal.prospectiveRenterId);
  if (proposal.propertyId) {
    const managers = await client.query<{ user_id: string }>(
      `SELECT po.user_id AS user_id
         FROM property_ownerships po
        WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
          AND (po.effective_to IS NULL OR po.effective_to > NOW())
       UNION
       SELECT pa.user_id AS user_id
         FROM property_assignments pa
        WHERE pa.property_id = $1 AND pa.status = 'active' AND pa.user_id IS NOT NULL
          AND pa.assignment_type IN ('property_manager','letting_agent')
          AND (pa.effective_to IS NULL OR pa.effective_to > NOW())`,
      [proposal.propertyId],
    );
    managers.rows.forEach((r) => recipients.add(r.user_id));
  }
  return [...recipients];
}

export async function setRentalProposalStatus(
  proposalId: string,
  status: string,
  changedBy: string,
  changeReason: string | null,
  timestampField: 'accepted_at' | 'declined_at' | 'withdrawn_at' | 'confirmed_at' | null = null,
  notification?: { eventType: string; idempotencyKey: string },
): Promise<RentalProposal | undefined> {
  return transaction(async (client) => {
    // Capture the previous status BEFORE updating so the history row records
    // the true transition (previous_status -> new_status). Reading it after the
    // UPDATE would return the new status, defeating the purpose of the audit trail.
    const before = await client.query<{ status: string }>(
      `SELECT status FROM rental_proposals WHERE id = $1 FOR UPDATE`,
      [proposalId],
    );

    const fields: string[] = ['status = $1', 'updated_by = $2', 'updated_at = NOW()'];
    const values: unknown[] = [status, changedBy];
    let paramIndex = 3;

    if (timestampField) {
      fields.push(`${timestampField} = $${paramIndex++}`);
      values.push(new Date());
    }

    values.push(proposalId);
    const result = await client.query<RentalProposal>(
      `UPDATE rental_proposals SET ${fields.join(', ')} WHERE id = $${paramIndex}
      RETURNING
        id, enquiry_id as "enquiryId", conversation_id as "conversationId",
        rental_application_id as "rentalApplicationId",
        property_id as "propertyId", unit_id as "unitId",
        prospective_renter_id as "prospectiveRenterId", landlord_user_id as "landlordUserId",
        type, status, proposed_rent_amount as "proposedRentAmount",
        proposed_deposit_amount as "proposedDepositAmount",
        proposed_start_date as "proposedStartDate", proposed_end_date as "proposedEndDate",
        proposed_rent_due_day as "proposedRentDueDay", special_conditions as "specialConditions",
        notes, expires_at as "expiresAt", accepted_at as "acceptedAt",
        declined_at as "declinedAt", withdrawn_at as "withdrawnAt",
        confirmed_at as "confirmedAt", created_by as "createdBy",
        updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
      values,
    );

    const updated = result.rows[0];
    if (updated) {
      // Critical proposal lifecycle events are persisted atomically with the
      // status change. A failing outbox insert rolls the status change back.
      if (notification) {
        const recipients = await resolveProposalRecipients(client, updated);
        if (recipients.length > 0) {
          await enqueueOutboxEventTransactional(client, {
            idempotencyKey: notification.idempotencyKey,
            eventType: notification.eventType,
            category: 'operational',
            priority: 'normal',
            recipientUserIds: recipients,
            organisationId: null,
            resourceType: 'rental_proposal',
            resourceId: proposalId,
            payload: { proposalId, status },
            channels: ['in_app', 'email'],
            classification: classifyEventType(notification.eventType),
          });
        }
      }
    }

    return updated;
  });
}

/**
 * Lazily expire proposals whose `expires_at` has passed while still pending a
 * seeker response. Uses a single set-based UPDATE so it is safe to call on
 * every proposal list/detail read (no dedicated worker required). Returns the
 * number of proposals expired by this call.
 */
export async function expireOverdueProposals(): Promise<number> {
  // Atomic expiry: the status transition and its outbox event share one
  // transaction. A crash between them cannot leave an expired proposal
  // without its notification.
  //
  // Concurrency / repeated sweeps: the UPDATE only matches proposals still in
  // an actionable status (sent/under_review/changes_requested). Two concurrent
  // sweeps race on the same rows; in READ COMMITTED the loser re-evaluates the
  // predicate after the winner commits and matches nothing, so exactly one
  // sweep transitions each proposal and emits its event. The outbox insert is
  // additionally idempotent on `proposal.expired:<id>`, so even a redelivered
  // job cannot create a duplicate logical expiry event.
  return transaction(async (client) => {
    const result = await client.query<{ id: string; property_id: string | null; rental_application_id: string | null; prospective_renter_id: string | null; landlord_user_id: string | null }>(
      `UPDATE rental_proposals
          SET status = 'expired', updated_at = NOW()
        WHERE status IN ('sent', 'under_review', 'changes_requested')
          AND expires_at IS NOT NULL
          AND expires_at < NOW()
        RETURNING id, property_id, rental_application_id, prospective_renter_id, landlord_user_id`,
    );

    for (const row of result.rows) {
      const recipients = await resolveProposalRecipients(client, {
        propertyId: row.property_id,
        prospectiveRenterId: row.prospective_renter_id,
        landlordUserId: row.landlord_user_id,
      });
      if (recipients.length === 0) continue;
      await enqueueOutboxEventTransactional(client, {
        idempotencyKey: `proposal.expired:${row.id}`,
        eventType: 'proposal.expired',
        category: 'operational',
        priority: 'normal',
        recipientUserIds: recipients,
        organisationId: null,
        resourceType: 'rental_proposal',
        resourceId: row.id,
        payload: { proposalId: row.id },
        channels: ['in_app', 'email'],
        classification: classifyEventType('proposal.expired'),
      });
    }

    return result.rowCount ?? 0;
  });
}

export async function createRentalProposalVersion(data: {
  proposalId: string;
  versionNumber: number;
  proposedRentAmount: number;
  proposedDepositAmount: number;
  proposedStartDate: Date;
  proposedEndDate: Date | null;
  proposedRentDueDay: number;
  specialConditions: string | null;
  notes: string | null;
  createdBy: string;
}): Promise<void> {
  await pool.query(
    `INSERT INTO rental_proposal_versions (
      proposal_id, version_number, proposed_rent_amount, proposed_deposit_amount,
      proposed_start_date, proposed_end_date, proposed_rent_due_day,
      special_conditions, notes, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [
      data.proposalId, data.versionNumber, data.proposedRentAmount, data.proposedDepositAmount,
      data.proposedStartDate, data.proposedEndDate, data.proposedRentDueDay,
      data.specialConditions, data.notes, data.createdBy,
    ],
  );
}

// ============================================================================
// FINANCIAL REPOSITORY
// ============================================================================

export interface Invoice {
  id: string;
  invoiceNumber: string;
  propertyId: string;
  unitId: string | null;
  tenantId: string | null;
  tenancyId: string | null;
  status: string;
  currency: string;
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
  dueDate: Date;
  subtotal: number;
  taxAmount: number;
  totalAmount: number;
  amountPaid: number;
  amountOutstanding: number;
  notes: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createInvoice(data: {
  invoiceNumber: string;
  propertyId: string;
  unitId: string | null;
  tenantId: string | null;
  tenancyId: string | null;
  currency?: string;
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
  dueDate: Date;
  subtotal: number;
  taxAmount: number;
  totalAmount: number;
  notes: string | null;
  createdBy: string;
}): Promise<Invoice> {
  const result = await pool.query<Invoice>(
    `INSERT INTO invoices (
      invoice_number, property_id, unit_id, tenant_id, tenancy_id, status,
      currency, billing_period_start, billing_period_end, due_date,
      subtotal, tax_amount, total_amount, amount_paid, amount_outstanding, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, 'draft', $6, $7, $8, $9, $10, $11, $12, 0, $12, $13, $14
    )
    RETURNING
      id, invoice_number as "invoiceNumber", property_id as "propertyId",
      unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
      status, currency, billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      subtotal, tax_amount as "taxAmount", total_amount as "totalAmount",
      amount_paid as "amountPaid", amount_outstanding as "amountOutstanding",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.invoiceNumber, data.propertyId, data.unitId, data.tenantId, data.tenancyId,
      data.currency ?? 'KES', data.billingPeriodStart, data.billingPeriodEnd, data.dueDate,
      data.subtotal, data.taxAmount, data.totalAmount, data.notes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findInvoiceById(invoiceId: string): Promise<Invoice | undefined> {
  const result = await pool.query<Invoice>(
    `SELECT
      id, invoice_number as "invoiceNumber", property_id as "propertyId",
      unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
      status, currency, billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      subtotal, tax_amount as "taxAmount", total_amount as "totalAmount",
      amount_paid as "amountPaid", amount_outstanding as "amountOutstanding",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM invoices WHERE id = $1`,
    [invoiceId],
  );
  return result.rows[0];
}

export async function findInvoices({
  propertyId,
  unitId,
  tenantId,
  tenancyId,
  status,
  fromDate,
  toDate,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  unitId?: string;
  tenantId?: string;
  tenancyId?: string;
  status?: string;
  fromDate?: Date;
  toDate?: Date;
  limit?: number;
  offset?: number;
}): Promise<Invoice[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }
  if (tenantId) {
    conditions.push(`tenant_id = $${paramIndex++}`);
    values.push(tenantId);
  }
  if (tenancyId) {
    conditions.push(`tenancy_id = $${paramIndex++}`);
    values.push(tenancyId);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }
  if (fromDate) {
    conditions.push(`due_date >= $${paramIndex++}`);
    values.push(fromDate);
  }
  if (toDate) {
    conditions.push(`due_date <= $${paramIndex++}`);
    values.push(toDate);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<Invoice>(
    `SELECT
      id, invoice_number as "invoiceNumber", property_id as "propertyId",
      unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
      status, currency, billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      subtotal, tax_amount as "taxAmount", total_amount as "totalAmount",
      amount_paid as "amountPaid", amount_outstanding as "amountOutstanding",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM invoices ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateInvoiceStatus(
  invoiceId: string,
  status: string,
  amountPaid: number,
  amountOutstanding: number,
  updatedBy: string,
): Promise<Invoice | undefined> {
  const result = await pool.query<Invoice>(
    `UPDATE invoices SET status = $1, amount_paid = $2, amount_outstanding = $3,
     updated_by = $4, updated_at = NOW() WHERE id = $5
    RETURNING
      id, invoice_number as "invoiceNumber", property_id as "propertyId",
      unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
      status, currency, billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      subtotal, tax_amount as "taxAmount", total_amount as "totalAmount",
      amount_paid as "amountPaid", amount_outstanding as "amountOutstanding",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [status, amountPaid, amountOutstanding, updatedBy, invoiceId],
  );
  return result.rows[0];
}

export interface PaymentTransaction {
  id: string;
  transactionReference: string;
  invoiceId: string | null;
  tenantId: string | null;
  propertyId: string;
  amount: number;
  currency: string;
  provider: string;
  providerTransactionId: string | null;
  status: string;
  paymentDate: Date;
  callbackPayload: Record<string, unknown> | null;
  callbackReceivedAt: Date | null;
  processedBy: string | null;
  failureReason: string | null;
  notes: string | null;
  idempotencyKey: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export async function createPaymentTransaction(data: {
  transactionReference: string;
  invoiceId: string | null;
  tenantId: string | null;
  propertyId: string;
  amount: number;
  currency: string;
  provider: string;
  providerTransactionId: string | null;
  status: string;
  paymentDate: Date | null;
  callbackPayload: Record<string, unknown> | null;
  idempotencyKey: string | null;
  createdBy: string;
}): Promise<PaymentTransaction> {
  const result = await pool.query<PaymentTransaction>(
    `INSERT INTO payment_transactions (
      transaction_reference, invoice_id, tenant_id, property_id, amount, currency,
      provider, provider_transaction_id, status, payment_date, callback_payload,
      idempotency_key, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
    )
    RETURNING
      id, transaction_reference as "transactionReference", invoice_id as "invoiceId",
      tenant_id as "tenantId", property_id as "propertyId", amount, currency, provider,
      provider_transaction_id as "providerTransactionId", status,
      payment_date as "paymentDate", callback_payload as "callbackPayload",
      callback_received_at as "callbackReceivedAt", processed_by as "processedBy",
      failure_reason as "failureReason", notes, idempotency_key as "idempotencyKey",
      created_by as "createdBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.transactionReference, data.invoiceId, data.tenantId, data.propertyId,
      data.amount, data.currency, data.provider, data.providerTransactionId,
      data.status, data.paymentDate, data.callbackPayload, data.idempotencyKey,
      data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export interface RentLedgerEntry {
  id: string;
  tenancyId: string;
  tenantId: string;
  propertyId: string;
  unitId: string | null;
  invoiceId: string | null;
  entryType: string;
  amount: number;
  currency: string;
  billingPeriodStart: Date | null;
  billingPeriodEnd: Date | null;
  dueDate: Date | null;
  paymentDate: Date | null;
  reference: string | null;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export async function createRentLedgerEntry(data: {
  tenancyId: string;
  tenantId: string;
  propertyId: string;
  unitId: string | null;
  invoiceId: string | null;
  entryType: string;
  amount: number;
  currency: string;
  billingPeriodStart: Date | null;
  billingPeriodEnd: Date | null;
  dueDate: Date | null;
  paymentDate: Date | null;
  reference: string | null;
  notes: string | null;
  createdBy: string;
}): Promise<RentLedgerEntry> {
  const result = await pool.query<RentLedgerEntry>(
    `INSERT INTO rent_ledger_entries (
      tenancy_id, tenant_id, property_id, unit_id, invoice_id, entry_type,
      amount, currency, billing_period_start, billing_period_end, due_date,
      payment_date, reference, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
    )
    RETURNING
      id, tenancy_id as "tenancyId", tenant_id as "tenantId",
      property_id as "propertyId", unit_id as "unitId", invoice_id as "invoiceId",
      entry_type as "entryType", amount, currency,
      billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      payment_date as "paymentDate", reference, notes,
      created_by as "createdBy", created_at as "createdAt"`,
    [
      data.tenancyId, data.tenantId, data.propertyId, data.unitId, data.invoiceId,
      data.entryType, data.amount, data.currency, data.billingPeriodStart,
      data.billingPeriodEnd, data.dueDate, data.paymentDate, data.reference,
      data.notes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findRentLedgerEntries({
  tenancyId,
  tenantId,
  propertyId,
  limit = 50,
  offset = 0,
}: {
  tenancyId?: string;
  tenantId?: string;
  propertyId?: string;
  limit?: number;
  offset?: number;
}): Promise<RentLedgerEntry[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (tenancyId) {
    conditions.push(`tenancy_id = $${paramIndex++}`);
    values.push(tenancyId);
  }
  if (tenantId) {
    conditions.push(`tenant_id = $${paramIndex++}`);
    values.push(tenantId);
  }
  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<RentLedgerEntry>(
    `SELECT
      id, tenancy_id as "tenancyId", tenant_id as "tenantId",
      property_id as "propertyId", unit_id as "unitId", invoice_id as "invoiceId",
      entry_type as "entryType", amount, currency,
      billing_period_start as "billingPeriodStart",
      billing_period_end as "billingPeriodEnd", due_date as "dueDate",
      payment_date as "paymentDate", reference, notes,
      created_by as "createdBy", created_at as "createdAt"
    FROM rent_ledger_entries ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

// ============================================================================
// MAINTENANCE REPOSITORY
// ============================================================================

export interface PropertyIssue {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  reporterId: string;
  reporterRole: string;
  title: string;
  description: string;
  category: string;
  priority: string;
  status: string;
  assignedToUserId: string | null;
  assignedToOrganisationId: string | null;
  estimatedCost: number | null;
  actualCost: number | null;
  currency: string;
  resolutionNotes: string | null;
  resolvedAt: Date | null;
  closedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function reportIssue(data: {
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  reporterId: string;
  reporterRole: string;
  title: string;
  description: string;
  category: string;
  priority: string;
  assignedToUserId: string | null;
}): Promise<PropertyIssue> {
  const result = await pool.query<PropertyIssue>(
    `INSERT INTO property_issues (
      property_id, unit_id, tenancy_id, reporter_id, reporter_role, title, description,
      category, priority, status, assigned_to_user_id
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, 'new', $10
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId",
      reporter_id as "reporterId", reporter_role as "reporterRole", title, description,
      category, priority, status,
      assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      estimated_cost as "estimatedCost", actual_cost as "actualCost", currency,
      resolution_notes as "resolutionNotes", resolved_at as "resolvedAt",
      closed_at as "closedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.tenancyId, data.reporterId, data.reporterRole,
      data.title, data.description, data.category, data.priority, data.assignedToUserId,
    ],
  );
  return result.rows[0]!;
}

export async function findIssueById(issueId: string): Promise<PropertyIssue | undefined> {
  const result = await pool.query<PropertyIssue>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId",
      reporter_id as "reporterId", reporter_role as "reporterRole", title, description,
      category, priority, status,
      assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      estimated_cost as "estimatedCost", actual_cost as "actualCost", currency,
      resolution_notes as "resolutionNotes", resolved_at as "resolvedAt",
      closed_at as "closedAt", created_at as "createdAt", updated_at as "updatedAt"
    FROM property_issues WHERE id = $1`,
    [issueId],
  );
  return result.rows[0];
}

export async function findIssues({
  propertyId,
  unitId,
  tenancyId,
  category,
  priority,
  status,
  limit = 20,
  offset = 0,
}: {
  propertyId?: string;
  unitId?: string;
  tenancyId?: string;
  category?: string;
  priority?: string;
  status?: string;
  limit?: number;
  offset?: number;
}): Promise<PropertyIssue[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }
  if (tenancyId) {
    conditions.push(`tenancy_id = $${paramIndex++}`);
    values.push(tenancyId);
  }
  if (category) {
    conditions.push(`category = $${paramIndex++}`);
    values.push(category);
  }
  if (priority) {
    conditions.push(`priority = $${paramIndex++}`);
    values.push(priority);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<PropertyIssue>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId",
      reporter_id as "reporterId", reporter_role as "reporterRole", title, description,
      category, priority, status,
      assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      estimated_cost as "estimatedCost", actual_cost as "actualCost", currency,
      resolution_notes as "resolutionNotes", resolved_at as "resolvedAt",
      closed_at as "closedAt", created_at as "createdAt", updated_at as "updatedAt"
    FROM property_issues ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateIssue(
  issueId: string,
  data: Partial<{
    title: string;
    description: string;
    category: string;
    priority: string;
    status: string;
    assignedToUserId: string | null;
    estimatedCost: number | null;
    actualCost: number | null;
    resolutionNotes: string | null;
  }>,
  updatedBy: string,
): Promise<PropertyIssue | undefined> {
  void updatedBy; // property_issues has no updated_by column
  const fields: string[] = ['updated_at = NOW()'];
  const values: unknown[] = [];
  let paramIndex = 1;

  const fieldMap: Record<string, string> = {
    title: 'title', description: 'description', category: 'category',
    priority: 'priority', status: 'status', assignedToUserId: 'assigned_to_user_id',
    estimatedCost: 'estimated_cost', actualCost: 'actual_cost',
    resolutionNotes: 'resolution_notes',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(issueId);
  const result = await pool.query<PropertyIssue>(
    `UPDATE property_issues SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId",
      reporter_id as "reporterId", reporter_role as "reporterRole", title, description,
      category, priority, status,
      assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      estimated_cost as "estimatedCost", actual_cost as "actualCost", currency,
      resolution_notes as "resolutionNotes", resolved_at as "resolvedAt",
      closed_at as "closedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

// ============================================================================
// LEASE / RENTAL AGREEMENT REPOSITORY
// ============================================================================

export interface RentalAgreement {
  id: string;
  tenancyId: string;
  agreementNumber: string;
  status: string;
  startDate: Date;
  endDate: Date | null;
  monthlyRent: number;
  depositAmount: number;
  rentDueDay: number;
  paymentMethod: string | null;
  specialConditions: string | null;
  documentUrl: string | null;
  signedByTenantAt: Date | null;
  signedByLandlordAt: Date | null;
  renewedFromAgreementId: string | null;
  terminatedAt: Date | null;
  terminationReason: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createRentalAgreement(data: {
  tenancyId: string;
  tenantId: string;
  propertyId: string;
  unitId: string;
  agreementNumber: string;
  startDate: Date;
  endDate: Date | null;
  monthlyRent: number;
  depositAmount: number;
  rentDueDay: number;
  paymentMethod: string | null;
  specialConditions: string | null;
  createdBy: string;
}): Promise<RentalAgreement> {
  const result = await pool.query<RentalAgreement>(
    `INSERT INTO rental_agreements (
      tenancy_id, tenant_id, property_id, unit_id, agreement_number, start_date, end_date, monthly_rent,
      deposit_amount, rent_due_day, payment_method, special_conditions, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
    )
    RETURNING
      id, tenancy_id as "tenancyId", agreement_number as "agreementNumber", status,
      start_date as "startDate", end_date as "endDate", monthly_rent as "monthlyRent",
      deposit_amount as "depositAmount", rent_due_day as "rentDueDay",
      payment_method as "paymentMethod", special_conditions as "specialConditions",
      document_url as "documentUrl", signed_by_tenant_at as "signedByTenantAt",
      signed_by_landlord_at as "signedByLandlordAt",
      renewed_from_agreement_id as "renewedFromAgreementId",
      terminated_at as "terminatedAt", termination_reason as "terminationReason",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.tenancyId, data.tenantId, data.propertyId, data.unitId, data.agreementNumber,
      data.startDate, data.endDate, data.monthlyRent, data.depositAmount, data.rentDueDay,
      data.paymentMethod, data.specialConditions, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findTenantByTenancyId(tenancyId: string): Promise<{ id: string } | undefined> {
  const result = await pool.query<{ id: string }>(
    `SELECT id FROM tenants WHERE tenancy_id = $1 ORDER BY created_at ASC LIMIT 1`,
    [tenancyId],
  );
  return result.rows[0];
}

export async function findTenancyById(tenancyId: string): Promise<{ id: string; propertyId: string; unitId: string; status: string } | undefined> {
  const result = await pool.query<{ id: string; propertyId: string; unitId: string; status: string }>(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", status FROM tenancies WHERE id = $1`,
    [tenancyId],
  );
  return result.rows[0];
}

export async function findRentalAgreementById(agreementId: string): Promise<RentalAgreement | undefined> {
  const result = await pool.query<RentalAgreement>(
    `SELECT
      id, tenancy_id as "tenancyId", agreement_number as "agreementNumber", status,
      start_date as "startDate", end_date as "endDate", monthly_rent as "monthlyRent",
      deposit_amount as "depositAmount", rent_due_day as "rentDueDay",
      payment_method as "paymentMethod", special_conditions as "specialConditions",
      document_url as "documentUrl", signed_by_tenant_at as "signedByTenantAt",
      signed_by_landlord_at as "signedByLandlordAt",
      renewed_from_agreement_id as "renewedFromAgreementId",
      terminated_at as "terminatedAt", termination_reason as "terminationReason",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM rental_agreements WHERE id = $1`,
    [agreementId],
  );
  return result.rows[0];
}

export async function findRentalAgreements({
  tenancyId,
  propertyId,
  status,
  limit = 20,
  offset = 0,
}: {
  tenancyId?: string;
  propertyId?: string;
  status?: string;
  limit?: number;
  offset?: number;
}): Promise<RentalAgreement[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (tenancyId) {
    conditions.push(`tenancy_id = $${paramIndex++}`);
    values.push(tenancyId);
  }
  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (status) {
    conditions.push(`status = $${paramIndex++}`);
    values.push(status);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<RentalAgreement>(
    `SELECT
      id, tenancy_id as "tenancyId", agreement_number as "agreementNumber", status,
      start_date as "startDate", end_date as "endDate", monthly_rent as "monthlyRent",
      deposit_amount as "depositAmount", rent_due_day as "rentDueDay",
      payment_method as "paymentMethod", special_conditions as "specialConditions",
      document_url as "documentUrl", signed_by_tenant_at as "signedByTenantAt",
      signed_by_landlord_at as "signedByLandlordAt",
      renewed_from_agreement_id as "renewedFromAgreementId",
      terminated_at as "terminatedAt", termination_reason as "terminationReason",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM rental_agreements ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

export async function updateRentalAgreement(
  agreementId: string,
  data: Partial<{
    endDate: Date | null;
    monthlyRent: number;
    depositAmount: number;
    rentDueDay: number;
    paymentMethod: string | null;
    specialConditions: string | null;
    status: string;
  }>,
  updatedBy: string,
): Promise<RentalAgreement | undefined> {
  const fields: string[] = ['updated_by = $1', 'updated_at = NOW()'];
  const values: unknown[] = [updatedBy];
  let paramIndex = 2;

  const fieldMap: Record<string, string> = {
    endDate: 'end_date', monthlyRent: 'monthly_rent', depositAmount: 'deposit_amount',
    rentDueDay: 'rent_due_day', paymentMethod: 'payment_method',
    specialConditions: 'special_conditions', status: 'status',
  };

  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    const col = fieldMap[key];
    if (!col) continue;
    fields.push(`${col} = $${paramIndex++}`);
    values.push(value);
  }

  values.push(agreementId);
  const result = await pool.query<RentalAgreement>(
    `UPDATE rental_agreements SET ${fields.join(', ')} WHERE id = $${paramIndex}
    RETURNING
      id, tenancy_id as "tenancyId", agreement_number as "agreementNumber", status,
      start_date as "startDate", end_date as "endDate", monthly_rent as "monthlyRent",
      deposit_amount as "depositAmount", rent_due_day as "rentDueDay",
      payment_method as "paymentMethod", special_conditions as "specialConditions",
      document_url as "documentUrl", signed_by_tenant_at as "signedByTenantAt",
      signed_by_landlord_at as "signedByLandlordAt",
      renewed_from_agreement_id as "renewedFromAgreementId",
      terminated_at as "terminatedAt", termination_reason as "terminationReason",
      created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export interface LeaseDocument {
  id: string;
  rentalAgreementId: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string | null;
  type: string;
  title: string;
  description: string | null;
  fileName: string;
  filePath: string;
  fileSizeBytes: number | null;
  mimeType: string | null;
  category: string | null;
  isPrivate: boolean;
  version: number;
  uploadedBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export async function createLeaseDocument(data: {
  rentalAgreementId: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string | null;
  type: string;
  title: string;
  description: string | null;
  fileName: string;
  filePath: string;
  fileSizeBytes: number | null;
  mimeType: string | null;
  category: string | null;
  isPrivate: boolean;
  uploadedBy: string;
}): Promise<LeaseDocument> {
  const result = await pool.query<LeaseDocument>(
    `INSERT INTO lease_documents (
      rental_agreement_id, property_id, unit_id, tenancy_id, tenant_id, type,
      title, description, file_name, file_path, file_size_bytes, mime_type,
      category, is_private, version, uploaded_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 1, $15
    )
    RETURNING
      id, rental_agreement_id as "rentalAgreementId", property_id as "propertyId",
      unit_id as "unitId", tenancy_id as "tenancyId", tenant_id as "tenantId", type,
      title, description, file_name as "fileName", file_path as "filePath",
      file_size_bytes as "fileSizeBytes", mime_type as "mimeType", category,
      is_private as "isPrivate", version, uploaded_by as "uploadedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.rentalAgreementId, data.propertyId, data.unitId, data.tenancyId,
      data.tenantId, data.type, data.title, data.description, data.fileName,
      data.filePath, data.fileSizeBytes, data.mimeType, data.category,
      data.isPrivate, data.uploadedBy,
    ],
  );
  return result.rows[0]!;
}

export async function findLeaseDocuments({
  rentalAgreementId,
  propertyId,
  unitId,
  tenancyId,
  limit = 20,
  offset = 0,
}: {
  rentalAgreementId?: string;
  propertyId?: string;
  unitId?: string;
  tenancyId?: string;
  limit?: number;
  offset?: number;
}): Promise<LeaseDocument[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (rentalAgreementId) {
    conditions.push(`rental_agreement_id = $${paramIndex++}`);
    values.push(rentalAgreementId);
  }
  if (propertyId) {
    conditions.push(`property_id = $${paramIndex++}`);
    values.push(propertyId);
  }
  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  }
  if (tenancyId) {
    conditions.push(`tenancy_id = $${paramIndex++}`);
    values.push(tenancyId);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(limit, offset);

  const result = await pool.query<LeaseDocument>(
    `SELECT
      id, rental_agreement_id as "rentalAgreementId", property_id as "propertyId",
      unit_id as "unitId", tenancy_id as "tenancyId", tenant_id as "tenantId", type,
      title, description, file_name as "fileName", file_path as "filePath",
      file_size_bytes as "fileSizeBytes", mime_type as "mimeType", category,
      is_private as "isPrivate", version, uploaded_by as "uploadedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM lease_documents ${whereClause}
    ORDER BY created_at DESC
    LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
    values,
  );
  return result.rows;
}

// ============================================================================
// INSPECTION REPOSITORY
// ============================================================================

export interface MoveInInspection {
  id: string;
  tenancyId: string;
  unitId: string;
  inspectionDate: Date;
  inspectorId: string;
  overallCondition: string | null;
  meterReadings: Record<string, unknown> | null;
  keyHandover: boolean;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createMoveInInspection(data: {
  tenancyId: string;
  tenantId: string;
  unitId: string;
  inspectionDate: Date;
  overallCondition: string | null;
  meterReadings: Record<string, unknown> | null;
  keyHandover: boolean;
  notes: string | null;
  inspectorId: string;
}): Promise<MoveInInspection> {
  const result = await pool.query<MoveInInspection>(
    `INSERT INTO move_in_inspections (
      tenancy_id, tenant_id, unit_id, inspection_date, inspector_id, overall_condition,
      meter_readings, key_handover, notes
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING
      id, tenancy_id as "tenancyId", unit_id as "unitId",
      inspection_date as "inspectionDate", inspector_id as "inspectorId",
      overall_condition as "overallCondition", meter_readings as "meterReadings",
      key_handover as "keyHandover", notes, created_at as "createdAt",
      updated_at as "updatedAt"`,
    [
      data.tenancyId, data.tenantId, data.unitId, data.inspectionDate, data.inspectorId,
      data.overallCondition, data.meterReadings, data.keyHandover, data.notes,
    ],
  );
  return result.rows[0]!;
}

export interface MoveOutInspection {
  id: string;
  tenancyId: string;
  unitId: string;
  inspectionDate: Date;
  inspectorId: string;
  overallCondition: string | null;
  meterReadings: Record<string, unknown> | null;
  keyReturned: boolean;
  damageNotes: string | null;
  cleaningRequired: boolean;
  cleaningCost: number | null;
  repairCost: number | null;
  currency: string;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createMoveOutInspection(data: {
  tenancyId: string;
  tenantId: string;
  unitId: string;
  inspectionDate: Date;
  overallCondition: string | null;
  meterReadings: Record<string, unknown> | null;
  keyReturned: boolean;
  damageNotes: string | null;
  cleaningRequired: boolean;
  cleaningCost: number | null;
  repairCost: number | null;
  notes: string | null;
  inspectorId: string;
}): Promise<MoveOutInspection> {
  const result = await pool.query<MoveOutInspection>(
    `INSERT INTO move_out_inspections (
      tenancy_id, tenant_id, unit_id, inspection_date, inspector_id, overall_condition,
      meter_readings, key_returned, damage_notes, cleaning_required,
      cleaning_cost, repair_cost, notes
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
    RETURNING
      id, tenancy_id as "tenancyId", unit_id as "unitId",
      inspection_date as "inspectionDate", inspector_id as "inspectorId",
      overall_condition as "overallCondition", meter_readings as "meterReadings",
      key_returned as "keyReturned", damage_notes as "damageNotes",
      cleaning_required as "cleaningRequired", cleaning_cost as "cleaningCost",
      repair_cost as "repairCost", currency, notes,
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.tenancyId, data.tenantId, data.unitId, data.inspectionDate, data.inspectorId,
      data.overallCondition, data.meterReadings, data.keyReturned, data.damageNotes,
      data.cleaningRequired, data.cleaningCost, data.repairCost, data.notes,
    ],
  );
  return result.rows[0]!;
}

export async function createInspectionItem(data: {
  inspectionId: string;
  itemCategory: string;
  itemName: string;
  conditionRating: string;
  notes: string | null;
  photoUrl: string | null;
}): Promise<void> {
  await pool.query(
    `INSERT INTO inspection_items (inspection_id, item_category, item_name, condition_rating, notes, photo_url)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [data.inspectionId, data.itemCategory, data.itemName, data.conditionRating, data.notes, data.photoUrl],
  );
}

export async function findInspectionItems(inspectionId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT id, inspection_id as "inspectionId", item_category as "itemCategory",
            item_name as "itemName", condition_rating as "conditionRating",
            notes, photo_url as "photoUrl", created_at as "createdAt"
     FROM inspection_items WHERE inspection_id = $1 ORDER BY created_at ASC`,
    [inspectionId],
  );
  return result.rows;
}

export async function findMoveInInspectionById(
  inspectionId: string,
): Promise<{ id: string; tenancyId: string; unitId: string } | undefined> {
  const result = await pool.query<{ id: string; tenancyId: string; unitId: string }>(
    `SELECT id, tenancy_id as "tenancyId", unit_id as "unitId"
     FROM move_in_inspections WHERE id = $1`,
    [inspectionId],
  );
  return result.rows[0];
}

// ============================================================================
// EXTENDED DASHBOARD STATS
// ============================================================================

export interface ExtendedDashboardStats {
  totalProperties: number;
  totalUnits: number;
  occupiedUnits: number;
  vacantUnits: number;
  activeListings: number;
  unpublishedListings: number;
  newEnquiries: number;
  activeTenancies: number;
  upcomingExpiries: number;
  pendingMaintenance: number;
  pendingGarbageRequests: number;
  expectedRent: number;
  collectedRent: number;
  outstandingRent: number;
}

export async function getExtendedDashboardStats(propertyId?: string): Promise<ExtendedDashboardStats> {
  const propertyFilter = propertyId ? `AND property_id = $1` : '';
  const idFilter = propertyId ? `AND id = $1` : '';
  const params: unknown[] = propertyId ? [propertyId] : [];

  const propertyResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM properties WHERE 1 = 1 ${idFilter}`,
    params,
  );
  const unitResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE 1 = 1 ${propertyFilter}`,
    params,
  );
  const occupiedResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE status = 'occupied' ${propertyFilter}`,
    params,
  );
  const vacantResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM units WHERE status = 'vacant' ${propertyFilter}`,
    params,
  );
  const listingResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_listings WHERE status = 'published' ${propertyFilter}`,
    params,
  );
  const unpublishedListingResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_listings WHERE status != 'published' ${propertyFilter}`,
    params,
  );
  const enquiryResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_enquiries WHERE status = 'new' ${propertyFilter}`,
    params,
  );
  const tenancyResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM tenancies WHERE status = 'active' ${propertyFilter}`,
    params,
  );
  const maintenanceResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM property_issues WHERE status IN ('new', 'acknowledged', 'under_assessment', 'approved', 'assigned', 'in_progress') ${propertyFilter}`,
    params,
  );
  const garbageResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM garbage_collection_requests WHERE status IN ('pending', 'assigned', 'in_progress') ${propertyFilter}`,
    params,
  );

  // Financial aggregates computed from invoices. "Rent" scopes to invoices that
  // carry at least one rent charge; expected = total billed, collected = amount
  // paid, outstanding = amount still owed (non-cancelled/void invoices).
  const financialResult = await pool.query<{
    expected: string | null;
    collected: string | null;
    outstanding: string | null;
  }>(
    `SELECT
        COALESCE(SUM(i.total_amount), 0) AS expected,
        COALESCE(SUM(i.amount_paid), 0) AS collected,
        COALESCE(SUM(i.amount_outstanding), 0) AS outstanding
       FROM invoices i
      WHERE i.status NOT IN ('draft', 'cancelled', 'void')
        ${propertyId ? 'AND i.property_id = $1' : ''}
        AND EXISTS (
          SELECT 1 FROM invoice_items ii
           WHERE ii.invoice_id = i.id AND ii.charge_type = 'rent'
        )`,
    params,
  );

  // Tenancies approaching expiry within the next 30 days.
  const expiryResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM tenancies
      WHERE status = 'active'
        AND end_date IS NOT NULL
        AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
        ${propertyFilter}`,
    params,
  );

  const row = financialResult.rows[0];
  return {
    totalProperties: parseInt(propertyResult.rows[0]?.count || '0', 10),
    totalUnits: parseInt(unitResult.rows[0]?.count || '0', 10),
    occupiedUnits: parseInt(occupiedResult.rows[0]?.count || '0', 10),
    vacantUnits: parseInt(vacantResult.rows[0]?.count || '0', 10),
    activeListings: parseInt(listingResult.rows[0]?.count || '0', 10),
    unpublishedListings: parseInt(unpublishedListingResult.rows[0]?.count || '0', 10),
    newEnquiries: parseInt(enquiryResult.rows[0]?.count || '0', 10),
    activeTenancies: parseInt(tenancyResult.rows[0]?.count || '0', 10),
    upcomingExpiries: parseInt(expiryResult.rows[0]?.count || '0', 10),
    pendingMaintenance: parseInt(maintenanceResult.rows[0]?.count || '0', 10),
    pendingGarbageRequests: parseInt(garbageResult.rows[0]?.count || '0', 10),
    expectedRent: Number(row?.expected ?? 0),
    collectedRent: Number(row?.collected ?? 0),
    outstandingRent: Number(row?.outstanding ?? 0),
  };
}
