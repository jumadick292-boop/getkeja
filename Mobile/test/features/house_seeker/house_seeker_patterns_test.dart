// House Seeker test patterns.
// Demonstrates reusable patterns for widget tests: loading/empty/error states,
// responsive layouts, localization, and navigation wiring. These tests exercise
// existing House Seeker UI without adding product behavior.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_home_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'house_seeker_test_utils.dart';

final _listing = ListingCardModel(
  listingId: 'l1',
  propertyId: 'p1',
  title: 'Cosy 1BR Riverside',
  propertyType: 'apartment',
  city: 'Nairobi',
  county: 'Nairobi',
  rentAmount: 45000,
  images: const <String>[],
  amenities: const <String>[],
  bedrooms: 1,
  bathrooms: 1,
);

Widget _appWithRepo({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: houseSeekerApp(child: const HouseSeekerHomePage(), locale: locale),
  );
}

class _RouteRecorder extends NavigatorObserver {
  final List<String> pushed = <String>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name ?? '');
  }
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('loading state', () {
    testWidgets('shows skeleton placeholders while featured loads', (
      tester,
    ) async {
      _setViewport(tester, 400, 1200);
      final repo = FakeHouseSeekerRepository.loading();
      await tester.pumpWidget(_appWithRepo(repository: repo));
      await tester.pump();

      expect(find.text('Cosy 1BR Riverside'), findsNothing);
    });
  });

  group('empty state', () {
    testWidgets('shows empty state when no featured homes', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(
        _appWithRepo(repository: FakeHouseSeekerRepository.empty()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Featured homes'), findsWidgets);
    });
  });

  group('error state', () {
    testWidgets('shows error notice with a retry action', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            houseSeekerFeaturedProvider.overrideWithValue(
              AsyncError<List<ListingCardModel>>(
                Exception('featured load failed'),
                StackTrace.empty,
              ),
            ),
          ],
          child: houseSeekerApp(child: const HouseSeekerHomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('data state', () {
    testWidgets('renders a featured listing card', (tester) async {
      _setViewport(tester, 400, 1600);
      await tester.pumpWidget(
        _appWithRepo(
          repository: FakeHouseSeekerRepository.data(<ListingCardModel>[
            _listing,
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.textContaining('KES 45,000'), findsOneWidget);
    });
  });

  group('responsive layouts', () {
    testWidgets('renders on a narrow phone viewport', (tester) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(
        _appWithRepo(
          repository: FakeHouseSeekerRepository.data(<ListingCardModel>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to GetKeja'), findsOneWidget);
    });

    testWidgets('renders on a wide desktop viewport', (tester) async {
      _setViewport(tester, 1200, 800);
      await tester.pumpWidget(
        _appWithRepo(
          repository: FakeHouseSeekerRepository.data(<ListingCardModel>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to GetKeja'), findsOneWidget);
    });
  });

  group('localization', () {
    testWidgets('loads without crashing in English', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(
        _appWithRepo(
          repository: FakeHouseSeekerRepository.empty(),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to GetKeja'), findsOneWidget);
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    });

    testWidgets('loads without crashing in Swahili', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(
        _appWithRepo(
          repository: FakeHouseSeekerRepository.empty(),
          locale: const Locale('sw'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Karibu GetKeja'), findsOneWidget);
      expect(AppLocalizations.supportedLocales, contains(const Locale('sw')));
    });
  });

  group('navigation wiring', () {
    testWidgets('tapping a shortcut card pushes the named route', (
      tester,
    ) async {
      _setViewport(tester, 400, 1200);
      final recorder = _RouteRecorder();
      final router = GoRouter(
        observers: <NavigatorObserver>[recorder],
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            name: 'house-seeker',
            builder: (context, _) => ProviderScope(
              overrides: [
                houseSeekerRepositoryProvider.overrideWithValue(
                  FakeHouseSeekerRepository.empty(),
                ),
              ],
              child: const HouseSeekerHomePage(),
            ),
          ),
          GoRoute(
            path: '/house-seeker-journey',
            name: 'house-seeker-journey',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-visits',
            name: 'house-seeker-visits',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-conversations',
            name: 'house-seeker-conversations',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-applications',
            name: 'house-seeker-applications',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-proposals',
            name: 'house-seeker-proposals',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-saved',
            name: 'house-seeker-saved',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-enquiries',
            name: 'house-seeker-enquiries',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-saved-searches',
            name: 'house-seeker-saved-searches',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-preferences',
            name: 'house-seeker-preferences',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-search',
            name: 'house-seeker-search',
            builder: (context, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/house-seeker-listing-detail/:listingId',
            name: 'house-seeker-listing-detail',
            builder: (context, _) => const SizedBox.shrink(),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Journey'), findsOneWidget);

      await tester.tap(find.text('Journey').first);
      await tester.pumpAndSettle();

      expect(recorder.pushed, contains('house-seeker-journey'));
    });
  });
}
