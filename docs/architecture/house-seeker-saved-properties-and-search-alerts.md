# House Seeker Saved Properties & Search Alerts — Implementation

**Repository:** `get-keja-repo`  
**Backend:** `server/` (Node.js/Express/PostgreSQL)  
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)  
**Feature:** House Seeker saved properties, saved searches, automated search alerts

## 1. Overview

House Seekers can save properties they are interested in, save search criteria for later reuse, and receive automated notifications when new listings match their saved searches. The feature spans the Node.js backend (API routes, repository, search-alert matching, notification outbox) and the Flutter frontend (saved properties page, saved searches page with CRUD, notification inbox integration).

## 2. User Workflows

### Saved Properties
1. House Seeker browses listings on the search/home page.
2. Taps the heart/save icon on a listing card → `POST /saved-listings`.
3. Saved properties appear on the Saved Properties page (`/house-seeker/saved`).
4. Tapping a saved property navigates to its listing detail page.
5. Tapping the remove icon → `DELETE /saved-listings/:listingId` removes it.
6. Unpublished/withdrawn listings are flagged as unavailable in the UI.

### Saved Searches
1. House Seeker applies filters on the search page.
2. Taps "Save current" → enters a name, selects alert frequency (immediate/daily/weekly), toggles alerts on/off → `POST /saved-searches`.
3. Saved searches appear on the Saved Searches page (`/house-seeker/saved-searches`).
4. Tapping a saved search re-applies its criteria and navigates to the search results page.
5. Tapping "Edit" modifies name, criteria, alerts, or frequency → `PATCH /saved-searches/:searchId`.
6. Tapping "Delete" shows a confirmation dialog → `DELETE /saved-searches/:searchId`.
7. Tapping "Run now" executes the search immediately → `GET /saved-searches/:searchId/run`.

### Automated Search Alerts
1. When a listing is published or resumed by a landlord, the backend calls `searchAlertService.matchListingAgainstSavedSearches()`.
2. The service finds saved searches whose criteria match the new listing.
3. For each match, it checks the `search_alert_deduplication` table to avoid duplicate alerts.
4. If not already alerted, it creates a notification via `NotificationService.createAndSend()` with event type `saved_search.match`.
5. The notification appears in the House Seeker's notification inbox.

## 3. Saved-Property Lifecycle

| State | Trigger | API | Database |
|-------|---------|-----|----------|
| Saved | User taps save on listing | `POST /api/v1/house-seeker/saved-listings` | INSERT into `saved_listings` |
| Listed | User opens Saved Properties page | `GET /api/v1/house-seeker/saved-listings` | SELECT from `saved_listings` joined with listings |
| Removed | User taps remove on saved tile | `DELETE /api/v1/house-seeker/saved-listings/:listingId` | DELETE from `saved_listings` |
| Unavailable | Listing status changes from published | N/A (detected on read) | Listing status in `property_listings` |

## 4. Saved-Search CRUD

| Action | API | Request Body | Response |
|--------|-----|--------------|----------|
| Create | `POST /api/v1/house-seeker/saved-searches` | `{ name, criteria, alertsEnabled?, alertFrequency? }` | `SavedSearchModel` (201) |
| List | `GET /api/v1/house-seeker/saved-searches` | none | `{ items: SavedSearchModel[] }` |
| Update | `PATCH /api/v1/house-seeker/saved-searches/:searchId` | `{ name?, criteria?, alertsEnabled?, alertFrequency? }` | `SavedSearchModel` |
| Delete | `DELETE /api/v1/house-seeker/saved-searches/:searchId` | none | `{ success, message, data }` |
| Run | `GET /api/v1/house-seeker/saved-searches/:searchId/run` | `?limit=&offset=` | `{ items, total, limit, offset }` |

All endpoints require Bearer token authentication. Ownership is enforced at the repository level (`user_id` match).

## 5. Supported Search Criteria

Criteria are stored as JSONB in the `saved_searches.criteria` column. Supported keys:

| Key | Type | Description |
|-----|------|-------------|
| `q` | string | Keyword search (area, estate, price) |
| `city` | string | City filter |
| `county` | string | County filter |
| `neighbourhood` | string | Neighbourhood/address filter |
| `propertyType` | string | Property type (apartment, house, etc.) |
| `rentMin` | number | Minimum rent (KES) |
| `rentMax` | number | Maximum rent (KES) |
| `bedrooms` | number | Exact bedroom count |
| `bathrooms` | number | Minimum bathroom count |
| `furnished` | string | 'true' or 'false' |
| `amenities` | string | Comma-separated amenity list |
| `sort` | string | Sort order (newest, price_asc, price_desc, relevance) |

## 6. Alert Frequencies

| Frequency | Description |
|-----------|-------------|
| `immediate` | Alert as soon as a matching listing is published |
| `daily` | Daily digest of new matches |
| `weekly` | Weekly digest of new matches |

Default: `immediate`. Stored in `saved_searches.alert_frequency` with a CHECK constraint.

## 7. Backend Routes

All routes are under `/api/v1/house-seeker` and require authentication (`requireAuth` middleware).

### Saved Homes
| Method | Path | Description |
|--------|------|-------------|
| POST | `/saved-listings` | Save a listing |
| GET | `/saved-listings` | List saved listings (pagination) |
| DELETE | `/saved-listings/:listingId` | Remove a saved listing |

### Saved Searches
| Method | Path | Description |
|--------|------|-------------|
| POST | `/saved-searches` | Create a saved search |
| GET | `/saved-searches` | List saved searches |
| PATCH | `/saved-searches/:searchId` | Update a saved search |
| DELETE | `/saved-searches/:searchId` | Delete a saved search |
| GET | `/saved-searches/:searchId/run` | Execute a saved search |

## 8. Backend Route/Controller/Schema Mapping

`server/src/modules/house-seeker/house-seeker.routes.ts` — route definitions with zod validation.

`server/src/modules/house-seeker/house-seeker.controller.ts` — controller handlers:

| Handler | Line | Purpose |
|---------|------|---------|
| `save` | ~68 | Create saved listing |
| `listSaved` | ~83 | List saved listings |
| `unsave` | ~77 | Remove saved listing |
| `createSearch` | ~93 | Create saved search |
| `listSearches` | ~99 | List saved searches |
| `updateSearch` | ~105 | Update saved search |
| `removeSearch` | ~111 | Delete saved search |
| `runSavedSearch` | ~117 | Execute saved search |

`server/src/modules/house-seeker/house-seeker.schema.ts` — zod validation schemas:

| Schema | Purpose |
|--------|---------|
| `saveListingSchema` | Validate save listing body |
| `savedListingsQuerySchema` | Validate list saved listings query |
| `listingIdParamSchema` | Validate listing ID param |
| `createSavedSearchSchema` | Validate create saved search body |
| `updateSavedSearchSchema` | Validate update saved search body |
| `savedSearchIdParamSchema` | Validate saved search ID param |
| `runSavedSearchQuerySchema` | Validate run saved search query |

## 9. Database Tables

### `saved_listings`
Stores user-saved property references.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References `users.id` |
| `listing_id` | UUID | References `property_listings.id` |
| `collection` | text | Optional collection name |
| `notes` | text | Optional user notes |
| `created_at` | timestamptz | Save timestamp |

### `saved_searches`
Stores saved search criteria and alert settings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References `users.id` |
| `name` | text | User-defined search name |
| `criteria` | JSONB | Search criteria key-value map |
| `alerts_enabled` | boolean | Whether alerts are active |
| `alert_frequency` | varchar(20) | `immediate`, `daily`, or `weekly` (default `immediate`) |
| `last_run_at` | timestamptz | Last manual run timestamp |
| `last_alerted_at` | timestamptz | Last alert sent timestamp |
| `created_at` | timestamptz | Creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

### `search_alert_deduplication`
Tracks which listings have been alerted for which saved searches, preventing duplicate notifications.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References `users.id` |
| `saved_search_id` | UUID | References `saved_searches.id` |
| `listing_id` | UUID | References `property_listings.id` |
| `alert_sent_at` | timestamptz | When the alert was sent |
| `created_at` | timestamptz | Record creation timestamp |

Unique constraint on `(saved_search_id, listing_id)`.

### Migration

`085_add_alert_frequency_to_saved_searches.sql` — adds `alert_frequency` column with CHECK constraint, creates `search_alert_deduplication` table with indexes, adds `updated_at` trigger.

## 10. Search-Alert Matching & Deduplication

`server/src/modules/house-seeker/search-alert.service.ts` — `SearchAlertService` class.

### `matchListingAgainstSavedSearches(listingId)`
Called when a listing is published/resumed. Finds all active saved searches whose criteria match the listing, checks deduplication, and creates notifications.

### `runSavedSearch(userId, searchId, { limit, offset })`
Executes a saved search manually, applying its criteria against published listings. Updates `last_run_at`.

### Deduplication
Before creating a notification, the service checks `search_alert_deduplication` for an existing `(saved_search_id, listing_id)` pair. If one exists, no duplicate notification is created. Uses `INSERT ... ON CONFLICT DO NOTHING` for atomicity.

### Notification Metadata
Search alert notifications include:
- `eventType`: `"saved_search.match"`
- `category`: `"property"`
- `metadata`: `{ savedSearchId, listingId, listingTitle, listingLocation, listingPrice, searchName, summary }`

## 11. Listing Publication Hooks

`server/src/modules/landlord/landlord.controller.ts`:

- `publishListing` (~line 171): After setting listing status to `published`, calls `enqueueSearchAlert(listingId)`.
- `resumeListing` (~line 204): After resuming a listing to `published`, calls `enqueueSearchAlert(listingId)`.

`server/src/modules/house-seeker/search-alert.worker.ts` — `enqueueSearchAlert(listingId)` enqueues the matching job via pg-boss.

## 12. pg-boss Worker, Retries & Failure Handling

The search alert worker uses pg-boss (same infrastructure as the notification outbox worker). Jobs are retried with exponential backoff on transient failures. Permanent failures are moved to dead letters.

## 13. Notification Outbox & Delivery Lifecycle

`server/src/modules/auth/notification.service.ts`, `notification.repository.ts`, `notification.worker.ts`:

- `createAndSend()` inserts into `notifications` table and enqueues delivery via pg-boss outbox.
- The pg-boss worker processes outbox entries, attempts delivery via configured channels (email, sms, push, in_app).
- Delivery attempts are recorded in `notification_delivery_attempts`.
- Failed deliveries are retried; persistent failures go to `notification_dead_letters`.
- House Seeker notification APIs: `GET /notifications`, `GET /notifications/:id`, `GET /unread-count`, `POST /mark-read`, `POST /mark-all-read`, `DELETE /notifications/:id`.
- All notification endpoints are user-scoped (IDOR prevention: a user can only access their own notifications).

## 14. Flutter Feature Structure

`Mobile/lib/features/house_seeker/`

| File | Purpose |
|------|---------|
| `domain/entities/house_seeker_models.dart` | `SavedListingModel`, `SavedSearchModel` (with `alertFrequency`) |
| `domain/repositories/house_seeker_repository.dart` | Abstract repository with saved listings/searches methods |
| `data/repositories/house_seeker_repository_impl.dart` | Repository implementation delegating to remote datasource |
| `data/datasources/house_seeker_remote_datasource.dart` | Dio-based API client for saved listings/searches endpoints |
| `presentation/state/house_seeker_state.dart` | Riverpod providers: `houseSeekerSavedListingsProvider`, `houseSeekerSavedSearchesProvider` |
| `presentation/pages/house_seeker_saved_page.dart` | Saved Properties page with loading/empty/error/unavailable states |
| `presentation/pages/house_seeker_saved_searches_page.dart` | Saved Searches page with CRUD, run-now, alert frequency |

### Models

`SavedListingModel` — includes `savedId`, `listingId`, `propertyId`, `title`, `propertyType`, `city`, `county`, `rentAmount`, `images`, `amenities`, `listingStatus`, `bedrooms`, `bathrooms`, plus derived getters: `isAvailable`, `primaryImage`, `locationLabel`.

`SavedSearchModel` — includes `id`, `name`, `criteria`, `alertsEnabled`, `alertFrequency`.

### Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `houseSeekerSavedListingsProvider` | `FutureProvider` | Fetch saved listings |
| `houseSeekerSavedSearchesProvider` | `FutureProvider` | Fetch saved searches |

## 15. UI States

| State | Trigger | Display |
|-------|---------|---------|
| Loading | FutureProvider pending | `AppListSkeleton` |
| Data | Listings/searches returned | List of cards/tiles |
| Empty | No items | Localized empty state with action button |
| Error | API failure | `AppNotice` with Retry action |
| Unavailable | Listing status != 'published' | Warning text on saved tile |

## 16. Authentication & Authorization

- All backend endpoints require Bearer token (`requireAuth` middleware).
- Saved listings/searches are scoped by `user_id` — a user can only access their own records.
- IDOR protection: `findSavedSearchById(userId, searchId)` returns null if the search doesn't belong to the user, resulting in 404.
- Notification endpoints are similarly user-scoped.

## 17. Localization

English (`app_en.arb`) and Swahili (`app_sw.arb`) strings:

| Key | English | Swahili |
|-----|---------|---------|
| `savedHomes` | Saved homes | Nyumba zililohifadhiwa |
| `noSavedHomesYet` | No saved homes yet | Hakuna nyumba zilizohifadhiwa |
| `tapHeartSaveHome` | Tap the heart on any listing to save it here. | Bonyeza roho mapema kwenye orodha yoyote kuwezesha kuhifadhisha. |
| `discoverHomes` | Discover homes | Tafuta nyumba |
| `couldNotLoadSavedHomes` | Could not load saved homes. | Haweza kuunda nyumba zilizohifadhiwa. |
| `removedFromSaved` | Removed from saved homes. | Imetolewa kutoka nyumba zilizohifadhiwa. |
| `propertyUnavailable` | This property is no longer available. | Milki huu haiwezi kutumika tena. |
| `rentalListing` | Rental listing | Orodha ya kiraye |
| `remove` | Remove | Ondoa |
| `savedSearches` | Saved searches | Tafuta zililohifadhiwa |
| `noSavedSearchesYet` | No saved searches yet | Hakuna tafuta zilizohifadhiwa |
| `applyFiltersSaveSearch` | Apply filters, then tap "Save current" to keep the search for later. | Tengeneza vifurushi, tafuta bonyeza "Hifadhi sasa" kuwezesha kuhifadhisha. |
| `couldNotLoadSavedSearches` | Could not load your saved searches. | Haweza kuwanda tafuta zililohifadhiwa. |
| `saveCurrentSearch` | Save current | Hifadhi sasa |
| `nameThisSearch` | Name this search | Jina tafuta hii |
| `save` | Save | Hifadhi |
| `searchSaved` | Search saved. | Tafuta imehifadhiwa. |
| `editSavedSearch` | Edit saved search | Hariri tafuta iliyohifadhiwa |
| `searchUpdated` | Search updated. | Tafuta imesasishwa. |
| `couldNotUpdateSearch` | Could not update the search. | Haweza kuendesha tafuta. |
| `deleteSavedSearch` | Delete saved search? | Futa tafuta iliyohifadhiwa? |
| `searchWillBeRemoved` | will be removed. | itatolewa. |
| `keep` | Keep | Rudia |
| `deleteSearch` | Delete | Futa |
| `turnOffAlerts` | Turn off | Funga arifa |
| `turnOnAlerts` | Turn on | Washa arifa |
| `alertsOn` | Alerts on | Arifa imeshawasiliwa |
| `alertsOff` | Alerts off | Arifa imezimwa |
| `alertFrequency` | Alert frequency | Mwelekeo wa arifa |
| `howOftenToAlert` | How often to alert | Mara ngapi kuwatumia arifa |
| `sendNotifications` | Send notifications | Tuma arifa |
| `alertImmediately` | Immediately | Hivi karibuni |
| `alertDaily` | Daily | Kila siku |
| `alertWeekly` | Weekly | Kila wiki |
| `runNow` | Run now | Enda sasa |
| `edit` | Edit | Hariri |
| `searchMatched` | Search matched against new listings. | Tafuta imepangana na milki mpya. |
| `couldNotRunSearch` | Could not run the search. Please try again. | Haweza kuendesha tafuta. Tafadhali jaribu tena. |
| `couldNotUpdateAlerts` | Could not update alerts. Please try again. | Haweza kusasisha arifa. Tafadhali jaribu tena. |
| `couldNotDeleteSearch` | Could not delete the search. Please try again. | Haweza kufuta tafuta. Tafadhali jaribu tena. |

Regenerate with: `flutter gen-l10n` (from `Mobile/`).

## 18. Navigation

Routes in `Mobile/lib/app/router/app_router.dart`:
- `/house-seeker/saved` → `HouseSeekerSavedPage`
- `/house-seeker/saved-searches` → `HouseSeekerSavedSearchesPage`
- `/house-seeker/listings/:listingId` → listing detail

The Saved Properties page uses `context.pushNamed('house-seeker-listing-detail', ...)` for navigation to listing detail.
The Saved Searches page uses `context.pushNamed('house-seeker-search', ...)` to re-apply saved criteria.

## 19. Test Commands

**Flutter:**
```
cd Mobile
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000
flutter analyze lib/features/house_seeker/
flutter format lib/features/house_seeker/
```

**Backend:**
```
cd server
NODE_OPTIONS="--max-old-space-size=4096" npx vitest run src/modules/house-seeker/
NODE_OPTIONS="--max-old-space-size=4096" npx vitest run src/modules/auth/notification.test.ts
npx tsc --noEmit
```

## 20. Known Limitations

- Alert frequency (`daily`/`weekly`) is stored but the actual scheduling digest is not yet implemented — only `immediate` alerts are sent in real-time on listing publication.
- The `price` field in search alert notifications uses the listing's `rent_amount`; currency formatting is done on the client.
- Saved property pricing uses a default `/mo` label since `pricingFrequency` is not part of the saved listings response.
- Flutter widget tests use mocked repositories; integration against a real backend is not yet covered in widget tests.
- One pre-existing backend test failure (`returns a public listing detail with landlord first name`) is unrelated to this feature and remains unfixed.

## 21. Files Created

- `docs/architecture/house-seeker-saved-properties-and-search-alerts.md` (this document)
- `Mobile/test/features/house_seeker/house_seeker_saved_test_utils.dart` — shared test utilities
- `Mobile/test/features/house_seeker/house_seeker_saved_page_test.dart` — saved properties widget tests (11 tests)
- `Mobile/test/features/house_seeker/house_seeker_saved_searches_page_test.dart` — saved searches widget tests (11 tests)

## 22. Files Modified

- `server/src/modules/house-seeker/house-seeker.test.ts` — added 9 run endpoint integration tests
- `server/src/modules/landlord/landlord.controller.ts` — added `enqueueSearchAlert` calls on publish/resume
- `Mobile/lib/features/house_seeker/domain/entities/house_seeker_models.dart` — expanded `SavedListingModel` fields
- `Mobile/lib/features/house_seeker/presentation/pages/house_seeker_saved_page.dart` — localization, real listing data
- `Mobile/lib/features/house_seeker/presentation/pages/house_seeker_saved_searches_page.dart` — localization
- `Mobile/lib/l10n/app_en.arb` — added saved features strings
- `Mobile/lib/l10n/app_sw.arb` — added saved features translations
- `Mobile/lib/l10n/generated/app_localizations.dart` — regenerated