# House Seeker Site Visit Scheduling and Management — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** Site visit scheduling and management for House Seekers, plus landlord-side site visit administration

## 1. Overview

House Seekers can request site visits to view properties, and Landlords can confirm, decline, reschedule, or cancel those visits. The feature spans the Node.js backend (API routes, repository, controller, database migration, notification templates) and the Flutter frontend (house seeker visits page, landlord visits page, landlord visit detail page, Riverpod state management, localization).

## 2. User Workflows

### Request a Site Visit (House Seeker)

1. House Seeker views a listing detail page.
2. Fills in the visit request form: preferred date/time, duration, contact phone, notes to landlord.
3. Submits → `POST /api/v1/house-seeker/site-visits` with body `{ listingId, scheduledAt, durationMinutes, visitorPhone, visitorNotes }`.
4. Backend acquires `pg_advisory_xact_lock` on the listing to prevent concurrent double-booking.
5. Validates availability rules and blackout exceptions; checks for conflicting visits.
6. Creates the visit with status `scheduled` and emits a `site_visit_requested` notification outbox event.
7. House Seeker sees their visits at `/house-seeker/visits`.

### Manage Site Visits (Landlord)

1. Landlord navigates to `/landlord/site-visits` to view all incoming visit requests.
2. Visits are listed with status badges (scheduled, confirmed, completed, cancelled, declined, no_show, rescheduled).
3. Landlord can filter by status and pull to refresh.
4. Actions per visit:
   - **Confirm** → `POST /api/v1/landlord/site-visits/:visitId/confirm` → status `confirmed`
   - **Decline** → `POST /api/v1/landlord/site-visits/:visitId/decline` → status `declined`
   - **Reschedule** → `POST /api/v1/landlord/site-visits/:visitId/reschedule` → new `scheduledAt`/`durationMinutes`
   - **Cancel** → `POST /api/v1/landlord/site-visits/:visitId/cancel` → status `cancelled`
5. Landlord can view visit details at `/landlord/site-visits/:visitId`.

### House Seeker Visit Management

1. House Seeker views their visits at `/house-seeker/visits`.
2. Can cancel a scheduled visit (confirmation dialog).
3. Can reschedule a scheduled visit (date/time picker form).
4. Status badges indicate current state.

## 3. Database Schema

### Migration `087_create_site_visit_availability_and_links.sql`

Adds `enquiry_id` and `assigned_to_user_id` columns to `site_visits`, plus two new tables:

| Table | Purpose |
|-------|---------|
| `site_visit_availability_rules` | Landlord-defined availability windows (day of week, start/end time, isActive) |
| `site_visit_availability_exceptions` | Blackout dates where visits are not allowed |

### Migration `088_seed_site_visit_notification_templates.sql`

Seeds notification template rows for site visit events (requested, confirmed, declined, cancelled, rescheduled, reminders at 24h and 2h) in English and Swahili.

### Migration `089_create_site_visit_reminder_jobs.sql`

Adds `site_visit_reminder_jobs` plus the reminder notification templates consumed by the pg-boss reminder worker.

## 4. Backend API

### House Seeker Routes (`/api/v1/house-seeker/site-visits`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/site-visits` | Request a site visit (transactional, availability- and conflict-checked) |
| GET | `/site-visits` | List the user's site visits (with filters) |
| GET | `/site-visits/:visitId` | Get a single site visit |
| POST | `/site-visits/:visitId/cancel` | Cancel a visit |
| POST | `/site-visits/:visitId/reschedule` | Reschedule a visit (re-checks overlap) |

Listing availability lookup (bookable slot grid, interpreted in `Africa/Nairobi`):

| Method | Path | Description |
|--------|------|-------------|
| GET | `/house-seeker/listings/:listingId/availability?date=YYYY-MM-DD` | Bookable slots for a listing on a local date |

### Landlord Routes (`/api/v1/landlord/site-visits`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/site-visits` | List all site visits for the landlord's owned/assigned properties |
| GET | `/site-visits/:visitId` | Get a single site visit |
| POST | `/site-visits/:visitId/confirm` | Confirm a visit (revalidates availability) |
| POST | `/site-visits/:visitId/decline` | Decline a visit (status becomes `cancelled`) |
| POST | `/site-visits/:visitId/reschedule` | Reschedule a visit (re-checks overlap) |
| POST | `/site-visits/:visitId/cancel` | Cancel a visit by landlord |
| POST | `/site-visits/:visitId/complete` | Mark a confirmed visit completed |
| POST | `/site-visits/:visitId/no-show` | Mark a confirmed visit as no-show |

### Landlord availability management (`/api/v1/landlord/properties/:propertyId/site-visit-availability`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/site-visit-availability` | List rules and blackout/partial-day exceptions |
| PUT | `/site-visit-availability/rules` | Upsert a weekly availability rule (unique per day-of-week) |
| DELETE | `/site-visit-availability/rules/:ruleId` | Remove a rule |
| PUT | `/site-visit-availability/exceptions` | Upsert a dated exception (blackout or partial-day window) |
| DELETE | `/site-visit-availability/exceptions/:exceptionId` | Remove an exception |

### Validation

- `VISIT_TRANSITIONS` map (in `site-visits/site-visit.service.ts`) defines valid status transitions. `decline` is not a status: a declined request is stored as `cancelled` with history action `declined`.
- Write operations run in a single transaction and acquire `pg_advisory_xact_lock(hashtext(property_id))` so concurrent requests for the same property are serialised.
- `evaluateAvailability()` is the single authority for bookability: it enforces the weekday window, blackout exceptions (`is_unavailable`), partial-day exception windows, buffer spacing, and `max_bookings_per_slot` capacity.
- Creating a visit requires a published availability rule for the requested weekday (landlords must publish availability first); confirmation revalidates availability at the visit time.
- `hasOverlappingVisit()` guards reschedules against moving a visit onto an already-occupied interval.
- Times are stored as `TIMESTAMPTZ` (UTC) and interpreted/displayed in `Africa/Nairobi`.

## 5. Backend Implementation Layers

| Layer | File | Responsibility |
|-------|------|---------------|
| Lifecycle service | `server/src/modules/site-visits/site-visit.service.ts` | Availability evaluation, transition table, UTC/Nairobi helpers, advisory lock key |
| Lifecycle writer | `server/src/modules/site-visits/site-visit-lifecycle.ts` | Transactional create/confirm/decline/cancel/reschedule/complete/no-show, history, outbox emission |
| Reminder worker | `server/src/modules/site-visits/site-visit-reminder.worker.ts` | pg-boss worker dispatching 24h/2h reminders idempotently |
| Routes (house-seeker) | `server/src/modules/house-seeker/house-seeker.routes.ts` | Seeker site-visit endpoints + listing availability lookup |
| Routes (landlord) | `server/src/modules/landlord/landlord.routes.ts` | Landlord visit + availability-management endpoints |
| Controller (house-seeker) | `server/src/modules/house-seeker/house-seeker.controller.ts` | `requestSiteVisit`, `listSiteVisits`, `getSiteVisit`, `cancelSiteVisit`, `rescheduleSiteVisit`, `getListingAvailability` |
| Controller (landlord) | `server/src/modules/landlord/landlord.controller.ts` | `listLandlordSiteVisits`, `getLandlordSiteVisit`, `confirmSiteVisit`, `declineSiteVisit`, `rescheduleSiteVisit`, `cancelSiteVisitByLandlord`, `completeSiteVisit`, `markSiteVisitNoShow`, availability CRUD |
| Repository | `server/src/modules/landlord/landlord.repository.ts` | Visit listing, availability rule/exception persistence |
| Migration | `server/src/db/migrations/087_create_site_visit_availability_and_links.sql` | `enquiry_id`/`assigned_to_user_id` links + availability tables |
| Migration | `server/src/db/migrations/088_seed_site_visit_notification_templates.sql` | Notification templates (en/sw) |
| Migration | `server/src/db/migrations/089_create_site_visit_reminder_jobs.sql` | Reminder job table + reminder templates |

## 6. Flutter Implementation

### State Management (`property_state.dart`)

| Provider | Type | Purpose |
|----------|------|---------|
| `siteVisitsProvider` | `Provider<List<SiteVisit>>` | Landlord's site visits list |
| `selectedSiteVisitProvider` | `Provider<SiteVisit?>` | Currently selected visit detail |
| `siteVisitLoadingProvider` | `Provider<bool>` | Loading state |
| `siteVisitErrorProvider` | `Provider<String?>` | Error state |

### `PropertyNotifier` Methods (site visits)

- `loadSiteVisits({propertyId, status})` — fetches landlord's visits
- `loadSiteVisit(visitId)` — fetches a single visit
- `confirmSiteVisit({visitId, hostNotes})` — confirms a visit
- `declineSiteVisit({visitId, reason})` — declines a visit
- `rescheduleSiteVisit({visitId, scheduledAt, durationMinutes, hostNotes})` — reschedules
- `cancelSiteVisit({visitId, reason})` — cancels a visit

### Site Visit Entity (`property.dart`)

`SiteVisit` class with fields: `id`, `propertyId`, `unitId`, `userId`, `visitorName`, `visitorPhone`, `visitorEmail`, `scheduledAt`, `durationMinutes`, `status`, `visitorNotes`, `hostNotes`, `outcome`, `enquiryId`, `assignedToUserId`, `createdAt`, `updatedAt`.

Computed properties: `canConfirm`, `canDecline`, `canReschedule`, `canComplete`, `canCancel`.

### UI Pages

| File | Purpose |
|------|---------|
| `landlord_site_visits_page.dart` | Landlord visits list with status filter, action buttons (confirm/decline/reschedule/cancel/details) |
| `landlord_site_visit_detail_page.dart` | Visit detail view with action buttons |
| `house_seeker_visits_page.dart` | House Seeker's visits list with cancel/reschedule |

### Routes (`app_router.dart`)

- `/landlord/site-visits` — landlord visits list (auth-guarded)
- `/landlord/site-visits/:visitId` — landlord visit detail (auth-guarded)
- `/landlord/site-visits/:visitId/reschedule` — reschedule (auth-guarded)

### Localization (`app_en.arb`, `app_sw.arb`)

45 site visit keys covering: visit request form, visit list, status labels, confirm/decline/cancel/reschedule dialogs, success messages, visit details, reminders.

## 7. Testing

### Backend

- Site visit suite: `server/src/modules/site-visits/site-visit.test.ts` (52 tests) covering eligibility, availability windows/capacity/buffers, blackout and partial-day exceptions, concurrent booking, lifecycle transitions and history, transactional outbox + notification materialisation, reminder idempotency, and authorization (seeker/landlord/caretaker scoping).
- Full backend suite: 353 tests across 27 files pass.
- Typecheck clean (`NODE_OPTIONS=--max-old-space-size=6144 npx tsc --noEmit`).

### Flutter

- `house_seeker_visits_test.dart`: 4 tests (empty state, visit list with status badges, cancel visit, Swahili empty state) — all pass
- Full Flutter test suite: 133 tests pass
- `flutter analyze`: no new errors (only pre-existing info-level warnings)

## 8. Notes

- Site visits are linked to listings and optionally to enquiries.
- Availability is authoritative: a visit can only be created for a weekday the landlord has published, within its window and remaining capacity; confirmation revalidates the same rules.
- Declining a request records history action `declined` but stores status `cancelled` (there is no `declined` enum value).
- Advisory locking plus in-transaction checks prevent concurrent over-booking; slot capacity is governed solely by `evaluateAvailability` (the earlier raw-overlap guard would have blocked legitimate multi-booking slots).
- Notification outbox events are emitted transactionally with each state change; `NotificationService.processOutboxEvent` materialises persistent `notifications` rows and per-channel delivery attempts honouring user preferences (including `in_app`).
- A pg-boss worker (`site-visit-reminder.worker.ts`) dispatches 24h/2h reminders idempotently per scheduled instant.
- House seeker visits page (`/house-seeker/visits`) was pre-existing; landlord-side pages are new.
- `openapi.yaml` currently does not describe the site-visit/availability paths and is structurally malformed from earlier work (duplicate `components:` keys, params/paths interleaved); it needs a dedicated repair pass. The architecture documented here reflects the implemented behaviour and test suite.
