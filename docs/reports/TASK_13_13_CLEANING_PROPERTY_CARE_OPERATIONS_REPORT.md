# Task 13.13 — Cleaning & Property Care Operations Report

## 1. Exact category IDs implemented (previous → new level)
- cleaning: `clean_deep`, `clean_home`, `clean_office` — C → A
- pest_control: `pest_control_general` — C → A
- landscaping: `gardening`, `landscaping_general` — C → A

6 categories / 3 domains moved from Level C (marketplace-only) to Level A (full
operational lifecycle). No categories invented or omitted; Installation (13.14)
and Finishing (13.15) groups untouched.

## 2. Database migrations and tables
- **123_cleaning_operations**: enum `cleaning_operation_status`; tables
  `cleaning_jobs` (unique `service_request_id`), `cleaning_job_history`,
  `cleaning_assessments`, `cleaning_checklists`, `cleaning_areas`,
  `cleaning_materials`, `cleaning_staff_assignments`, `cleaning_amendments`,
  `cleaning_exceptions`, `cleaning_attachments`; `scheduling_domain` += `cleaning`;
  `provider.cleaning.*` permissions granted to `service_provider`.
- **124_scheduling_cleaning**: `scheduling_activities.cleaning_job_id` + rebuilt
  per-resource CHECK (other domains unchanged).
- Both idempotent; `Pending: 0` after apply + re-run.

## 3. Backend modules and endpoints
`server/src/modules/cleaning-operations/` mounted at `/api/v1/cleaning-operations`.
Customer: list/detail jobs, cancel, confirm-completion, exceptions, amendment
decide, material decide. Provider: create job from quotation, list/detail,
progress, fail, cancel, assessments, checklists (+ item toggle), areas, materials
(+ decide), attachments, staff assign/revoke, amendments, completion. `{success,data}`,
pagination, resource-scoped authz, strict Zod.

## 4. Lifecycle and transition rules
15-state matrix with stage skipping + customer-confirmation completion; invalid
transitions → 409; append-only history. Terminal: completed/cancelled/failed.
Single shared visit engine for cleaning/pest/landscaping.

## 5. Scheduling integration
Extended `SchedulingDomain`, `loadResource`, repository column map + insert,
schema enum and migration 124. Capacity-conflict EXCLUDE, reschedule and staff
assignment reused. Africa/Nairobi timezone supported.

## 6. Permissions and privacy protections
`provider.cleaning.{view,view_locations,update_progress,manage_assessments,
manage_schedule,upload_evidence,assign_staff,propose_changes}`. Owner profile
manages own job; non-owner active assigned staff + explicit permission; revoked
staff denied; internal notes stripped from customer responses; attachments scoped;
immutable quotation snapshot.

## 7. Flutter screens and routes
`Mobile/lib/features/cleaning_operations/`: customer jobs list/detail, provider
jobs list/detail (progress, assessment, checklist toggle, completion). Routes
`/cleaning-operations/jobs`, `/cleaning-operations/jobs/:jobId`,
`/cleaning-operations/provider/jobs`, `/cleaning-operations/provider/jobs/:jobId`.
EN + SW l10n. Reuses shared design system + API client + scheduling/messaging.

## 8. Communications and notifications
`cleaning_job.*` outbox events (CRITICAL) via existing worker; localized in-app +
deep links; contextual conversation via marketplace_request. No second system.

## 9. Tests, commands, counts, results
- `npx tsc --noEmit` (server): exit 0.
- `npx vitest run src/modules/cleaning-operations`: **8/8**.
- Full regression `npx vitest run --no-file-parallelism` over cleaning-operations,
  home-maintenance, scheduling, moving, garbage, laundry, marketplace,
  provider-catalogue, messaging: **94/94** (10 files).
- `flutter analyze`: **0 errors**.
- `flutter test test/features/cleaning_operations/cleaning_operations_test.dart`:
  **3/3**.
- Migrations: applied 123 + 124, re-run `No pending migrations` (idempotent).

## 10. Known limitations and deferred work
- Provider-side Flutter screens for staff assignment, materials and evidence
  upload are backend-complete/tested but not yet surfaced as dedicated Flutter
  screens (limitation, not fully delivered on the client).
- Requires Postgres (btree_gist) + pg-boss worker enabled.
- Installation (13.14) and Finishing (13.15) groups remain Level C.

## 11. Updated totals
**A = 45** (12 domains: moving, garbage, laundry, home-maintenance 6 domains,
cleaning 3 domains), **B = 0**, **C = 10** (roofing, flooring, tiling, painting×2,
networking×2, solar — 6 domains), **D = 0**. (13.11 baseline A=39/C=16; +6 C→A.)