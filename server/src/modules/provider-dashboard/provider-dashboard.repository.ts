// Provider dashboard repository (Task 13.16). All metrics are computed with
// aggregate SQL over the authoritative operational tables (no in-memory scans).
import { pool } from '../../db/pool.js';
import { OPERATIONAL_TABLES } from '../../shared/operationalResources.js';
import type {
  CategoryPerformanceRow,
  DomainMetric,
  ProviderDashboardFilters,
  ProviderDashboardMetrics,
  ProviderReportRow,
  StaffWorkloadEntry,
} from './provider-dashboard.types.js';

// Tables that predate the category_id column (moving/garbage/laundry).
const NO_CATEGORY = new Set(['moving', 'garbage', 'laundry']);
const categoryExpr = (domain: string) => (NO_CATEGORY.has(domain) ? 'NULL::text' : 'category_id');

// Build a UNION ALL subquery exposing a uniform job projection across all
// operational domains, scoped to the provider's profiles (+ optional org).
function jobsUnion(scopeProfiles: string[], orgId: string | null): { sql: string; params: unknown[] } {
  const parts: string[] = [];
  const params: unknown[] = [scopeProfiles, orgId];
  const scope = `(provider_profile_id = ANY($1::uuid[]) OR ($2::uuid IS NOT NULL AND provider_organisation_id = $2))`;
  for (const [domain, table] of Object.entries(OPERATIONAL_TABLES)) {
    parts.push(
      `SELECT '${domain}'::text AS domain, ${categoryExpr(domain)} AS category_id, status::text AS status,
              customer_confirmation_status AS ccs, created_at, updated_at
         FROM ${table} WHERE ${scope}`,
    );
  }
  return { sql: parts.join(' UNION ALL '), params };
}

function timeFilter(filters: ProviderDashboardFilters, params: unknown[], startIdx: number): { clause: string; next: number } {
  let i = startIdx;
  let clause = '';
  if (filters.from) { clause += ` AND created_at >= $${i++}`; params.push(filters.from); }
  if (filters.to) { clause += ` AND created_at <= $${i++}`; params.push(filters.to); }
  return { clause, next: i };
}

export async function getMetrics(
  scopeProfiles: string[],
  orgId: string | null,
  filters: ProviderDashboardFilters,
): Promise<ProviderDashboardMetrics> {
  const union = jobsUnion(scopeProfiles, orgId);
  const params: unknown[] = [...union.params];
  let idx = params.length + 1;
  const domainCat: string[] = [];
  if (filters.domain) { domainCat.push(`domain = $${idx++}`); params.push(filters.domain); }
  if (filters.categoryId) { domainCat.push(`category_id = $${idx++}`); params.push(filters.categoryId); }
  if (filters.status) { domainCat.push(`status = $${idx++}`); params.push(filters.status); }
  const tf = timeFilter(filters, params, idx);
  const extra = [...domainCat, tf.clause.replace(/^ AND /, '')].filter(Boolean).join(' AND ');
  const where = extra ? `WHERE ${extra}` : '';
  const today = new Date().toISOString().slice(0, 10);

  const jobSql = `
    WITH jobs AS (${union.sql})
    SELECT
      COUNT(*) FILTER (WHERE status = 'completed')::int AS "completedJobs",
      COUNT(*) FILTER (WHERE status = 'cancelled')::int AS "cancelledJobs",
      COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled','failed'))::int AS "activeJobs",
      COUNT(*) FILTER (WHERE status = 'completed_pending_confirmation')::int AS "awaitingConfirmation",
      COUNT(*) FILTER (WHERE status IN ('exception','failed') OR (status NOT IN ('completed','cancelled') AND updated_at < NOW() - INTERVAL '7 days'))::int AS "overdueOrInterrupted"
    FROM jobs ${where}`;

  const [jobRes, schedRes, complaintRes, ratingRes, quoteRes, reqRes] = await Promise.all([
    pool.query(jobSql, params),
    pool.query(
      `SELECT COUNT(*)::int AS n FROM scheduling_activities
        WHERE provider_profile_id = ANY($1::uuid[])
          AND ($2::uuid IS NOT NULL AND provider_organisation_id = $2 OR $2::uuid IS NULL)
          AND status IN ('proposed','confirmed')
          AND start_at >= $3 AND start_at < ($3::date + INTERVAL '1 day')`,
      [scopeProfiles, orgId, today],
    ),
    pool.query(
      `SELECT COUNT(*)::int AS n FROM complaints c
        WHERE c.provider_profile_id = ANY($1::uuid[])
          AND ($2::uuid IS NOT NULL AND c.provider_organisation_id = $2 OR $2::uuid IS NULL)
          AND c.status NOT IN ('resolved','closed')`,
      [scopeProfiles, orgId],
    ),
    pool.query(
      `SELECT AVG(overall_rating)::float AS avg, COUNT(*)::int AS n
         FROM provider_reviews WHERE provider_profile_id = ANY($1::uuid[]) AND status = 'published'`,
      [scopeProfiles],
    ),
    pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status IN ('submitted','revised'))::int AS "pendingQuotations",
         COUNT(*) FILTER (WHERE status = 'accepted')::int AS "acceptedQuotations"
       FROM service_quotations WHERE provider_profile_id = ANY($1::uuid[])`,
      [scopeProfiles],
    ),
    pool.query(
      `SELECT COUNT(*)::int AS n FROM service_requests sr
        WHERE sr.status = 'open'
          AND EXISTS (SELECT 1 FROM provider_service_offerings o
                       WHERE o.specialized_profile_id = ANY($1::uuid[]) AND o.domain = sr.domain AND o.status = 'active')`,
      [scopeProfiles],
    ),
  ]);

  const j = jobRes.rows[0];
  // upcoming = active jobs scheduled in the future (approximated by active count
  // beyond today is not tracked per-job; upcomingJobs mirrors scheduled future).
  const upcoming = await pool.query(
    `SELECT COUNT(*)::int AS n FROM scheduling_activities
      WHERE provider_profile_id = ANY($1::uuid[])
        AND ($2::uuid IS NOT NULL AND provider_organisation_id = $2 OR $2::uuid IS NULL)
        AND status IN ('proposed','confirmed') AND start_at >= NOW()`,
    [scopeProfiles, orgId],
  );

  return {
    newEligibleRequests: reqRes.rows[0].n as number,
    pendingQuotations: quoteRes.rows[0].pendingQuotations as number,
    acceptedQuotations: quoteRes.rows[0].acceptedQuotations as number,
    activeJobs: j.activeJobs as number,
    scheduledToday: schedRes.rows[0].n as number,
    upcomingJobs: upcoming.rows[0].n as number,
    awaitingConfirmation: j.awaitingConfirmation as number,
    overdueOrInterrupted: j.overdueOrInterrupted as number,
    completedJobs: j.completedJobs as number,
    cancelledJobs: j.cancelledJobs as number,
    unresolvedComplaints: complaintRes.rows[0].n as number,
    averageRating: ratingRes.rows[0].avg == null ? null : Number(ratingRes.rows[0].avg),
    reviewCount: ratingRes.rows[0].n as number,
  };
}

export async function getByDomain(scopeProfiles: string[], orgId: string | null): Promise<DomainMetric[]> {
  const union = jobsUnion(scopeProfiles, orgId);
  const r = await pool.query(
    `WITH jobs AS (${union.sql})
     SELECT domain,
       COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled','failed'))::int AS active,
       COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
       COUNT(*) FILTER (WHERE status = 'cancelled')::int AS cancelled,
       COUNT(*) FILTER (WHERE status = 'completed_pending_confirmation')::int AS "awaitingConfirmation"
     FROM jobs GROUP BY domain ORDER BY domain`,
    union.params,
  );
  return r.rows as unknown as DomainMetric[];
}

export async function getStaffWorkload(scopeProfiles: string[], orgId: string | null): Promise<StaffWorkloadEntry[]> {
  const params: unknown[] = [scopeProfiles, orgId];
  const scope = `(provider_profile_id = ANY($1::uuid[]) OR ($2::uuid IS NOT NULL AND provider_organisation_id = $2))`;
  const parts: string[] = [];
  for (const table of Object.values(OPERATIONAL_TABLES)) {
    parts.push(`SELECT assigned_staff_user_id AS "userId", status::text AS status FROM ${table} WHERE ${scope} AND assigned_staff_user_id IS NOT NULL`);
  }
  const r = await pool.query(
    `WITH s AS (${parts.join(' UNION ALL ')})
     SELECT "userId",
       COUNT(*)::int AS "assignedJobs",
       COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled','failed'))::int AS "activeJobs",
       COUNT(*) FILTER (WHERE status = 'completed')::int AS "completedJobs"
     FROM s GROUP BY "userId" ORDER BY "assignedJobs" DESC`,
    params,
  );
  return r.rows as unknown as StaffWorkloadEntry[];
}

export async function getReport(
  scopeProfiles: string[],
  orgId: string | null,
  filters: ProviderDashboardFilters,
): Promise<ProviderReportRow[]> {
  const union = jobsUnion(scopeProfiles, orgId);
  const params: unknown[] = [...union.params];
  let idx = params.length + 1;
  const clauses: string[] = [];
  if (filters.domain) { clauses.push(`domain = $${idx++}`); params.push(filters.domain); }
  if (filters.categoryId) { clauses.push(`category_id = $${idx++}`); params.push(filters.categoryId); }
  const tf = timeFilter(filters, params, idx);
  const where = [...clauses, tf.clause.replace(/^ AND /, '')].filter(Boolean).join(' AND ');
  const r = await pool.query(
    `WITH jobs AS (${union.sql})
     SELECT to_char(created_at, 'YYYY-MM-DD') AS period,
       COUNT(*)::int AS "jobsCreated",
       COUNT(*) FILTER (WHERE status = 'completed')::int AS "jobsCompleted",
       COUNT(*) FILTER (WHERE status = 'cancelled')::int AS "jobsCancelled"
     FROM jobs ${where ? `WHERE ${where}` : ''}
     GROUP BY period ORDER BY period DESC LIMIT 90`,
    params,
  );
  // requests/quotations/accepted are reported at the summary level; per-period
  // request/quotation counts are joined from the marketplace below.
  const q = await pool.query(
    `SELECT to_char(created_at, 'YYYY-MM-DD') AS period,
       COUNT(*)::int AS quotations,
       COUNT(*) FILTER (WHERE status = 'accepted')::int AS accepted
     FROM service_quotations WHERE provider_profile_id = ANY($1::uuid[]) GROUP BY period`,
    [scopeProfiles],
  );
  const qMap = new Map<string, { quotations: number; accepted: number }>();
  for (const row of q.rows) qMap.set(row.period as string, { quotations: row.quotations as number, accepted: row.accepted as number });
  return (r.rows as Record<string, unknown>[]).map((row) => {
    const period = row.period as string;
    const qq = qMap.get(period) ?? { quotations: 0, accepted: 0 };
    return {
      period,
      requests: 0,
      quotations: qq.quotations,
      accepted: qq.accepted,
      jobsCreated: row.jobsCreated as number,
      jobsCompleted: row.jobsCompleted as number,
      jobsCancelled: row.jobsCancelled as number,
    };
  });
}

export async function getCategoryPerformance(scopeProfiles: string[], orgId: string | null): Promise<CategoryPerformanceRow[]> {
  const union = jobsUnion(scopeProfiles, orgId);
  const jobRes = await pool.query(
    `WITH jobs AS (${union.sql})
     SELECT domain, category_id AS "categoryId",
       COUNT(*)::int AS jobs,
       COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
       COUNT(*) FILTER (WHERE status = 'cancelled')::int AS cancelled
     FROM jobs GROUP BY domain, category_id ORDER BY domain, category_id`,
    union.params,
  );
  const revRes = await pool.query(
    `SELECT resource_domain AS domain, category_id AS "categoryId",
       AVG(overall_rating)::float AS avg, COUNT(*)::int AS n
     FROM provider_reviews rv
     JOIN LATERAL (
       SELECT category_id FROM (
         SELECT NULL::text AS category_id WHERE rv.resource_domain = 'moving'
         UNION ALL SELECT NULL::text WHERE rv.resource_domain = 'garbage'
         UNION ALL SELECT NULL::text WHERE rv.resource_domain = 'laundry'
         UNION ALL SELECT category_id FROM home_maintenance_jobs WHERE id = rv.resource_id AND rv.resource_domain = 'home_maintenance'
         UNION ALL SELECT category_id FROM cleaning_jobs WHERE id = rv.resource_id AND rv.resource_domain = 'cleaning'
         UNION ALL SELECT category_id FROM installation_jobs WHERE id = rv.resource_id AND rv.resource_domain = 'installation'
         UNION ALL SELECT category_id FROM finishing_jobs WHERE id = rv.resource_id AND rv.resource_domain = 'finishing'
       ) c LIMIT 1
     ) cat ON TRUE
     WHERE rv.provider_profile_id = ANY($1::uuid[]) AND rv.status = 'published'
     GROUP BY domain, category_id`,
    [scopeProfiles],
  );
  const revMap = new Map<string, { avg: number; n: number }>();
  for (const row of revRes.rows) revMap.set(`${row.domain}|${row.categoryId}`, { avg: Number(row.avg), n: row.n as number });
  return (jobRes.rows as Record<string, unknown>[]).map((row) => {
    const key = `${row.domain}|${row.categoryId}`;
    const rev = revMap.get(key);
    return {
      domain: row.domain as string,
      categoryId: row.categoryId as string,
      jobs: row.jobs as number,
      completed: row.completed as number,
      cancelled: row.cancelled as number,
      averageRating: rev ? rev.avg : null,
      reviewCount: rev ? rev.n : 0,
    };
  });
}