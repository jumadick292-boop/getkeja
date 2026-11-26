# Task 13.15 — Finishing & Building Services Operations Report

## 1. Exact category IDs implemented (previous → new level)
- roofing: `roofing` — C → A
- flooring: `flooring` — C → A
- tiling: `tiling` — C → A
- painting: `painting`, `painting_decoration` — C → A

5 categories / 4 domains moved from Level C (marketplace-only) to Level A.

## 2. Pre-implementation audit (as required)
- Source of truth: readiness audit (current). Finishing group = roofing,
  flooring, tiling, painting (painting + painting_decoration).
- Domains/capabilities: roofing, flooring, tiling, painting from the 13.4 catalogue.
- Existing strict request schemas: only `painting_decoration` had one. Added
  `roofingDetailsSchema`, `flooringDetailsSchema`, `tilingDetailsSchema`; mapped
  plain `painting` to `paintingDetailsSchema`; registered all in
  `detailsSchemaForCategory` + `anyDetailsSchema`.
- Provider offerings/pricing/eligibility: shared marketplace, unchanged.
- No prior operational records (Level C).
- Lifecycle: shared finishing visit engine (inspection → plan → materials →
  work → quality inspection → handover → customer confirm).

## 3. Domain/category counts
4 domains (roofing, flooring, tiling, painting), 5 categories.

## 4. Database migrations and tables
- **127_finishing_operations**: enum `finishing_operation_status`; tables
  `finishing_jobs` (unique `service_request_id`), `finishing_job_history`,
  `finishing_assessments`, `finishing_plans`, `finishing_materials`,
  `finishing_inspections`, `finishing_staff_assignments`,
  `finishing_amendments`, `finishing_exceptions`, `finishing_attachments`;
  `scheduling_domain` += `finishing`; `provider.finishing.*` permissions.
- **128_scheduling_finishing**: `scheduling_activities.finishing_job_id` +
  rebuilt per-resource CHECK (other domains unchanged).
- Both idempotent; applied via `npm run migrate up`; re-run `No pending migrations`.

## 5. Backend modules and API endpoints
`server/src/modules/finishing-operations/` mounted at
`/api/v1/finishing-operations`. Customer: list/detail, cancel,
confirm-completion, exceptions, amendment decide, material decide. Provider:
create job from quotation, list/detail, progress, fail, cancel, assessments,
plans, materials (+ decide), inspections, attachments, staff assign/revoke,
amendments, completion. `{success,data}`, pagination, resource-scoped authz,
strict Zod. 23 operations across 22 OpenAPI paths.

## 6. Lifecycle and category-specific differences
18-state matrix with stage skipping + customer-confirmation completion; invalid
transitions → 409; append-only history. Single shared engine; per-category strict
request schemas capture roofing/flooring/tiling/painting specifics; materials carry
`finishOrSpec`; quality inspections cover water-ingress/workmanship/handover.
Weather/site interruptions via `exception` + rescheduling.

## 7. Scheduling integration
Extended `SchedulingDomain`, `loadResource`, repository column map + insert,
schema enum and migration 128. Capacity-conflict EXCLUDE, reschedule and staff
assignment reused. Africa/Nairobi timezone supported.

## 8. Permissions and privacy controls
`provider.finishing.{view,view_locations,update_progress,manage_assessments,
manage_plans,manage_schedule,upload_evidence,assign_staff,propose_changes}`.
Owner profile manages own job; non-owner active assigned staff + explicit
permission; revoked staff denied; internal notes stripped; customer-visible gating
on materials/inspections; attachments scoped; immutable quotation snapshot.

## 9. Flutter screens and routes
`Mobile/lib/features/finishing_operations/`: customer jobs list/detail;
provider jobs list/detail with REAL in-app workflows — record assessment, add
plan, add materials, record inspection, upload evidence, assign/revoke staff,
progress, completion. Routes `/finishing-operations/jobs`,
`/finishing-operations/jobs/:jobId`,
`/finishing-operations/provider/jobs`,
`/finishing-operations/provider/jobs/:jobId`. EN + SW l10n. Reuses shared
design system + API client + scheduling/messaging.

## 10. Communications and notifications
`finishing_job.*` outbox events (CRITICAL) via existing worker; localized
in-app + deep links; contextual conversation via marketplace_request. No second
system.

## 11. Tests, commands, counts, results
- `NODE_OPTIONS=--max-old-space-size=4096 npx tsc --noEmit` (server): exit 0.
- `vitest run src/modules/finishing-operations`: **8/8**.
- `flutter analyze` (finishing feature + router): **0 errors** (only repo-wide
  info lints, incl. pre-existing `material.dart` deprecation pattern).
- `flutter test test/features/finishing_operations/finishing_operations_test.dart`:
  **3/3**.
- Migrations: applied 127 + 128, re-run `No pending migrations` (idempotent).
- OpenAPI: parses; 296 paths; 22 finishing paths (23 operations); no new
  unresolved refs.

## 12. Known limitations and deferred work
- Requires Postgres (btree_gist) + pg-boss worker enabled.
- Evidence upload UI captures a document ID (shared document/attachment service
  reused); binary upload/download is the existing shared flow.
- No automatic weather monitoring / continuous location tracking (explicitly out
  of scope); interruptions are provider-reported.

## 13. Updated totals
**A = 53** (18 domains — all 18 service domains now Level A), **B = 0**,
**C = 0**, **D = 0**. (13.14 baseline A=48/C=7; +5 C→A. Finishing was the final
category-operations group; the full provider-category readiness audit is now all
Level A.)