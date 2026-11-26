# Task 13.5 — Pre-Implementation Audit (short)

## Reusable (do not duplicate)
- **Identity/org/RBAC**: `specialized_profiles`, `organisations`, `organisation_members`,
  `role_assignments`, `authorization.service` (`hasPermission`, `getUserOrganizations`,
  `getUserOrganizationRoleIds`, `isOrganizationMember`), provider context
  (`resolveProviderContext`) and the 13.4 offering gate (`offeringGate`,
  `contextHasEligibleOffering`).
- **Catalogue (13.4)**: `service_categories` (26), `service_capabilities` (19),
  `provider_service_offerings`, `provider_service_offering_capabilities`,
  `provider_service_pricing`, `provider_service_areas`, `saved_locations`,
  `provider_operating_hours`, `provider_availability_exceptions`.
- **Outbox/notifications**: `notification_outbox` + `enqueueOutboxEventTransactional`
  + `classifyEventType` + `notification.worker` (idempotent, retries).
- **Messaging/attachments**: `conversations`/`messages`/`message_attachments` +
  `private-document-storage.service` (S3 presigned).
- **Validation/response**: `validate(schema, source)`, `{success,data,pagination}`,
  `shared/errors`, Zod conventions.
- **Flutter**: central Dio `ApiClient`, Riverpod 3 Notifier/FutureProvider patterns,
  GoRouter guards, design system, `flutter gen-l10n`, house-seeker as the browse/
  discovery reference, laundry/garbage as the request-form reference.

## Gaps (must add)
- **No quotation tables/module** exist (only unused Zod `providerQuotationSchema`).
- **No unified request engine**: legacy `moving_requests`/`laundry_requests`/
  `garbage_collection_requests` are tenancy-coupled and cover only 3 domains.
- `garbage_collection_requests` lacks `tenant_id`/contact/cancellation columns and
  uses a different status enum — asymmetric.
- Two divergent Zod sets (`service-requests.schema.ts` vs `tenant.schema.ts`).

## Decision
- Add **one** unified marketplace request engine: new `service_requests` +
  `service_request_history` + `service_quotations` (append-only revisions) +
  `service_quotation_items`. This is the single engine for all 18 categories;
  category-specific fields live in a Zod-validated `details` JSONB (strict per
  category, no arbitrary JSON).
- **Legacy** moving/laundry/garbage tenant endpoints remain untouched
  (regression preserved); the marketplace is additive.
- Reuse provider identity, catalogue, areas, locations, outbox, messaging, S3
  storage. No new auth, location, messaging, notification or API-client systems.
- Flutter: new `marketplace` customer feature (browse → category form → request
  list/detail → quotation compare/accept) and provider quotation flow, reusing
  existing datasource/state/router/design-system/l10n patterns.