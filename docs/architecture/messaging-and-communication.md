# Messaging and Communication Centre — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** In-app messaging between House Seekers and Landlords, with contextual conversations, unread tracking, and notification delivery

## 1. Overview

The Messaging and Communication Centre provides authenticated in-app conversations between House Seekers and Landlords. Conversations are created from authorized contexts (property enquiry, site visit, tenancy, etc.) and support text messages, attachments, read receipts, and archival. Messages trigger notifications (in-app, push, email) via the existing `NotificationService` outbox infrastructure.

## 2. User Workflows

### Start a Conversation (House Seeker)

1. House Seeker views a property detail page or site visit.
2. Taps **Message Landlord** → `POST /api/v1/messaging/conversations` with body `{ type, propertyId, landlordUserId, message, subject? }`.
3. Backend validates the seeker's authorization for the property context (enquiry, site visit, etc.).
4. Creates a conversation (or reuses an existing active one) with the seeker and landlord as participants.
5. Inserts the first message and emits a `message.created` notification outbox event.
6. Seeker is navigated to the conversation thread at `/house-seeker/conversations/:conversationId`.

### View Conversations (Inbox)

1. User navigates to `/house-seeker/conversations` (seeker) or landlord inbox.
2. `GET /api/v1/messaging/conversations` returns cursor-paginated conversations with unread counts, last message preview, and property context.
3. Tapping a conversation opens the thread at `/house-seeker/conversations/:conversationId`.
4. Opening a conversation calls `POST /api/v1/messaging/conversations/:conversationId/read` to mark messages as read.

### Send a Message

1. User types a message in the conversation thread.
2. Submits → `POST /api/v1/messaging/conversations/:conversationId/messages` with body `{ content, type?, replyToId? }`.
3. Backend validates participant authorization, inserts the message, and emits a `message.created` outbox event (idempotency key `message.created:<messageId>`).
4. The message appears in the thread; the other participant receives a notification (in_app/push/email per their preferences).

### Attachments

1. User attaches a file → `POST /api/v1/messaging/conversations/:conversationId/attachments` (multipart/form-data, 10 MB max, mime allowlist).
2. File is stored in S3 private storage with a rollback delete on failure.
3. Download uses a short-lived presigned URL via `GET /api/v1/messaging/attachments/:attachmentId`.

## 3. Backend Architecture

### Module: `server/src/modules/messaging/`

| File | Responsibility |
|------|----------------|
| `messaging.repository.ts` | Cursor helpers (`encodeMessageCursor`/`decodeMessageCursor`), `assertActiveParticipant`, `listConversationsForUser`, `listMessages` (keyset pagination), `findActivePropertyConversation`, attachment CRUD |
| `messaging.service.ts` | Authorization (`derivePropertyManagers`/`resolveContext` with `allowInitiatorJoin`), race-safe dedup via `pg_advisory_xact_lock(hashtext(...))`, `startConversation`/`sendMessage` (transactional + outbox), `markRead`, `archive`/`reopen` |
| `messaging.schema.ts` | Zod schemas for request validation |
| `messaging.controller.ts` | Multer (10 MB, mime allowlist), S3 private storage + rollback, HTTP handlers |
| `messaging.routes.ts` | Express router mounted at `/api/v1/messaging` in `app.ts` |
| `messaging.test.ts` | Integration tests (17 tests) |

### Authorization Model

- Conversations are accessible only to **active participants** (`assertActiveParticipant`).
- Managers are derived from property ownership and unit assignment (`derivePropertyManagers`), restricted to the staff assignment types `property_manager` and `letting_agent`.
- Caretakers (and maintenance/security/other staff) with unit or property access **must not** inherit landlord messaging privileges — only ownership or a staff assignment grants manager standing.
- Rental application / rental proposal contexts resolve participants to the applicant/renter plus the property's managers; revoked or expired assignments remove access immediately (verified on every `startConversation`).
- No `site_visit.manage` permission row exists; the RBAC check is bypassed in favour of context-based ownership.

### Contextual Messaging Entry Points (Task 10.4)

A single shared flow (`startConversation`) backs four entry points; none create private duplicate threads:

1. **Landlord / manager → applicant** from the rental application review surface (`rentalApplicationId`).
2. **Seeker → landlord** from a rental proposal (`rentalProposalId`).
3. **Landlord / manager → renter** from the landlord proposal review surface (`rentalProposalId`).
4. **Counter-offer / negotiation** for both parties, reusing the application/proposal thread.

Each entry point sends the business context id; the backend dedups per context (`conversations.rental_application_id` / `rental_proposal_id`) so repeated taps reuse one thread.

### Outbox Reliability (Task 10.4)

- Critical lifecycle events (`application.*`, `proposal.accepted/declined/counter/changes_requested/withdrawn/confirmed/expired`) are persisted to `notification_outbox` **in the same transaction** as the business state change (`enqueueOutboxEventTransactional`). If the outbox insert fails, the state change rolls back — no silent, un-notified mutation.
- Proposal expiry (`expireOverdueProposals`) is atomic: the status transition and its `proposal.expired:<id>` event share one transaction. Concurrent sweeps transition each proposal exactly once (READ COMMITTED re-evaluation) and the outbox key dedups any redelivery.
- Counter-offers use version-scoped idempotency keys (`proposal.counter:<id>:v<n>`) so distinct negotiation rounds produce distinct events.
- The pg-boss worker (`processOutboxEvent`) is idempotent: a redelivered job for an already-`completed`/`processing` event is a no-op, so notifications are never duplicated.

### Concurrency and Dedup

- `startConversation` uses `pg_advisory_xact_lock(hashtext(...))` to serialize concurrent "start conversation" requests for the same property+landlord pair, preventing duplicate conversations.
- `sendMessage` is transactional and emits an idempotent outbox event with key `message.created:<messageId>`.

### Notification Integration

- `NotificationService.createOutboxEvent(...)` is called with channels `in_app`, `push`, `email`.
- The pg-boss worker drains via `processOutboxEvent(outboxId)` (idempotent).
- `shouldSendViaChannel` checks category-channel preference keys (e.g., `propertyInApp`, `propertyPush`). The snake_case bug (`'propertyIn_app'` → `'propertyInApp'`) was fixed by capitalizing each `_`-separated segment.
- Templates are seeded in migration `091_seed_message_notification_templates.sql` (privacy-safe en/sw, no message body) and `091` sets `created_by` nullable with `ON DELETE SET NULL` (migration `092`).

## 4. Database Schema

### Migration `090_messaging_centre_support.sql`

Adds `archived_at` to `conversations` plus indexes for cursor pagination and unread counting.

### Migration `091_seed_message_notification_templates.sql`

Seeds `message_notification_templates` with en/sw templates for `message.created` events. No message body is included in the template (privacy-safe).

### Migration `092_notification_templates_created_by_set_null.sql`

Makes `notification_templates.created_by` nullable with `ON DELETE SET NULL` to prevent FK fragility during auth test cleanup.

### Migration `095_conversation_rental_application_link.sql`

Adds `conversations.rental_application_id` (FK to `rental_applications`, `ON DELETE CASCADE`) and completes the `rental_proposal_id` FK, enabling per-application / per-proposal conversation deduplication.

### Migration `096_add_rental_application_conversation_type.sql`

Extends the `conversation_type` enum with `rental_application` so application-scoped conversations can be persisted (previously rejected as an invalid enum value).

## 5. API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/messaging/conversations` | List conversations (cursor-paginated) |
| `POST` | `/api/v1/messaging/conversations` | Start (or reuse) a conversation |
| `GET` | `/api/v1/messaging/conversations/unread-count` | Total unread count |
| `GET` | `/api/v1/messaging/conversations/:conversationId` | Conversation detail with participants |
| `GET` | `/api/v1/messaging/conversations/:conversationId/messages` | List messages (cursor-paginated) |
| `POST` | `/api/v1/messaging/conversations/:conversationId/messages` | Send a message |
| `POST` | `/api/v1/messaging/conversations/:conversationId/read` | Mark all as read |
| `POST` | `/api/v1/messaging/conversations/:conversationId/archive` | Archive conversation |
| `POST` | `/api/v1/messaging/conversations/:conversationId/reopen` | Reopen conversation |
| `POST` | `/api/v1/messaging/conversations/:conversationId/attachments` | Upload attachment |
| `POST` | `/api/v1/messaging/messages/:messageId/read` | Mark single message as read |
| `GET` | `/api/v1/messaging/attachments/:attachmentId` | Presigned download URL |

All endpoints require `bearerAuth` and enforce participant authorization.

## 6. Flutter Frontend

### Pages

| File | Route | Description |
|------|-------|-------------|
| `house_seeker_conversations_page.dart` | `/house-seeker/conversations` | Inbox list with unread badges, loading/empty/error states |
| `house_seeker_conversation_page.dart` | `/house-seeker/conversations/:conversationId` | Thread with message bubbles (mine vs theirs), send field, mark-read on open |

### State

- `houseSeekerConversationsProvider` — `FutureProvider<List<ConversationModel>>`
- `houseSeekerMessagesProvider` — `FutureProvider.family<List<MessageModel>, String>`
- Both read from `houseSeekerRepositoryProvider`

### Repository Methods

- `getConversations({limit, offset})`
- `getMessages(conversationId, {limit, offset})`
- `sendMessage({conversationId, content})`
- `markConversationRead(conversationId)`
- `startConversation({propertyId, landlordUserId, message, ...})`

### Avatar Source

Message avatars use `user_profiles.profile_photo_url` (NOT `users.avatar_url`).

## 7. Localization

- English and Swahili ARB files (`app_en.arb`, `app_sw.arb`) include messaging keys.
- Conversation and message text is user-provided (not localized).

## 8. Testing

### Backend

- `server/src/modules/messaging/messaging.test.ts` — 17 integration tests covering authorization, dedup, pagination, read tracking, archival, and attachment upload/download.
- `server/src/modules/rental-applications/rental-application.test.ts` — includes Task 10.4 regressions:
  - Outbox insert failure rolls back the critical application state change (trigger-injected failure).
  - Concurrent + repeated proposal expiry sweeps emit exactly one `proposal.expired:<id>` event.
  - Distinct counter versions produce distinct `proposal.counter:<id>:v<n>` events.
  - Worker retry (`processOutboxEvent` twice) does not duplicate notifications.
  - Conversation reuse per application / proposal across both parties, with context linkage preserved.
  - Non-participants, caretakers, and revoked managers are denied (403).

### Flutter

- `Mobile/test/features/house_seeker/house_seeker_messaging_test.dart` — 10 widget tests covering:
  - Loading skeleton for inbox and thread
  - Empty state for inbox and thread
  - Conversation tile rendering (subject, location, unread badge)
  - Message bubble rendering
  - Send button disabled state
  - Send message flow (repository interaction, field cleared)
  - Send failure snackbar
  - `AppNotice` error rendering (in isolation)
- `Mobile/test/features/house_seeker/house_seeker_proposals_test.dart` — verifies the proposal "Message landlord" action reuses `startConversation` with the `rentalProposalId`.
- `Mobile/test/features/rental_applications/rental_application_test.dart` — verifies the review surface "Message applicant" action reuses `startConversation` with the `rentalApplicationId`.
- `Mobile/test/features/property_management/landlord_proposals_page_test.dart` — verifies the landlord proposal review "Message renter" action reuses `startConversation` with the `rentalProposalId`.

## 9. OpenAPI

Messaging endpoints are documented in `server/openapi.yaml` under the `Messaging` tag with full request/response schemas (`Conversation`, `Message`, `MessageListResponse`, `StartConversationRequest`, etc.).

## 10. Verification

- Backend: `npx tsc --noEmit` (clean), `npx vitest run` (416 tests pass across 30 files)
- Flutter: `flutter analyze` (0 errors), `flutter test --dart-define=API_BASE_URL=...` (169 tests pass)
- OpenAPI: parses cleanly, 56 paths, 56 schemas, 0 unresolved refs