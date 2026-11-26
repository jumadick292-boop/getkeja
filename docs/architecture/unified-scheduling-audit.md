# Unified Scheduling Audit (Task 13.9)

## 1. Existing scheduling entities & workflows
- **Provider availability (13.4, migration 107)**: `provider_operating_hours`
  (per profile or per offering, day_of_week 0–6, open/close, is_closed, time_zone
  default Africa/Nairobi), `provider_availability_exceptions` (date-scoped
  closures/special hours), `provider_service_areas` (+ offering_id), `saved_locations`
  (+ org/public/visibility/primary). Repository helpers in
  `provider-catalogue.repository.ts`; expiry worker `provider-availability.worker.ts`.
- **Moving (13.6)**: `moving_jobs.agreed_move_date/agreed_window_start/end`;
  reschedule via `moving_job_schedule_changes` (propose/decide, original kept until
  accepted); staff via `moving_job_staff_assignments`.
- **Garbage (13.7)**: `garbage_jobs.scheduled_date/window_start/end`;
  `garbage_recurring_agreements` + `garbage_recurring_occurrences` (period_key,
  scheduled_date, Africa/Nairobi generator `generateRecurringWork`);
  `garbage_job_staff_assignments`.
- **Laundry (13.8)**: `laundry_orders.collection_date/window`, `return_date/window`;
  `laundry_order_handovers` (kind collection/return, scheduled_at, window);
  `laundry_order_staff_assignments`.

## 2. Staff assignment mechanisms
Three parallel per-domain tables (`moving_job_staff_assignments`,
`garbage_job_staff_assignments`, `laundry_order_staff_assignments`) with identical
shape (resource_id, user_id, label, is_active, assigned_by, revoked_at/by). Access is
gated in each domain service by owner-profile OR active-assigned-staff AND explicit
`provider.<domain>.*` permission.

## 3. Availability & operating-hours logic
Provider-level only today. No staff working-hours/leave model. No capacity limits,
buffer, min-notice or max-advance config. No cross-domain calendar.

## 4. Duplicate / inconsistent validation
- Each domain re-implements staff assignment + revocation + history.
- Reschedule exists only for moving (schedule_changes); garbage uses
  status→rescheduled + applyReschedule; laundry has handovers but no reschedule
  request/approval.
- Window validation (HH:MM) duplicated across schemas.
- No shared conflict detection; each domain relies on a single-writer status update.

## 5. Rescheduling & cancellation behaviour
- Moving: propose/decide with original preserved until acceptance (good model).
- Garbage: provider reschedules unilaterally (status rescheduled).
- Laundry: handover records, no approval flow.
- Cancellation: per-domain terminal status; no shared record.

## 6. Background jobs & reminders
pg-boss cron workers: provider availability expiry, garbage recurring occurrences,
laundry overdue, site-visit reminders, outbox. No scheduling reminder/overdue
worker; no appointment reminder state.

## 7. Domain-specific behaviour that must stay independent
Status lifecycles (moving/garbage/laundry enums), item inventory (laundry),
recurring occurrence generation (garbage), assessments/amendments (moving),
quotation snapshots. The shared layer must NOT own these lifecycles.

## 8. Safe shared-infrastructure opportunities
- One `scheduling_activities` table referencing each schedulable resource with a
  per-domain unique constraint (exactly one schedule per resource) and enforced FKs
  (nullable typed columns + CHECK exactly-one).
- Shared `staff_availability` + `scheduling_capacity` (per provider/offering).
- Shared `staff_assignments` + `assignment_history` (migrate-by-reference; keep
  legacy tables intact, mirror new assignments).
- Shared `reschedule_requests` (propose/approve/reject; original schedule kept until
  accepted).
- Shared `scheduling_reminders` state + pg-boss reminder/overdue worker.
- Conflict detection via interval overlap + `EXCLUDE`/advisory locks in a txn.
- Unified calendar query joining activities across domains with date-window paging.

## 9. Reuse decisions
Extend `provider_operating_hours`/`provider_availability_exceptions` for provider
availability (no duplicate tables). Add only staff availability + capacity +
shared activities/assignments/reschedule/reminders. Keep legacy per-domain staff
tables and the garbage occurrence generator untouched; the shared layer references
existing resources rather than duplicating schedule truth (single writer per
resource via unique index).