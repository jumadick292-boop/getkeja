// Search alert matching engine.
// Matches newly published listings against saved searches and creates
// notifications for House Seekers whose criteria are met.
//
// Reuses the existing notification service (outbox + delivery) and the
// existing pg-boss worker infrastructure. Does not create a duplicate
// notification system or job queue.

import { pool } from '../../db/pool.js';
import { NotificationService } from '../auth/notification.service.js';
import type { NotificationCategory, NotificationChannel } from '../auth/auth.types.js';

// Search alert frequencies.
export type SearchAlertFrequency = 'immediate' | 'daily' | 'weekly';

// How far back to look for recently published listings when backfilling alerts.
const RECENT_LISTINGS_WINDOW_MINUTES = 60;

// Maximum number of saved searches to evaluate per listing batch.
const MAX_SAVED_SEARCHES_PER_BATCH = 500;

// Maximum number of notifications to create per batch.
const MAX_NOTIFICATIONS_PER_BATCH = 100;

// Category used for search-alert notifications.
const SEARCH_ALERT_CATEGORY: NotificationCategory = 'property';

// Channels used for search-alert notifications (respect user preferences).
const SEARCH_ALERT_CHANNELS: NotificationChannel[] = ['in_app', 'email', 'push'];

/**
 * Check whether a listing matches a saved search's criteria.
 * Reuses the same field semantics as the search API.
 */
function listingMatchesCriteria(
  listing: Record<string, unknown>,
  criteria: Record<string, unknown>,
): boolean {
  // Keyword search.
  if (criteria.q) {
    const q = String(criteria.q).toLowerCase();
    const haystack = [
      listing.title,
      listing.description,
      listing.propertyTitle,
      listing.address,
      listing.city,
      listing.county,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    if (!haystack.includes(q)) return false;
  }

  // City.
  if (criteria.city && listing.city) {
    if (String(listing.city).toLowerCase() !== String(criteria.city).toLowerCase()) return false;
  }

  // County.
  if (criteria.county && listing.county) {
    if (String(listing.county).toLowerCase() !== String(criteria.county).toLowerCase()) return false;
  }

  // Neighbourhood (matched against address).
  if (criteria.neighbourhood && listing.address) {
    if (!String(listing.address).toLowerCase().includes(String(criteria.neighbourhood).toLowerCase()))
      return false;
  }

  // Property type.
  if (criteria.propertyType && listing.propertyType) {
    if (String(listing.propertyType).toLowerCase() !== String(criteria.propertyType).toLowerCase())
      return false;
  }

  // Price range.
  const rentAmount = listing.rentAmount !== null && listing.rentAmount !== undefined
    ? Number(listing.rentAmount)
    : null;
  if (rentAmount === null) {
    // If the listing has no price, it can't match a price range.
    if (criteria.rentMin !== undefined || criteria.rentMax !== undefined) return false;
  } else {
    if (criteria.rentMin !== undefined && rentAmount < Number(criteria.rentMin)) return false;
    if (criteria.rentMax !== undefined && rentAmount > Number(criteria.rentMax)) return false;
  }

  // Bedrooms.
  if (criteria.bedrooms !== undefined) {
    const bedrooms = listing.bedrooms !== null && listing.bedrooms !== undefined
      ? Number(listing.bedrooms)
      : null;
    if (bedrooms === null || bedrooms < Number(criteria.bedrooms)) return false;
  }

  // Bathrooms.
  if (criteria.bathrooms !== undefined) {
    const bathrooms = listing.bathrooms !== null && listing.bathrooms !== undefined
      ? Number(listing.bathrooms)
      : null;
    if (bathrooms === null || bathrooms < Number(criteria.bathrooms)) return false;
  }

  // Furnished.
  if (criteria.furnished !== undefined && listing.furnished !== undefined) {
    const wanted = String(criteria.furnished) === 'true';
    if (Boolean(listing.furnished) !== wanted) return false;
  }

  // Amenities (comma-separated string, matched against JSONB ? operator).
  if (criteria.amenities && listing.amenities) {
    const amenities = String(criteria.amenities).split(',').map((a) => a.trim()).filter(Boolean);
    const listingAmenities = listing.amenities as unknown as Record<string, unknown>;
    for (const amenity of amenities) {
      if (!(amenity in listingAmenities)) return false;
    }
  }

  return true;
}

/**
 * Determine whether an alert should be sent now based on frequency and
 * the last alert timestamp.
 */
function shouldSendAlert(
  frequency: SearchAlertFrequency,
  lastAlertedAt: Date | null | undefined,
): boolean {
  const now = new Date();
  switch (frequency) {
    case 'immediate':
      return true;
    case 'daily':
      if (!lastAlertedAt) return true;
      const lastAlertDate = new Date(lastAlertedAt);
      return now.getDate() !== lastAlertDate.getDate() ||
             now.getMonth() !== lastAlertDate.getMonth() ||
             now.getFullYear() !== lastAlertDate.getFullYear();
    case 'weekly':
      if (!lastAlertedAt) return true;
      const lastAlert = new Date(lastAlertedAt);
      const daysDiff = Math.floor((now.getTime() - lastAlert.getTime()) / (1000 * 60 * 60 * 24));
      return daysDiff >= 7;
    default:
      return true;
  }
}

/**
 * Format a compact property summary for notification content.
 */
function formatPropertySummary(listing: Record<string, unknown>): string {
  const parts: string[] = [];
  if (listing.title) parts.push(String(listing.title));
  if (listing.propertyType) parts.push(String(listing.propertyType));
  if (listing.bedrooms !== null && listing.bedrooms !== undefined) {
    parts.push(`${listing.bedrooms} bed`);
  }
  if (listing.city) parts.push(String(listing.city));
  if (listing.rentAmount !== null && listing.rentAmount !== undefined) {
    parts.push(`KES ${Number(listing.rentAmount)}`);
  }
  return parts.join(' · ');
}

export class SearchAlertService {
  private notificationService: NotificationService;

  constructor() {
    this.notificationService = new NotificationService();
  }

  // -----------------------------------------------------------------------
  // Match a single listing against all eligible saved searches.
  // -----------------------------------------------------------------------
  async matchListingAgainstSavedSearches(listingId: string): Promise<{
    matched: number;
    notified: number;
    skipped: number;
  }> {
    // Fetch the listing details.
    const listingResult = await pool.query(
      `SELECT pl.id AS "listingId", pl.title, pl.description, p.title AS "propertyTitle",
              p.city, p.county, p.address, p.property_type AS "propertyType",
              COALESCE(pl.rent_amount, u.rent_amount) AS "rentAmount",
              u.bedrooms, u.bathrooms, pl.furnished,
              COALESCE(NULLIF(pl.amenities, '[]'::jsonb), NULLIF(p.amenities, '[]'::jsonb), '[]'::jsonb) AS amenities,
              pl.status
       FROM property_listings pl
       JOIN properties p ON p.id = pl.property_id
       LEFT JOIN units u ON u.id = pl.unit_id
       WHERE pl.id = $1`,
      [listingId],
    );
    const listing = listingResult.rows[0];
    if (!listing) return { matched: 0, notified: 0, skipped: 0 };

    // Only match published listings.
    if (listing.status !== 'published') return { matched: 0, notified: 0, skipped: 0 };

    // Fetch all active saved searches with alerts enabled, in bounded batches.
    const searchesResult = await pool.query(
      `SELECT id, user_id AS "userId", name, criteria, alerts_enabled AS "alertsEnabled",
              alert_frequency AS "alertFrequency",
              last_alerted_at AS "lastAlertedAt"
       FROM saved_searches
       WHERE alerts_enabled = TRUE
       ORDER BY created_at DESC
       LIMIT $1`,
      [MAX_SAVED_SEARCHES_PER_BATCH],
    );
    const savedSearches = searchesResult.rows;

    let matched = 0;
    let notified = 0;
    let skipped = 0;

    for (const search of savedSearches) {
      const criteria = (search.criteria as Record<string, unknown>) ?? {};
      const frequency = (search.alertFrequency as SearchAlertFrequency) ?? 'immediate';

      if (!listingMatchesCriteria(listing, criteria)) {
        skipped++;
        continue;
      }

      matched++;

      // Frequency check.
      if (!shouldSendAlert(frequency, search.lastAlertedAt)) {
        skipped++;
        continue;
      }

      // Deduplication: has this listing already been alerted for this search?
      const dedupResult = await pool.query(
        `SELECT 1 FROM search_alert_deduplication
         WHERE saved_search_id = $1 AND listing_id = $2`,
        [search.id, listingId],
      );
      if (dedupResult.rows.length > 0) {
        skipped++;
        continue;
      }

      // Create the notification.
      const searchName = search.name as string;
      const summary = formatPropertySummary(listing);
      const title = `New match: ${searchName}`;
      const body = `A new property matches your saved search "${searchName}": ${summary}.`;

      try {
        await this.notificationService.createAndSend({
          userId: search.userId as string,
          organisationId: null,
          eventType: 'saved_search.match',
          category: SEARCH_ALERT_CATEGORY,
          title,
          body,
          metadata: {
            savedSearchId: search.id,
            listingId,
            listingTitle: listing.title,
            listingLocation: listing.city || listing.county || listing.address,
            listingPrice: listing.rentAmount,
            searchName,
            summary,
          },
          priority: 'normal',
          expiresAt: null,
          channels: SEARCH_ALERT_CHANNELS,
        });

        // Record deduplication.
        await pool.query(
          `INSERT INTO search_alert_deduplication (user_id, saved_search_id, listing_id)
           VALUES ($1, $2, $3)
           ON CONFLICT (saved_search_id, listing_id) DO NOTHING`,
          [search.userId, search.id, listingId],
        );

        // Update last_alerted_at.
        await pool.query(
          `UPDATE saved_searches SET last_alerted_at = NOW() WHERE id = $1`,
          [search.id],
        );

        notified++;
      } catch (error) {
        // Notification failures must not break the matching loop.
        console.error(`Failed to create alert for saved search ${search.id}:`, error);
      }
    }

    return { matched, notified, skipped };
  }

  // -----------------------------------------------------------------------
  // Process pending listings for search alerts (called by the worker).
  // Finds recently published listings and matches them against saved searches.
  // -----------------------------------------------------------------------
  async processPendingAlerts(): Promise<{
    processed: number;
    matched: number;
    notified: number;
  }> {
    // Find listings published recently that haven't been alert-matching processed yet.
    // We use the search_alert_deduplication table implicitly: if a listing has
    // been processed for all matching searches, it will have dedup entries.
    // For simplicity, we process listings published in the last window.
    const result = await pool.query(
      `SELECT pl.id AS "listingId"
       FROM property_listings pl
       WHERE pl.status = 'published'
         AND pl.published_at >= NOW() - INTERVAL '${RECENT_LISTINGS_WINDOW_MINUTES} minutes'
       ORDER BY pl.published_at DESC
       LIMIT $1`,
      [MAX_SAVED_SEARCHES_PER_BATCH],
    );

    const listings = result.rows;
    let processed = 0;
    let matched = 0;
    let notified = 0;

    for (const listing of listings) {
      processed++;
      const res = await this.matchListingAgainstSavedSearches(listing.listingId as string);
      matched += res.matched;
      notified += res.notified;
    }

    return { processed, matched, notified };
  }

  // -----------------------------------------------------------------------
  // Run a saved search on-demand (user-initiated).
  // Returns matching listings without creating notifications.
  // -----------------------------------------------------------------------
  async runSavedSearch(
    userId: string,
    searchId: string,
    limit: number,
    offset: number,
  ): Promise<{ items: Record<string, unknown>[]; total: number; limit: number; offset: number }> {
    const searchResult = await pool.query(
      `SELECT id, name, criteria, alerts_enabled AS "alertsEnabled",
              alert_frequency AS "alertFrequency"
       FROM saved_searches WHERE id = $1 AND user_id = $2`,
      [searchId, userId],
    );
    const search = searchResult.rows[0];
    if (!search) throw new Error('Saved search not found');

    const criteria = (search.criteria as Record<string, unknown>) ?? {};

    // Build the WHERE clause using the same logic as the search API.
    const values: unknown[] = [userId];
    let bindIdx = 1;
    const bind = (value: unknown) => { values.push(value); return `$${bindIdx++}`; };

    const where: string[] = ["pl.status = 'published'"];
    if (criteria.q) {
      const like = bind(`%${String(criteria.q)}%`);
      where.push(`(pl.title ILIKE ${like} OR pl.description ILIKE ${like} OR p.address ILIKE ${like} OR p.city ILIKE ${like} OR p.county ILIKE ${like})`);
    }
    if (criteria.city) where.push(`p.city ILIKE ${bind(String(criteria.city))}`);
    if (criteria.county) where.push(`p.county ILIKE ${bind(String(criteria.county))}`);
    if (criteria.neighbourhood) where.push(`p.address ILIKE ${bind(String(criteria.neighbourhood))}`);
    if (criteria.propertyType) where.push(`p.property_type = ${bind(String(criteria.propertyType))}`);
    if (criteria.rentMin !== undefined) where.push(`COALESCE(pl.rent_amount, u.rent_amount) >= ${bind(Number(criteria.rentMin))}`);
    if (criteria.rentMax !== undefined) where.push(`COALESCE(pl.rent_amount, u.rent_amount) <= ${bind(Number(criteria.rentMax))}`);
    if (criteria.bedrooms !== undefined) where.push(`u.bedrooms = ${bind(Number(criteria.bedrooms))}`);
    if (criteria.bathrooms !== undefined) where.push(`u.bathrooms >= ${bind(Number(criteria.bathrooms))}`);
    if (criteria.furnished !== undefined) where.push(`pl.furnished = ${bind(String(criteria.furnished) === 'true')}`);
    if (criteria.amenities) {
      for (const amenity of String(criteria.amenities).split(',').map((a) => a.trim()).filter(Boolean)) {
        const key = bind(amenity);
        where.push(`(COALESCE(NULLIF(pl.amenities, '[]'::jsonb), NULLIF(p.amenities, '[]'::jsonb), '[]'::jsonb) ? ${key})`);
      }
    }

    const sort = (criteria.sort as string) ?? 'relevance';
    const orderClause =
      sort === 'price_asc'
        ? 'COALESCE(pl.rent_amount, u.rent_amount) ASC NULLS LAST, pl.published_at DESC NULLS LAST'
        : sort === 'price_desc'
          ? 'COALESCE(pl.rent_amount, u.rent_amount) DESC NULLS LAST, pl.published_at DESC NULLS LAST'
          : 'pl.published_at DESC NULLS LAST, pl.id';

    const limitBind = bind(limit);
    const offsetBind = bind(offset);

    const totalResult = await pool.query(
      `SELECT count(*)::int AS total
       FROM property_listings pl
       JOIN properties p ON p.id = pl.property_id
       LEFT JOIN units u ON u.id = pl.unit_id
       WHERE ${where.join(' AND ')}`,
      values,
    );

    const itemsResult = await pool.query(
      `SELECT pl.id AS "listingId", pl.title, pl.description, p.title AS "propertyTitle",
              p.city, p.county, p.address, p.property_type AS "propertyType",
              COALESCE(pl.rent_amount, u.rent_amount) AS "rentAmount",
              u.bedrooms, u.bathrooms, pl.furnished,
              pl.available_from AS "availableFrom", pl.available_to AS "availableTo",
              COALESCE(NULLIF(pl.amenities, '[]'::jsonb), NULLIF(p.amenities, '[]'::jsonb), '[]'::jsonb) AS amenities,
              COALESCE(NULLIF(pl.images, '[]'::jsonb), p.images, '[]'::jsonb) AS images,
              pl.published_at AS "publishedAt"
       FROM property_listings pl
       JOIN properties p ON p.id = pl.property_id
       LEFT JOIN units u ON u.id = pl.unit_id
       WHERE ${where.join(' AND ')}
       ORDER BY ${orderClause}
       LIMIT ${limitBind} OFFSET ${offsetBind}`,
      values,
    );

    return {
      items: itemsResult.rows,
      total: totalResult.rows[0]?.total ?? 0,
      limit,
      offset,
    };
  }
}

export const searchAlertService = new SearchAlertService();
