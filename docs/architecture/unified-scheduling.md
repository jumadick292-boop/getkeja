# Unified Scheduling (Task 13.9)

A shared scheduling, workforce-assignment and operational-coordination layer that
serves moving, garbage (including recurring occurrences) and laundry **without**
owning or replacing their lifecycles. Domain adapters validate resource ownership
and eligibility and mirror confirmed windows back to the domain record.

## Architecture
- **Shared module**: `server/src/modules/scheduling/` (types, schemas, repository,
  service, controller, routes, reminders worker) mounted at `/api/v1/scheduling`.
- **Single source of schedule truth per resource**: `scheduling_activities` has a
  unique partial index per resource column (moving_job_id / garbage_job_id /
  garbage_occurrence_id / laundry_order_id) so each operational resource has at
  most one schedule; a CHECK enforces the resource column matches the domain.
- **No lifecycle ownership**: the service reads the domain resource status and
  refuses scheduling/rescheduling of terminal resources (completed/cancelled/
  failed/exception/missed). Domain status transitions remain in their own modules.
- **Provider availability reused**: `provider_operating_hours` +
  `provider_availability_exceptions` (migration 107) are queried directly; no
  duplicate tables. Staff availability (`staff_availability`, `staff_leave`) and
  capacity (`scheduling_capacity`) are new shared tables.

## Entities (migration 119)
`scheduling_activities`, `staff_availability`, `staff_leave`, `scheduling_capacity`,
`staff_assignments` (+ `staff_assignment_history`), `reschedule_requests`,
`scheduling_reminders`. `timestamptz` everywhere; `time_zone` default
Africa/Nairobi (configurable). `btree_gist` + an `EXCLUDE` constraint prevent
overlapping **confirmed** appointments for the same `capacity_key`
(`staff:<id>` or `provider:<id>`).

## Conflict detection & concurrency
- DB-level `EXCLUDE USING gist (capacity_key =, tstzrange(start,end) &&) WHERE
  status='confirmed'` is the hard guarantee — concurrent bookings of the same
  constrained slot cannot both succeed (unique_violation / exclusion_violation →
  409).
- Friendly pre-check `hasOverlap()` for clearer errors.
- Unique pending reschedule per activity prevents concurrent reschedule overwrites.
- All multi-row changes run in a transaction with outbox in the same txn.

## Staff assignment & permissions
Shared `staff_assignments` (active/revoked + history). A staff assignment is tied
to the exact activity and provider org/individual. Access requires owner profile
or active assigned staff; revocation is immediate. Service-specific permissions
remain enforced by each domain (`provider.<domain>.*`); the shared layer never
grants cross-domain access. Legacy per-domain staff tables are preserved.

## Rescheduling
`reschedule_requests` (propose/approve/reject). The original confirmed window is
kept until the affected party approves; approval updates the activity window and
cancels obsolete reminders. Completed/cancelled resources cannot be rescheduled.

## Recurring garbage integration
Each `garbage_recurring_occurrences` row is an independently schedulable resource
(`domain='garbage_occurrence'`); the existing idempotent Africa/Nairobi generator
is untouched. A schedule references the occurrence, not the agreement, so retries
cannot duplicate schedules (unique index).

## Reminders & overdue
`scheduling-reminders.worker.ts` (pg-boss every 5 min) sends due reminders via the
transactional outbox (idempotent keys) and flags overdue confirmed activities as
`missed`. Schedule changes cancel obsolete reminders.

## API
`/api/v1/scheduling`: provider/customer calendar, activity detail, create schedule,
reschedule request/decide, cancel, staff assign/revoke, availability check,
staff availability/leave, capacity. Strict Zod, `{success,data}`, date-window
limits, resource-scoped authz. 10 OpenAPI paths under `Scheduling`.

## Flutter
`Mobile/lib/features/scheduling/`: datasource, repository, Riverpod state,
`provider_calendar_page` (day/week/month + domain filters, links to existing
domain detail screens) and `customer_appointments_page`. Routes
`/scheduling/calendar`, `/scheduling/appointments`. EN + SW l10n. Existing domain
detail screens remain the source of truth; no duplicate operational screens.

## Timezones
`timestamptz` storage; configurable `time_zone` (default Africa/Nairobi); Flutter
receives ISO-8601 UTC and renders local. Recurring garbage keeps Nairobi semantics.

## Exclusions
No fleet, drivers, GPS, route optimization, payments/payouts, new marketplace/
quotation/notification/provider-identity systems, or domain lifecycle replacement.