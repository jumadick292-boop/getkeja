# Laundry Operations (Task 13.8)

Laundry is a first-class service domain alongside moving and garbage, built on the
shared marketplace, provider identity, organization, permissions, locations,
messaging, notifications, attachments and outbox infrastructure. No duplicate
request, quotation, provider, organization, location, messaging or notification
systems are introduced.

## Architecture
- **Marketplace (13.5)** drives request → quotation → acceptance. `laundry` is a
  valid `service_domain`; categories/capabilities are seeded additively
  (migration 118): `laundry_wash_fold`, `laundry_dry_clean`, `laundry_iron_only`,
  `laundry_bedding`, `laundry_textile` + capabilities.
- **Operational order (13.8)** is created from an accepted quotation and retains
  an immutable `quotation_id` + `quotation_version`.
- **Legacy preserved**: `laundry_requests` (101), `laundry_provider_services`
  (057) and the tenant `/api/v1/tenant/laundry-requests` endpoints are untouched.

## Entities (migration 117)
`laundry_orders`, `laundry_order_history` (+ status trigger), `laundry_order_items`,
`laundry_order_inspections`, `laundry_order_staff_assignments`,
`laundry_order_handovers`, `laundry_order_amendments`, `laundry_order_exceptions`,
`laundry_order_attachments`. Money `NUMERIC(12,2)`; append-only history; unique
`service_request_id` (exactly-once); partial unique active-staff index.

## Lifecycle
`confirmed → collection_scheduled → collected → received_at_facility → inspection
→ awaiting_customer_approval → processing → washing → drying → ironing → folding
→ quality_check → ready_for_return → out_for_delivery → delivered →
awaiting_customer_confirmation → completed`; `cancelled` / `failed` / `exception`
terminal. **Stage skipping**: providers may jump forward across processing stages
(e.g. `awaiting_customer_approval → folding`) and from intake directly to
`ready_for_return`. Invalid transitions return `409`. Matrix in
`laundry.lifecycle.ts`.

## Item accountability
Order-level items support category, description, bulk quantity, customer
reference, intake condition, stains/damage, special handling, processing
instructions, item status, return condition/handover notes and photo document
references (access-controlled). Intake inspections record declared vs received
quantities; discrepancies/missing/damage require customer approval and **pause**
progression out of `awaiting_customer_approval` until resolved.

## Pricing & changes
Reuses marketplace quotation items (per item / per kg / per service / custom).
Accepted quotation is immutable; additional work uses `laundry_order_amendments`
(proposed by provider, accepted/rejected by customer). Acceptance adds the
additional cost to the order total without mutating the quotation. No payments.

## Collection / return
`dropoff`, `collection`, `both` fulfilment modes. Handovers (`collection` /
`return`) carry location (saved location or text address fallback), schedule
window, notes and proof document references; provider confirms handover.

## Authorization
Owner profile always manages its order; non-owner staff must be active assigned
staff AND hold the explicit `provider.laundry.*` permission. Revocation is
immediate. Addresses gated by `canViewLocations` (owner/assigned staff true; org
staff require `provider.laundry.view_locations`). Customer ownership enforced on
every customer route.

## API
Mounted at `/api/v1/laundry` (`laundry.routes.ts`). Customer: list/detail orders,
cancel, confirm-completion, report exception, resolve inspection, decide
amendment. Provider: create order, list/detail, progress, fail, cancel, add/update
items, record inspection, assign/revoke staff, checklist, schedule/confirm
handover, propose amendment, submit completion. Strict Zod, `{success,data}`,
pagination, resource-scoped authz.

## Background
`laundry-overdue.worker.ts` (pg-boss cron every 15 min) idempotently flags
orders past their return date still in an active state as `exception`.

## Flutter
`Mobile/lib/features/laundry/` (datasource, repository, Riverpod state, customer
orders list/detail, provider orders list/detail with stage-skipping controls).
Routes `/laundry/orders`, `/laundry/orders/:orderId`, `/laundry/provider/orders`,
`/laundry/provider/orders/:orderId`. EN + SW l10n.

## Exclusions
No payments/settlement, payouts/commissions, fleet/drivers, GPS, route
optimization, separate chat/notification system, duplicate marketplace/provider
identity, or unrelated auth/tenancy changes.