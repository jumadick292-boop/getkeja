import { pool } from '../../db/pool.js';
import { randomUUID } from 'node:crypto';
import { HttpError } from '../../shared/errors.js';
import { transaction } from '../../db/tx.js';
import { createEnquiry, expireOverdueProposals, findRentalProposalById, setRentalProposalStatus } from '../landlord/landlord.repository.js';
import { createSiteVisit, findSiteVisitById, findSiteVisitsByUser, updateSiteVisit } from '../auth/auth.repository.js';
import { createRentalApplication, findRentalApplicationById, findRentalApplicationsByUser } from '../auth/auth.repository.js';
import { NotificationService } from '../auth/notification.service.js';
import { MAX_COMPARISON_ITEMS } from './house-seeker.schema.js';
import type {
  AlertFrequency,
  CreateSavedSearch,
  MapBoundsQuery,
  RunSavedSearchQuery,
  SearchQuery,
  UpdateSavedSearch,
  CreateSeekerEnquiry,
  UpdatePreferences,
  CreateListingReport,
  CreateSeekerSiteVisit,
  StartConversation,
  SendMessage,
  CreateSeekerApplication,
  RespondToProposal,
} from './house-seeker.schema.js';

const notifications = new NotificationService();

async function notifyLandowner(propertyId: string, event: {
  eventType: string;
  title: string;
  body: string;
  metadata: Record<string, unknown>;
  resourceId: string;
}) {
  try {
    const owner = await pool.query<{ user_id: string }>(
      `SELECT po.user_id FROM property_ownerships po
        WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
          AND (po.effective_to IS NULL OR po.effective_to > NOW())
        ORDER BY po.effective_from DESC LIMIT 1`,
      [propertyId],
    );
    const ownerId = owner.rows[0]?.user_id;
    if (!ownerId) return;
    await notifications.createOutboxEvent({
      idempotencyKey: `${event.eventType}:${event.resourceId}:${ownerId}`,
      eventType: event.eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [ownerId],
      organisationId: null,
      resourceType: event.eventType.split('.')[0] ?? null,
      resourceId: event.resourceId,
      payload: event.metadata,
      channels: ['in_app', 'email'],
    });
  } catch (err) {
    console.error('Notification outbox persistence failed:', err instanceof Error ? err.message : err);
  }
}

type Bind = (value: unknown) => string;

function makeBinder(values: unknown[]): Bind {
  return (value: unknown) => {
    values.push(value);
    return `$${values.length}`;
  };
}

// Effective rent for a listing: prefer the listing price, fall back to the unit price.
const EFFECTIVE_RENT = 'COALESCE(pl.rent_amount, u.rent_amount)';
// Public images: prefer listing images, fall back to property images.
const PUBLIC_IMAGES = "COALESCE(NULLIF(pl.images, '[]'::jsonb), p.images, '[]'::jsonb)";
const PUBLIC_AMENITIES = "COALESCE(NULLIF(pl.amenities, '[]'::jsonb), NULLIF(p.amenities, '[]'::jsonb), '[]'::jsonb)";

const LISTING_CARD_COLUMNS = `
  pl.id AS "listingId",
  pl.title,
  pl.description,
  p.id AS "propertyId",
  p.title AS "propertyTitle",
  p.property_type AS "propertyType",
  p.city,
  p.county,
  CASE WHEN p.latitude IS NULL THEN NULL ELSE round(p.latitude::numeric, 4)::double precision END AS latitude,
  CASE WHEN p.longitude IS NULL THEN NULL ELSE round(p.longitude::numeric, 4)::double precision END AS longitude,
  ${EFFECTIVE_RENT} AS "rentAmount",
  pl.deposit_amount AS "depositAmount",
  u.bedrooms,
  u.bathrooms,
  u.unit_number AS "unitNumber",
  pl.unit_id AS "unitId",
  pl.furnished,
  pl.available_from AS "availableFrom",
  pl.available_to AS "availableTo",
  ${PUBLIC_IMAGES} AS images,
  ${PUBLIC_AMENITIES} AS amenities,
  pl.published_at AS "publishedAt"`;

function baseFrom(): string {
  return `FROM property_listings pl
    JOIN properties p ON p.id = pl.property_id
    LEFT JOIN units u ON u.id = pl.unit_id
    WHERE pl.status = 'published'`;
}

function buildSearchWhere(query: Partial<SearchQuery> & { q?: string }, bind: Bind): string[] {
  const where: string[] = ["pl.status = 'published'"];
  if (query.q) {
    const like = bind(`%${query.q}%`);
    where.push(`(pl.title ILIKE ${like} OR pl.description ILIKE ${like} OR p.address ILIKE ${like} OR p.city ILIKE ${like} OR p.county ILIKE ${like})`);
  }
  if (query.city) where.push(`p.city ILIKE ${bind(`%${query.city}%`)}`);
  if (query.county) where.push(`p.county ILIKE ${bind(`%${query.county}%`)}`);
  if (query.neighbourhood) where.push(`p.address ILIKE ${bind(`%${query.neighbourhood}%`)}`);
  if (query.propertyType) where.push(`p.property_type = ${bind(query.propertyType)}`);
  if (query.rentMin !== undefined) where.push(`${EFFECTIVE_RENT} >= ${bind(query.rentMin)}`);
  if (query.rentMax !== undefined) where.push(`${EFFECTIVE_RENT} <= ${bind(query.rentMax)}`);
  if (query.bedrooms !== undefined) where.push(`u.bedrooms = ${bind(query.bedrooms)}`);
  if (query.bathrooms !== undefined) where.push(`u.bathrooms >= ${bind(query.bathrooms)}`);
  if (query.furnished !== undefined) where.push(`pl.furnished = ${bind(query.furnished === 'true')}`);
  if (query.amenities) {
    for (const amenity of query.amenities.split(',').map((a) => a.trim()).filter(Boolean)) {
      const key = bind(amenity);
      where.push(`(${PUBLIC_AMENITIES} ? ${key})`);
    }
  }
  return where;
}

function orderClause(sort: string | undefined): string {
  switch (sort) {
    case 'price_asc':
      return `${EFFECTIVE_RENT} ASC NULLS LAST, pl.published_at DESC NULLS LAST`;
    case 'price_desc':
      return `${EFFECTIVE_RENT} DESC NULLS LAST, pl.published_at DESC NULLS LAST`;
    case 'newest':
      return 'pl.published_at DESC NULLS LAST, pl.id';
    default:
      return 'pl.published_at DESC NULLS LAST, pl.id';
  }
}

function normalizeCard(row: Record<string, unknown>) {
  return {
    ...row,
    rentAmount: row.rentAmount !== null && row.rentAmount !== undefined ? Number(row.rentAmount) : null,
    depositAmount: row.depositAmount !== null && row.depositAmount !== undefined ? Number(row.depositAmount) : null,
    bathrooms: row.bathrooms !== null && row.bathrooms !== undefined ? Number(row.bathrooms) : null,
  };
}

export async function searchListings(query: SearchQuery) {
  const values: unknown[] = [];
  const bind = makeBinder(values);
  const where = buildSearchWhere(query, bind);
  const totalResult = await pool.query(
    `SELECT count(*)::int AS total ${baseFrom()} AND ${where.join(' AND ')}`,
    values,
  );

  const limit = bind(query.limit);
  const offset = bind(query.offset);
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS}
       ${baseFrom()} AND ${where.join(' AND ')}
     ORDER BY ${orderClause(query.sort)}
     LIMIT ${limit} OFFSET ${offset}`,
    values,
  );
  return {
    items: result.rows.map(normalizeCard),
    total: totalResult.rows[0]?.total ?? 0,
    limit: query.limit,
    offset: query.offset,
  };
}

export async function getFeaturedListings(): Promise<Record<string, unknown>[]> {
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS}
       ${baseFrom()}
     ORDER BY pl.published_at DESC NULLS LAST, pl.id
     LIMIT 8`,
  );
  return result.rows.map(normalizeCard);
}

export async function getRecentlyPublished(): Promise<Record<string, unknown>[]> {
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS}
       ${baseFrom()}
     ORDER BY pl.published_at DESC NULLS LAST, pl.id
     LIMIT 12`,
  );
  return result.rows.map(normalizeCard);
}

export async function getMapListings(query: MapBoundsQuery) {
  const values: unknown[] = [];
  const bind = makeBinder(values);
  const west = bind(query.west);
  const east = bind(query.east);
  const north = bind(query.north);
  const south = bind(query.south);
  const where = [
    "pl.status = 'published'",
    'p.latitude IS NOT NULL',
    'p.longitude IS NOT NULL',
    `p.latitude BETWEEN ${south} AND ${north}`,
    query.east < query.west
      ? `(p.longitude >= ${west} OR p.longitude <= ${east})`
      : `p.longitude BETWEEN ${west} AND ${east}`,
  ];
  if (query.q) {
    const like = bind(`%${query.q}%`);
    where.push(`(pl.title ILIKE ${like} OR p.city ILIKE ${like} OR p.county ILIKE ${like} OR p.address ILIKE ${like})`);
  }
  if (query.propertyType) where.push(`p.property_type = ${bind(query.propertyType)}`);
  if (query.rentMin !== undefined) where.push(`${EFFECTIVE_RENT} >= ${bind(query.rentMin)}`);
  if (query.rentMax !== undefined) where.push(`${EFFECTIVE_RENT} <= ${bind(query.rentMax)}`);
  if (query.bedrooms !== undefined) where.push(`u.bedrooms = ${bind(query.bedrooms)}`);

  const limit = bind(query.limit);
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS}
       ${baseFrom()} AND ${where.join(' AND ')}
     ORDER BY pl.published_at DESC NULLS LAST, pl.id
     LIMIT ${limit}`,
    values,
  );
  return result.rows.map(normalizeCard);
}

export async function getFilterFacets() {
  const [types, counties, price] = await Promise.all([
    pool.query(
      `SELECT p.property_type AS value, count(*)::int AS count
         FROM property_listings pl JOIN properties p ON p.id = pl.property_id
        WHERE pl.status = 'published' AND p.property_type IS NOT NULL
        GROUP BY p.property_type ORDER BY count DESC`,
    ),
    pool.query(
      `SELECT p.county AS value, count(*)::int AS count
         FROM property_listings pl JOIN properties p ON p.id = pl.property_id
        WHERE pl.status = 'published' AND p.county IS NOT NULL
        GROUP BY p.county ORDER BY count DESC`,
    ),
    pool.query(
      `SELECT min(${EFFECTIVE_RENT})::float AS "minRent", max(${EFFECTIVE_RENT})::float AS "maxRent"
         ${baseFrom()}`,
    ),
  ]);
  return {
    propertyTypes: types.rows,
    counties: counties.rows,
    priceRange: price.rows[0] ?? { minRent: null, maxRent: null },
  };
}

export async function getPublicListingById(listingId: string) {
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS},
            pl.pricing_frequency AS "pricingFrequency",
            pl.features AS listingFeatures,
            pl.pet_policy AS "petPolicy",
            pl.smoking_allowed AS "smokingAllowed",
            pl.floor_plan_url AS "floorPlanUrl",
            pl.virtual_tour_url AS "virtualTourUrl",
            p.address,
            p.description AS "propertyDescription",
            u.description AS "unitDescription",
             (SELECT COALESCE(up.display_name, NULLIF(split_part(coalesce(owner.name, ''), ' ', 1), ''), NULL)
               FROM property_ownerships po
               JOIN users owner ON owner.id = po.user_id
               LEFT JOIN user_profiles up ON up.user_id = po.user_id
              WHERE po.property_id = p.id AND po.status = 'active'
                AND po.user_id IS NOT NULL
                AND (po.effective_to IS NULL OR po.effective_to > NOW())
              ORDER BY po.effective_from DESC
              LIMIT 1) AS "landlordFirstName",
             (SELECT po.user_id
               FROM property_ownerships po
              WHERE po.property_id = p.id AND po.status = 'active'
                AND po.user_id IS NOT NULL
                AND (po.effective_to IS NULL OR po.effective_to > NOW())
              ORDER BY po.effective_from DESC
              LIMIT 1) AS "landlordUserId"
       ${baseFrom()} AND pl.id = $1
       LIMIT 1`,
    [listingId],
  );
  const row = result.rows[0];
  if (!row) throw new HttpError('Listing not found', 404);
  return normalizeCard(row);
}

export async function getRelatedListings(listingId: string, query: { limit: number; offset: number }) {
  // First resolve the current listing to get its property for matching.
  const current = await pool.query(
    `SELECT pl.property_id, p.property_type, p.county, p.city
       FROM property_listings pl
       JOIN properties p ON p.id = pl.property_id
      WHERE pl.id = $1 AND pl.status = 'published'
      LIMIT 1`,
    [listingId],
  );
  const currentRow = current.rows[0] as { property_id: string; property_type?: string; county?: string; city?: string } | undefined;
  if (!currentRow) throw new HttpError('Listing not found', 404);

  const values: unknown[] = [listingId, currentRow.property_id];
  const bind = makeBinder(values);
  const where = [
    "pl.status = 'published'",
    `pl.id <> ${bind(listingId)}`,
    `pl.property_id <> ${bind(currentRow.property_id)}`,
  ];

  // Match same property type first, then same county/city.
  if (currentRow.property_type) {
    where.push(`p.property_type = ${bind(currentRow.property_type)}`);
  }
  if (currentRow.county) {
    where.push(`p.county = ${bind(currentRow.county)}`);
  } else if (currentRow.city) {
    where.push(`p.city = ${bind(currentRow.city)}`);
  }

  const limit = bind(query.limit);
  const offset = bind(query.offset);
  const result = await pool.query(
    `SELECT ${LISTING_CARD_COLUMNS}
       ${baseFrom()} AND ${where.join(' AND ')}
      ORDER BY pl.published_at DESC NULLS LAST, pl.id
      LIMIT ${limit} OFFSET ${offset}`,
    values,
  );
  return {
    items: result.rows.map(normalizeCard),
    total: result.rows.length,
    limit: query.limit,
    offset: query.offset,
  };
}

// ---------------------------------------------------------------------------
// Saved homes
// ---------------------------------------------------------------------------
export async function saveListing(userId: string, data: { listingId: string; collection?: string; notes?: string }) {
  const listing = await pool.query(`SELECT id FROM property_listings WHERE id = $1 AND status = 'published'`, [data.listingId]);
  if (!listing.rows[0]) throw new HttpError('Listing not found', 404);
  const result = await pool.query(
    `INSERT INTO saved_listings (user_id, listing_id, collection, notes)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, listing_id) DO UPDATE SET collection = EXCLUDED.collection, notes = EXCLUDED.notes
     RETURNING id, user_id AS "userId", listing_id AS "listingId", collection, notes, created_at AS "createdAt"`,
    [userId, data.listingId, data.collection ?? null, data.notes ?? null],
  );
  return result.rows[0];
}

export async function removeSavedListing(userId: string, listingId: string) {
  const result = await pool.query(
    `DELETE FROM saved_listings WHERE user_id = $1 AND listing_id = $2 RETURNING id`,
    [userId, listingId],
  );
  if (!result.rows[0]) throw new HttpError('Saved listing not found', 404);
  return { removed: true };
}

export async function listSavedListings(userId: string, query: { collection?: string; limit: number; offset: number }) {
  const values: unknown[] = [userId];
  const bind = makeBinder(values);
  const where = ['sl.user_id = $1'];
  if (query.collection) where.push(`sl.collection = ${bind(query.collection)}`);
  const total = await pool.query(
    `SELECT count(*)::int AS total FROM saved_listings sl WHERE ${where.join(' AND ')}`,
    values,
  );
  const limit = bind(query.limit);
  const offset = bind(query.offset);
  const result = await pool.query(
    `SELECT sl.id AS "savedId", sl.collection, sl.notes, sl.created_at AS "savedAt",
            pl.status AS "listingStatus",
            ${LISTING_CARD_COLUMNS}
       FROM saved_listings sl
       JOIN property_listings pl ON pl.id = sl.listing_id
       JOIN properties p ON p.id = pl.property_id
       LEFT JOIN units u ON u.id = pl.unit_id
      WHERE ${where.join(' AND ')}
      ORDER BY sl.created_at DESC
      LIMIT ${limit} OFFSET ${offset}`,
    values,
  );
  return {
    items: result.rows.map((row) => normalizeCard(row)),
    total: total.rows[0]?.total ?? 0,
    limit: query.limit,
    offset: query.offset,
  };
}

// ---------------------------------------------------------------------------
// Saved searches
// ---------------------------------------------------------------------------
export async function createSavedSearch(userId: string, data: CreateSavedSearch) {
  const result = await pool.query(
    `INSERT INTO saved_searches (user_id, name, criteria, alerts_enabled, alert_frequency)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, user_id AS "userId", name, criteria, alerts_enabled AS "alertsEnabled",
               alert_frequency AS "alertFrequency",
               last_run_at AS "lastRunAt", last_alerted_at AS "lastAlertedAt",
               created_at AS "createdAt", updated_at AS "updatedAt"`,
    [userId, data.name, JSON.stringify(data.criteria), data.alertsEnabled, data.alertFrequency],
  );
  return result.rows[0];
}

export async function listSavedSearches(userId: string) {
  const result = await pool.query(
    `SELECT id, user_id AS "userId", name, criteria, alerts_enabled AS "alertsEnabled",
            alert_frequency AS "alertFrequency",
            last_run_at AS "lastRunAt", last_alerted_at AS "lastAlertedAt",
            created_at AS "createdAt", updated_at AS "updatedAt"
       FROM saved_searches WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows;
}

export async function findSavedSearchById(userId: string, searchId: string) {
  const result = await pool.query(
    `SELECT id, user_id AS "userId", name, criteria, alerts_enabled AS "alertsEnabled",
            alert_frequency AS "alertFrequency",
            last_run_at AS "lastRunAt", last_alerted_at AS "lastAlertedAt"
       FROM saved_searches WHERE id = $1 AND user_id = $2`,
    [searchId, userId],
  );
  return result.rows[0];
}

export async function updateSavedSearch(userId: string, searchId: string, data: UpdateSavedSearch) {
  const existing = await findSavedSearchById(userId, searchId);
  if (!existing) throw new HttpError('Saved search not found', 404);
  const result = await pool.query(
    `UPDATE saved_searches
        SET name = COALESCE($3, name),
            criteria = COALESCE($4, criteria),
            alerts_enabled = COALESCE($5, alerts_enabled),
            alert_frequency = COALESCE($6, alert_frequency)
      WHERE id = $1 AND user_id = $2
      RETURNING id, user_id AS "userId", name, criteria, alerts_enabled AS "alertsEnabled",
                alert_frequency AS "alertFrequency",
                last_run_at AS "lastRunAt", last_alerted_at AS "lastAlertedAt",
                created_at AS "createdAt", updated_at AS "updatedAt"`,
    [searchId, userId, data.name ?? null, data.criteria ? JSON.stringify(data.criteria) : null, data.alertsEnabled ?? null, data.alertFrequency ?? null],
  );
  return result.rows[0];
}

export async function deleteSavedSearch(userId: string, searchId: string) {
  const result = await pool.query(
    `DELETE FROM saved_searches WHERE id = $1 AND user_id = $2 RETURNING id`,
    [searchId, userId],
  );
  if (!result.rows[0]) throw new HttpError('Saved search not found', 404);
  return { removed: true };
}

// ---------------------------------------------------------------------------
// Run saved search
// ---------------------------------------------------------------------------
export async function runSavedSearch(
  userId: string,
  searchId: string,
  query: RunSavedSearchQuery,
) {
  const search = await findSavedSearchById(userId, searchId);
  if (!search) throw new HttpError('Saved search not found', 404);

  const criteria = search.criteria as Record<string, unknown> | null ?? {};
  const searchQuery: SearchQuery = {
    q: criteria.q as string | undefined,
    city: criteria.city as string | undefined,
    county: criteria.county as string | undefined,
    neighbourhood: criteria.neighbourhood as string | undefined,
    propertyType: criteria.propertyType as string | undefined,
    rentMin: criteria.rentMin as number | undefined,
    rentMax: criteria.rentMax as number | undefined,
    bedrooms: criteria.bedrooms as number | undefined,
    bathrooms: criteria.bathrooms as number | undefined,
    furnished: criteria.furnished as 'true' | 'false' | undefined,
    amenities: criteria.amenities as string | undefined,
    sort: (criteria.sort as SearchQuery['sort']) ?? 'relevance',
    limit: query.limit,
    offset: query.offset,
  };

  // Update last_run_at.
  await pool.query(
    `UPDATE saved_searches SET last_run_at = NOW() WHERE id = $1 AND user_id = $2`,
    [searchId, userId],
  );

  return searchListings(searchQuery);
}

// ---------------------------------------------------------------------------
// Property comparison
// ---------------------------------------------------------------------------

const COMPARISON_COLUMNS = `
  pl.id AS "listingId",
  pl.title,
  pl.description,
  pl.status AS "listingStatus",
  pl.pricing_frequency AS "pricingFrequency",
  pl.deposit_amount AS "depositAmount",
  pl.furnished,
  pl.pet_policy AS "petPolicy",
  pl.smoking_allowed AS "smokingAllowed",
  pl.available_from AS "availableFrom",
  pl.available_to AS "availableTo",
  pl.features AS listingFeatures,
  pl.floor_plan_url AS "floorPlanUrl",
  pl.virtual_tour_url AS "virtualTourUrl",
  p.id AS "propertyId",
  p.title AS "propertyTitle",
  p.property_type AS "propertyType",
  p.address,
  p.description AS "propertyDescription",
  p.city,
  p.county,
  CASE WHEN p.latitude IS NULL THEN NULL ELSE round(p.latitude::numeric, 4)::double precision END AS latitude,
  CASE WHEN p.longitude IS NULL THEN NULL ELSE round(p.longitude::numeric, 4)::double precision END AS longitude,
  COALESCE(pl.rent_amount, u.rent_amount) AS "rentAmount",
  u.bedrooms,
  u.bathrooms,
  u.unit_number AS "unitNumber",
  pl.unit_id AS "unitId",
  u.description AS "unitDescription",
  COALESCE(NULLIF(pl.images, '[]'::jsonb), p.images, '[]'::jsonb) AS images,
  COALESCE(NULLIF(pl.amenities, '[]'::jsonb), NULLIF(p.amenities, '[]'::jsonb), '[]'::jsonb) AS amenities,
  pl.published_at AS "publishedAt",
  (SELECT COALESCE(up.display_name, NULLIF(split_part(coalesce(owner.name, ''), ' ', 1), ''), NULL)
    FROM property_ownerships po
    JOIN users owner ON owner.id = po.user_id
    LEFT JOIN user_profiles up ON up.user_id = po.user_id
   WHERE po.property_id = p.id AND po.status = 'active'
     AND po.user_id IS NOT NULL
     AND (po.effective_to IS NULL OR po.effective_to > NOW())
   ORDER BY po.effective_from DESC
   LIMIT 1) AS "landlordFirstName",
  (SELECT po.user_id
    FROM property_ownerships po
   WHERE po.property_id = p.id AND po.status = 'active'
     AND po.user_id IS NOT NULL
     AND (po.effective_to IS NULL OR po.effective_to > NOW())
   ORDER BY po.effective_from DESC
   LIMIT 1) AS "landlordUserId"`;

async function ensureComparisonList(userId: string): Promise<string> {
  let result = await pool.query<{ id: string }>(
    `SELECT id FROM house_seeker_comparison_lists WHERE user_id = $1`,
    [userId],
  );
  if (result.rows[0]) return result.rows[0]!.id;
  result = await pool.query<{ id: string }>(
    `INSERT INTO house_seeker_comparison_lists (user_id) VALUES ($1) RETURNING id`,
    [userId],
  );
  return result.rows[0]!.id;
}

export async function getComparisonList(
  userId: string,
  query: { limit: number; offset: number },
) {
  const listId = await ensureComparisonList(userId);

  const totalResult = await pool.query(
    `SELECT count(*)::int AS total
       FROM house_seeker_comparison_items ci
      WHERE ci.list_id = $1`,
    [listId],
  );

  const limit = query.limit;
  const offset = query.offset;
  const result = await pool.query(
    `SELECT ci.id AS "comparisonItemId", ci.position, ci.created_at AS "addedAt",
            ${COMPARISON_COLUMNS}
       FROM house_seeker_comparison_items ci
       JOIN property_listings pl ON pl.id = ci.listing_id
       JOIN properties p ON p.id = pl.property_id
       LEFT JOIN units u ON u.id = pl.unit_id
      WHERE ci.list_id = $1
      ORDER BY ci.position ASC, ci.created_at ASC
      LIMIT $2 OFFSET $3`,
    [listId, limit, offset],
  );

  return {
    items: result.rows.map((row) => normalizeCard(row)),
    total: totalResult.rows[0]?.total ?? 0,
    limit,
    offset,
  };
}

export async function addToComparison(userId: string, listingId: string) {
  const listing = await pool.query(
    `SELECT id, status FROM property_listings WHERE id = $1`,
    [listingId],
  );
  if (!listing.rows[0]) throw new HttpError('Listing not found', 404);

  const listId = await ensureComparisonList(userId);

  const count = await pool.query<{ count: string }>(
    `SELECT count(*)::int AS count FROM house_seeker_comparison_items WHERE list_id = $1`,
    [listId],
  );
  const currentCount = Number(count.rows[0]?.count ?? 0);
  if (currentCount >= MAX_COMPARISON_ITEMS) {
    throw new HttpError('Comparison list is full. Remove a property to add another.', 409);
  }

  const existing = await pool.query<{ id: string }>(
    `SELECT id FROM house_seeker_comparison_items WHERE list_id = $1 AND listing_id = $2`,
    [listId, listingId],
  );
  if (existing.rows[0]) {
    return { added: false, listingId, reason: 'already_in_comparison' };
  }

  const position = currentCount;
  const result = await pool.query(
    `INSERT INTO house_seeker_comparison_items (list_id, listing_id, position)
     VALUES ($1, $2, $3)
     RETURNING id, list_id AS "listId", listing_id AS "listingId", position, created_at AS "createdAt"`,
    [listId, listingId, position],
  );
  return { added: true, ...result.rows[0] };
}

export async function removeFromComparison(userId: string, listingId: string) {
  const list = await pool.query<{ id: string }>(
    `SELECT id FROM house_seeker_comparison_lists WHERE user_id = $1`,
    [userId],
  );
  if (!list.rows[0]) throw new HttpError('Comparison list not found', 404);

  const result = await pool.query(
    `DELETE FROM house_seeker_comparison_items
      WHERE list_id = $1 AND listing_id = $2
      RETURNING id`,
    [list.rows[0].id, listingId],
  );
  if (!result.rows[0]) throw new HttpError('Listing not in comparison', 404);

  // Reposition remaining items to close gaps.
  await pool.query(
    `UPDATE house_seeker_comparison_items ci
       SET position = sub.new_position
      FROM (
        SELECT id, row_number() OVER (ORDER BY position ASC, created_at ASC) - 1 AS new_position
          FROM house_seeker_comparison_items
         WHERE list_id = $1
      ) sub
      WHERE ci.id = sub.id`,
    [list.rows[0].id],
  );

  return { removed: true };
}

export async function clearComparison(userId: string) {
  const list = await pool.query<{ id: string }>(
    `SELECT id FROM house_seeker_comparison_lists WHERE user_id = $1`,
    [userId],
  );
  if (!list.rows[0]) return { cleared: true, removedCount: 0 };

  const countResult = await pool.query<{ count: string }>(
    `SELECT count(*)::int AS count FROM house_seeker_comparison_items WHERE list_id = $1`,
    [list.rows[0].id],
  );
  const removedCount = Number(countResult.rows[0]?.count ?? 0);

  await pool.query(
    `DELETE FROM house_seeker_comparison_items WHERE list_id = $1`,
    [list.rows[0].id],
  );
  return { cleared: true, removedCount };
}

// ---------------------------------------------------------------------------
// Enquiries (house seeker side)
// ---------------------------------------------------------------------------
export async function findUserContact(userId: string) {
  const result = await pool.query(
    `SELECT u.name, u.email, up.phone_number AS "phoneNumber"
       FROM users u LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE u.id = $1`,
    [userId],
  );
  return result.rows[0] as { name: string | null; email: string; phoneNumber: string | null } | undefined;
}

export async function createSeekerEnquiry(userId: string, data: CreateSeekerEnquiry) {
  let propertyId = data.propertyId;
  let unitId = data.unitId ?? null;
  const listingId: string | null = data.listingId ?? null;
  if (data.listingId) {
    const lr = await pool.query(
      `SELECT property_id, unit_id, status FROM property_listings WHERE id = $1`,
      [data.listingId],
    );
    const lrRow = lr.rows[0] as { property_id: string; unit_id: string | null; status: string } | undefined;
    if (!lrRow) throw new HttpError('Listing not found', 404);
    if (lrRow.status !== 'published') throw new HttpError('Listing is not available', 409);
    propertyId = lrRow.property_id;
    if (!unitId) unitId = lrRow.unit_id;
  }

  // Verify the property has an active published listing (public discoverability).
  const eligible = await pool.query(
    `SELECT 1 FROM property_listings WHERE property_id = $1 AND status = 'published' LIMIT 1`,
    [propertyId],
  );
  if (!eligible.rows[0]) throw new HttpError('Property is not currently listed', 409);

  const contact = await findUserContact(userId);
  const name = contact?.name || contact?.email || 'House Seeker';
  const phone = data.phone || contact?.phoneNumber || '';
  if (!phone) throw new HttpError('A contact phone number is required to enquire', 400);

  const enquiry = await createEnquiry({
    propertyId,
    unitId,
    listingId,
    prospectiveRenterId: userId,
    prospectiveRenterName: name,
    prospectiveRenterEmail: contact?.email ?? null,
    prospectiveRenterPhone: phone,
    enquirySource: data.listingId ? 'public_listing' : 'property_detail',
    message: data.message,
    assignedToUserId: null,
    followUpDate: null,
    internalNotes: null,
    createdBy: userId,
  });
  await notifyLandowner(propertyId, {
    eventType: 'enquiry.created',
    title: 'New enquiry',
    body: `${name} sent an enquiry about your property.`,
    metadata: { enquiryId: enquiry.id, propertyId },
    resourceId: enquiry.id,
  });
  return enquiry;
}

export async function listMyEnquiries(userId: string, query: { status?: string; limit: number; offset: number }) {
  const values: unknown[] = [userId];
  const bind = makeBinder(values);
  const where = ['e.prospective_renter_id = $1'];
  if (query.status) where.push(`e.status = ${bind(query.status)}`);
  const total = await pool.query(
    `SELECT count(*)::int AS total FROM property_enquiries e WHERE ${where.join(' AND ')}`,
    values,
  );
  const limit = bind(query.limit);
  const offset = bind(query.offset);
  const result = await pool.query(
    `SELECT e.id, e.property_id AS "propertyId", e.unit_id AS "unitId", e.listing_id AS "listingId",
            e.message, e.status, e.enquiry_source AS "source", e.created_at AS "createdAt",
            p.title AS "propertyTitle", p.city, p.county,
            pl.title AS "listingTitle"
       FROM property_enquiries e
       JOIN properties p ON p.id = e.property_id
       LEFT JOIN property_listings pl ON pl.id = e.listing_id
      WHERE ${where.join(' AND ')}
      ORDER BY e.created_at DESC
      LIMIT ${limit} OFFSET ${offset}`,
    values,
  );
  return { items: result.rows, total: total.rows[0]?.total ?? 0, limit: query.limit, offset: query.offset };
}

export async function findMyEnquiry(userId: string, enquiryId: string) {
  const result = await pool.query(
    `SELECT e.id, e.property_id AS "propertyId", e.unit_id AS "unitId", e.listing_id AS "listingId",
            e.message, e.status, e.enquiry_source AS "source", e.created_at AS "createdAt",
            e.prospective_renter_name AS "prospectiveRenterName",
            p.title AS "propertyTitle", p.city, p.county,
            pl.title AS "listingTitle"
       FROM property_enquiries e
       JOIN properties p ON p.id = e.property_id
       LEFT JOIN property_listings pl ON pl.id = e.listing_id
      WHERE e.id = $1 AND e.prospective_renter_id = $2`,
    [enquiryId, userId],
  );
  const row = result.rows[0];
  if (!row) throw new HttpError('Enquiry not found', 404);
  return row;
}

export async function withdrawEnquiry(userId: string, enquiryId: string) {
  const current = await pool.query(
    `SELECT status FROM property_enquiries WHERE id = $1 AND prospective_renter_id = $2`,
    [enquiryId, userId],
  );
  const row = current.rows[0] as { status: string } | undefined;
  if (!row) throw new HttpError('Enquiry not found', 404);
  if (['converted_to_tenant', 'closed', 'lost_declined'].includes(row.status)) {
    throw new HttpError('This enquiry can no longer be withdrawn', 409);
  }
  const updated = await pool.query(
    `UPDATE property_enquiries SET status = 'closed', updated_by = $2
      WHERE id = $1 AND prospective_renter_id = $3
      RETURNING id, status`,
    [enquiryId, userId, userId],
  );
  return updated.rows[0];
}

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------
export async function getPreferences(userId: string) {
  const result = await pool.query(
    `SELECT id, user_id AS "userId", min_budget AS "minBudget", max_budget AS "maxBudget",
            preferred_property_types AS "preferredPropertyTypes", preferred_bedrooms AS "preferredBedrooms",
            preferred_bathrooms AS "preferredBathrooms", preferred_amenities AS "preferredAmenities",
            preferred_locations AS "preferredLocations", move_in_date AS "moveInDate",
            alerts_enabled AS "alertsEnabled", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM house_seeker_preferences WHERE user_id = $1`,
    [userId],
  );
  return result.rows[0] ?? null;
}

export async function upsertPreferences(userId: string, data: UpdatePreferences) {
  const result = await pool.query(
    `INSERT INTO house_seeker_preferences (
        user_id, min_budget, max_budget, preferred_property_types, preferred_bedrooms,
        preferred_bathrooms, preferred_amenities, preferred_locations, move_in_date, alerts_enabled
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, COALESCE($10, TRUE))
     ON CONFLICT (user_id) DO UPDATE SET
        min_budget = COALESCE(EXCLUDED.min_budget, house_seeker_preferences.min_budget),
        max_budget = COALESCE(EXCLUDED.max_budget, house_seeker_preferences.max_budget),
        preferred_property_types = COALESCE(NULLIF(EXCLUDED.preferred_property_types, '[]'::jsonb), house_seeker_preferences.preferred_property_types),
        preferred_bedrooms = COALESCE(EXCLUDED.preferred_bedrooms, house_seeker_preferences.preferred_bedrooms),
        preferred_bathrooms = COALESCE(EXCLUDED.preferred_bathrooms, house_seeker_preferences.preferred_bathrooms),
        preferred_amenities = COALESCE(NULLIF(EXCLUDED.preferred_amenities, '[]'::jsonb), house_seeker_preferences.preferred_amenities),
        preferred_locations = COALESCE(NULLIF(EXCLUDED.preferred_locations, '[]'::jsonb), house_seeker_preferences.preferred_locations),
        move_in_date = COALESCE(EXCLUDED.move_in_date, house_seeker_preferences.move_in_date),
        alerts_enabled = COALESCE(EXCLUDED.alerts_enabled, house_seeker_preferences.alerts_enabled)
     RETURNING id, user_id AS "userId", min_budget AS "minBudget", max_budget AS "maxBudget",
               preferred_property_types AS "preferredPropertyTypes", preferred_bedrooms AS "preferredBedrooms",
               preferred_bathrooms AS "preferredBathrooms", preferred_amenities AS "preferredAmenities",
               preferred_locations AS "preferredLocations", move_in_date AS "moveInDate",
               alerts_enabled AS "alertsEnabled", created_at AS "createdAt", updated_at AS "updatedAt"`,
    [
      userId,
      data.minBudget ?? null,
      data.maxBudget ?? null,
      JSON.stringify(data.preferredPropertyTypes ?? []),
      data.preferredBedrooms ?? null,
      data.preferredBathrooms ?? null,
      JSON.stringify(data.preferredAmenities ?? []),
      JSON.stringify(data.preferredLocations ?? []),
      data.moveInDate ?? null,
      data.alertsEnabled ?? null,
    ],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Listing reports
// ---------------------------------------------------------------------------
export async function createListingReport(userId: string, data: CreateListingReport) {
  const listing = await pool.query(`SELECT id FROM property_listings WHERE id = $1`, [data.listingId]);
  if (!listing.rows[0]) throw new HttpError('Listing not found', 404);
  const result = await pool.query(
    `INSERT INTO listing_reports (listing_id, reporter_user_id, reason, details, evidence_urls)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, listing_id AS "listingId", reason, status, created_at AS "createdAt"`,
    [data.listingId, userId, data.reason, data.details ?? null, JSON.stringify(data.evidenceUrls ?? [])],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Site visits (house seeker side)
// ---------------------------------------------------------------------------
async function resolvePublishedProperty(propertyId: string, listingId?: string | null) {
  if (listingId) {
    const lr = await pool.query<{ property_id: string; status: string }>(
      `SELECT property_id, status FROM property_listings WHERE id = $1`,
      [listingId],
    );
    const row = lr.rows[0];
    if (!row) throw new HttpError('Listing not found', 404);
    if (row.status !== 'published') throw new HttpError('Listing is not available', 409);
    return row.property_id;
  }
  const eligible = await pool.query(
    `SELECT 1 FROM property_listings WHERE property_id = $1 AND status = 'published' LIMIT 1`,
    [propertyId],
  );
  if (!eligible.rows[0]) throw new HttpError('Property is not currently listed', 409);
  return propertyId;
}

export async function listMySiteVisits(userId: string, query: { status?: string; limit: number; offset: number }) {
  const visits = await findSiteVisitsByUser(userId, { limit: query.limit, offset: query.offset });
  const filtered = query.status ? visits.filter((v: { status: string }) => v.status === query.status) : visits;
  return { items: filtered, total: filtered.length, limit: query.limit, offset: query.offset };
}

/**
 * Compute the bookable slot grid for a property on a given local date.
 * Slots come from the active availability rule for that weekday, are filtered
 * by blackout/partial-day exceptions, and have their remaining capacity
 * annotated from existing non-terminal visits.
 */
export async function getListingAvailability(
  propertyId: string,
  date: string,
): Promise<{ slots: Array<{ start: string; end: string; available: boolean; remainingCapacity: number }>; unavailableReason: string | null }> {
  const dayKey = date;
  const dayDate = new Date(`${date}T00:00:00Z`);
  if (Number.isNaN(dayDate.getTime())) {
    throw new HttpError('date must be a valid YYYY-MM-DD date', 400);
  }
  const dayName = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: 'UTC' })
    .format(dayDate)
    .toLowerCase();

  const ruleResult = await pool.query<{
    start_time: string;
    end_time: string;
    slot_duration_minutes: number;
    buffer_minutes: number;
    max_bookings_per_slot: number;
  }>(
    `SELECT start_time, end_time, slot_duration_minutes, buffer_minutes, max_bookings_per_slot
       FROM site_visit_availability_rules
      WHERE property_id = $1 AND is_active = true AND day_of_week = $2::availability_day_of_week
      LIMIT 1`,
    [propertyId, dayName],
  );

  if (ruleResult.rows.length === 0) {
    return {
      slots: [],
      unavailableReason: 'No availability has been published for this day.',
    };
  }

  const rule = ruleResult.rows[0]!;
  const exceptionResult = await pool.query<{ is_unavailable: boolean; start_time: string | null; end_time: string | null }>(
    `SELECT is_unavailable, start_time, end_time
       FROM site_visit_availability_exceptions
      WHERE property_id = $1 AND exception_date = $2::date
      LIMIT 1`,
    [propertyId, dayKey],
  );

  const exception = exceptionResult.rows[0];
  if (exception?.is_unavailable) {
    return { slots: [], unavailableReason: 'The property is unavailable on this date.' };
  }

  const toMinutes = (value: string) => {
    const [hours = '0', minutes = '0'] = value.split(':');
    return Number(hours) * 60 + Number(minutes);
  };
  const fromMinutes = (total: number) =>
    `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;

  let windowStart = toMinutes(rule.start_time);
  let windowEnd = toMinutes(rule.end_time);
  if (exception && !exception.is_unavailable && exception.start_time && exception.end_time) {
    windowStart = Math.max(windowStart, toMinutes(exception.start_time));
    windowEnd = Math.min(windowEnd, toMinutes(exception.end_time));
  }

  const slot = rule.slot_duration_minutes > 0 ? rule.slot_duration_minutes : 30;
  const capacity = rule.max_bookings_per_slot > 0 ? rule.max_bookings_per_slot : 1;
  const buffer = rule.buffer_minutes;

  const slots: Array<{ start: string; end: string; available: boolean; remainingCapacity: number }> = [];
  if (windowEnd <= windowStart) {
    return { slots: [], unavailableReason: 'No bookable window on this date.' };
  }

  for (let start = windowStart; start + slot <= windowEnd; start += slot) {
    const startStr = fromMinutes(start);
    const endStr = fromMinutes(start + slot);

    const bookingResult = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count
         FROM site_visits sv
        WHERE sv.property_id = $1
          AND sv.status NOT IN ('cancelled', 'no_show', 'completed')
          AND (sv.scheduled_at AT TIME ZONE 'Africa/Nairobi')::date = $2::date
          AND (sv.scheduled_at AT TIME ZONE 'Africa/Nairobi')::time
                < ($3::time + ($4::int || ' minutes')::interval)
          AND ((sv.scheduled_at + (sv.duration_minutes || ' minutes')::interval
                + ($5::int || ' minutes')::interval) AT TIME ZONE 'Africa/Nairobi')::time
                > $3::time`,
      [propertyId, dayKey, startStr, slot, buffer],
    );

    const used = Number(bookingResult.rows[0]?.count ?? '0');
    slots.push({
      start: startStr,
      end: endStr,
      available: used < capacity,
      remainingCapacity: Math.max(0, capacity - used),
    });
  }

  return { slots, unavailableReason: null };
}

export async function getMySiteVisit(userId: string, visitId: string) {
  const visit = await findSiteVisitById(visitId);
  if (!visit) throw new HttpError('Site visit not found', 404);
  if (visit.userId !== userId && visit.createdBy !== userId) throw new HttpError('Not allowed', 403);
  return visit;
}

// ---------------------------------------------------------------------------
// Conversations & messages (house seeker side)
// ---------------------------------------------------------------------------
async function isParticipant(conversationId: string, userId: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
    [conversationId, userId],
  );
  return Boolean(result.rows[0]);
}

async function assertParticipant(conversationId: string, userId: string): Promise<void> {
  if (!(await isParticipant(conversationId, userId))) throw new HttpError('Not allowed', 403);
}

export async function startSeekerConversation(userId: string, data: StartConversation) {
  const conversationId = randomUUID();
  await pool.query(
    `INSERT INTO conversations (id, type, subject, property_id, unit_id, enquiry_id, created_by)
     VALUES ($1, 'enquiry', $2, $3, $4, $5, $6)`,
    [conversationId, data.subject ?? null, data.propertyId, data.unitId ?? null, data.enquiryId ?? null, userId],
  );
  const participants = new Set([userId, data.landlordUserId]);
  for (const participantId of participants) {
    await pool.query(
      `INSERT INTO conversation_participants (conversation_id, user_id, role)
       VALUES ($1, $2, $3) ON CONFLICT (conversation_id, user_id) DO NOTHING`,
      [conversationId, participantId, participantId === userId ? 'owner' : 'participant'],
    );
  }
  const message = await pool.query(
    `INSERT INTO messages (conversation_id, sender_id, type, content)
     VALUES ($1, $2, 'text', $3)
     RETURNING id, conversation_id AS "conversationId", sender_id AS "senderId", type, content, status, reply_to_id AS "replyToId", created_at AS "createdAt", updated_at AS "updatedAt", deleted_at AS "deletedAt"`,
    [conversationId, userId, data.message],
  );
  await pool.query(`UPDATE conversations SET last_message_at = NOW() WHERE id = $1`, [conversationId]);
  await notifyLandowner(data.propertyId, {
    eventType: 'conversation.started',
    title: 'New message',
    body: 'A prospective renter sent you a message.',
    metadata: { conversationId },
    resourceId: conversationId,
  });
  const conversation = await pool.query(
    `SELECT id, type, subject, property_id AS "propertyId", unit_id AS "unitId",
            enquiry_id AS "enquiryId", rental_proposal_id AS "rentalProposalId",
            tenancy_id AS "tenancyId", site_visit_id AS "siteVisitId", created_by AS "createdBy",
            status, last_message_at AS "lastMessageAt", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM conversations WHERE id = $1`,
    [conversationId],
  );
  return { conversation: conversation.rows[0], firstMessage: message.rows[0] };
}

export async function listMyConversations(userId: string, limit = 20, offset = 0) {
  const result = await pool.query(
    `SELECT c.id, c.type, c.subject, c.property_id AS "propertyId", c.unit_id AS "unitId",
            c.enquiry_id AS "enquiryId", c.rental_proposal_id AS "rentalProposalId",
            c.tenancy_id AS "tenancyId", c.site_visit_id AS "siteVisitId", c.status,
            c.last_message_at AS "lastMessageAt", c.created_at AS "createdAt", c.updated_at AS "updatedAt",
            p.title AS "propertyTitle", p.city, p.county,
            (SELECT count(*)::int FROM messages m
              WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
                AND NOT EXISTS (SELECT 1 FROM message_read_states mrs WHERE mrs.message_id = m.id AND mrs.user_id = $1)
            ) AS "unreadCount"
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       LEFT JOIN properties p ON p.id = c.property_id
      WHERE cp.user_id = $1 AND cp.left_at IS NULL
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
      LIMIT $2 OFFSET $3`,
    [userId, limit, offset],
  );
  return result.rows;
}

export async function getMyConversation(userId: string, conversationId: string) {
  await assertParticipant(conversationId, userId);
  const result = await pool.query(
    `SELECT id, type, subject, property_id AS "propertyId", unit_id AS "unitId",
            enquiry_id AS "enquiryId", rental_proposal_id AS "rentalProposalId",
            tenancy_id AS "tenancyId", site_visit_id AS "siteVisitId", created_by AS "createdBy",
            status, last_message_at AS "lastMessageAt", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM conversations WHERE id = $1`,
    [conversationId],
  );
  return result.rows[0];
}

export async function listMyMessages(userId: string, conversationId: string, query: { limit: number; offset: number }) {
  await assertParticipant(conversationId, userId);
  const result = await pool.query(
    `SELECT m.id, m.conversation_id AS "conversationId", m.sender_id AS "senderId", m.type,
            m.content, m.status, m.reply_to_id AS "replyToId", m.created_at AS "createdAt",
            EXISTS (
              SELECT 1 FROM message_read_states mrs WHERE mrs.message_id = m.id AND mrs.user_id = $1
            ) AS "isRead"
       FROM messages m
      WHERE m.conversation_id = $2 AND m.deleted_at IS NULL
      ORDER BY m.created_at ASC
      LIMIT $3 OFFSET $4`,
    [userId, conversationId, query.limit, query.offset],
  );
  return result.rows;
}

export async function sendSeekerMessage(userId: string, data: SendMessage) {
  await assertParticipant(data.conversationId, userId);
  const message = await pool.query(
    `INSERT INTO messages (conversation_id, sender_id, type, content)
     VALUES ($1, $2, 'text', $3)
     RETURNING id, conversation_id AS "conversationId", sender_id AS "senderId", type, content,
               status, reply_to_id AS "replyToId", created_at AS "createdAt", updated_at AS "updatedAt", deleted_at AS "deletedAt"`,
    [data.conversationId, userId, data.content],
  );
  await pool.query(`UPDATE conversations SET last_message_at = NOW() WHERE id = $1`, [data.conversationId]);
  return message.rows[0];
}

export async function markMyMessagesRead(userId: string, conversationId: string) {
  await assertParticipant(conversationId, userId);
  await pool.query(
    `INSERT INTO message_read_states (message_id, user_id)
     SELECT m.id, $2 FROM messages m
      WHERE m.conversation_id = $1 AND m.deleted_at IS NULL AND m.sender_id <> $2
     ON CONFLICT (message_id, user_id) DO NOTHING`,
    [conversationId, userId],
  );
  return { marked: true };
}

// ---------------------------------------------------------------------------
// Rental applications (house seeker side)
// ---------------------------------------------------------------------------
export async function createSeekerApplication(userId: string, data: CreateSeekerApplication) {
  const propertyId = await resolvePublishedProperty(data.propertyId, data.listingId);
  const contact = await findUserContact(userId);
  const name = contact?.name || contact?.email || 'House Seeker';
  const phone = contact?.phoneNumber || '';
  const email = contact?.email || '';
  if (!email) throw new HttpError('A verified email is required to apply', 400);
  const application = await createRentalApplication({
    propertyId,
    unitId: data.unitId ?? null,
    userId,
    applicantName: name,
    applicantEmail: email,
    applicantPhone: phone,
    preferredStartDate: data.preferredStartDate ? new Date(data.preferredStartDate) : null,
    preferredEndDate: data.preferredEndDate ? new Date(data.preferredEndDate) : null,
    proposedRentAmount: data.proposedRentAmount ?? null,
    documents: data.documents ? { urls: data.documents } : null,
    employerName: data.employerName ?? null,
    employerContact: data.employerContact ?? null,
    monthlyIncome: data.monthlyIncome ?? null,
    previousLandlordName: data.previousLandlordName ?? null,
    previousLandlordContact: data.previousLandlordContact ?? null,
    guarantorName: data.guarantorName ?? null,
    guarantorPhone: data.guarantorPhone ?? null,
    guarantorRelationship: data.guarantorRelationship ?? null,
  });
  await notifyLandowner(propertyId, {
    eventType: 'application.submitted',
    title: 'New rental application',
    body: `${name} submitted a rental application.`,
    metadata: { applicationId: application.id },
    resourceId: application.id,
  });
  return application;
}

export async function listMyApplications(userId: string, query: { status?: string; limit: number; offset: number }) {
  const applications = await findRentalApplicationsByUser(userId, { limit: query.limit, offset: query.offset });
  const filtered = query.status
    ? applications.filter((a: { status: string }) => a.status === query.status)
    : applications;
  const withProperty = await Promise.all(
    filtered.map(async (app: { propertyId: string }) => {
      const prop = await pool.query(
        `SELECT title AS "propertyTitle", city, county FROM properties WHERE id = $1`,
        [app.propertyId],
      );
      return { ...app, ...(prop.rows[0] ?? {}) };
    }),
  );
  return { items: withProperty, total: withProperty.length, limit: query.limit, offset: query.offset };
}

export async function getMyApplication(userId: string, applicationId: string) {
  const application = await findRentalApplicationById(applicationId);
  if (!application) throw new HttpError('Application not found', 404);
  if (application.userId !== userId) throw new HttpError('Not allowed', 403);
  const prop = await pool.query(
    `SELECT title AS "propertyTitle", city, county FROM properties WHERE id = $1`,
    [application.propertyId],
  );
  return { ...application, ...(prop.rows[0] ?? {}) };
}

export async function withdrawMyApplication(userId: string, applicationId: string) {
  const application = await getMyApplication(userId, applicationId);
  if (['approved', 'rejected', 'withdrawn', 'expired'].includes(application.status)) {
    throw new HttpError('This application can no longer be withdrawn', 409);
  }
  const updated = await pool.query(
    `UPDATE rental_applications SET status = 'withdrawn' WHERE id = $1 RETURNING id, status`,
    [applicationId],
  );
  return updated.rows[0];
}

// ---------------------------------------------------------------------------
// Rental proposals (house seeker responses)
// ---------------------------------------------------------------------------
export async function listMyProposals(userId: string, query: { status?: string; limit: number; offset: number }) {
  // Lazily expire overdue proposals so the seeker never sees a stale "sent"
  // proposal they can no longer act on.
  await expireOverdueProposals();
  const conditions = ['prospective_renter_id = $1'];
  const values: unknown[] = [userId];
  let idx = 2;
  if (query.status) {
    conditions.push(`status = $${idx++}`);
    values.push(query.status);
  }
  const where = `WHERE ${conditions.join(' AND ')}`;
  const count = await pool.query(
    `SELECT count(*)::int AS total FROM rental_proposals ${where}`,
    values,
  );
  values.push(query.limit, query.offset);
  const result = await pool.query(
    `SELECT rp.id, rp.enquiry_id AS "enquiryId", rp.conversation_id AS "conversationId",
            rp.property_id AS "propertyId", rp.unit_id AS "unitId",
            rp.prospective_renter_id AS "prospectiveRenterId", rp.landlord_user_id AS "landlordUserId",
            rp.type, rp.status, rp.proposed_rent_amount AS "proposedRentAmount",
            rp.proposed_deposit_amount AS "proposedDepositAmount",
            rp.proposed_start_date AS "proposedStartDate", rp.proposed_end_date AS "proposedEndDate",
            rp.proposed_rent_due_day AS "proposedRentDueDay", rp.special_conditions AS "specialConditions",
            rp.notes, rp.expires_at AS "expiresAt", rp.accepted_at AS "acceptedAt",
            rp.declined_at AS "declinedAt", rp.confirmed_at AS "confirmedAt", rp.created_at AS "createdAt",
            p.title AS "propertyTitle", p.city, p.county
       FROM rental_proposals rp
       JOIN properties p ON p.id = rp.property_id
       ${where}
      ORDER BY rp.created_at DESC
      LIMIT $${idx++} OFFSET $${idx++}`,
    values,
  );
  return { items: result.rows, total: count.rows[0]?.total ?? 0, limit: query.limit, offset: query.offset };
}

export async function getMyProposal(userId: string, proposalId: string) {
  await expireOverdueProposals();
  const proposal = await findRentalProposalById(proposalId);
  if (!proposal) throw new HttpError('Rental proposal not found', 404);
  if (proposal.prospectiveRenterId !== userId) throw new HttpError('Not allowed', 403);
  return proposal;
}

export async function respondToMyProposal(userId: string, proposalId: string, data: RespondToProposal) {
  const proposal = await getMyProposal(userId, proposalId);
  if (!['sent', 'under_review', 'changes_requested'].includes(proposal.status)) {
    throw new HttpError(`This proposal cannot be actioned in its current state (${proposal.status})`, 409);
  }

  let newStatus: string;
  let timestampField: 'accepted_at' | 'declined_at' | null = null;
  let eventType: string;
  switch (data.action) {
    case 'accept':
      newStatus = 'accepted';
      timestampField = 'accepted_at';
      eventType = 'proposal.accepted';
      break;
    case 'decline':
      newStatus = 'declined';
      timestampField = 'declined_at';
      eventType = 'proposal.declined';
      break;
    case 'request_changes':
      newStatus = 'changes_requested';
      eventType = 'proposal.changes_requested';
      break;
    case 'counter':
      newStatus = 'under_review';
      eventType = 'proposal.counter';
      break;
    default:
      throw new HttpError('Invalid action', 400);
  }

  // Counter proposals create a new version so the landlord sees the proposed terms.
  // Distinct versions get a distinct event identity (version-scoped idempotency
  // key) so each negotiation round produces its own logical notification.
  // The FOR UPDATE lock serialises concurrent counter responses so two seekers
  // (or two rapid requests) cannot both receive the same version number.
  let counterVersion: number | null = null;
  if (data.action === 'counter' && data.counter) {
    const counter = data.counter;
    counterVersion = await transaction(async (client) => {
      await client.query(
        `SELECT id FROM rental_proposals WHERE id = $1 FOR UPDATE`,
        [proposalId],
      );
      const versionCount = await client.query<{ next: string }>(
        `SELECT COALESCE(max(version_number), 0) + 1 AS next FROM rental_proposal_versions WHERE proposal_id = $1`,
        [proposalId],
      );
      const nextVersion = Number(versionCount.rows[0]?.next ?? 1);
      await client.query(
        `INSERT INTO rental_proposal_versions (proposal_id, version_number, proposed_rent_amount, proposed_deposit_amount, proposed_start_date, proposed_end_date, proposed_rent_due_day, special_conditions, notes, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          proposalId,
          nextVersion,
          counter.rentAmount ?? proposal.proposedRentAmount,
          counter.depositAmount ?? proposal.proposedDepositAmount,
          counter.startDate ? new Date(counter.startDate) : proposal.proposedStartDate,
          counter.endDate ? new Date(counter.endDate) : proposal.proposedEndDate,
          proposal.proposedRentDueDay,
          proposal.specialConditions,
          data.reason ?? proposal.notes,
          userId,
        ],
      );
      return nextVersion;
    });
  }

  const idempotencyKey = counterVersion != null
    ? `${eventType}:${proposalId}:v${counterVersion}`
    : `${eventType}:${proposalId}`;

  // Critical event persisted atomically with the status change; no separate
  // best-effort notify that could lose the notification on a crash.
  const updated = await setRentalProposalStatus(
    proposalId,
    newStatus,
    userId,
    data.reason ?? null,
    timestampField,
    { eventType, idempotencyKey },
  );
  return updated;
}

// ---------------------------------------------------------------------------
// Rental journey (dashboard)
// ---------------------------------------------------------------------------
export async function getSeekerJourney(userId: string) {
  const [saved, enquiries, visits, proposals, applications] = await Promise.all([
    pool.query(`SELECT count(*)::int AS total FROM saved_listings WHERE user_id = $1`, [userId]),
    pool.query(`SELECT count(*)::int AS total FROM property_enquiries WHERE prospective_renter_id = $1 AND status NOT IN ('closed','lost_declined')`, [userId]),
    pool.query(`SELECT count(*)::int AS total FROM site_visits WHERE user_id = $1 AND status IN ('scheduled','confirmed','rescheduled')`, [userId]),
    pool.query(`SELECT count(*)::int AS total FROM rental_proposals WHERE prospective_renter_id = $1 AND status IN ('sent','under_review','changes_requested','accepted')`, [userId]),
    pool.query(`SELECT count(*)::int AS total FROM rental_applications WHERE user_id = $1 AND status NOT IN ('withdrawn','rejected','expired')`, [userId]),
  ]);
  const upcoming = await pool.query(
    `SELECT id, property_id AS "propertyId", scheduled_at AS "scheduledAt", status
       FROM site_visits WHERE user_id = $1 AND status IN ('scheduled','confirmed','rescheduled') AND scheduled_at >= NOW()
      ORDER BY scheduled_at ASC LIMIT 5`,
    [userId],
  );
  const recentProposals = await pool.query(
    `SELECT rp.id, rp.status, rp.proposed_rent_amount AS "proposedRentAmount", p.title AS "propertyTitle"
       FROM rental_proposals rp JOIN properties p ON p.id = rp.property_id
      WHERE rp.prospective_renter_id = $1 ORDER BY rp.created_at DESC LIMIT 5`,
    [userId],
  );
  return {
    counts: {
      savedHomes: saved.rows[0]?.total ?? 0,
      activeEnquiries: enquiries.rows[0]?.total ?? 0,
      upcomingVisits: visits.rows[0]?.total ?? 0,
      pendingProposals: proposals.rows[0]?.total ?? 0,
      activeApplications: applications.rows[0]?.total ?? 0,
    },
    upcomingVisits: upcoming.rows,
    recentProposals: recentProposals.rows,
  };
}