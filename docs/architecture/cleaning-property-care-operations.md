# Cleaning & Property Care Operations (Task 13.13)

Shared operational module for the Cleaning & Property Care group, built on the
13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and 13.10
communications. No duplicate marketplace/scheduling/messaging/notification system.

## Categories in scope (exact IDs)
clean_deep, clean_home, clean_office (cleaning); pest_control_general
(pest_control); gardening, landscaping_general (landscaping). 6 categories across
3 domains. (plumbing/electrical/hvac/appliances/general/carpentry are Home
Maintenance, Task 13.12; painting/roofing/flooring/tiling are Finishing, Task
13.15; wifi/internet/solar are Installation, Task 13.14 — all excluded.)

## Architecture
- Module `server/src/modules/cleaning-operations/` (types, lifecycle, schemas,
  repository, service, controller, routes). Mounted `/api/v1/cleaning-operations`.
- Migration 123: `cleaning_jobs` (unique `service_request_id`), append-only
  `cleaning_job_history`, `cleaning_assessments` (customer-visible report vs
  `internal_notes`), `cleaning_checklists` (items + completion), `cleaning_areas`
  (room/area/outdoor breakdown), `cleaning_materials` (consumables, job-level),
  revocable `cleaning_staff_assignments` (partial unique active),
  `cleaning_amendments`, `cleaning_exceptions`, `cleaning_attachments`;
  `scheduling_domain` enum + `cleaning`; `provider.cleaning.*` permissions granted
  to `service_provider`.
- Migration 124: `scheduling_activities.cleaning_job_id` + updated per-resource
  CHECK (moving/garbage/laundry/home_maintenance behaviour unchanged).
- Category-specific strict request schemas in `marketplace.schemas.ts`
  (cleaningDetailsSchema, pestControlDetailsSchema, landscapingDetailsSchema) with
  `categoryId` cross-check via `detailsSchemaForCategory`.

## Accepted quotation → job
`createJobFromQuotation` requires an accepted quotation owned by the provider,
locks the `service_requests` row `FOR UPDATE`, and is idempotent (returns the
existing job on repeat). Emits `cleaning_job.confirmed` in the same txn. The
shared marketplace acceptance is unchanged (no auto-create).

## Lifecycle
`confirmed → (assessment_scheduled → awaiting_assessment →
assessment_in_progress → awaiting_customer_decision) → scheduled → assigned →
in_progress (→ awaiting_supplies / awaiting_customer_decision) → quality_check →
completed_pending_confirmation → completed`. Stage skipping allowed (e.g. simple
clean: confirmed → in_progress). Customer confirmation required to reach
`completed`; `cancelled`/`failed` terminal. Matrix in
`cleaning-operations.lifecycle.ts`. The single visit engine accommodates cleaning,
pest control and landscaping differences (optional assessment, supplies hold,
additional-scope approval) without separate engines.

## Assessment / checklist / areas / materials / amendments
Assessments store findings, scope assessment, recommended tasks, safety, a
customer-visible report and **internal notes** (stripped from all customer
responses via `toCustomerDetail`). Checklists hold items with per-item done flags
and recomputed completion counts. Areas break down rooms/areas/outdoor work.
Materials (supplied_by, proposed_cost, approval_status) are job-level records.
Amendments preserve the immutable accepted quotation; customer approves/rejects;
price change requires approval.

## Scheduling
Extended `scheduling.service.loadResource` + `SchedulingDomain` + repo + schema +
migration 124 for `cleaning`. Inspections/work appointments use the shared engine
(capacity conflict EXCLUDE, reschedule, staff assignment). No new scheduling system.

## Staff & permissions
Owner provider profile manages its own job; non-owner staff must be active assigned
staff AND hold `provider.cleaning.*`; revoked staff lose access immediately;
org membership alone insufficient.

## Flutter
`Mobile/lib/features/cleaning_operations/`: datasource, Riverpod state, customer
jobs list + detail (assessment report, amendment approve/reject, confirm
completion), provider jobs list + detail (progress, record assessment, checklist
toggle, completion). Routes `/cleaning-operations/jobs`,
`/cleaning-operations/jobs/:jobId`, `/cleaning-operations/provider/jobs`,
`/cleaning-operations/provider/jobs/:jobId`. EN + SW l10n via `flutter gen-l10n`.
Reuses shared scheduling + messaging + inbox.

## Communications
Outbox events `cleaning_job.*` (classified CRITICAL) → existing worker →
localized in-app notifications + deep links; contextual conversation via
`marketplace_request` context. No second system.

## Security
Customer ownership, provider owner/assigned authz, revoked staff denial,
cross-provider isolation, property/tenancy FKs, attachment privacy, internal-note
isolation, immutable quotation snapshot, validated transitions.

## Exclusions honoured
No installation/finishing modules, payments, inventory, fleet/GPS, or duplicate
infra; moving/garbage/laundry/home-maintenance/marketplace/scheduling unchanged.