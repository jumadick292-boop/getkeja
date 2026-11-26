# Laundry Operations Audit (Task 13.8)

## 1. Existing laundry assets
- **Legacy request tables** (migration `101_create_laundry_requests_table.sql`):
  `laundry_requests` (property/unit/tenancy/tenant anchored, `laundry_request_status`
  enum submitted→…→completed/declined/cancelled, `laundry_service_category`,
  `laundry_collection_preference`, garment_count, preferred_date_time) and
  `laundry_status_history` (append-only + status trigger).
- **Legacy provider services** (migration `057_create_laundry_provider_services_table.sql`):
  `laundry_provider_services` (offers_washing/dry_cleaning/ironing/folding/bedding/
  household_textile, offers_pickup/delivery, pickup_delivery_areas JSONB) FK to
  `provider_profile_extensions`.
- **Legacy tenant endpoints**: `server/src/modules/tenant/tenant.controller.ts`
  GET/POST `/api/v1/tenant/laundry-requests`, DELETE `/:requestId`; emits
  `laundry_request.created` outbox event.
- **Role/permissions**: role `laundry_provider` (migration 038); profile category
  `laundry_service_provider` (migration 055); registration role `laundry_provider`.
- **No** `server/src/modules/laundry` backend module and **no** `Mobile/lib/features/laundry`
  Flutter feature exist yet.

## 2. Shared infrastructure reused (no duplication)
- Marketplace engine (Task 13.5): `service_requests`, `service_quotations`,
  `service_quotation_items`, category/capability catalogue, acceptance workflow.
  `laundry` is already a valid `service_domain` and `ServiceDomain` union member.
- Provider identity/org (13.2–13.3): `specialized_profiles`, `organisations`,
  `organisation_members`, `role_assignments`, `role_permissions`,
  `resolveProviderContext`, `authz.hasPermission`.
- Catalogue/offering (13.4): `service_categories`, `service_capabilities`,
  `provider_service_offerings`, service areas, availability, offering gate.
- Locations: `saved_locations`, `provider_service_areas`, location authorization.
- Messaging/notifications: `conversations`/`messages`, `notification_outbox`,
  `transactional-outbox.service` (classifier + `enqueueOutboxEventTransactional`).
- Attachments: loose `document_id` (UUID) references, access-controlled.
- Operational pattern (13.6 moving, 13.7 garbage): job + append-only history +
  staff assignments + exceptions + attachments + completion/confirmation, all in
  one transaction with outbox; pg-boss cron workers wired in `main.ts`.

## 3. Gaps / missing capabilities (to build)
- No operational laundry order distinct from the marketplace request; legacy
  `laundry_requests` is property-anchored and not quotation-driven.
- No item-level intake/inventory accountability.
- No laundry processing-stage lifecycle, inspection, discrepancy/approval,
  amendment, collection/return handover, or operational exceptions.
- No laundry marketplace categories/capabilities seeded (109/112 skip laundry).
- No laundry Flutter experience.

## 4. Schema conflict / compatibility notes
- Legacy `laundry_requests` / `laundry_provider_services` / tenant endpoints are
  **preserved unchanged** (backward compatibility). New operational tables are
  additive and quotation-driven, mirroring garbage (115/116).
- New categories seeded additively; no enum changes to `service_domain` needed
  (`laundry` already present).
- `laundry_collection_status` is a NEW enum (legacy `laundry_request_status`
  untouched).

## 5. Reuse decisions
- One provider identity, one marketplace request/quotation engine, one outbox,
  one messaging system, one location model. New code only adds the laundry
  operational layer + item inventory + collection/return handover on top.
- Provider/staff authorization mirrors garbage: owner profile always manages;
  non-owner staff must be active assigned staff AND hold explicit
  `provider.laundry.*` permission; addresses gated by `canViewLocations`.
- Recurring not required by spec; overdue/reminder via idempotent pg-boss worker.