# Home Maintenance & Repairs Operations (Task 13.12)

Shared operational module for the Home Maintenance & Repairs group, built on the
13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and 13.10
communications. No duplicate marketplace/scheduling/messaging/notification system.

## Categories in scope (exact IDs)
plumbing_emergency, plumbing_general, electrical_general, electrical_wiring,
hvac_service, appliance_repair, handyman, carpentry. (painting/roofing/flooring/
tiling belong to the Finishing group; cleaning/pest/landscaping to Cleaning;
wifi/internet/solar to Installation — all excluded.)

## Architecture
- Module `server/src/modules/home-maintenance/` (types, lifecycle, schemas,
  repository, service, controller, routes). Mounted `/api/v1/home-maintenance`.
- Migration 121: `home_maintenance_jobs` (unique `service_request_id`), append-only
  `home_maintenance_job_history`, `home_maintenance_inspections` (customer-visible
  report vs `internal_notes`), `home_maintenance_work_plans`, `home_maintenance_parts`,
  revocable `home_maintenance_staff_assignments` (partial unique active),
  `home_maintenance_amendments`, `home_maintenance_exceptions`,
  `home_maintenance_attachments`; `scheduling_domain` enum + `home_maintenance`;
  `provider.home_maintenance.*` permissions granted to `service_provider`.
- Migration 122: `scheduling_activities.home_maintenance_job_id` + updated
  per-resource CHECK (moving/garbage/laundry behaviour unchanged).
- Category-specific strict request schemas in `marketplace.schemas.ts`
  (plumbing/electrical/hvac/carpentry/appliance/handyman) with `categoryId`
  cross-check via `detailsSchemaForCategory`.

## Accepted quotation → job
`createJobFromQuotation` requires an accepted quotation owned by the provider,
locks the `service_requests` row `FOR UPDATE`, and is idempotent (returns the
existing job on repeat). Emits `home_maintenance_job.confirmed` in the same txn.
The shared marketplace acceptance is unchanged (no auto-create), preserving
moving/garbage/laundry.

## Lifecycle
`confirmed → (inspection_scheduled → awaiting_inspection → inspection_in_progress
→ awaiting_customer_approval) → work_scheduled → assigned → in_progress
(→ awaiting_parts / awaiting_customer_decision) → quality_check →
completed_pending_confirmation → completed`. Stage skipping allowed (e.g. simple
repair: confirmed → in_progress). Customer confirmation required to reach
`completed`; `cancelled`/`failed` terminal. Matrix in `home-maintenance.lifecycle.ts`.

## Inspection / work plan / parts / amendments
Inspections store findings, diagnosis, recommended work, safety, a
customer-visible report and **internal notes** (stripped from all customer
responses via `toCustomerDetail`). Work plans and parts (supplied_by, proposed_cost,
approval_status) recorded. Amendments preserve the immutable accepted quotation;
customer approves/rejects; price change requires approval.

## Scheduling
Extended `scheduling.service.loadResource` + `SchedulingDomain` + repo + schema for
`home_maintenance`. Inspections/work appointments use the shared engine (capacity
conflict EXCLUDE, reschedule, staff assignment). No new scheduling system.

## Staff & permissions
Owner provider profile manages its own job; non-owner staff must be active assigned
staff AND hold `provider.home_maintenance.*`; revoked staff lose access immediately;
org membership alone insufficient.

## Flutter
`Mobile/lib/features/home_maintenance/`: datasource, Riverpod state, customer
jobs list + detail (inspection report, amendment approve/reject, confirm
completion), provider jobs list + detail (progress, record inspection, complete).
Routes `/home-maintenance/jobs`, `/home-maintenance/jobs/:jobId`,
`/home-maintenance/provider/jobs`, `/home-maintenance/provider/jobs/:jobId`.
EN + SW l10n via `flutter gen-l10n`. Reuses shared scheduling + messaging + inbox.

## Communications
Outbox events `home_maintenance_job.*` (classified CRITICAL) → existing worker →
localized in-app notifications + deep links; contextual conversation via
`marketplace_request` context. No second system.

## Security
Customer ownership, provider owner/assigned authz, revoked staff denial,
cross-provider isolation, property/tenancy FKs, attachment privacy, internal-note
isolation, immutable quotation snapshot, validated transitions.

## Exclusions honoured
No cleaning/installation/finishing modules, payments, inventory, fleet/GPS, or
duplicate infra; moving/garbage/laundry/marketplace/scheduling unchanged.