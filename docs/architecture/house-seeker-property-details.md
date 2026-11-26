# House Seeker Property Details — Implementation

**Repository:** `Mobile/` + `server/`  
**Feature:** `lib/features/house_seeker/` (Flutter) + `server/src/modules/house-seeker/` (backend)

## 1. Overview

The House Seeker Property Details page is a production-quality, localized
property listing detail experience connected to real backend data. Users can view
full property details (title, price with billing frequency, location, description,
attributes, amenities, landlord contact), browse images in a full-screen gallery
with pinch-to-zoom, save/unsave the listing, enquire, request a site visit,
submit a rental application, message the landlord, view on map, share the
listing, and see related properties.

It builds on the existing architecture without introducing duplicate
infrastructure: same Dio API client, same Riverpod 3 providers, same GoRouter
navigation, same design system tokens, same l10n ARB files.

## 2. Screen structure

```
HouseSeekerListingDetailPage (ConsumerWidget)
├── CustomScrollView
│   ├── SliverAppBar
│   │   ├── FlexibleSpaceBar (_ImageGallery — PageView with image position indicator)
│   │   ├── Actions (share, report)
│   │   └── expandedHeight: 340, pinned
│   └── SliverToBoxAdapter
│       ├── Padding
│       │   └── Column
│       │       ├── Title + Price (with pricing frequency label)
│       │       ├── Location label
│       │       ├── Description (expand/collapse, 3-line preview)
│       │       ├── Amenities section (6-chip preview + show all/less toggle)
│       │       ├── Details card (deposit, furnishing, pet policy, smoking, availability, unit)
│       │       ├── Listed by (landlord avatar + name + enquire/message buttons)
│       │       ├── Location + map (_MapPreview placeholder with coordinates)
│       │       └── Related properties (_RelatedPropertyCard horizontal scroll)
│       └── SizedBox (bottom spacer)
└── bottomNavigationBar (_ContactBar — save toggle, request visit, apply now)
```

Full-screen gallery:
```
_FullScreenGallery (Scaffold, black theme)
├── AppBar (image position indicator "N / M", close button)
├── PageView (InteractiveViewer for pinch-to-zoom, Image.network)
└── Bottom bar (close, gallery jump-to-first)
```

## 3. Reusable design system components

Existing components reused: `AppSectionHeader`, `AppCard`, `PrimaryButton`,
`SecondaryButton`, `OutlinedButton`, `AppTile`, `AppDivider`, `AppListSkeleton`,
`AppLoadingIndicator`, `AppNotice`, `CircleAvatar`.

New page-level widgets (in `house_seeker_listing_detail_page.dart`):
- `_ImageGallery` — PageView gallery with image count badge + error/loading states
- `_FullScreenGallery` — pinch-to-zoom full-screen gallery with position indicator
- `_DetailContent` — scrollable detail content (ConsumerStatefulWidget)
- `_AmenityChip` — styled amenity chip
- `_DetailRow` — label/value detail row
- `_MapPreview` — map placeholder card with coordinates
- `_RelatedPropertyCard` — horizontal related listing card with image, price, title, location
- `_ListingImage` / `_PlaceholderImage` — listing image widget
- `_ContactBar` — bottom contact bar (save/enquire/apply)

## 4. State management

All in `lib/features/house_seeker/presentation/state/house_seeker_state.dart`:

| Provider | Type | Purpose |
|----------|------|---------|
| `houseSeekerListingDetailProvider` | `FutureProvider.family<ListingDetailModel, String>` | Load listing detail by ID |
| `houseSeekerRelatedListingsProvider` | `FutureProvider.family<List<ListingCardModel>, String>` | Load related listings by ID |

## 5. Backend endpoints

### New migration

`server/src/db/migrations/084_add_pricing_frequency_to_listings.sql`:
- Adds `pricing_frequency VARCHAR(20) DEFAULT 'monthly'` to `property_listings`
- CHECK constraint: `pricing_frequency IN ('monthly', 'weekly', 'annual', 'sale')`

### Backend changes

| File | Change |
|------|--------|
| `house-seeker.repository.ts` | `getPublicListingById` now selects `pl.pricing_frequency AS "pricingFrequency"`; added `getRelatedListings(listingId)` |
| `house-seeker.controller.ts` | Added `getRelatedListings` controller action |
| `house-seeker.routes.ts` | Added `GET /api/v1/house-seeker/listings/:listingId/related` |
| `house-seeker.schema.ts` | Added `relatedListingsQuerySchema` |

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/house-seeker/listings/:listingId` | GET | Public listing detail (now includes `pricingFrequency`) |
| `/api/v1/house-seeker/listings/:listingId/related` | GET | Related listings (same city/county, different listing) |

Authorization: Bearer token via existing `AuthInterceptor`. Only published
listings are returned.

## 6. Models

`ListingDetailModel` (in `house_seeker_models.dart`):
- New field: `pricingFrequency` (String?, nullable)
- New getter: `pricingLabel` — maps frequency to display label:
  - `'monthly'` → `/month`, `'weekly'` → `/week`, `'annual'` → `/year`, `'sale'` → `for sale`, null → `/month`
- All existing optional fields (bedrooms, bathrooms, address, latitude, longitude, etc.) remain nullable

## 7. Data layer

| File | Change |
|------|--------|
| `house_seeker_repository.dart` | Added `getListingDetail(String)` and `getRelatedListings(String)` to interface |
| `house_seeker_repository_impl.dart` | Implemented both methods via Dio calls to backend |
| `house_seeker_remote_datasource.dart` | Added Dio GET calls for detail and related listings |

## 8. Localization

All user-facing strings localized via `AppLocalizations` (en/sw). Strings added
to `lib/l10n/app_en.arb` and `app_sw.arb`:

- `propertyDetails`, `amenitiesAndFeatures`, `listingDetails`, `listedBy` — section headers
- `share`, `save`, `unsave` — favorite/share actions
- `enquire`, `message`, `requestVisit`, `applyNow` — contact actions
- `priceOnRequest` — price when rent is null
- `beds`, `baths`, `furnished`, `unfurnished` — attribute labels
- `availableFrom`, `petPolicy`, `smoking`, `deposit` — detail labels
- `perMonth`, `perWeek`, `perYear`, `forSale` — pricing frequency labels
- `readMore`, `ReadLess`, `showAll`, `ShowLess amenities` — expand/collapse
- `mapPreviewUnavailable`, `viewOnMap` — map section
- `propertyUnavailable`, `Property Not Found`, `couldNotLoadProperty` — error states
- `gallery`, `imageCount`, `closeGallery`, `shareProperty`, `shareNotAvailable` — gallery
- `relatedProperties` — related listings section
- `enquirySent`, `visitRequested`, `applicationSubmitted` — action confirmations
- `propertyOwner` — landlord role label

Regenerate with: `flutter gen-l10n` (from `Mobile/`)

## 9. Navigation

Routes (existing, defined in `lib/app/router/app_router.dart`):
- `/house-seeker/listings/:listingId` → `HouseSeekerListingDetailPage`

Related properties navigate via `context.pushNamed('house-seeker-listing-detail', pathParameters: {'listingId': ...})`.

Map preview shows a placeholder (actual `google_maps_flutter` integration requires API key and platform setup). `_viewOnMap` shows `mapPreviewUnavailable` snackbar.

## 10. Responsive design

- Viewport-aware layout via `_setViewport` in tests
- Bottom contact bar with save/enquire/apply buttons
- Related properties horizontal scroll with fixed-width cards
- Description expands beyond 3-line preview
- Amenities shows 6 chips preview with show-all toggle
- Image gallery with position indicator badge

No third-party responsive package introduced.

## 11. Accessibility

- Semantic labels via standard Material widgets
- Sufficient touch targets (48dp minimum)
- Theme-aware colors (contrast via `colorScheme`)
- Readable font sizes from `AppTypography`
- Tooltips on action buttons (share, report, close gallery)
- Screen-reader-friendly buttons and icons

## 12. Known limitations

- Map preview is a placeholder card; live Google Maps requires API key + platform configuration
- Share uses `share_plus` which may not be available on all platforms (caught with `shareNotAvailable` fallback)
- Pricing frequency defaults to `/month` when null
- Related listings limited to same city/county, excludes current listing
- Deposit amount and other optional fields only show when present in backend response

## 13. Tests

| File | Coverage |
|------|----------|
| `test/features/house_seeker/house_seeker_detail_test.dart` | `ListingDetailModel` parsing (pricingFrequency, pricingLabel for weekly/monthly/annual/sale/null, optional fields null) + widget tests (loaded state title/price/location/landlord, Swahili localization, error state property not found, gallery PageView renders, amenities chips show humanized labels, pricing on request when rent null, description displays) |

Run tests: `flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000` (from `Mobile/`)

## 14. Verification results

- **Flutter analyze:** 0 errors, 0 warnings (only pre-existing info-level deprecation notices)
- **Flutter tests:** 67 passed / 0 failed (full suite)
- **dart format:** Applied to all changed files
- **Build:** Dart compilation clean; Android build not verified (no Android SDK in environment)

## 15. Files created

- `docs/architecture/house-seeker-property-details.md` (this document)
- `server/src/db/migrations/084_add_pricing_frequency_to_listings.sql`
- `test/features/house_seeker/house_seeker_detail_test.dart`

## 16. Files modified

### Mobile
- `lib/features/house_seeker/presentation/pages/house_seeker_listing_detail_page.dart` — full rewrite with gallery, full-screen viewer, pricing frequency, description expand/collapse, amenities preview, map preview, landlord contact, location, related properties, bottom contact bar, share, error/unavailable/loading states, l10n
- `lib/features/house_seeker/domain/entities/house_seeker_models.dart` — `ListingDetailModel.pricingFrequency` + `pricingLabel`
- `lib/features/house_seeker/presentation/state/house_seeker_state.dart` — `houseSeekerListingDetailProvider`, `houseSeekerRelatedListingsProvider`
- `lib/features/house_seeker/domain/repositories/house_seeker_repository.dart` — `getListingDetail`, `getRelatedListings` interface
- `lib/features/house_seeker/data/repositories/house_seeker_repository_impl.dart` — implementations
- `lib/features/house_seeker/data/datasources/house_seeker_remote_datasource.dart` — Dio calls
- `lib/core/widgets/design_widgets.dart` — `PrimaryButton` text overflow fix (`Flexible` + `TextOverflow.ellipsis`)
- `lib/l10n/app_en.arb` — detail page strings
- `lib/l10n/app_sw.arb` — detail page translations
- `lib/l10n/generated/app_localizations.dart` (+ language-specific files) — regenerated
- `test/features/house_seeker/house_seeker_test_utils.dart` — `_DetailFakeRepository`, `getRelatedListings` stub, `getListingDetail`, `_detailJson` getter
- `test/features/house_seeker/house_seeker_detail_test.dart` — 13 unit + widget tests

### Backend
- `server/src/modules/house-seeker/house-seeker.repository.ts` — `getPublicListingById` pricingFrequency, `getRelatedListings`
- `server/src/modules/house-seeker/house-seeker.controller.ts` — `getRelatedListings` controller
- `server/src/modules/house-seeker/house-seeker.routes.ts` — `/listings/:listingId/related` route
- `server/src/modules/house-seeker/house-seeker.schema.ts` — `relatedListingsQuerySchema`

## 17. Backend endpoints added

- `GET /api/v1/house-seeker/listings/:listingId/related` — related listings

## 18. Database changes

- Migration `084_add_pricing_frequency_to_listings.sql` — `pricing_frequency` column with CHECK constraint
