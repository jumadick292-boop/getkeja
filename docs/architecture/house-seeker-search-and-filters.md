# House Seeker Search & Filters — Implementation

**Repository:** `Mobile/`  
**Feature:** `lib/features/house_seeker/`

## 1. Overview

The House Seeker Search page is a production-quality, responsive, localized
property search experience connected to real backend data. Users can search by
keyword (area/estate/price), refine results with filter facets (price range,
bedrooms, property type, county, neighbourhood, amenities), sort results, and
clear all filters at once. Results render in a responsive grid with pull-to-refresh
and pagination scroll.

It builds on the existing architecture without introducing duplicate
infrastructure: same Dio API client, same Riverpod 3 providers, same GoRouter
navigation, same design system tokens, same l10n ARB files.

## 2. Screen structure

```
HouseSeekerSearchPage (ConsumerStatefulWidget)
├── CustomScrollView
│   ├── SliverAppBar
│   │   ├── Title ("Search")
│   │   └── Actions (filter button + clear filters chip row)
│   ├── SliverToBoxAdapter
│   │   ├── AppSearchField (debounced keyword search)
│   │   └── _SortBar (sort chips: Newest first, Price low→high, etc.)
│   └── SliverPadding
│       └── listing results
│           ├── data → SliverGrid of HouseSeekerListingCard
│           ├── empty → _EmptyResults (localized message + Reset filters)
│           ├── loading → AppListSkeleton grid
│           └── error → AppNotice (error + Retry)
└── Filter bottom sheet (draggable, full screen on narrow viewports)
    ├── Price range (min/max KES sliders + text fields)
    ├── Bedrooms (0–5+ chip selector)
    ├── Property type (apartments, houses, townhouses, studios, bedsitters, land, commercial)
    ├── County (county selector)
    ├── Neighbourhood (neighbourhood selector)
    ├── Amenities (multi-select chip grid)
    ├── PrimaryButton ("Apply filters")
    └── SecondaryButton ("Clear all")
```

Filter state persists in `HouseSeekerFilter` (copyWith-based immutable model).
Applying filters triggers a new `houseSeekerSearchProvider` read with `ref.invalidate()`.

## 3. Reusable design system components

Added to `lib/core/widgets/design_widgets.dart`:

| Component | Purpose |
|-----------|---------|
| `AppSearchField` | Reusable property search field with l10n hint, search icon, submit action, clear-on-submit |
| `AppCategoryChip` | Selectable property-type filter chip (selected/unselected states) |
| `AppHeroBanner` | Personalized hero: greeting, saved location pill, notifications button |
| `AppLocationPrompt` | Location setup prompt when no saved location exists |
| `AppListingBadge` | Small badge for verified/featured status |
| `AppListSkeleton` | Shimmer loading skeleton (single item or list grid) |
| `AppNotice` | Empty/error/notice state with optional Retry action |

Existing components reused: `AppSectionHeader`, `AppCard`, `PrimaryButton`, `SecondaryButton`, `TextButton`, `AppTile`, `AppDivider`, `AppListSkeleton`.

## 4. State management

All in `lib/features/house_seeker/presentation/state/house_seeker_state.dart`:

| Provider | Type | Purpose |
|----------|------|---------|
| `houseSeekerSearchProvider` | `NotifierProvider` | Search/filter listings with debounce + pagination |
| `houseSeekerFacetsProvider` | `FutureProvider` | Filter facets (property types, counties, neighbourhoods, amenities) |
| `houseSeekerToggleSaveProvider` | `NotifierProvider` | Optimistic save/unsave toggle with rollback on failure |
| `houseSeekerFeaturedProvider` | `FutureProvider` | Featured published listings |
| `houseSeekerSavedIdsProvider` | `FutureProvider` | Set of saved listing ids |
| `houseSeekerPersonalLocationProvider` | `FutureProvider` | User's saved personal_residential location |

`HouseSeekerFilter` (in `house_seeker_state.dart`):
- Immutable model: `query`, `minPrice`, `maxPrice`, `bedrooms`, `propertyTypes`, `county`, `neighbourhood`, `amenities`, `sortBy`
- `isActive` — true if any filter is set
- `activeCount` — count of active filters
- `copyWith({clear: false})` — partial update or full reset when `clear: true`
- `toCriteria()` — converts filter to backend search criteria
- `fromCriteria(Map)` — reconstructs filter from criteria map

`HouseSeekerToggleSaveNotifier` extends `Notifier<Set<String>>`:
- Optimistically updates local saved-ids state on toggle
- Calls `repo.saveListing()` or `repo.removeSavedListing()`
- Invalidates `houseSeekerSavedIdsProvider` on success
- Rolls back optimistic change and rethrows on failure

## 5. Backend endpoints used

All endpoints already existed; no backend changes were required.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/house-seeker/listings` | GET | Search/filter published listings (pagination) |
| `/api/v1/house-seeker/listings/featured` | GET | Featured published listings |
| `/api/v1/house-seeker/facets` | GET | Filter facets (property types, counties, neighbourhoods, amenities) |
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
- `FilterFacetsModel` — filter facets (property types, counties, neighbourhoods, amenities)
- `SavedListingModel` — saved listing reference
- `ListingDetailModel`, `HouseSeekerFilter`, etc.

All optional fields (bedrooms, bathrooms, images, amenities) are nullable and
handled gracefully in the listing card.

## 7. Localization

All user-facing strings are localized via `AppLocalizations` (en/sw). Strings
added to `lib/l10n/app_en.arb` and `app_sw.arb`:

- `search`, `searchByArea`, `searchHint`, `searchResults`, `noResults` — search header/hints
- `filters`, `applyFilters`, `clearFilters`, `resetFilters` — filter actions
- `priceRange`, `minPrice`, `maxPrice`, `bedrooms`, `propertyType`, `county`, `neighbourhood`, `amenities` — filter labels
- `sortBy`, `newestFirst`, `priceLowHigh`, `priceHighLow` — sort options
- `categoryApartments`, `categoryHouses`, `categoryTownhouses`, `categoryStudios`, `categoryBedsitters`, `categoryLand`, `categoryCommercial` — property categories
- `beds0`, `beds1`, `beds2`, `beds3`, `beds4`, `beds5Plus` — bedroom chip labels
- `amenityWifi`, `amenityParking`, `amenityPool`, `amenityGym`, `amenitySecurity`, `amenityFurnished` — amenity labels
- `noSavedLocationDescription` — location prompt description
- `saveHome`, `unsaveHome`, `propertySaved`, `propertyUnsaved` — favorites
- `pullToRefresh`, `retry` — refresh/retry actions
- `featuredLoadError` — featured listings error message

Regenerate with: `flutter gen-l10n` (from `Mobile/`)

## 8. Navigation

Routes (existing, defined in `lib/app/router/app_router.dart`):
- `/house-seeker` → `HouseSeekerHomePage`
- `/house-seeker/search` → `HouseSeekerSearchPage`
- `/house-seeker/listings/:listingId` → listing detail
- `/house-seeker/saved` → saved listings
- `/profile-locations` → location management
- `/notifications` → notifications

The search page uses `context.pushNamed(...)` for navigation to listing detail,
consistent with existing House Seeker pages. Filter bottom sheet uses
`showModalBottomSheet` (or fullscreen on narrow viewports).

## 9. Responsive design

- Grid column count adapts: 1 column on screens < 600dp, 2 columns above
- Skeleton count adapts to viewport width
- Search field and chips use horizontal scrolling on narrow screens
- Filter bottom sheet is draggable on mobile, fullscreen on narrow viewports
- Sort bar chips scroll horizontally

No third-party responsive package introduced.

## 10. Accessibility

- Semantic labels via standard Material widgets
- Sufficient touch targets (48dp minimum)
- Theme-aware colors (contrast via `colorScheme`)
- Readable font sizes from `AppTypography`
- Screen-reader-friendly buttons and icons

## 11. Known limitations

- Debounce delay is hardcoded (300ms); no user-configurable debounce.
- Price range uses text fields + KES currency assumption; no multi-currency support.
- Amenities list comes from facets endpoint; custom amenities require backend change.
- Neighbourhood filtering depends on backend facet data; empty if no facets returned.
- Favorites require authentication; unauthenticated users see listings but save
  operations will fail with an auth error from the backend.

## 12. Tests

| File | Coverage |
|------|----------|
| `test/features/house_seeker/house_seeker_search_test.dart` | Filter model (`isActive`, `activeCount`, `copyWith`, `toCriteria`, `fromCriteria`) + widget tests (search heading, listings render, empty state, Swahili empty state, search submission, clear button, filter sheet opens) |
| `test/features/house_seeker/house_seeker_patterns_test.dart` | Loading state, empty state, error state (+retry), data state, responsive layouts (narrow/wide), l10n (en/sw), navigation wiring |
| `test/features/house_seeker/house_seeker_test_utils.dart` | `houseSeekerApp` builder + `FakeHouseSeekerRepository` (data/empty/loading/error) |

Run tests: `flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000` (from `Mobile/`)

## 13. Verification results

- **Flutter analyze:** 0 errors, 0 warnings (2 pre-existing info-level issues in `api_client.dart`)
- **Flutter tests:** 54 passed / 0 failed
- **dart format:** Applied to all changed files
- **Build:** Dart compilation clean; Android build not verified (no Android SDK in environment)

## 14. Files created

- `docs/architecture/house-seeker-search-and-filters.md` (this document)

## 15. Files modified

- `lib/features/house_seeker/presentation/pages/house_seeker_search_page.dart` — full rewrite with debounced search, filter sheet, sort bar, results grid, pull-to-refresh, pagination, l10n
- `lib/features/house_seeker/presentation/state/house_seeker_state.dart` — `HouseSeekerFilter` model (neighbourhood, amenities, `isActive`, `activeCount`, `copyWith`, `toCriteria`, `fromCriteria`)
- `lib/core/widgets/design_widgets.dart` — `AppListSkeleton` (added alongside existing components)
- `lib/l10n/app_en.arb` — added search/filter/sort/amenity strings
- `lib/l10n/app_sw.arb` — added search/filter/sort/amenity translations
- `lib/l10n/generated/app_localizations.dart` (+ language-specific files) — regenerated
- `test/features/house_seeker/house_seeker_search_test.dart` — filter model + widget tests
- `test/features/house_seeker/house_seeker_patterns_test.dart` — updated for search page patterns
- `Mobile/pubspec.yaml` — `scripts` section with `test`/`test:coverage` commands supplying `--dart-define=API_BASE_URL=http://127.0.0.1:4000`

## 16. Backend endpoints added

None. All endpoints already existed.

## 17. Database changes

None.

## 18. Recommended next implementation task

Task 5: Property Detail Screen — implement the listing detail page connected to
`GET /api/v1/house-seeker/listings/:listingId`, with save toggle, enquiry entry
point, and related listings.
