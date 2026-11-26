# Task 13.6 — Moving & Relocation Operations: Pre-Implementation Audit

## Reused (extended, not duplicated)
- **Marketplace engine (13.5)**: `service_requests`, `service_quotations`
  (append-only revisions), `service_request_history`, `service_request_attachments`.
  A moving job is created **from** an accepted quotation — no new request/quotation
  engine.
- **Provider identity/authz**: `specialized_profiles`, `organisations`,
  `organisation_members`, `role_assignments`, `authorization.service`
  (`hasPermission`, `getUserOrganizationRoleIds`), `resolveProviderContext`,
  offering gate (`provider.repository.offeringGate`/`contextHasEligibleOffering`).
- **Catalogue (13.4/13.5)**: `service_categories` (moving_* + 18 marketplace),
  `service_capabilities`, `provider_service_offerings`, `provider_service_areas`.
- **Locations**: `saved_locations` (already extended with org/visibility/primary).
  Moving jobs reference origin/destination `saved_locations` + textual fallback.
- **Messaging**: `conversations`/`conversation_participants`/`messages`/
  `message_attachments`. Needs a `moving_job` conversation_type + `moving_job_id`
  link column (additive).
- **Notifications/outbox**: `notification_outbox` +
  `enqueueOutboxEventTransactional` + `classifyEventType` (idempotent, retries).
- **Attachments**: loose `document_id` reference pattern (as
  `service_request_attachments`) + `document-signed-url.service` for access.
- **Tenancy/property**: `tenancies`, `properties`, `units` — optionally linked
  from a moving job when the move relates to a GetKeja tenancy.
- **Flutter**: marketplace datasource/repository/Riverpod/Dio, GoRouter guards,
  design system, `flutter gen-l10n` (en+sw).

## Gaps / decisions
- **No moving-job entity exists.** Introduce a dedicated `moving_jobs` record
  linked 1:1 to the accepted `service_request` + exact accepted quotation
  revision (contractual snapshot). Legacy `moving_requests` (100) is the old
  tenancy-coupled flow and is left untouched.
- **Site visits are property-anchored** (`property_id NOT NULL`); a move
  assessment is location/request-scoped, not property-scoped. Reuse the
  site-visit *lifecycle + history conventions* but add a dedicated
  `moving_job_assessments` table (documented deviation).
- **Staff permissions**: reuse `organisation_members` + `role_permissions`;
  add `provider.moving.*` permissions. A caretaker gains nothing automatically.
- **Checklists**: configurable per service scope; state stored as JSONB on the
  job (template defined in code), avoiding a rigid per-item table.
- **Completion**: provider submits evidence → customer confirms or reports an
  exception; no payout/commission logic. Disputes deferred.
- **Privacy**: exact coordinates/addresses only for assigned provider + active
  assigned staff; textual fallback always available; no continuous GPS.

## Out of scope (later tasks)
Fleet/vehicles, driver accounts, route optimization, live GPS, dispatch,
payments/payouts/commissions, full dispute resolution, reviews/ratings.