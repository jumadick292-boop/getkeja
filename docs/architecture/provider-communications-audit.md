# Provider Communications — Initial Audit (Task 13.10)

Audit of the actual implementation (migrations + source), not documentation.
Constraint: do **not** build a second messaging system, notification engine,
outbox or job queue. Reuse the existing ones.

## 1. Existing messaging capability
- Tables (migration `076`, extended by `090/095/096/113/114`):
  `conversations` (type enum `conversation_type`, context columns
  `property_id, unit_id, enquiry_id, rental_proposal_id, tenancy_id,
  site_visit_id, rental_application_id, moving_job_id`), `conversation_participants`
  (`role owner/participant/observer`, `left_at`, `last_read_at`, UNIQUE
  conversation+user), `messages` (`type text/system/notification`,
  `status delivery_status`, `deleted_at`), `message_attachments`,
  `message_read_states` (UNIQUE message+user).
- Service `messaging.service.ts`: centralized `startConversation` with
  `pg_advisory_xact_lock` per context, participant derivation from
  ownership/assignment data, dedup via `findActiveConversationForContext`
  (`messaging.repository.ts:400`) and `findActivePropertyConversation`
  (`:424`). Auth via `assertActiveParticipant` (`repository.ts:132`),
  `purgeRevokedManagers` (`:157`).
- Endpoints (`messaging.routes.ts`, base `/api/v1/messaging`): list,
  unread-count, start, get, messages (cursor), send, read, archive, reopen,
  attachments upload/download. Strict Zod in `messaging.schema.ts`.
- Unread counts + read states + attachment signed-URL download (participant-gated)
  all exist.

## 2. Existing event producers / consumers
- Producers publish to `notification_outbox` via
  `enqueueOutboxEventTransactional` (`transactional-outbox.service.ts:43`) or
  `NotificationService.createOutboxEvent`. Domains already emitting:
  marketplace (`quotation.*`, `service_request.*`), moving (`moving_job.*`),
  garbage (`garbage_job.*`, `garbage_agreement.*`), laundry (`laundry_order.*`),
  scheduling (`schedule.*`), rental-applications, payments, tenant
  (`*_request.created`). `classifyEventType` (`:70`) marks all these CRITICAL.
- Consumer: pg-boss worker `notification.worker.ts` (cron `*/30s`) →
  `processOutboxEvent` materializes `notifications` + per-channel
  `notification_delivery_attempts`, then `NotificationDeliveryService` sends.
- `message.created` outbox is emitted by `messaging.service.ts:535`
  (`enqueueNewMessageOutbox`).

## 3. Delivery guarantees & failure behaviour
- Outbox insert is atomic with the business txn when a client is passed;
  `idempotency_key` UNIQUE + `ON CONFLICT DO NOTHING` gives dedup.
- Worker skips `completed`/`processing`; retries failed events with capped
  exponential backoff (max 3) then `dead_letter`.
- Channel attempts: `delivery_status` enum
  `pending/sent/delivered/failed/bounced/complained/suppressed`;
  `handleFailure` retries 3× (`[60s,300s,900s]`) then writes
  `notification_dead_letters`.
- Gaps: `sent` is set **before** the provider call; `recipientId` is null for
  outbox-materialized attempts so email/sms recipient resolution fails;
  push hard-fails (`PUSH_NOT_IMPLEMENTED`, provider unwired); in-app has no
  real-time fan-out (persisted only); no locale resolution; HTTP outbox
  fallback idempotency key uses `Date.now()`.

## 4. Conversation authorization & deduplication
- Authorization is resource-scoped: participant universe derived from
  ownership/manager assignments; caretakers excluded; client cannot inject
  arbitrary counterparts; revoked managers purged. Dedup is per context column
  under an advisory lock (no DB unique constraint).
- Only `enquiry/site_visit/tenancy/rental_application/rental_proposal/property`
  contexts are wired. `moving_job` type+column exist but `resolveContext` and
  `ConversationContextType` lack it; `marketplace/garbage/laundry/scheduling`
  have **no** conversation integration.

## 5. Missing service-domain integrations
- No contextual conversation for: marketplace service requests/quotations,
  moving jobs, garbage jobs/occurrences, laundry orders, scheduling activities.
- No "contact provider / message" entry point on any of the 8 service-detail
  Flutter pages.

## 6. Notification preferences & user controls
- `notification_preferences` (051): global channel toggles + 8 categories × 4
  channels; marketing defaults FALSE (opt-in), others TRUE. Endpoints
  GET/PATCH `/api/v1/auth/notifications/preferences`.
- Gaps: no verified-contact enforcement at send time; no explicit
  "security cannot be disabled" guard; marketing vs transactional treated
  identically at send; no locale.

## 7. Privacy & authorization gaps
- No verified-email/phone gate before email/sms/push.
- Push previews / lock-screen content not minimized (no preview policy).
- No deep-link authorization (links absent entirely).
- Legacy house-seeker/landlord direct conversation inserts bypass central
  authz/dedup.
- No notification deep links; `metadata` mentions them but unused.

## 8. Safe reuse opportunities
- Reuse `conversations`/`conversation_participants`/`messages` + add context
  columns for the five domains; extend `resolveContext` with per-domain
  resolvers deriving participants from `customer_user_id` + org owners/admins +
  active `*_staff_assignments`.
- Reuse `notification_outbox` + worker; add locale resolution, verified-contact
  gating, security/marketing rules, deep-link metadata.
- Reuse Flutter `features/notifications` inbox; add deep-link navigation,
  preferences screen, and contact-provider entry points on service pages.
- Reuse design system (`AppCard`, `AppNotice`, `AppListSkeleton`,
  `PrimaryButton`) and Riverpod/GoRouter patterns.

## 9. Flutter state
- `features/notifications` inbox exists (list, unread, mark read/all, delete) at
  `/notifications`; datasource hits `/api/v1/auth/notifications`.
- Messaging lives under `features/house_seeker` conversations; no shared
  messaging feature; no domain contact entry points.
- Riverpod 3.5, GoRouter 18.1, Dio 5.7; flat `GoRoute` list with per-route auth
  redirect + global redirect. l10n `app_en.arb`/`app_sw.arb` (464 keys, SW
  partially untranslated). Design system in `core/widgets/design_widgets.dart`.