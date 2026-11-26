# Task 13.8 — Laundry Provider Platform and Operations Report

## 1. Initial audit findings
- Legacy assets: `laundry_requests` + `laundry_status_history` (migration 101),
  `laundry_provider_services` (057), tenant `/api/v1/tenant/laundry-requests`
  endpoints, role `laundry_provider` (038), profile category
  `laundry_service_provider` (055).
- No `server/src/modules/laundry` backend module and no `Mobile/lib/features/laundry`
  feature existed.
- `laundry` was already a valid `service_domain` / `ServiceDomain`, but no laundry
  marketplace categories were seeded.
- Full detail: `docs/architecture/laundry-operations-audit.md`.

## 2. Existing systems reused
Marketplace request/quotation/acceptance (13.5); provider identity/org/staff/
permissions (13.2–13.3); catalogue/offering/areas/availability (13.4); saved
locations; conversations/messages; notification outbox + transactional outbox;
loose `document_id` attachments; moving/garbage operational pattern (13.6/13.7);
pg-boss. No duplicate systems created.

## 3. New migrations and entities
- `117_laundry_operations.sql`: enum `laundry_collection_status`; tables
  `laundry_orders`, `laundry_order_history` (+ status trigger),
  `laundry_order_items`, `laundry_order_inspections`,
  `laundry_order_staff_assignments`, `laundry_order_handovers`,
  `laundry_order_amendments`, `laundry_order_exceptions`,
  `laundry_order_attachments`; `provider.laundry.*` perms granted to
  `laundry_provider` / `service_provider`.
- `118_laundry_marketplace_categories.sql`: 5 laundry categories + 6 capabilities.
- Both applied; `migrate status` → Pending: 0; re-run idempotent.

## 4. API routes and OpenAPI changes
Mounted `/api/v1/laundry` (`laundry.routes.ts`). 13 new OpenAPI paths under the
`Laundry` tag (orders list/detail, confirm-completion, cancel, inspection resolve,
amendment decide, provider orders create/list/detail, items, inspections,
progress, staff, completion). YAML parses; laundry paths = 13. (Pre-existing
`PaymentInitiateResponse` pointer error is unrelated.)

## 5. Customer and provider workflows
Customer: discover (marketplace), request, quotation compare/accept, order
list/detail, item intake review, discrepancy approval, amendment decision,
delivery confirmation, exception reporting, cancel. Provider: dashboard/list,
detail, item intake, inspection/discrepancy, stage management (with skipping),
staff assign/revoke, scheduling/handover, amendment proposal, ready/completion,
history.

## 6. Lifecycle and item-accountability rules
21-state lifecycle with forward stage skipping; invalid transitions → 409;
append-only history with actor/timestamp/prev/new/metadata. Items support bulk
quantity, condition, stains/damage, handling, photos, status, return notes.
Inspections record declared vs received; discrepancies require customer approval
and block progression until resolved. Customer confirmation distinct from
provider completion.

## 7. Authorization and privacy controls
Customer ownership on every customer route; provider owner profile or active
assigned staff + explicit `provider.laundry.*` permission; immediate revocation;
`canViewLocations` gate on addresses; property/unit/tenancy captured; attachment
access limited to authorized participants; accepted quotation immutable.

## 8. Flutter screens and navigation
`Mobile/lib/features/laundry/`: datasource, repository, Riverpod state; pages
`laundry_orders_page`, `laundry_order_detail_page`, `provider_laundry_orders_page`,
`provider_laundry_order_detail_page`. Routes `/laundry/orders`,
`/laundry/orders/:orderId`, `/laundry/provider/orders`,
`/laundry/provider/orders/:orderId`. EN + SW l10n via `flutter gen-l10n`.

## 9. Tests run and exact results
- `npm run typecheck`: clean.
- `laundry.test.ts`: 5/5.
- Regression (laundry + marketplace + provider-catalogue + moving + garbage): 49/49.
- Tenant + messaging regression: 40/40.
- `flutter analyze` (laundry + router): 0 errors (style infos only).
- `laundry_test.dart`: 2/2.
- Migrations: 0 pending, idempotent re-run.

## 10. Known limitations and pre-existing failures
- Full backend suite: `auth.mfa.test.ts` fails only in parallel due to pre-existing
  Redis `flushall` flakiness (passes isolated).
- Task 13.4/13.5 residual Flutter failures in
  `house_seeker_compare_page_test.dart` / `house_seeker_saved_page_test.dart` from
  reconstructed l10n strings (unrelated to 13.8).
- OpenAPI `swagger-cli validate` reports a pre-existing missing
  `PaymentInitiateResponse` pointer unrelated to this task.
- No payments/payouts, fleet, GPS, route optimization, or separate chat (by design).

## 11. Manual configuration / deployment
- Run `npm run migrate up` (117, 118) before start; the laundry overdue worker
  starts automatically with the server (pg-boss). No new env vars required.