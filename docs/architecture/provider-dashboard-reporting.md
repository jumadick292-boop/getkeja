# Provider Dashboard & Reporting

Task 13.16. Read-only operational dashboards and reporting for service
providers, scoped to the caller's resolved provider context.

## Purpose
Give providers a single operational surface across all seven job domains
(moving, garbage, laundry, home maintenance, cleaning, installation, finishing)
without duplicating job tables or introducing financial flows.

## Provider context & authorization
- `resolveProviderContext(userId, orgId)` returns a `ProviderContext` with
  `effectiveProfileIds`, `activeOrganizationId`, and `isProvider`.
- Organization scoping uses the `x-organization-id` header; the active org is
  resolved server-side, never trusted from the client body.
- Every query is filtered by the caller's effective provider profile IDs and
  active organization. Authorization uses `authz.hasPermission` and
  `authz.getUserOrganizationRoleIds`.
- Required permission: `provider.dashboard.read` for the dashboard;
  `provider.reports.view` / `provider.reports.view_org` for reporting.

## Cross-domain resource resolution
All domains share `server/src/shared/operationalResources.ts`:
- `OPERATIONAL_TABLES` enumerates the seven job tables.
- `loadOperationalResource(domain, id)` loads a row regardless of domain.
- `isReviewEligible(row)` is true only when `status = 'completed'` and
  `customer_confirmation_status = 'confirmed'`.
- Tables without `category_id` (moving, garbage, laundry) use `NULL::text`
  via `NO_CATEGORY` / `categoryExpr()`.

## Endpoints
Mounted in `server/src/app.ts`:
- `/api/v1/provider/dashboard` — overview metrics, by-domain breakdown.
- `/api/v1/provider/reports` — operational time-series + service performance.

Both routers are mounted **before** the legacy `/api/v1/provider` router so the
new operational surface takes precedence.

## Dashboard payload
- `overview`: active, completed, averageRating (published reviews only).
- `byDomain`: per-domain active/completed counts.
- Quick links surface the filtered drill-downs (active, scheduled today,
  awaiting confirmation, new eligible requests, pending quotations,
  overdue/interrupted, unresolved complaints).

## Reporting payload
- Operational report rows: `period`, `jobsCreated`, `jobsCompleted`,
  `jobsCancelled`, `quotations`, `accepted`.
- Service performance rows: `domain`, `categoryId`, `completed`, `cancelled`,
  `averageRating`.

## Flutter surface
`Mobile/lib/features/provider_platform/`:
- `data/datasources/provider_platform_remote_datasource.dart` — Dio datasource
  with a 401/403/404/409 error mapper.
- `presentation/state/provider_platform_state.dart` — Riverpod providers.
- `presentation/pages/provider_dashboard_page.dart`,
  `provider_reports_page.dart`, `staff_workload_page.dart`.

Routes are registered in `Mobile/lib/app/router/app_router.dart`
(`/provider/dashboard`, `/provider/reports`, `/provider/staff-workload`).