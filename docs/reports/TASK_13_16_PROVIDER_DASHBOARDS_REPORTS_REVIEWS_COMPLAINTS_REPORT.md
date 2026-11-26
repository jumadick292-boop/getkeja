# Task 13.16 — Provider Dashboards, Reporting, Reviews & Complaints Report

## 1. Scope delivered
- Unified provider dashboard across seven job domains.
- Operational + service-performance reporting.
- Verified provider reviews with provider responses and moderation.
- Complaint lifecycle shared by customer, provider, and admin, with
  admin-only internal notes.

## 2. Migrations (idempotent)
- **129_provider_reviews**: enum `review_status`; `provider_reviews`
  (unique `(resource_domain, resource_id)`), `provider_review_responses`,
  `provider_review_reports`, `provider_review_status_history`; permissions
  `provider.reports.view`, `provider.reports.view_org`,
  `provider.reviews.view`, `provider.reviews.respond`, `review.moderate`.
- **130_provider_complaints**: enum `complaint_status`; `complaint_reasons`
  (8 seeded), `complaints`, `complaint_messages`,
  `complaint_corrective_actions`, `complaint_internal_notes`,
  `complaint_status_history`; permissions `provider.complaints.view`,
  `provider.complaints.respond`, `complaint.manage`.
- Applied via `npm run migrate up`; re-run reports `No pending migrations`.
- Permissions inserted with `ON CONFLICT DO NOTHING` (UNIQUE `id` and `name`).

## 3. Backend modules
- `server/src/modules/provider-dashboard/` — types, repository, service,
  controller, routes (`/api/v1/provider/dashboard`).
- `server/src/modules/provider-reporting/` — service, controller, routes
  (`/api/v1/provider/reports`).
- `server/src/modules/reviews/` — types, schemas, repository, service,
  controller, routes (`/api/v1/reviews`).
- `server/src/modules/complaints/` — types, lifecycle, schemas, repository,
  service, controller, routes (`/api/v1/complaints`).
- Mounted in `server/src/app.ts`; dashboard + reports mounted **before** the
  legacy `/api/v1/provider` router.
- Shared cross-domain resolver `server/src/shared/operationalResources.ts`.

## 4. API surface
24 new OpenAPI paths (openapi.yaml parses OK; 319 total paths). Responses use
`{success, data}`, pagination, resource-scoped authz, strict Zod validation.

## 5. Lifecycle & eligibility guarantees
- Reviews eligible only for completed + customer-confirmed jobs; one per job;
  ratings from published reviews only.
- Complaints never alter job completion and never move money.
- Only `closed` is terminal; illegal/terminal transitions → 409 ConflictError.
- Internal notes are admin-only and never returned to customers/providers.

## 6. Flutter
`Mobile/lib/features/provider_platform/`:
- Datasource (Dio + 401/403/404/409 mapper), Riverpod state.
- Pages: dashboard, reports, provider reviews, customer reviews, customer
  complaints, provider complaints, admin complaints, complaint detail,
  staff workload.
- Routes added in `app_router.dart`; 50 l10n keys added to `app_en.arb` and
  `app_sw.arb`; l10n regenerated.

## 7. Verification
- Server `tsc --noEmit`: clean (TSC_EXIT=0).
- Backend vitest `provider-platform.test.ts`: 6/6 passing.
- Flutter `flutter analyze`: 0 errors (only pre-existing infos/warnings).
- Flutter `flutter test test/features/provider_platform`: 7/7 passing.
- Migrations status: latest applied 130; re-run = no pending.
- openapi.yaml parses; 319 paths.

## 8. Non-goals / invariants preserved
- No duplicate job tables; no financial flows introduced.
- Additive and idempotent only; prior Task 13.14 behavior unchanged.