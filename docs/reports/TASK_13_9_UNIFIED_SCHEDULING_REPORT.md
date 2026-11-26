# Task 13.9 — Unified Scheduling Report

## Scope
Shared scheduling/availability/staff coordination for moving, garbage (incl.
recurring occurrences) and laundry, without replacing domain lifecycles.

## Delivered
- **Migration** `119_unified_scheduling.sql`: `btree_gist`; enums
  `scheduling_domain`, `scheduling_status`; tables `scheduling_activities`
  (per-resource CHECK + partial unique indexes + EXCLUDE overlap),
  `staff_availability`, `staff_leave`, `scheduling_capacity`, `staff_assignments`
  (+ history), `reschedule_requests`, `scheduling_reminders`.
- **Module** `server/src/modules/scheduling/`: types, strict Zod schemas,
  repository, service (createSchedule, requestReschedule, decideReschedule,
  cancelSchedule, assignStaff, revokeStaff, providerCalendar, customerCalendar,
  getActivityDetail, checkAvailability, setStaffAvailability, addStaffLeave,
  setCapacity), controller, routes, `scheduling-reminders.worker.ts`
  (pg-boss cron `*/5 * * * * *`).
- **Wiring**: `app.ts` mounts `/api/v1/scheduling`; `main.ts` starts/stops the
  reminders worker; outbox classifier handles `schedule.*` events.
- **Flutter** `Mobile/lib/features/scheduling/`: datasource, repository,
  Riverpod state (`providerCalendarProvider`, `customerAppointmentsProvider`),
  `provider_calendar_page` (day/week/month + domain filters),
  `customer_appointments_page`; routes `/scheduling/calendar`,
  `/scheduling/appointments`; EN + SW l10n.
- **OpenAPI**: 10 `/api/v1/scheduling/...` paths (Scheduling tag).
- **Docs**: `docs/architecture/unified-scheduling.md`.

## Verification
- `npm run typecheck`: clean.
- Migrations: `Pending: 0`, re-run idempotent.
- Vitest scheduling 5/5; domain regression moving+garbage+laundry+scheduling 20/20.
- Marketplace/provider/tenant/messaging regression 74/74.
- Flutter scheduling test 2/2; `flutter analyze` 0 errors.
- OpenAPI parses; 10 scheduling paths.

## Notes
- Single source of schedule truth per resource via partial unique indexes.
- Overlap prevented at DB level (EXCLUDE gist) → 409 on concurrent booking.
- Reschedule keeps original window until approval; reminders cancelled on change.
- No fleet/GPS/payments/lifecycle replacement introduced.