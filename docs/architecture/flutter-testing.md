# Flutter Testing — GetKeja Mobile

**Repository:** `Mobile/`  
**Command:** `cd Mobile`

## 1. Prerequisite: `API_BASE_URL` environment variable

The app resolves `ApiConfig.baseUrl` at compile time from the `API_BASE_URL`
string environment constant. Every test run must supply
`--dart-define=API_BASE_URL=http://127.0.0.1:4000`, otherwise tests that touch
the API config fail with `StateError`.

> This matches CI (`.github/workflows/mobile-ci.yml`), which already runs the
> `flutter test` command with this dart-define.

### Run all tests

```bash
# From Mobile/
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000

# Via pubspec scripts (adds the dart-define automatically)
dart pub run scripts test           # or: flutter pub run scripts test
dart pub run scripts test:coverage
```

### Run a single test file or test name

```bash
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000 \
  test/features/house_seeker/house_seeker_patterns_test.dart

flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4000 \
  --plain-name "renders a featured listing card"
```

### Test coverage

```bash
flutter test --coverage --dart-define=API_BASE_URL=http://127.0.0.1:4000
# -> coverage/lcov.info
```

## 2. Baseline

| Scenario | Result |
|----------|--------|
| All tests with `API_BASE_URL` | **39 passed / 0 failed** |
| All tests without `API_BASE_URL` | 12 failures (cascading API config errors) |

House Seeker specifically: **12 passed / 0 failed** (3 original + 9 new pattern tests).

## 3. Test utilities

`test/features/house_seeker/house_seeker_test_utils.dart` contains reusable helpers:

### `houseSeekerApp`

Builds a `MaterialApp` configured with `AppLocalizations` (en/sw) and the shared
design-system theme. Callers wrap the result in a `ProviderScope` with provider
overrides.

```dart
Widget houseSeekerApp({
  required Widget child,
  Locale locale = const Locale('en'),
  ThemeData? theme,
});
```

### `FakeHouseSeekerRepository`

Mock `HouseSeekerRepository` whose `getFeatured()` future can be controlled to
exercise data, empty, loading, and error rendering paths.

```dart
// data state
FakeHouseSeekerRepository.data(<ListingCardModel>[listing]);

// empty state
FakeHouseSeekerRepository.empty();

// loading state — complete manually via repo.complete(...) / repo.fail(...)
FakeHouseSeekerRepository.loading();

// error state — throws immediately
FakeHouseSeekerRepository.error();
```

For `loading()` repositories, call `repo.complete(listings)` or
`repo.fail(error)` from the test to resolve the future at the desired time.

## 4. Recommended patterns

All patterns live in `test/features/house_seeker/house_seeker_patterns_test.dart`.

### Riverpod provider overrides

Wrap the widget under test in `ProviderScope` and override
`houseSeekerRepositoryProvider`:

```dart
final widget = ProviderScope(
  overrides: [
    houseSeekerRepositoryProvider.overrideWithValue(
      FakeHouseSeekerRepository.data(<ListingCardModel>[listing]),
    ),
  ],
  child: houseSeekerApp(child: const HouseSeekerHomePage()),
);
```

### Loading/empty/error/data states

- **Loading:** `FakeHouseSeekerRepository.loading()`; assert skeleton placeholders render before the future completes.
- **Empty:** `FakeHouseSeekerRepository.empty()`; assert "No featured homes yet".
- **Error:** override `houseSeekerFeaturedProvider` with
  `AsyncError(...)` (or drive the repository's `loading()` future to fail);
  assert the `AppNotice` error message and "Retry" action render.
- **Data:** `FakeHouseSeekerRepository.data(...)`; assert listing title/rent render.

### Responsive layouts

Set the tester view size, then reset in a tear-down:

```dart
tester.view.physicalSize = const Size(400, 1200);
addTearDown(tester.view.resetPhysicalSize);
tester.view.devicePixelRatio = 1;
addTearDown(tester.view.resetDevicePixelRatio);
```

Test narrow phone (e.g. `Size(390, 844)`) and wide desktop (e.g. `Size(1200, 800)`) viewports.

### Localization

`houseSeekerApp` accepts a `locale`. Test `en` and `sw`:

```dart
await tester.pumpWidget(_appWithRepo(
  repository: FakeHouseSeekerRepository.empty(),
  locale: const Locale('sw'),
));
await tester.pumpAndSettle();
```

Verify `AppLocalizations.supportedLocales` contains the locale under test.

### Navigation wiring

Build a standalone `GoRouter` with `observers` including a test `NavigatorObserver`,
pass it to `MaterialApp.router`, tap the shortcut card, and assert the observer
captured `didPush` with the expected route name:

```dart
final recorder = _RouteRecorder(); // extends NavigatorObserver
final router = GoRouter(
  observers: <NavigatorObserver>[recorder],
  routes: <RouteBase>[...],
);
await tester.pumpWidget(MaterialApp.router(routerConfig: router, ...));
await tester.tap(find.text('Journey').first);
await tester.pumpAndSettle();
expect(recorder.pushed, contains('house-seeker-journey'));
```

## 5. Golden tests

No golden tests exist in this project:
- Zero `matchGoldenFile` references in the test tree.
- No golden PNG fixtures committed.

Golden-test sections are therefore not applicable. If goldens are added later,
run `flutter test --update-goldens --dart-define=API_BASE_URL=http://127.0.0.1:4000`
to regenerate them.

## 6. API client / repository testing

`test/core/api/api_client_test.dart` tests the shared Dio client directly.
Because `ApiClient` reads `ApiConfig.baseUrl`, these tests require the
`API_BASE_URL` dart-define. Construct clients in tests with a `Dio` instance
rather than hitting the real network.

## 7. Lint / format

```bash
# Analyze
flutter analyze

# Format
dart format <changed-files>

# Full analyze (baseline: 329 info-level issues only, 0 errors/warnings)
flutter analyze 2>&1 | grep -E "error|warning" || echo "no errors or warnings"
```

## 8. Environment limitations

Tests run headless on Linux CI. Widget tests use `flutter_test`'s headless test
binder — no display, emulator, or physical device required. API calls are mocked
via Riverpod provider overrides; no live backend is needed.
