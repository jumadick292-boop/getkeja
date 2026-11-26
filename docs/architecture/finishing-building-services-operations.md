# Finishing & Building Services Operations (Task 13.15)

Shared operational module for the Finishing & Building Services group, built on
the 13.5 marketplace, 13.4 provider catalogue, 13.9 scheduling and 13.10
communications. No duplicate marketplace/scheduling/messaging/notification system.

## Categories in scope (exact IDs)
roofing (domain roofing); flooring (domain flooring); tiling (domain tiling);
painting + painting_decoration (domain painting). 5 categories / 4 domains.
Home Maintenance, Cleaning and Installation groups are already Level A (13.12–13.14).

## Pre-implementation audit (summary)
- Finishing group = roofing, flooring, tiling, painting, painting_decoration
  (readiness audit §3 Level C list; live catalogue 55 categories / 18 domains).
- Domains/capabilities: roofing, flooring, tiling, painting from the 13.4 catalogue.
- Existing strict request schemas: only `painting_decoration` had one
  (`paintingDetailsSchema`). Added strict `roofingDetailsSchema`,
  `flooringDetailsSchema`, `tilingDetailsSchema`, and mapped plain `painting` to
  `paintingDetailsSchema` in `marketplace.schemas.ts` (registered in
  `detailsSchemaForCategory` + `anyDetailsSchema`).
- Provider offerings/pricing/eligibility: shared marketplace, unchanged.
- No prior finishing operational records existed (Level C, marketplace-only).
- Lifecycle: shared finishing visit engine (inspection/measurement → plan →
  materials/finish → work → quality inspection → handover → customer confirm).

## Architecture
- Module `server/src/modules/finishing-operations/` (types, lifecycle, schemas,
  repository, service, controller, routes). Mounted `/api/v1/finishing-operations`.
- Migration 127: `finishing_jobs` (unique `service_request_id`), append-only
  `finishing_job_history`, `finishing_assessments` (customer-visible report vs
  `internal_notes`), `finishing_plans`, `finishing_materials` (category/quantity/
  finish-or-spec/proposed-vs-confirmed/applied status/customer-visible flag),
  `finishing_inspections` (quality + corrective work), revocable
  `finishing_staff_assignments`, `finishing_amendments`, `finishing_exceptions`,
  `finishing_attachments`; `scheduling_domain` enum + `finishing`;
  9 `provider.finishing.*` perms + role_permissions.
- Migration 128: `scheduling_activities.finishing_job_id` + updated per-resource
  CHECK (other domains unchanged).

## Accepted quotation → job
`createJobFromQuotation` requires an accepted quotation owned by the provider,
locks the `service_requests` row `FOR UPDATE`, idempotent (returns existing job on
repeat). Emits `finishing_job.confirmed` in the same txn. Shared marketplace
acceptance unchanged (no auto-create).

## Lifecycle
`confirmed → (assessment_scheduled → awaiting_assessment →
assessment_in_progress → plan_prepared → awaiting_customer_approval) → scheduled →
assigned → materials_prepared → in_progress (→ awaiting_materials / awaiting_customer_approval)
→ quality_inspection → awaiting_handover → completed_pending_confirmation →
completed`. Stage skipping allowed (simple job: confirmed → in_progress →
quality_inspection → awaiting_handover → completion). Customer confirmation
required to reach `completed`; `cancelled`/`failed` terminal. Weather/site
interruptions modelled via `exception` status + rescheduling (no auto weather
monitoring). Matrix in `finishing-operations.lifecycle.ts`.

## Category-specific differences
Single shared engine; the strict per-category request schemas capture the actual
work requirements: roofing (roof type, material, area, affected sections, damage),
flooring (floor type, existing surface, area/rooms, proposed material/finish,
surface prep), tiling (surface, area, tile type/size/pattern/finish, prep),
painting (interior/exterior, surface, rooms/area, finish type, prep). Materials
records carry a `finishOrSpec` field for tile/paint/finish selections; quality
inspections cover water-ingress, workmanship and final handover checks.

## Scheduling
Extended `SchedulingDomain`, `loadResource`, repository column map + insert,
schema enum and migration 128 for `finishing`. Capacity-conflict EXCLUDE,
reschedule and staff assignment reused. Africa/Nairobi timezone supported.

## Staff & permissions
Owner provider profile manages its own job; non-owner staff must be active assigned
staff AND hold `provider.finishing.*`; revoked staff lose access immediately;
org membership alone insufficient.

## Flutter
`Mobile/lib/features/finishing_operations/`: datasource, Riverpod state,
customer jobs list + detail (assessment, plan, materials, quality inspection,
material/amendment approval, confirm completion); provider jobs list + detail with
REAL workflows surfaced in-app — record assessment, add plan, add materials,
record inspection, upload evidence, assign/revoke staff, progress, completion.
Routes `/finishing-operations/jobs`, `/finishing-operations/jobs/:jobId`,
`/finishing-operations/provider/jobs`,
`/finishing-operations/provider/jobs/:jobId`. EN + SW l10n via `flutter gen-l10n`.

## Communications
Outbox events `finishing_job.*` (classified CRITICAL) → existing worker →
localized in-app notifications + deep links; contextual conversation via
`marketplace_request`. No second system.

## Security
Customer ownership, provider owner/assigned authz, revoked staff denial,
cross-provider isolation, property/tenancy FKs, attachment privacy, internal-note
isolation, customer-visible material/inspection gating, immutable quotation
snapshot, validated transitions.

## Exclusions honoured
No payments, inventory/warehouse, procurement, full construction PM, fleet/GPS, or
duplicate infra; other operational domains unchanged.