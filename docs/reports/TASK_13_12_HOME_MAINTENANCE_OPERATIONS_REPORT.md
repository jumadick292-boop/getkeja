# Task 13.12 — Home Maintenance & Repairs Operations Report

## 1. Initial audit findings
Reused marketplace (13.5), provider catalogue (13.4), scheduling (13.9),
communications (13.10), attachments and the laundry operational pattern. Only
moving/garbage/laundry had ops modules; maintenance categories were Level C.
Audit: `docs/architecture/home-maintenance-operations-audit.md`.

## 2. Exact categories implemented
plumbing_emergency, plumbing_general, electrical_general, electrical_wiring,
hvac_service, appliance_repair, handyman, carpentry (8 categories, 6 domains).

## 3. Category-specific request schemas
Strict Zod (marketplace.schemas.ts): plumbingDetailsSchema (problemType, fixture,
severity, waterSupplyAvailable), electricalDetailsSchema (jobType, affectedArea,
safetyConcerns, powerAvailable), hvacDetailsSchema (equipmentType, capacityModel,
faultDescription), carpentryDetailsSchema (itemType, dimensions, material),
applianceDetailsSchema (applianceCategory, manufacturer, model, warrantyStatus),
handymanDetailsSchema (taskType, rooms). Mapped by categoryId with cross-check.

## 4. Operational lifecycle
16-state matrix with stage skipping + customer-confirmation completion; invalid
transitions → 409. Append-only history per transition.

## 5. Inspection & diagnosis
Inspections with findings/diagnosis/recommended work/safety/customer-visible
report + internal notes (stripped from customer APIs). Work plans + parts with
approval status.

## 6. Materials & amendments
Parts (supplied_by, proposed_cost, approval_status); amendments preserve the
immutable accepted quotation and require customer approval for price/scope change.

## 7. Database migrations
121 (ops tables + scheduling_domain enum + permissions), 122 (scheduling_activities
home_maintenance_job_id + CHECK). Both idempotent; `Pending: 0`.

## 8. API & OpenAPI
`/api/v1/home-maintenance/...` customer + provider endpoints (strict Zod,
`{success,data}`, pagination, resource-scoped authz). OpenAPI +8 path templates
(234 total), valid.

## 9. Scheduling integration
Extended loadResource/SchedulingDomain/repo/schema + migration 122; moving/garbage/
laundry scheduling unchanged (regression green).

## 10. Staff & permissions
Owner profile manages own job; non-owner active assigned staff + explicit
`provider.home_maintenance.*`; revoked staff denied; org membership insufficient.

## 11. Flutter screens & navigation
Customer jobs list/detail (inspection, amendment approval, confirm completion);
provider jobs list/detail (progress, inspection, completion). Routes + EN/SW l10n.
Reuses shared scheduling/messaging/inbox. Limitation: staff-assignment/part/evidence
upload UI is backend-complete but not yet surfaced as dedicated Flutter screens.

## 12. Communications & notifications
`home_maintenance_job.*` outbox events (CRITICAL) via existing worker; localized
in-app + deep links; contextual conversation via marketplace_request.

## 13. Security & privacy
Ownership, provider/assigned authz, revoked staff, cross-provider isolation,
property/tenancy FKs, attachment privacy, internal-note isolation, immutable quote.

## 14. Verification results
- Server typecheck: clean. Migrations pending 0; idempotent re-run.
- Vitest home-maintenance 6/6; full regression (home-maintenance, scheduling,
  moving, garbage, laundry, marketplace, provider-catalogue, messaging) 86/86.
- Flutter analyze 0 errors; home_maintenance Flutter test 3/3.
- OpenAPI 234 paths valid.

## 15. Remaining limitations & deployment
- Requires Postgres (btree_gist for scheduling EXCLUDE) + pg-boss worker enabled.
- Provider-side Flutter screens for staff assignment, parts and evidence upload are
  not yet built (backend APIs exist and are tested).
- Painting/roofing/flooring/tiling (Finishing), cleaning/pest/landscaping
  (Cleaning), wifi/internet/solar (Installation) remain Level C for later groups.