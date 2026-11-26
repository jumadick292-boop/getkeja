# House Seeker Property Comparison — Implementation

**Repository:** `get-keja-repo`
**Backend:** `server/` (Node.js/Express/PostgreSQL)
**Flutter app:** `Mobile/` (Flutter 3.50.0, Riverpod 3, Dio, GoRouter)
**Feature:** House Seeker property comparison — side-by-side comparison of up to 4 listings

## 1. Overview

House Seekers can add properties to a comparison list and view them side by side, with a grid showing pricing, specifications, amenities, and location differences. The comparison list is separate from saved properties (different database tables). The feature spans the Node.js backend (API routes, repository, controller, database migration) and the Flutter frontend (comparison page, comparison buttons on listing cards/detail, Riverpod state management).

## 2. User Workflows

### Add to Comparison
1. House Seeker browses listings on search/home/detail page.
2. Taps the compare icon on a listing card → `POST /api/v1/house-seeker/comparison`.
3. If the listing is already in comparison, the API returns `added: false` with reason `already_in_comparison`.
4. If the comparison list is full (4 items), the notifier returns `false` without calling the API.
5. On success, the comparison page reloads to show the added item with full details.

### View Comparison
1. House Seeker navigates to `/house-seeker/compare` (auth-guarded route).
2. The comparison page loads the current list via `GET /api/v1/house-seeker/comparison`.
3. Items render in a grid (property card with image, title, location, price) followed by comparison rows:
   - Overview: property cards
   - Pricing: price, deposit
   - Specifications: bedrooms, bathrooms, furnishing, pet policy, smoking, available from
   - Amenities: yes/no per amenity
   - Location: county, town
4. A "Show differences only" toggle hides rows where all compared properties have the same value.
5. A "Clear all" button removes all items from comparison.

### Remove from Comparison
1. On the comparison page, tapping the X icon on a property card → `DELETE /api/v1/house-seeker/comparison/:listingId`.
2. The item is removed from the list and the page re-renders.

### Clear Comparison
1. Tapping "Clear all" in the app bar or bottom bar → `DELETE /api/v1/house-seeker/comparison`.
2. A confirmation dialog appears (clear / cancel).
3. On confirm, all items are removed and the empty state is shown.

### Save All Compared
1. On the comparison page bottom bar, tapping "Save all" saves every compared property to the user's saved homes via `POST /api/v1/house-seeker/saved-listings`.
2. A snackbar confirms how many were saved.

## 3. Database Schema

### Migration `086_create_house_seeker_comparison_tables.sql`

Two new tables (separate from `saved_listings`):

| Table | Purpose |
|-------|---------|
| `house_seeker_comparison_lists` | One row per user; stores `id`, `user_id`, `created_at`, `updated_at` |
| `house_seeker_comparison_items` | One row per compared listing; stores `id`, `list_id`, `listing_id`, `position`, `created_at` |

Constraints:
- `comparison_lists.user_id` references `users(id)`, unique (one list per user)
- `comparison_items.list_id` references `comparison_lists(id)`, ON DELETE CASCADE
- `comparison_items.listing_id` references `property_listings(id)`
- `comparison_items.position` is unique per list (ordering)
- Max 4 items per list enforced in application logic

Migration `085` was also fixed to use an idempotent `DO $$ ... END $$` block for constraint creation.

## 4. Backend API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/house-seeker/comparison` | Get the user's comparison list |
| POST | `/api/v1/house-seeker/comparison` | Add a listing to comparison (body: `{ listingId }`) |
| DELETE | `/api/v1/house-seeker/comparison/:listingId` | Remove a listing from comparison |
| DELETE | `/api/v1/house-seeker/comparison` | Clear all items from comparison |

Routes are mounted under `/api/v1/house-seeker` (same router as other house-seeker routes).

### Request/Response Schemas

**POST /comparison** Body: `{ listingId: string }`
**Response:** `{ added: boolean, listingId: string, reason?: string, listId?: string, position?: number, createdAt?: string }`

**DELETE /comparison/:listingId**
**Response:** `{ removed: boolean }`

**DELETE /comparison**
**Response:** `{ cleared: boolean, removedCount: number }`

**GET /comparison**
**Response:** `{ items: ComparisonListing[], total: number, limit: number, offset: number }`

### Validation
- `MAX_COMPARISON_ITEMS = 4` — enforced in the notifier before calling the API
- `listingId` is a required string parameter

## 5. Backend Implementation Layers

| Layer | File | Responsibility |
|-------|------|---------------|
| Routes | `server/src/modules/house-seeker/house-seeker.routes.ts` | Mounts 4 comparison endpoints |
| Controller | `server/src/modules/house-seeker/house-seeker.controller.ts` | `getComparison()`, `addToComparison()`, `removeFromComparison()`, `clearComparison()` |
| Repository | `server/src/modules/house-seeker/house-seeker.repository.ts` | `getComparisonList()`, `addToComparison()`, `removeFromComparison()`, `clearComparison()`, `ensureComparisonList()` |
| Schema | `server/src/modules/house-seeker/house-seeker.schema.ts` | Zod schemas: `comparisonAddSchema`, `comparisonItemParamSchema`, `comparisonQuerySchema`, `MAX_COMPARISON_ITEMS` |
| Migration | `server/src/db/migrations/086_create_house_seeker_comparison_tables.sql` | Creates `house_seeker_comparison_lists` and `house_seeker_comparison_items` |
| OpenAPI | `server/openapi.yaml` | Comparison paths and schemas |

## 6. Flutter Implementation

### State Management (`house_seeker_state.dart`)

| Provider | Type | Purpose |
|----------|------|---------|
| `houseSeekerComparisonProvider` | `NotifierProvider<ComparisonNotifier, ComparisonState>` | Reads/writes comparison state via `ComparisonNotifier` |
| `houseSeekerComparisonIdsProvider` | `Provider<Set<String>>` | Quick read of compared listing IDs |
| `houseSeekerComparisonCountProvider` | `Provider<int>` | Number of items in comparison |
| `houseSeekerComparisonIsAtMaxProvider` | `Provider<bool>` | Whether comparison is at max (4) |
| `differenceOnlyProvider` | `NotifierProvider<DifferenceOnlyNotifier, bool>` | "Show differences only" toggle state |
| `kMaxComparisonItems` | `const int` | Constant: 4 |

### `ComparisonNotifier` Methods
- `load()` — fetches comparison list from repository
- `add(listingId)` — adds listing, reloads on success, respects max limit
- `remove(listingId)` — removes listing optimistically
- `clear()` — clears all items

### UI Pages/Widgets

| File | Purpose |
|------|---------|
| `house_seeker_compare_page.dart` | Main comparison page: empty state, data state, loading, error, app bar with clear, bottom bar with save-all |
| `listing_card.dart` | Added `onToggleCompare`/`isCompared` params + `_CompareButton` widget |
| `house_seeker_search_page.dart` | Comparison toggle integrated on search listing cards |
| `house_seeker_home_page.dart` | Comparison toggle integrated on featured listings |
| `house_seeker_listing_detail_page.dart` | Compare button in `_ContactBar` |
| `app_router.dart` | `/house-seeker/compare` route with auth guard |

### Localization (`app_en.arb`, `app_sw.arb`)

37 comparison keys added (title, empty state, section headers, row labels, values, buttons, confirm dialog, snackbar messages).

## 7. Testing

### Backend (`server/src/modules/house-seeker/house-seeker.test.ts`)
- 12 comparison tests covering: GET empty list, GET with items, POST add, POST duplicate, POST at max, DELETE remove, DELETE not found, DELETE clear, validation errors, auth required
- All comparison tests pass; pre-existing unrelated test failure unchanged

### Flutter (`Mobile/test/features/house_seeker/house_seeker_compare_page_test.dart`)
- 7 widget tests: empty state, data rendering, remove item, clear all, at-max warning, difference toggle checkbox, Swahili localization
- All tests pass

### Existing test files updated
- `house_seeker_test_utils.dart` — added comparison stubs to `FakeHouseSeekerRepository`
- `house_seeker_home_page_test.dart` — added comparison stubs to `_FakeHouseSeekerRepository`
- `house_seeker_search_test.dart` — added comparison stubs to `_FakeSearchRepository`
- `house_seeker_detail_test.dart` — added comparison stubs to `_DetailFakeRepository`

## 8. Notes

- Comparison uses separate tables from saved listings (per task requirements)
- Max 4 properties per comparison; enforced in Flutter notifier and backend schema
- Comparison belongs to the authenticated user (`user_id`)
- OpenAPI spec updated with comparison paths under the `/api/v1/auth` base URL
- Pre-existing backend test failure (`returns a public listing detail with landlord first name`) is unrelated and not fixed
