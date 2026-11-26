# Flutter Architecture — GetKeja Mobile

**Repository:** `Mobile/`  
**Stack:** Flutter stable, Dart SDK 3.8, Riverpod 3, GoRouter 18, Dio 5, `flutter_secure_storage`, `google_maps_flutter`, `geolocator`, `image_picker`, Firebase Core, `intl` l10n.

## 1. Actual structure (adopted)

The target structure is used as a reference. The existing app is already feature-first with Riverpod + GoRouter established, so paths were kept as-is.

```
Mobile/lib/
  main.dart              — Entry: bootstrap()
  app/
    bootstrap.dart       — Firebase, secure storage, ProviderScope, GetKejaApp
    config/              — App config
    preferences/         — AppPreferences (theme, locale, persisted state)
    router/
      app_router.dart    — GoRouter routerProvider; auth-guarded redirects
    theme/
      app_theme.dart     — Material 3 themes built on design_system.dart
      design_system.dart — Design tokens (see section 3)
  core/
    config/              — ApiConfig (API_BASE_URL via -D API_BASE_URL string env)
    constants/           — AppConstants (timeouts, app name)
    errors/              — AppException hierarchy (Unauthorized, Forbidden,
                          Server, RateLimit, Network, TokenRevoked)
    network/             — reserved (empty)
    security/            — reserved (empty)
    storage/             — secure_storage.dart (AuthTokenStorage)
    utils/               — reserved (empty)
    validators/          — reserved (empty)
    widgets/             — shared UI widgets
    api/
      api_client.dart    — Single shared Dio client (apiClientProvider) with
                           AuthInterceptor (Bearer token + 401 refresh retry),
                           LoggingInterceptor; auth base /api/v1/auth
  shared/
    models/              — auth_models.dart (+ freezed/json_serializable generated)
    widgets/             — reserved (empty)
    services/            — reserved (empty)
  features/
    <24 feature folders>, each with data/, domain/, presentation/
    house_seeker/        — data (remote datasource, repository impl),
                           domain (entities, repository interface),
                           presentation (pages, Riverpod state, widgets)
    authentication, account, profile, onboarding, dashboard, property_search,
    property_management, notifications, site_visits, tenancies, organisations,
    movers, laundries, garbage, devices, mfa, password_recovery,
    account_recovery, verification, administration, registration, splash
  navigation/            — not separate; routing lives in app/router via GoRouter
  l10n/
    app_en.arb, app_sw.arb, generated/ (app_localizations.dart)
```

## 2. Layering rules (per feature)

- `data/` — remote datasources (Dio calls) + repository implementations. No API calls outside this layer.
- `domain/` — entities (plain Dart models with `fromJson`) + abstract repository interfaces.
- `presentation/` — pages, widgets, Riverpod providers/notifiers. Depends on `domain` only; UI never imports `data` directly.
- Dependencies flow inward: `presentation → domain ← data`. No circular feature dependencies.
- Feature-to-feature communication happens through shared models or the shared API client, not by importing another feature's `data` layer.

## 3. Shared infrastructure (single instances)

- **API client:** one Dio instance in `core/api/api_client.dart` (`apiClientProvider`), base URL `ApiConfig.authBaseUrl` (`/api/v1/auth`); `baseUrl` resolves profile/listing/house-seeker paths. House Seeker datasource uses `${ApiConfig.baseUrl}/api/v1/house-seeker`.
- **Auth state:** `features/authentication/presentation/state/auth_state.dart` (`authNotifierProvider`); consumed by `app/bootstrap.dart` and router guards.
- **Secure storage:** `core/storage/secure_storage.dart`, injected in `bootstrap()` via `secureStorageProvider` override.
- **Localization:** `intl` ARB files + generated `AppLocalizations`; en and sw supported.
- **Design tokens:** `app/theme/design_system.dart` — `AppColors`, `AppTypography`, `AppSpacing`, `AppBorderRadius`, `AppElevation`, `AppAnimation`; consumed by `app_theme.dart` (Material 3 light/dark).

## 4. Navigation

- GoRouter `routerProvider` in `app/router/app_router.dart`; top-level redirect guard handles auth, MFA, verification, and onboarding flows.
- House Seeker routes (all redirect to `/sign-in` when unauthenticated): `/house-seeker`, `/house-seeker/search`, `/house-seeker/listings/:listingId`, `/house-seeker/saved`, `/house-seeker/enquiries`, `/house-seeker/visits`, `/house-seeker/conversations`, `/house-seeker/conversations/:conversationId`, `/house-seeker/applications`, `/house-seeker/proposals`, `/house-seeker/journey`, `/house-seeker/saved-searches`, `/house-seeker/preferences`.

## 5. State management

- Riverpod 3 (`flutter_riverpod`, `riverpod_annotation`). House Seeker uses `NotifierProvider` for search state and `FutureProvider`/`FutureProvider.family` for read operations (`house_seeker_state.dart`). Established convention; no new state library introduced.

## 6. Deviations from the target structure (justified)

| Target | Existing | Reason kept |
|---|---|---|
| `navigation/` directory | `app/router/` | GoRouter is configured in one file; a separate navigation layer adds indirection. |
| `core/network/` | `core/api/api_client.dart` | Dio client already centralizes networking; `core/network` is reserved empty. |
| `shared/widgets/` populated | Empty | Reusable widgets live in `core/widgets/` and feature `presentation/widgets/`; house_seeker has `listing_card.dart`, `format_utils.dart`. |

## 7. Conventions

- No API calls directly inside widgets: pages call Riverpod providers → repository → datasource → Dio.
- `API_BASE_URL` must be supplied as a Dart define environment string (`-D API_BASE_URL=...`) at build time; release builds require HTTPS.
- Fonts: Inter (variable). Assets: `assets/images/`, `assets/images/brand/`, `generate: true`.
- Visual direction: modern, photographic, clean, premium, spacious, mobile-first — colors/tokens in `design_system.dart`; reusable House Seeker components (property card, search bar, filter chips, image gallery, buttons, empty/loading/error states) are to be added in Phase 2 against these tokens, not built now.
