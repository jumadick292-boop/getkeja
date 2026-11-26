// Provider reviews repository (Task 13.16).
import { pool } from '../../db/pool.js';
import type { PoolClient } from 'pg';
import type { ProviderReview, ReviewRatingSummary, ReviewStatus } from './reviews.types.js';

function mapReview(row: Record<string, unknown>): ProviderReview {
  return {
    id: row.id as string,
    resourceDomain: row.resourceDomain as string,
    resourceId: row.resourceId as string,
    customerUserId: row.customerUserId as string,
    providerProfileId: row.providerProfileId as string,
    providerOrganisationId: (row.providerOrganisationId as string) ?? null,
    overallRating: row.overallRating as number,
    comment: (row.comment as string) ?? null,
    qualityRating: (row.qualityRating as number) ?? null,
    professionalismRating: (row.professionalismRating as number) ?? null,
    timelinessRating: (row.timelinessRating as number) ?? null,
    valueRating: (row.valueRating as number) ?? null,
    status: row.status as ReviewStatus,
    response: (row.response as string) ?? null,
    responseAt: (row.responseAt as string) ?? null,
    createdAt: row.createdAt as Date,
    updatedAt: row.updatedAt as Date,
  };
}

const SELECT = `
  SELECT r.id, r.resource_domain AS "resourceDomain", r.resource_id AS "resourceId",
         r.customer_user_id AS "customerUserId", r.provider_profile_id AS "providerProfileId",
         r.provider_organisation_id AS "providerOrganisationId", r.overall_rating AS "overallRating",
         r.comment, r.quality_rating AS "qualityRating", r.professionalism_rating AS "professionalismRating",
         r.timeliness_rating AS "timelinessRating", r.value_rating AS "valueRating", r.status::text AS status,
         resp.response, resp.created_at AS "responseAt", r.created_at AS "createdAt", r.updated_at AS "updatedAt"
    FROM provider_reviews r
    LEFT JOIN provider_review_responses resp ON resp.review_id = r.id`;

export async function findById(id: string): Promise<ProviderReview | null> {
  const r = await pool.query(`${SELECT} WHERE r.id = $1`, [id]);
  return r.rows[0] ? mapReview(r.rows[0]) : null;
}

export async function findByResource(domain: string, resourceId: string): Promise<ProviderReview | null> {
  const r = await pool.query(`${SELECT} WHERE r.resource_domain = $1 AND r.resource_id = $2`, [domain, resourceId]);
  return r.rows[0] ? mapReview(r.rows[0]) : null;
}

export async function insertReview(client: PoolClient, row: {
  domain: string; resourceId: string; customerUserId: string; providerProfileId: string;
  providerOrganisationId: string | null; overallRating: number; comment: string | null;
  qualityRating: number | null; professionalismRating: number | null; timelinessRating: number | null; valueRating: number | null;
}): Promise<{ id: string }> {
  const r = await client.query<{ id: string }>(
    `INSERT INTO provider_reviews
       (resource_domain, resource_id, customer_user_id, provider_profile_id, provider_organisation_id,
        overall_rating, comment, quality_rating, professionalism_rating, timeliness_rating, value_rating)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id`,
    [row.domain, row.resourceId, row.customerUserId, row.providerProfileId, row.providerOrganisationId,
      row.overallRating, row.comment, row.qualityRating, row.professionalismRating, row.timelinessRating, row.valueRating],
  );
  return r.rows[0]!;
}

export async function upsertResponse(client: PoolClient, reviewId: string, responderUserId: string, response: string): Promise<void> {
  await client.query(
    `INSERT INTO provider_review_responses (review_id, responder_user_id, response)
     VALUES ($1,$2,$3)
     ON CONFLICT (review_id) DO UPDATE SET response = EXCLUDED.response,
       responder_user_id = EXCLUDED.responder_user_id, updated_at = NOW()`,
    [reviewId, responderUserId, response],
  );
}

export async function listForProvider(profileIds: string[], status: string | undefined, limit: number, offset: number) {
  const where = ['r.provider_profile_id = ANY($1::uuid[])'];
  const params: unknown[] = [profileIds];
  let i = 2;
  if (status) { where.push(`r.status::text = $${i++}`); params.push(status); }
  const clause = `WHERE ${where.join(' AND ')}`;
  const count = await pool.query(`SELECT COUNT(*)::int AS n FROM provider_reviews r ${clause}`, params);
  const rows = await pool.query(`${SELECT} ${clause} ORDER BY r.created_at DESC LIMIT $${i++} OFFSET $${i}`, [...params, limit, offset]);
  return { rows: rows.rows.map((r) => mapReview(r as Record<string, unknown>)), total: count.rows[0].n as number };
}

export async function listForCustomer(customerUserId: string, limit: number, offset: number) {
  const rows = await pool.query(`${SELECT} WHERE r.customer_user_id = $1 ORDER BY r.created_at DESC LIMIT $2 OFFSET $3`, [customerUserId, limit, offset]);
  return rows.rows.map((r) => mapReview(r as Record<string, unknown>));
}

export async function insertReport(client: PoolClient, reviewId: string, reportedBy: string, reason: string, details: string | null): Promise<void> {
  await client.query(
    `INSERT INTO provider_review_reports (review_id, reported_by, reason, details) VALUES ($1,$2,$3,$4)`,
    [reviewId, reportedBy, reason, details],
  );
}

export async function setStatus(client: PoolClient, reviewId: string, status: ReviewStatus, changedBy: string, reason: string | null, previous: ReviewStatus): Promise<void> {
  await client.query(`UPDATE provider_reviews SET status = $2, updated_at = NOW() WHERE id = $1`, [reviewId, status]);
  await client.query(
    `INSERT INTO provider_review_status_history (review_id, previous_status, new_status, changed_by, reason)
     VALUES ($1,$2,$3,$4,$5)`,
    [reviewId, previous, status, changedBy, reason],
  );
}

export async function getRatingSummary(providerProfileId: string): Promise<ReviewRatingSummary> {
  const avg = await pool.query(
    `SELECT AVG(overall_rating)::float AS avg, COUNT(*)::int AS n
       FROM provider_reviews WHERE provider_profile_id = $1 AND status = 'published'`,
    [providerProfileId],
  );
  const dist = await pool.query(
    `SELECT overall_rating AS rating, COUNT(*)::int AS count
       FROM provider_reviews WHERE provider_profile_id = $1 AND status = 'published'
      GROUP BY overall_rating ORDER BY overall_rating`,
    [providerProfileId],
  );
  return {
    providerProfileId,
    averageRating: avg.rows[0].avg == null ? null : Number(avg.rows[0].avg),
    reviewCount: avg.rows[0].n as number,
    distribution: dist.rows as unknown as { rating: number; count: number }[],
  };
}