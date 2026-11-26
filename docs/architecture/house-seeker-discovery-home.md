# House Seeker Discovery Home — Implementation

**Repository:** `Mobile/`  
**Feature:** `lib/features/house_seeker/`

## 1. Overview

The House Seeker Discovery Home is the primary property discovery screen. It is a
production-quality, responsive, localized experience connected to real backend
data: featured published listings, user's saved location, personalized greeting,
notifications entry point, and favorites (save/unsave) with optimistic updates
and rollback.

It builds on the existing architecture without introducing duplicate
infrastructure: same Dio API client, same Riverpod 3 providers, same GoRouter
navigation, same design system tokens, same l10n ARB files.

## 2. Screen structure

```
HouseSeekerHomePage (ConsumerStatefulWidget)
├── RefreshIndicator (pull-to-refresh)
│   └── CustomScrollView
│       ├── AppHeroBanner
│       │   ├── Greeting ("Welcome back, {name}" / "Welcome to GetKeja")
│       │   ├── Location pill (saved location + change action)
│       │   └── Notifications button
│       ├── AppLocationPrompt (when no saved location)
│       ├── AppSearchField (search by area/estate/price)
│       ├── _QuickFilters (category chips: apartments, houses, etc.)
│       ├── _ShortcutRow (journey, visits, messages, etc.)
│       ├── AppSectionHeader ("Featured homes" + "See all")
│       └── featuredAsync.when(...)
│           ├── data → _FeaturedList (SliverGrid of HouseSeekerListingCard)
│           ├── loading → _FeaturedSkeleton
│           └── error → AppNotice (error + Retry)
```

## 3. Reusable design system components

Added to `lib/core/widgets/design_widgets.dart`:

| Component | Purpose |
|-----------|---------|
| `AppSearchField` | Reusable property search field with l10n hint, search icon, submit action |
| `AppCategoryChip` | Selectable property-type filter chip (selected/unselected states) |
| `AppHeroBanner` | Personalized hero: greeting, saved location pill, notifications button |
| `AppLocationPrompt` | Location setup prompt when no saved location exists |
| `AppListingBadge` | Small badge for verified/featured status |

Existing components reused: `AppSectionHeader`, `AppNotice`, `AppCard`, `PrimaryButton`, `AppTile`, `AppDivider`.

## 4. State management

All in `lib/features/house_seeker/presentation/state/house_seeker_state.dart`:

| Provider | Type | Purpose |
|----------|------|---------|
| `houseSeekerFeaturedProvider` | `FutureProvider` | Fetch featured published listings (`GET /api/v1/house-seeker/listings/featured`) |
| `houseSeekerSearchProvider` | `NotifierProvider` | Search/filter listings with pagination |
| `houseSeekerPersonalLocationProvider` | `FutureProvider` | User's saved personal_residential location (`GET /api/v1/profile/locations`) |
| `houseSeekerSavedIdsProvider` | `FutureProvider` | Set of saved listing ids |
| `houseSeekerToggleSaveProvider` | `NotifierProvider` | Optimistic save/unsave toggle with rollback on failure |
| `houseSeekerFacetsProvider` | `FutureProvider` | Filter facets (property types, counties) |
| `houseSeekerListingDetailProvider` | `FutureProvider.family` | Listing detail by id |

`HouseSeekerToggleSaveNotifier` extends `Notifier<Set<String>>`:
- Optimistically updates local saved-ids state on toggle
- Calls `repo.saveListing()` or `repo.removeSavedListing()`
- Invalidates `houseSeekerSavedIdsProvider` on success
- Rolls back optimistic change and rethrows on failure

## 5. Backend endpoints used

All endpoints already existed; no backend changes were required.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/house-seeker/listings/featured` | GET | Featured published listings |
| `/api/v1/house-seeker/listings` | GET | Search/filter published listings (pagination) |
| `/api/v1/profile/locations` | GET | User's saved locations (personal_residential) |
| `/api/v1/house-seeker/saved-listings` | POST | Save a listing |
| `/api/v1/house-seeker/saved-listings/:id` | DELETE | Unsave a listing |
| `/api/v1/house-seeker/saved-listings` | GET | List saved listings |

Authorization: Bearer token via existing `AuthInterceptor`. Only publicly
published listings are returned; draft/pending/rejected/archived listings are
excluded by the backend.

## 6. Models

Existing models in `lib/features/house_seeker/domain/entities/house_seeker_models.dart`:
- `ListingCardModel` — listing card data (title, price, city, propertyType, bedrooms, bathrooms, images, etc.)
- `SearchResultModel` — paginated search results
- `FilterFacetsModel` — filter facets
- `SavedListingModel` — saved listing reference
- `ListingDetailModel`, `HouseSeekerFilter`, etc.

All optional fields (bedrooms, bathrooms, images, amenities) are nullable and
handled gracefully in the listing card.

## 7. Localization

All user-facing strings are localized via `AppLocalizations` (en/sw). Strings
added to `lib/l10n/app_en.arb` and `app_sw.arb`:

- `welcomeBack`, `welcomeGuest` — personalized greeting
- `savedLocation`, `locationNotSet`, `setLocation`, `changeLocation` — location context
- `notifications` — notifications entry point
- `noSavedLocationDescription` — location prompt description
- `saveHome`, `unsaveHome`, `propertySaved`, `propertyUnsaved` — favorites
- `pullToRefresh`, `retry` — refresh/retry actions
- `categoryApartments`, `categoryHouses`, `categoryTownhouses`, `categoryStudios`, `categoryBedsitters`, `categoryLand`, `categoryCommercial` — property categories
- `featuredLoadError` — featured listings error message

Regenerate with: `flutter gen-l10n` (from `Mobile/`)

## 8. Navigation

Routes (existing, defined in `lib/app/router/app_router.dart`):
- `/house-seeker` → `HouseSeekerHomePage`
- `/house-seeker/search` → search results
- `/house-seeker/listings/:listingId` → listing detail
- `/house-seeker/saved` → saved listings
- `/profile-locations` → location management
- `/notifications` → notifications

The home page uses `context.pushNamed(...)` for navigation, consistent with
existing House Seeker pages.

## 9. Responsive design

- Grid column count adapts: 1 column on screens < 600dp, 2 columns above
- Skeleton count adapts to viewport width
- Search field and chips use horizontal scrolling on narrow screens
- Hero banner uses responsive layout with location pill

No third-party responsive package introduced.

## 10. Accessibility

- Semantic labels via standard Material widgets
- Sufficient touch targets (48dp minimum)
- Theme-aware colors (contrast via `colorScheme`)
- Readable font sizes from `AppTypography`
- Screen-reader-friendly buttons and icons

## 11. Known limitations

- No backend endpoint exists for "recommended" or "near me" sections; only
  featured listings are displayed. Sections requiring popularity/recommendation
  scores are intentionally omitted (no manufactured data).
- Location is read from the user's saved profile; no GPS/continuous tracking.
- Notifications button navigates to a placeholder route; the notifications
  feature is handled in a subsequent task.
- Favorites require authentication; unauthenticated users see listings but
  save operations will fail with an auth error from the backend.

## 12. Tests

| File | Coverage |
|------|----------|
| `test/features/house_seeker/house_seeker_home_page_test.dart` | Discovery home heading, featured listings rendering, empty state |
| `test/features/house_seeker/house_seeker_patterns_test.dart` | Loading state, empty state, error state (+retry), data state, responsive layouts (narrow/wide), l10n (en/sw), navigation wiring |
| `test/features/house_seeker/house_seeker_test_utils.dart` | `houseSeekerApp` builder + `FakeHouseSeekerRepository` (data/empty/loading/error) |

Run tests: `flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000` (from `Mobile/`)

## 13. Verification results

- **Flutter analyze:** 0 errors, 0 warnings (2 pre-existing info-level issues in `api_client.dart`)
- **Flutter tests:** 39 passed / 0 failed
- **dart format:** Applied to all changed files
- **Build:** Dart compilation clean; Android build not verified (no Android SDK in environment)

## 14. Files created

- `docs/architecture/house-seeker-discovery-home.md` (this document)

## 15. Files modified

- `lib/features/house_seeker/presentation/pages/house_seeker_home_page.dart` — full rewrite with l10n, location, notifications, favorites, pull-to-refresh, responsive grid
- `lib/features/house_seeker/presentation/state/house_seeker_state.dart` — added `houseSeekerPersonalLocationProvider`, `HouseSeekerToggleSaveNotifier`, `houseSeekerToggleSaveProvider`
- `lib/core/widgets/design_widgets.dart` — added `AppSearchField`, `AppCategoryChip`, `AppHeroBanner`, `AppLocationPrompt`, `AppListingBadge`
- `lib/l10n/app_en.arb` — added 17 new strings
- `lib/l10n/app_sw.arb` — added 17 new translations
- `lib/l10n/generated/app_localizations.dart` (+ language-specific files) — regenerated
- `test/features/house_seeker/house_seeker_home_page_test.dart` — updated for l10n, new layout
- `test/features/house_seeker/house_seeker_patterns_test.dart` — updated for new home page

## 16. Backend endpoints added

None. All endpoints already existed.

## 17. Database changes

None.

## 18. Recommended next implementation task

Task 4: Property Detail Screen — implement the listing detail page connected to
`GET /api/v1/house-seeker/listings/:listingId`, with save toggle, enquiry entry
point, and related listings.
