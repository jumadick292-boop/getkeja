# Task 13.10 — Provider Communications & Customer Experience Report

## 1. Initial audit findings
- Messaging (`conversations`/`messages`/participants) + central `startConversation`
  with advisory-lock dedup and ownership-derived participants existed but only
  wired enquiry/site-visit/tenancy/rental/property contexts. `moving_job` type +
  column existed but was unused; marketplace/garbage/laundry/scheduling had no
  conversation integration.
- Notification subsystem (templates, notifications, preferences, delivery
  attempts, dead letters, outbox + pg-boss worker) existed. Gaps: push unwired,
  no verified-contact enforcement, no security/marketing send-time rules, no
  locale resolution, template lookup keyed on `template_key` while callers passed
  `event_type` (mismatch), no deep links, outbox `recipientId=null`.
- Flutter: `features/notifications` inbox existed; messaging only under
  house_seeker; no contact-provider entry points on service detail pages.
- Full audit: `docs/architecture/provider-communications-audit.md`.

## 2. Existing infrastructure reused
conversations/messages tables, `startConversation`, notification tables +
outbox + worker, `enqueueOutboxEventTransactional`/`classifyEventType`, Flutter
inbox, design system, Riverpod/GoRouter/Dio, l10n. **No** new messaging/
notification/outbox/queue introduced.

## 3. Conversation context & authorization design
Migration 120 adds 4 conversation types + 4 context columns + per-context partial
unique indexes. Per-domain resolvers derive participants = customer + org
owners/admins + actively-assigned staff. Unassigned staff, revoked staff and
cross-provider id swaps are denied. Dedup via advisory lock + DB unique index.

## 4. Notification event catalogue
Reused existing CRITICAL events: `message.created`, `quotation.*`,
`service_request.*`, `moving_job.*`, `garbage_job.*`/`garbage_agreement.*`,
`laundry_order.*`, `schedule.*`. Added `message.created` in-app/push templates
(en/sw). No duplicate notification emission introduced.

## 5. Outbox & delivery architecture
Unchanged transactional outbox + pg-boss worker. `processOutboxEvent` now
resolves per-recipient locale + verification, applies verified-contact + security
+ marketing rules, and attaches deep links.

## 6. Retry & deduplication
Existing outbox `idempotency_key` dedup + worker capped exponential backoff +
dead-letter retained. `message.created` uses `message.created:<messageId>` key.

## 7. Notification preferences
Existing per-category × per-channel prefs. Added send-time enforcement:
verified-contact gating, security-always, marketing opt-in separation.

## 8. Localization & templates
Per-recipient locale (en/sw) with sw→en fallback; event-based template lookup
fix; deep links; no hand-edited generated files (used `flutter gen-l10n`).

## 9. Customer & provider Flutter workflows
Contact-provider entry on 4 customer detail pages → contextual conversation;
unified inbox with deep-link navigation; preferences screen; provider uses same
inbox/conversation entry from operational records.

## 10. Privacy & security controls
Participant authz, org isolation, revoked-staff denial, deep-link re-auth,
notification ownership, verified contacts, security protection, safe previews.

## 11. API & OpenAPI changes
Messaging endpoints documented (4 path templates / 5 operations) incl. new
conversation types + context ids; notifications/preferences already present.
OpenAPI valid: 226 paths.

## 12. Exact test results
- Server typecheck: clean.
- Migrations: fresh-schema build of all 120 migrations succeeded; re-run
  `migrate up` → `No pending migrations` (idempotent).
- Vitest: messaging 18/18; provider-communications 8/8; marketplace +
  provider-catalogue + messaging = 60/60; moving+garbage+laundry+scheduling+tenant
  = 42/42; notification 18/18 (clean DB).
- Flutter: `flutter analyze` 0 errors; notifications + messaging tests 34/34
  (incl. new comms_test 5/5).

## 13. Known limitations & deployment requirements
- `notification.test.ts` cleanup (`DELETE FROM users`) is not FK-complete, so it
  only passes on a clean DB — a **pre-existing** test-isolation weakness,
  unrelated to this task.
- Push provider classes exist but remain unwired at the delivery switch
  (pre-existing); in-app has no real-time fan-out (persisted + refresh-based).
- Requires Postgres with `btree_gist` (already used by scheduling) and the
  pg-boss worker enabled (`NOTIFICATION_OUTBOX_WORKER_ENABLED`).