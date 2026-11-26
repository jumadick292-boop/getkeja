# Task 13.6 — Moving & Relocation Provider Operations Report

## 1. Initial audit findings
See `docs/architecture/moving-operations-audit.md`. Reused the 13.5 marketplace
engine, provider identity/org/RBAC, locations, messaging, outbox and attachments;
added a dedicated moving-job record because no operational job entity existed and
`site_visits` is property-anchored (`property_id NOT NULL`).

## 2. Reused structures
`service_requests`/`service_quotations` (accepted quotation = contractual
snapshot), `saved_locations`, `conversations`/`messages` (new `moving_job` type +
`moving_job_id` link), `notification_outbox` (transactional, idempotent),
`organisation_members`/`role_permissions`, loose `document_id` attachments.

## 3. New schema (migrations 113–114, additive/idempotent)
- 113: `conversation_type` += `moving_job` (enum-only).
- 114: `moving_job_status`, `moving_assessment_status`, `moving_change_status`
  enums; `moving_jobs` (UNIQUE `service_request_id` = one job per accepted
  request; immutable quotation ref + version; origin/destination refs + textual
  fallback; agreed schedule; scope/price/checklist JSONB; optional
  tenancy/property/unit; completion + confirmation columns); `moving_job_history`
  (append-only + status trigger); `moving_job_staff_assignments` (unique active);
  `moving_job_assessments`; `moving_job_schedule_changes`; `moving_job_amendments`
  (immutable when accepted); `moving_job_attachments`; `conversations.moving_job_id`;
  7 `provider.moving.*` permissions granted to moving roles.

## 4. Lifecycle & transitions (`moving.lifecycle.ts`)
`confirmed → awaiting_customer_details → preparation → ready_for_move →
in_progress → arrived_at_destination → unloading → awaiting_customer_confirmation
→ completed`; `cancelled`/`failed` from active states; completed/failed/cancelled
terminal. Completion is **customer-driven** (provider only reaches
`awaiting_customer_confirmation`). Every transition records actor + history;
cancellation records actor/reason/timestamp; invalid transitions → 409.

## 5. Staff permissions
Owner profile always manages its own job. Non-owner staff must be active assigned
staff AND hold the explicit `provider.moving.*` permission (view, view_locations,
update_progress, manage_schedule, upload_evidence, propose_changes, assign_staff).
Caretakers gain nothing automatically.

## 6. Site assessment workflow
Provider requests → customer accepts/declines → provider completes with outcome.
An assessment never changes the accepted price.

## 7. Scheduling & amendment rules
Reschedule is a proposal the **other** party accepts/rejects; accepted change
updates the agreed schedule and preserves the previous one in history. Amendments
require explicit customer approval; accepted amendments are immutable and adjust
scope/price once.

## 8. API endpoints
Customer: `GET /api/v1/moving/jobs`, `GET .../{jobId}`,
`POST .../{jobId}/confirm-completion`, `.../cancel`, `.../assessments/{id}/respond`,
`.../reschedule`, `.../schedule-changes/{id}/decide`, `.../amendments/{id}/decide`.
Provider: `POST/GET /api/v1/moving/provider/jobs`, `GET .../{jobId}`,
`.../progress`, `.../fail`, `.../cancel`, `.../staff`, `.../checklist`,
`.../assessments`, `.../assessments/{id}/complete`, `.../reschedule`,
`.../amendments`, `.../completion`. All Zod-validated, `{success,data}`.

## 9. Privacy & authorization
Exact addresses only for the owning profile / assigned staff
(`canViewLocations`); unrelated providers 403; only the customer approves
reschedule/amendments/completion; only authorized provider staff update status.

## 10. Notification events
`moving_job.confirmed`, `...cancelled`, `...completed`, `...completion_submitted`,
`...completion_exception`, `...staff_assigned`, `...assessment_requested`,
`...amendment_proposed/accepted/rejected`, and progress events — all written in
the same transaction and classified CRITICAL where reliability matters.

## 11. Flutter screens
Customer: `MovingJobsPage`, `MovingJobDetailPage`. Provider:
`ProviderMovingJobsPage`, `ProviderMovingJobDetailPage`. API-backed via the
existing Dio/Riverpod/GoRouter architecture.

## 12. Localization
Added en+sw keys (`movingJobs`, `movingJobDetails`, `movingStatus`, `movingOrigin`,
`movingDestination`, `movingSchedule`, `movingChecklist`, `movingProgress`,
`movingAcceptedQuotation`, `movingConfirmCompletion`, `movingReportIncomplete`,
`movingCancelJob`, `movingNoJobs`, `movingRetry`, `providerMovingJobs`, …) and
regenerated `app_localizations*`.

## 13. Test results
- Backend `moving.test.ts`: 5/5 (job-once + duplicate 409, full lifecycle to
  customer-confirmed completion + no reopen, assessment/reschedule/amendment,
  authz + location privacy, invalid transition 409).
- Regression: marketplace + catalogue 34/34.
- Flutter `moving_test.dart`: 2/2; `flutter analyze` 0 errors.

## 14. OpenAPI
11 `/api/v1/moving/*` paths added; YAML validated (187 paths).

## 15. Known limitations
No fleet/vehicle/driver/dispatch/GPS/payments/payouts/commission/disputes/reviews
(later tasks). Live-location sharing and full complaints module deferred.

## 16. Verification commands
```
cd server && npm run typecheck
cd server && npx vitest run src/modules/moving/moving.test.ts
cd server && npx vitest run src/modules/marketplace src/modules/provider/provider-catalogue.test.ts
cd Mobile && flutter analyze lib/features/moving
cd Mobile && flutter test test/features/moving/moving_test.dart
```