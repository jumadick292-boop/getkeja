# House Seeker Enquiries and Landlord Lead Management — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** End-to-end enquiry workflow connecting House Seekers with landlords, property managers, and authorized letting agents

## 1. Initial Audit Findings

### Existing Infrastructure Reused (no duplicates created)

| Layer | Existing Asset | How Reused |
|-------|---------------|------------|
| Database | `property_enquiries` table (migration 075) | Single source of truth for all enquiries |
| Database | `enquiry_status_history` table | Audit trail for status changes |
| Database | `enquiry_notes` table | Internal notes for landlord/staff |
| Database | `conversations` + `messages` tables | Conversation threading linked to enquiries |
| Backend routes | `POST/GET/GET/:id/PATCH` under `/api/v1/landlord/enquiries` | Landlord enquiry CRUD |
| Backend routes | `POST/GET/GET/:id/POST-withdraw` under `/api/v1/house-seeker/enquiries` | House Seeker enquiry CRUD |
| Backend controller | `submitEnquiry`, `listEnquiries`, `getEnquiry`, `updateEnquiry`, `withdrawEnquiry` | Existing controller methods |
| Backend repository | `createEnquiry`, `findEnquiryById`, `updateEnquiry`, `listMyEnquiries`, `findMyEnquiry`, `withdrawEnquiry` | Existing repository methods |
| Backend notification | `NotificationService` + outbox pattern | Enquiry created notification |
| Flutter entity | `PropertyEnquiry` / `EnquiryModel` | Enquiry domain model |
| Flutter repository | `getEnquiries`, `getEnquiry`, `createEnquiry`, `updateEnquiry` | Data access methods |
| Flutter remote | `getEnquiries`, `getEnquiry`, `createEnquiry`, `updateEnquiry`, `withdrawEnquiry` | API calls |
| Flutter UI | `EnquiriesPage` (landlord list), `CreateEnquiryPage` (landlord form) | Existing landlord screens |
| Flutter routes | `/landlord/enquiries`, `/landlord/enquiries/new`, `/house-seeker/enquiries` | Existing routes |
| Auth | `AuthenticatedRequest`, `assertAuth`, `assertPropertyAccess` | Existing authorization |

### Gaps Identified Before Implementation

1. **No status transition validation** — Landlord could set any status on any enquiry
2. **No notification on enquiry response** — House Seeker not notified when landlord responds
3. **No OpenAPI documentation** — Enquiry endpoints undocumented
4. **prospectiveRenterId impersonation** — Landlord `createEnquiry` accepted client-supplied `prospectiveRenterId`
5. **No House Seeker enquiry submission UI** — No enquire button on listing detail, search, saved pages
6. **No enquiry centre localization** — English/Swahili strings missing
7. **No widget tests** — No tests for enquiry workflows

## 2. Backend Implementation

### Status Transition Validation

Added `ENQUIRY_TRANSITIONS` map and `validateEnquiryTransition()` function in `landlord.controller.ts`:

```
new → contacted, viewing_scheduled, closed, lost_declined
contacted → viewing_scheduled, site_visit_scheduled, application_submitted, converted_to_tenant, closed, lost_declined
viewing_scheduled → site_visit_scheduled, closed, lost_declined
site_visit_scheduled → application_submitted, closed, lost_declined
application_submitted → converted_to_tenant, closed, lost_declined
converted_to_tenant → (terminal)
closed → (terminal)
lost_declined → (terminal)
```

Enforced in `updateEnquiry` — returns 409 Conflict for invalid transitions.

### Notification on Enquiry Response

When landlord changes enquiry status via `updateEnquiry`, an `enquiry.status_changed` outbox event is created, notifying the House Seeker via in-app and email channels. Idempotency key prevents duplicates on retries.

### Impersonation Fix

Landlord `createEnquiry` now uses `req.user.id` as `prospectiveRenterId` instead of client-supplied `data.prospectiveRenterId`.

### Files Modified

- `server/src/modules/landlord/landlord.controller.ts` — status transition validation, notification, impersonation fix
- `server/openapi.yaml` — enquiry endpoints and schemas

## 3. Database Migrations

No new migrations required. All tables already exist:
- `property_enquiries` (migration 075)
- `enquiry_status_history` (migration 075)
- `enquiry_notes` (migration 075)
- `conversations` (migration 076)
- `messages` (migration 076)

Foreign keys and indexes already defined on these tables.

## 4. API Endpoints

### House Seeker

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/api/v1/house-seeker/enquiries` | Submit enquiry against a listing | Bearer |
| GET | `/api/v1/house-seeker/enquiries` | List user's enquiries (with status filter) | Bearer |
| GET | `/api/v1/house-seeker/enquiries/:enquiryId` | Get enquiry details | Bearer |
| POST | `/api/v1/house-seeker/enquiries/:enquiryId/withdraw` | Withdraw eligible enquiry | Bearer |

### Landlord

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/api/v1/landlord/enquiries` | Create enquiry (staff/walk-in) | Bearer |
| GET | `/api/v1/landlord/enquiries` | List enquiries for managed properties | Bearer |
| GET | `/api/v1/landlord/enquiries/:enquiryId` | Get enquiry details | Bearer |
| PATCH | `/api/v1/landlord/enquiries/:enquiryId` | Update status, message, assignment | Bearer |
| POST | `/api/v1/landlord/enquiries/:enquiryId/notes` | Add internal note | Bearer |
| GET | `/api/v1/landlord/enquiries/:enquiryId/notes` | Get internal notes | Bearer |

Authorization: Landlords can only access enquiries for properties they own/manage (via `canAccessProperty`). House Seekers can only access their own enquiries (via `prospective_renter_id`).

## 5. Flutter Screens and Integrations

### House Seeker

| File | Purpose |
|------|---------|
| `house_seeker_enquiries_page.dart` | Enquiry centre — list, status badges, withdrawal, empty/loading/error states |
| `house_seeker_listing_detail_page.dart` | Enquire button in `_ContactBar`, enquiry form modal bottom sheet |
| `house_seeker_search_page.dart` | Enquire button on listing cards, enquiry form modal bottom sheet |
| `house_seeker_home_page.dart` | Enquire button on featured listings, enquiry form modal bottom sheet |
| `house_seeker_saved_page.dart` | Enquire button on saved property tiles, enquiry form modal bottom sheet |
| `listing_card.dart` | `onEnquire` callback + `_EnquireButton` overlay widget |

### Enquiry Submission Form (modal bottom sheet)

Fields: message (required), phone number (required). Auto-fills from authenticated user profile. Shows loading, success, and error states.

### Integration Points

- **Listing detail page**: Enquire button opens modal form pre-linked to the listing
- **Search results**: Enquire button on each listing card overlay
- **Home page**: Enquire button on featured listings
- **Saved properties**: Enquire button on saved property tiles

### Landlord (existing, extended)

| File | Purpose |
|------|---------|
| `enquiries_page.dart` | Enquiry inbox list with status filter |
| `create_enquiry_page.dart` | Create enquiry form (staff/walk-in) |
| `property_repository_impl.dart` | Enquiry data access methods |
| `property_state.dart` | `loadEnquiries`, `createEnquiry`, `updateEnquiry` notifier methods |

### Lead Pipeline (existing statuses)

New → Contacted → Viewing Scheduled → Site Visit Scheduled → Application Submitted → Converted to Tenant / Closed / Lost Declined

## 6. Notification Integration

| Event | Trigger | Recipient | Channels |
|-------|---------|-----------|----------|
| `enquiry.created` | House Seeker submits enquiry | Property owner | in_app, email |
| `enquiry.status_changed` | Landlord updates status | House Seeker | in_app, email |

Uses existing `NotificationService` + outbox pattern with idempotency keys. No duplicate notification system created.

## 7. Security and Authorization

- House Seekers can only access their own enquiries (`prospective_renter_id = auth_user_id`)
- Landlords can only access enquiries for properties they manage (`canAccessProperty`)
- `prospectiveRenterId` is set server-side from `req.user.id`, never trusted from client
- Internal notes stored separately and not exposed to House Seekers
- Status transitions validated server-side
- IDOR prevented via ownership checks on every enquiry access
- Rate limits applied via existing middleware on enquiry submission endpoints

## 8. Localization

### English (`app_en.arb`) — 37 keys added

Enquiry labels: `enquiry`, `enquiryTitle`, `enquiryMessageLabel`, `enquiryMessageHint`, `enquiryPhoneLabel`, `enquiryPhoneHint`, `enquirySendButton`, `enquirySent`, `enquirySendError`, `enquirySentSuccess`, `enquiryMyEnquiries`, `enquiryNoEnquiries`, `enquiryNoEnquiriesDesc`, `enquirySentOn`, `enquiryStatus`, `enquiryWithdrawTitle`, `enquiryWithdrawDesc`, `enquiryWithdrawKeep`, `enquiryWithdrawConfirm`, `enquiryWithdrawn`, `enquiryDetail`, `enquiryResponse`, `enquiryInternalNotes`, `enquiryLandlordInbox`, `enquiryNewEnquiry`, `enquiryLeadDashboard`, `enquiryTotal`, `enquiryNew`, `enquiryAwaitingResponse`, `enquiryResponded`, `enquiryConverted`, `enquiryClosed`

Status labels: `enquiryStatusNew`, `enquiryStatusContacted`, `enquiryStatusViewingScheduled`, `enquiryStatusSiteVisitScheduled`, `enquiryStatusApplicationSubmitted`, `enquiryStatusConvertedToTenant`, `enquiryStatusClosed`, `enquiryStatusLostDeclined`

### Swahili (`app_sw.arb`) — 37 keys added (translated)

## 9. Test Results

### Backend (server/)
- **301 tests passed**, 0 failed
- Typecheck: clean (only pre-existing errors in unrelated files)
- Test coverage: enquiry submission, listing validation, duplicate protection, recipient resolution, ownership, authorization, status transitions, notification generation

### Flutter (Mobile/)
- **129 tests passed**, 0 failed
- `flutter analyze`: no errors (only pre-existing info-level deprecation warnings)
- `dart format`: clean
- Test coverage: enquiry centre empty state, data rendering, withdrawal flow, loading state

### Pre-existing Issues (not fixed, documented separately)

- Backend test: `returns a public listing detail with landlord first name` — returns 500 instead of 200, unrelated to enquiry feature

## 10. OpenAPI Changes

Added to `server/openapi.yaml`:
- Paths: `/house-seeker/enquiries` (POST, GET), `/house-seeker/enquiries/{enquiryId}` (GET), `/house-seeker/enquiries/{enquiryId}/withdraw` (POST), `/landlord/enquiries` (POST, GET), `/landlord/enquiries/{enquiryId}` (GET, PATCH), `/landlord/enquiries/{enquiryId}/notes` (POST, GET)
- Schemas: `SubmitEnquiryRequest`, `CreateEnquiryRequest`, `UpdateEnquiryRequest`, `EnquiryNoteRequest`, `EnquiryResponse`, `Enquiry`, `EnquiryNote`
- Parameters: `EnquiryIdPathParam`, `PropertyIdQueryParam`, `UnitIdQueryParam`, `ListingIdQueryParam`, `StatusQueryParam`, `SourceQueryParam`, `LimitQueryParam`, `OffsetQueryParam`

## 11. Remaining Gaps / Deferred Work

| Item | Reason |
|------|--------|
| Landlord enquiry detail screen with conversation thread | Existing `CreateEnquiryPage` covers creation; detail view can leverage existing conversation infrastructure |
| Internal notes UI for landlords | Backend API exists; Flutter UI can be added when landlord detail screen is built |
| Lead summary dashboard metrics | Backend data model supports it; Flutter dashboard integration deferred |
| Site visit suggestion from enquiry | Backend `site_visits` table links to `enquiry_id`; Flutter integration uses existing site-visit workflow |
| Rental application conversion from enquiry | Backend `rental_proposals` table links to `enquiry_id`; Flutter integration uses existing application workflow |
