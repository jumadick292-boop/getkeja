# Task 13.7 — Garbage Collection Provider Operations Report

## 1. Objective
Deliver provider-side garbage collection operations built on the Task 13.5 unified
service-request + quotation marketplace and the Task 13.6 moving operational
pattern, without creating parallel provider accounts or a second request engine.
Legacy garbage tables/endpoints are preserved for backward compatibility.

## 2. Legacy reconciliation
- Authoritative provider identity: `specialized_profiles` (`profile_category =
  garbage_collection_provider`) + `organisations` / `organisation_members` /
  `role_assignments` / `role_permissions`.
- Legacy `garbage_providers`, `garbage_provider_assignments`,
  `garbage_collection_requests`, and the tenant `/api/v1/tenant/garbage-requests`
  endpoints are left untouched and continue to function.
- New operations reuse the marketplace (`service_requests` / `service_quotations`),
  `saved_locations`, `conversations` / `messages`, `notification_outbox`,
  `organisation_members` / `role_permissions`, and the loose `document_id`
  attachment convention.

## 3. Data model (migration 115 + 116)
- Enums: `garbage_collection_status`, `garbage_agreement_status`,
  `garbage_occurrence_status`.
- Tables: `garbage_jobs`, `garbage_job_history` (+ status trigger),
  `garbage_job_staff_assignments`, `garbage_job_attachments`,
  `garbage_job_exceptions`, `garbage_recurring_agreements`,
  `garbage_recurring_occurrences`.
- Money `NUMERIC(12,2)`; `created_by` FK to `users`; unique partial indexes on
  `service_request_id` and `recurring_occurrence_id` (one job per source).
- Permissions `provider.garbage.{view,view_locations,update_progress,
  manage_schedule,upload_evidence,assign_staff,manage_agreements}` granted to
  `garbage_provider` and `service_provider`.
- Migration 116 seeds the `garbage` marketplace domain with five categories
  (`garbage_household`, `garbage_recycling`, `garbage_bulky`, `garbage_organic`,
  `garbage_commercial`) and six capabilities so customers can raise requests and
  providers can publish offerings consumed by the operations engine.

## 4. Lifecycle
`confirmed → scheduled → provider_assigned → en_route → arrived → collecting →
awaiting_customer_confirmation → completed`; `cancelled` / `missed` / `failed`
terminal; `rescheduled` reachable from active states. Completion is
customer-driven. Invalid transitions return `409`. Matrix in
`garbage.lifecycle.ts`.

## 5. Backend module
`server/src/modules/garbage/` mounted at `/api/v1/garbage`:
- Customer: list/detail jobs, cancel, confirm-completion (+ exception), report
  exception, list agreements, decide agreement, list occurrences.
- Provider: create job from accepted quotation, list/detail jobs (with
  `canViewLocations`), progress, missed, fail, cancel, assign staff, checklist,
  reschedule, submit completion, propose/list agreements, set agreement status.
- Strict Zod schemas; `{success,data}` envelopes; transactional state change +
  history + outbox in one transaction.

## 6. Authorization
Owner profile always manages its job; non-owner staff must be active assigned
staff AND hold the explicit `provider.garbage.*` permission. Addresses gated by
`canViewLocations` (owner/assigned staff true; org staff require
`provider.garbage.view_locations`).

## 7. Recurring agreements + occurrence generation
- Provider proposes an agreement from an accepted quotation/request; customer
  accepts → `active`.
- `garbage-recurring.worker.ts` (pg-boss cron every 15 min) calls
  `generateRecurringWork()`: idempotent (`agreement_id + period_key` unique),
  missed-run safe (7-day lookback, 14-day horizon), Africa/Nairobi date logic,
  only `active` agreements processed, per-occurrence row lock prevents
  double-create, history preserved. Wired in `main.ts`.

## 8. Outbox / notifications
New critical event types added to the classifier: `garbage_job.*` and
`garbage_agreement.*`, emitted in the same transaction as the change.

## 9. Flutter experience
`Mobile/lib/features/garbage/` (namespaced `garbage_ops_*` to avoid clashing with
the legacy tenant garbage feature): datasource, repository, Riverpod state, and
pages — customer jobs list/detail, provider jobs list/detail with operational
controls. Routes `/garbage/jobs`, `/garbage/jobs/:jobId`,
`/garbage/provider/jobs`, `/garbage/provider/jobs/:jobId`. EN + SW l10n keys
added and regenerated.

## 10. OpenAPI
12 new `/api/v1/garbage/...` paths documented under the `Garbage` tag. (The
pre-existing `PaymentInitiateResponse` missing-pointer validation error is
unrelated to this task.)

## 11. Out of scope
Fleet/vehicles, drivers, GPS, route optimization, dispatch, payments/payouts/
commission, transfer stations, processing plants, regulatory reporting,
reviews/ratings, dispute resolution. Hazardous/regulated waste requires provider
verification.

## 12. Verification
- `npm run typecheck`: clean.
- Migrations: 0 pending (115, 116 applied).
- `garbage.test.ts`: 5/5.
- Regression (marketplace, provider-catalogue, moving, garbage, tenant): 66/66.
- `flutter analyze` (garbage + router): 0 errors (style infos only).
- `garbage_ops_test.dart`: 2/2.

## 13. Residual / known issues
- Full backend suite: only `auth.mfa.test.ts` fails in parallel due to
  pre-existing Redis `flushall` flakiness (passes isolated).
- Task 13.4/13.5 residual Flutter failures remain in
  `house_seeker_compare_page_test.dart` / `house_seeker_saved_page_test.dart`
  from reconstructed l10n strings (unrelated to 13.7).

## 14. Files
- Migrations: `115_garbage_operations.sql`, `116_garbage_marketplace_categories.sql`.
- Backend: `server/src/modules/garbage/*`, `app.ts`, `main.ts`,
  `auth/transactional-outbox.service.ts`, `marketplace/marketplace.schemas.ts`.
- Flutter: `Mobile/lib/features/garbage/{data,domain,presentation}` (ops),
  `app_router.dart`, `l10n/app_{en,sw}.arb`, `test/features/garbage/garbage_ops_test.dart`.
- Docs: `docs/architecture/garbage-operations-audit.md`, this report.