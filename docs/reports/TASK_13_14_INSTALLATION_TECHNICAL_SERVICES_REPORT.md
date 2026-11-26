# Task 13.14 — Installation & Technical Services Operations Report

## 1. Exact category IDs implemented (previous → new level)
- networking: `wifi_installation`, `internet_installation` — C → A
- solar: `solar_installation` — C → A

3 categories / 2 domains moved from Level C (marketplace-only) to Level A. No
categories invented or omitted; Finishing group (Task 13.15) untouched.

## 2. Pre-implementation audit (as required)
- Source of truth: readiness audit (current). Installation group = networking
  (wifi_installation, internet_installation) + solar (solar_installation).
- Domains/capabilities: networking + solar from the 13.4 catalogue.
- Existing strict request schemas reused (`wifiDetailsSchema`,
  `internetDetailsSchema`, `solarDetailsSchema`) — not replaced.
- Provider offerings/pricing/eligibility: shared marketplace, unchanged.
- No prior operational records (Level C).
- Lifecycle: shared installation visit engine (assessment → plan → schedule →
  install → test/commission → handover → customer confirm).

## 3. Domain/category counts
2 domains (networking, solar), 3 categories.

## 4. Database migrations and tables
- **125_installation_operations**: enum `installation_operation_status`; tables
  `installation_jobs` (unique `service_request_id`), `installation_job_history`,
  `installation_assessments`, `installation_plans`, `installation_equipment`,
  `installation_tests`, `installation_staff_assignments`,
  `installation_amendments`, `installation_exceptions`, `installation_attachments`;
  `scheduling_domain` += `installation`; `provider.installation.*` permissions.
- **126_scheduling_installation**: `scheduling_activities.installation_job_id` +
  rebuilt per-resource CHECK (other domains unchanged).
- Both idempotent; `Pending: 0` after apply + re-run.

## 5. Backend modules and API endpoints
`server/src/modules/installation-operations/` mounted at
`/api/v1/installation-operations`. Customer: list/detail, cancel,
confirm-completion, exceptions, amendment decide, equipment decide. Provider:
create job from quotation, list/detail, progress, fail, cancel, assessments,
plans, equipment (+ decide), tests, attachments, staff assign/revoke, amendments,
completion. `{success,data}`, pagination, resource-scoped authz, strict Zod.

## 6. Lifecycle and category-specific differences
17-state matrix with stage skipping + customer-confirmation completion; invalid
transitions → 409; append-only history. Single shared engine; solar adds power
requirements, wifi/internet add coverage/existing-equipment fields (via existing
strict request schemas). Testing/commissioning + handover required before
completion.

## 7. Scheduling integration
Extended `SchedulingDomain`, `loadResource`, repository column map + insert,
schema enum and migration 126. Capacity-conflict EXCLUDE, reschedule and staff
assignment reused. Africa/Nairobi timezone supported.

## 8. Permissions and privacy controls
`provider.installation.{view,view_locations,update_progress,manage_assessments,
manage_plans,manage_schedule,upload_evidence,assign_staff,propose_changes}`.
Owner profile manages own job; non-owner active assigned staff + explicit
permission; revoked staff denied; internal notes stripped; customer-visible gating
on equipment/test records; attachments scoped; immutable quotation snapshot.

## 9. Flutter screens and routes
`Mobile/lib/features/installation_operations/`: customer jobs list/detail;
provider jobs list/detail with REAL in-app workflows — record assessment, add
plan, add equipment, record test, upload evidence, assign/revoke staff, progress,
completion. Routes `/installation-operations/jobs`,
`/installation-operations/jobs/:jobId`,
`/installation-operations/provider/jobs`,
`/installation-operations/provider/jobs/:jobId`. EN + SW l10n. Reuses shared
design system + API client + scheduling/messaging.

## 10. Communications and notifications
`installation_job.*` outbox events (CRITICAL) via existing worker; localized
in-app + deep links; contextual conversation via marketplace_request. No second
system.

## 11. Tests, commands, counts, results
- `npx tsc --noEmit` (server): exit 0.
- `vitest run src/modules/installation-operations`: **8/8**.
- Full regression `npx vitest run --no-file-parallelism` over installation,
  cleaning, home-maintenance, scheduling, moving, garbage, laundry, marketplace,
  provider-catalogue, messaging: **102/102** (11 files).
- `flutter analyze`: **0 errors**.
- `flutter test test/features/installation_operations/installation_operations_test.dart`:
  **3/3**.
- Migrations: applied 125 + 126, re-run `No pending migrations` (idempotent).
- OpenAPI: parses; +18 installation paths; no new unresolved refs (pre-existing
  payments refs remain).

## 12. Known limitations and deferred work
- Requires Postgres (btree_gist) + pg-boss worker enabled.
- Evidence upload UI captures a document ID (the shared document/attachment
  service is reused); binary upload/download flow is the existing shared one.
- Finishing & Building Services (roofing, flooring, tiling, painting) remain
  Level C for Task 13.15.

## 13. Updated totals
**A = 48** (14 domains: +networking, +solar), **B = 0**, **C = 7** (roofing,
flooring, tiling, painting×2 — 4 domains, Finishing group), **D = 0**. (13.13
baseline A=45/C=10; +3 C→A.)