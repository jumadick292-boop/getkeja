# Provider Communications & Customer Experience (Task 13.10)

A unified communications layer that connects the existing messaging, notification,
outbox and scheduling infrastructure to every service journey (marketplace,
moving, garbage, laundry, scheduling) **without** introducing a second messaging
system, notification engine, outbox or job queue.

## Reused infrastructure
- **Messaging**: existing `conversations` / `conversation_participants` /
  `messages` / `message_attachments` / `message_read_states` and the central
  `startConversation` service (advisory-lock dedup, participant derivation,
  revocation purge). Extended — not replaced.
- **Notifications**: existing `notifications`, `notification_templates`,
  `notification_preferences`, `notification_delivery_attempts`,
  `notification_dead_letters`, `notification_outbox` and the pg-boss outbox
  worker (`notification.worker.ts`).
- **Outbox**: `enqueueOutboxEventTransactional` / `NotificationService.createOutboxEvent`
  with `idempotency_key` dedup and `classifyEventType` (all domain events CRITICAL).
- **Flutter**: existing `features/notifications` inbox, design system, Riverpod 3,
  GoRouter 18, Dio, `app_en.arb`/`app_sw.arb`.

## Contextual conversations (migration 120)
- Added `conversation_type` values `marketplace_request`, `garbage_job`,
  `laundry_order`, `scheduling_activity` (`moving_job` already existed) and
  context columns `marketplace_request_id`, `garbage_job_id`, `laundry_order_id`,
  `scheduling_activity_id` on `conversations`.
- **Per-context partial unique indexes** enforce one active conversation per
  business record at the DB level; the service also dedups under an advisory lock.
- `messaging.service.ts` gained `resolveMarketplaceRequestContext`,
  `resolveMovingJobContext`, `resolveGarbageJobContext`,
  `resolveLaundryOrderContext`, `resolveSchedulingActivityContext` and
  `deriveProviderParticipants`.
- **Authorization**: participant universe = the customer + the provider
  organisation's active owners/admins + staff **explicitly and actively assigned**
  to that resource (`*_staff_assignments.is_active`). A staff member who merely
  belongs to the org is denied; revoked staff are excluded; cross-provider access
  by changing an id is rejected (`ForbiddenError`). Client-suggested participants
  are validated against the universe.
- `startConversationSchema` / controller accept the new context ids; exactly one
  context is required.

## Notification delivery improvements
- **Verified-contact enforcement**: email/SMS/push are skipped unless the
  recipient's `email_verified` / `phone_verified` is set (in-app always allowed).
- **Essential security**: `category = security` bypasses per-category opt-out and
  quiet hours so security alerts cannot be disabled via ordinary preferences.
- **Marketing separation**: marketing categories default to opt-in (false).
- **Locale resolution**: per-recipient locale (en/sw) resolved at delivery time
  from the user's Google identity locale, with `sw → en` template fallback. Fixed
  the template lookup to key on `event_type + channel + locale`
  (`findNotificationTemplateByEvent`) instead of the mismatched `template_key`.
- **Deep links**: `buildDeepLink` attaches a safe `getkeja://` link to operational
  notifications (moving/garbage/laundry/marketplace/scheduling/conversation).
  Links carry only type+id; the target re-checks authorization.

## API
- Messaging (now documented in OpenAPI): `GET/POST /api/v1/messaging/conversations`,
  `GET .../unread-count`, `GET/POST .../{id}/messages`, `POST .../{id}/read`.
- Notifications/preferences: existing `/api/v1/auth/notifications` + `/preferences`.
- No new backend route modules were required; existing endpoints were extended.

## Flutter
- New `features/messaging`: datasource (`/api/v1/messaging`), state, and a
  `ConversationPage`; `startContextualConversation` launcher.
- "Contact provider" AppBar action on the customer moving/laundry/garbage/
  marketplace detail pages → starts/reuses the authorized conversation.
- `features/notifications`: preferences screen (`/notifications/preferences`)
  with channel + category switches; inbox deep-link navigation via
  `notificationDeepLinkToPath` (getkeja:// → GoRouter location) to the correct
  service detail / conversation.
- l10n keys added in EN + SW; generated files regenerated via `flutter gen-l10n`.

## Security & privacy
- Conversation participant authorization enforced server-side; provider org
  isolation; revoked staff denied; deep-link target re-checks access; notification
  ownership enforced by existing user-scoped queries; verified-contact gating;
  security notifications protected; previews limited to safe summaries (no full
  addresses/attachments/private notes in template bodies).

## Exclusions honoured
No new messaging/notification/outbox/queue; no payments/payouts; no marketing
automation; no location tracking; no new auth; no changes to domain lifecycles.