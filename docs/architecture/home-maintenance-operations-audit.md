# Home Maintenance & Repairs — Operations Audit (Task 13.12)

Read-only audit of reusable infrastructure before implementation.

## Group membership (from Task 13.11 report §7, group 1)
Categories (exact IDs) in scope:
- plumbing: `plumbing_emergency`, `plumbing_general`
- electrical: `electrical_general`, `electrical_wiring`
- hvac: `hvac_service`
- appliances: `appliance_repair`
- general: `handyman`
- carpentry: `carpentry`

Excluded (other groups): cleaning/property-care, installation/technical
(wifi/internet/solar), finishing/building (painting/roofing/flooring/tiling).

## Reused infrastructure (do not rebuild)
- **Marketplace (13.5)**: `service_requests`, `service_quotations`, request
  creation, immutable versioned quotations, atomic single-winner acceptance
  (`marketplace.service.acceptQuotation`). Accepted quotation exposes
  `id`, `versionNumber`, `providerProfileId`, `totalAmount`, `currency`.
- **Provider identity/offering (13.2–13.4)**: `specialized_profiles`,
  `organisations`/`organisation_members`, `provider_service_offerings`
  (domain+category), `provider_service_offering_capabilities`. Offering creation
  is domain-generic (`provider-catalogue.service.createOffering`).
- **Scheduling (13.9)**: `scheduling_activities`, `staff_assignments`,
  `scheduling.service.loadResource` switch + `scheduling_domain` enum
  (currently moving/garbage/garbage_occurrence/laundry). To extend.
- **Staff**: per-domain `*_staff_assignments` pattern (laundry: `is_active`
  partial unique + history). Provider access via `loadProviderContext` +
  `assertProviderAccess` (owner profile always; else active assigned staff;
  org owner/admin bypass).
- **Messaging (13.10)**: `messaging.service.resolveContext` with
  `marketplace_request` context (works for all domains); conversation reuse/dedup.
- **Notifications/outbox (13.10)**: `enqueueOutboxEventTransactional`,
  `classifyEventType`, pg-boss worker, preferences/locale/deep-links.
- **Attachments**: private document storage (`profile/private-document-storage`),
  `service_request_attachments` pattern; reuse `putPrivateDocument`/
  `signedPrivateDocumentUrl`.
- **Template**: laundry module (`createOrderFromQuotation` → `insertOrder` +
  history + outbox in one txn; lifecycle transition matrix with stage skipping;
  repository/service/controller/routes/worker/test).

## Domain-specific differences (maintenance vs laundry)
- Need **inspection/diagnosis** records (findings, diagnosis, recommended work,
  safety, customer-visible report vs internal notes).
- Need **work plan** + **materials/parts** with approval status.
- Need **amendments** (scope/price change) with customer approval; accepted
  quotation immutable.
- Lifecycle centres on inspection → approval → work → quality check → completion
  (not pickup/processing/delivery).
- Category-specific request fields (strict Zod) for plumbing/electrical/hvac/
  carpentry/appliance/handyman.

## Gaps to fill
- No `home_maintenance` scheduling domain; extend enum + `loadResource`.
- No maintenance ops tables; add migration 121.
- Marketplace uses generic details for these categories; add strict schemas.
- No maintenance Flutter feature; add `features/home_maintenance`.
- No maintenance outbox events; add `home_maintenance_job.*` + classify.

## Authorization model to preserve
Customer ownership (`customerUserId === userId`); provider owner/assigned-staff
only; revoked staff denied; org membership alone insufficient; property/tenancy
boundaries via existing models; internal notes never in customer APIs.