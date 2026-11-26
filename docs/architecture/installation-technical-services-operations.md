# Installation & Technical Services Operations (Task 13.14)

Shared operational module for the Installation & Technical Services group, built
on the 13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and 13.10
communications. No duplicate marketplace/scheduling/messaging/notification system.

## Categories in scope (exact IDs)
wifi_installation, internet_installation (networking); solar_installation (solar).
3 categories across 2 domains. (roofing/flooring/tiling/painting are Finishing,
Task 13.15; moving/garbage/laundry/home-maintenance/cleaning already Level A.)

## Pre-implementation audit (summary)
- Domains: networking, solar. Capabilities: networking (wifi/internet) and solar
  installation/maintenance from the 13.4 catalogue.
- Existing strict request schemas already present in `marketplace.schemas.ts`
  (`wifiDetailsSchema`, `internetDetailsSchema`, `solarDetailsSchema`) — reused,
  not replaced. They capture property use/type, rooms/coverage, existing
  equipment, job type, power requirements (solar), preferred date, photos.
- Provider offerings/pricing/eligibility: unchanged shared marketplace
  (`providerEligibleDomains`, offering `config`, immutable versioned quotations).
- No prior installation operational records existed (Level C, marketplace-only).
- Appropriate lifecycle: installation visit engine (assessment → plan →
  schedule → install → test/commission → handover → customer confirm).

## Architecture
- Module `server/src/modules/installation-operations/` (types, lifecycle, schemas,
  repository, service, controller, routes). Mounted `/api/v1/installation-operations`.
- Migration 125: `installation_jobs` (unique `service_request_id`), append-only
  `installation_job_history`, `installation_assessments` (customer-visible report
  vs `internal_notes`), `installation_plans`, `installation_equipment`
  (category/serial/proposed-vs-confirmed/install status/customer-visible flag),
  `installation_tests` (commissioning), revocable
  `installation_staff_assignments`, `installation_amendments`,
  `installation_exceptions`, `installation_attachments`;
  `scheduling_domain` enum + `installation`; `provider.installation.*` permissions
  granted to `service_provider`.
- Migration 126: `scheduling_activities.installation_job_id` + updated per-resource
  CHECK (other domains unchanged).

## Accepted quotation → job
`createJobFromQuotation` requires an accepted quotation owned by the provider,
locks the `service_requests` row `FOR UPDATE`, idempotent (returns existing job on
repeat). Emits `installation_job.confirmed` in the same txn. Shared marketplace
acceptance unchanged (no auto-create).

## Lifecycle
`confirmed → (assessment_scheduled → awaiting_assessment →
assessment_in_progress → plan_prepared → awaiting_customer_approval) → scheduled →
assigned → in_progress (→ awaiting_equipment / awaiting_customer_approval) →
testing → awaiting_handover → completed_pending_confirmation → completed`. Stage
skipping allowed (simple install: confirmed → in_progress → testing →
awaiting_handover → completion). Customer confirmation required to reach
`completed`; `cancelled`/`failed` terminal. Matrix in
`installation-operations.lifecycle.ts`.

## Assessment / plans / equipment / testing
Assessments store findings, measurements, site readiness, recommended scope,
safety, customer-visible report and **internal notes** (stripped from customer
responses). Plans hold summary/steps/deliverables. Equipment records are job-level
(category, serial/ID, proposed cost, approval status, install status,
customer-visible flag) — not inventory/warehouse. Tests record commissioning
outcomes, corrective work and customer-visible results. Customer must approve
equipment and amendments; completion requires testing + handover steps.

## Scheduling
Extended `SchedulingDomain`, `loadResource`, repository column map + insert,
schema enum and migration 126 for `installation`. Capacity-conflict EXCLUDE,
reschedule and staff assignment reused. Africa/Nairobi timezone supported.

## Staff & permissions
Owner provider profile manages its own job; non-owner staff must be active assigned
staff AND hold `provider.installation.*`; revoked staff lose access immediately;
org membership alone insufficient.

## Flutter
`Mobile/lib/features/installation_operations/`: datasource, Riverpod state,
customer jobs list + detail (assessment, plan, equipment, test results, equipment/
amendment approval, confirm completion); provider jobs list + detail with REAL
workflows surfaced in-app — record assessment, add plan, add equipment, record
test, upload evidence, assign/revoke staff (dialogs + list), progress, completion.
Routes `/installation-operations/jobs`, `/installation-operations/jobs/:jobId`,
`/installation-operations/provider/jobs`,
`/installation-operations/provider/jobs/:jobId`. EN + SW l10n via `flutter gen-l10n`.

## Communications
Outbox events `installation_job.*` (classified CRITICAL) → existing worker →
localized in-app notifications + deep links; contextual conversation via
`marketplace_request`. No second system.

## Security
Customer ownership, provider owner/assigned authz, revoked staff denial,
cross-provider isolation, property/tenancy FKs, attachment privacy, internal-note
isolation, customer-visible equipment/test gating, immutable quotation snapshot,
validated transitions.

## Exclusions honoured
No finishing modules, payments, inventory/warehouse, fleet/GPS, or duplicate infra;
other operational domains unchanged.