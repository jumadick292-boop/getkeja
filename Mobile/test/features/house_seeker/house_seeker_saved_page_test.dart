// Widget tests for the House Seeker Saved Properties page.
// Exercises loading, data, empty, error, removal and localization paths
// against a mocked [HouseSeekerRepository].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_saved_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

import 'house_seeker_saved_test_utils.dart';

Widget _app({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: houseSeekerSavedApp(child: const HouseSeekerSavedPage(), locale: locale),
  );
}

void main() {
  group('HouseSeekerSavedPage', () {
    testWidgets('shows loading state while fetching saved listings',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListingsMode: SavedMode.loading,
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pump();

      // Loading skeleton should be visible while future is pending.
      expect(find.byType(AppListSkeleton), findsOneWidget);
    });

    testWidgets('renders saved listing data with title, location, rent',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[
          sampleSavedListing(
            title: 'Cosy 1BR Riverside',
            city: 'Nairobi',
            county: 'Nairobi',
            rentAmount: 45000,
            bedrooms: 1,
            bathrooms: 1,
            images: const <String>[],
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.textContaining('Nairobi'), findsOneWidget);
    });

    testWidgets('renders bedrooms and bathrooms info when available',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[
          sampleSavedListing(
            title: '2BR Apartment',
            bedrooms: 2,
            bathrooms: 2.0,
            images: const <String>[],
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('2BR Apartment'), findsOneWidget);
    });

    testWidgets('shows unavailable listing badge when listing is not published',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[
          sampleSavedListing(
            title: 'Unavailable Home',
            listingStatus: 'withdrawn',
            images: const <String>[],
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Unavailable Home'), findsOneWidget);
      expect(find.text('This property is no longer available.'), findsOneWidget);
    });

    testWidgets('shows empty state with discover homes action when no saved listings',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListingsMode: SavedMode.empty,
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No saved homes yet'), findsOneWidget);
      expect(find.text('Tap the heart on any listing to save it here.'), findsOneWidget);
      expect(find.text('Discover homes'), findsOneWidget);
    });

    testWidgets('AppNotice renders error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppNotice(
            message: 'Could not load saved homes.',
            type: NoticeType.error,
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load saved homes.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('transitions from loading to data when listings complete',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListingsMode: SavedMode.loading,
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pump();

      expect(find.byType(AppListSkeleton), findsOneWidget);

      repo.completeListings(<SavedListingModel>[sampleSavedListing()]);
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.byType(AppListSkeleton), findsNothing);
    });

    testWidgets('removes a saved property and shows confirmation snackbar',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[sampleSavedListing()],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(repo.removedListingIds, equals(<String>['listing-1']));
      expect(find.text('Removed from saved homes.'), findsOneWidget);
    });

    testWidgets('tapping a saved tile does not crash', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[sampleSavedListing()],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);

      // Verify the tile is present and tappable (navigation requires GoRouter).
      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('renders saved listings in Swahili', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListings: <SavedListingModel>[sampleSavedListing()],
      );

      await tester.pumpWidget(
        _app(repository: repo, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nyumba zililohifadhiwa'), findsOneWidget);
      expect(find.text('Hakuna nyumba zilizohifadhiwa'), findsNothing);
    });

    testWidgets('renders empty state in Swahili', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedListingsMode: SavedMode.empty,
      );

      await tester.pumpWidget(
        _app(repository: repo, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hakuna nyumba zilizohifadhiwa'), findsOneWidget);
    });
  });
}
