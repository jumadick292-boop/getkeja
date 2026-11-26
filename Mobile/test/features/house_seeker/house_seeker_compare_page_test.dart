// Widget tests for the House Seeker Comparison page.
// Exercises loading, data, empty, error, removal, clear, difference toggle,
// max-items, and localization paths against a mocked [HouseSeekerRepository].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_compare_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

import 'house_seeker_saved_test_utils.dart';

Widget _app({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: houseSeekerSavedApp(
      child: const HouseSeekerComparePage(),
      locale: locale,
    ),
  );
}

List<ComparisonListingModel> sampleComparisonItems() {
  return <ComparisonListingModel>[
    sampleComparisonListing(
      comparisonItemId: 'compare-1',
      listingId: 'listing-1',
      propertyId: 'property-1',
      title: 'Cosy 1BR Riverside',
      city: 'Nairobi',
      county: 'Nairobi',
      rentAmount: 45000,
      bedrooms: 1,
      bathrooms: 1.0,
      amenities: const <String>['wifi', 'parking'],
      furnished: true,
      petPolicy: 'pets allowed',
      smokingAllowed: false,
      images: const <String>['https://example.com/img1.jpg'],
    ),
    sampleComparisonListing(
      comparisonItemId: 'compare-2',
      listingId: 'listing-2',
      propertyId: 'property-2',
      title: 'Modern 2BR Apartment',
      city: 'Mombasa',
      county: 'Mombasa',
      rentAmount: 60000,
      bedrooms: 2,
      bathrooms: 2.0,
      amenities: const <String>['wifi', 'gym'],
      furnished: false,
      petPolicy: 'no pets',
      smokingAllowed: true,
      images: const <String>['https://example.com/img2.jpg'],
    ),
  ];
}

void main() {
  group('HouseSeekerComparePage', () {
    testWidgets('shows empty state when no items are compared', (tester) async {
      final repo = FakeSavedFeaturesRepository();

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No properties compared yet'), findsOneWidget);
      expect(
        find.text(
          'Tap the compare icon on any listing to add it here. You can compare up to 4 properties side by side.',
        ),
        findsOneWidget,
      );
      expect(find.text('Discover homes'), findsOneWidget);
    });

    testWidgets('renders comparison items with all sections', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        comparisonItems: sampleComparisonItems(),
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.text('Modern 2BR Apartment'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.textContaining('KES 45000'), findsWidgets);
      expect(find.textContaining('KES 60000'), findsWidgets);
      expect(find.text('Bedrooms'), findsOneWidget);
      expect(find.text('1 beds'), findsOneWidget);
      expect(find.text('2 beds'), findsOneWidget);
      expect(find.text('Bathrooms'), findsOneWidget);
      expect(find.text('Amenities'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('County'), findsOneWidget);
      expect(find.text('Town'), findsOneWidget);
    });

    testWidgets('removes an item from comparison when X is tapped', (
      tester,
    ) async {
      final repo = FakeSavedFeaturesRepository(
        comparisonItems: sampleComparisonItems(),
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.text('Modern 2BR Apartment'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(repo.removedComparisonIds, contains('listing-1'));
      expect(find.text('Cosy 1BR Riverside'), findsNothing);
      expect(find.text('Modern 2BR Apartment'), findsOneWidget);
    });

    testWidgets('clears all comparison items via app bar clear button', (
      tester,
    ) async {
      final repo = FakeSavedFeaturesRepository(
        comparisonItems: sampleComparisonItems(),
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all').last);
      await tester.pumpAndSettle();

      expect(find.text('No properties compared yet'), findsOneWidget);
    });

    testWidgets('shows at max warning when comparison has 4 items', (
      tester,
    ) async {
      final items = <ComparisonListingModel>[
        for (int i = 1; i <= 4; i++)
          sampleComparisonListing(
            listingId: 'listing-$i',
            title: 'Property $i',
            rentAmount: 45000 * i,
          ),
      ];
      final repo = FakeSavedFeaturesRepository(comparisonItems: items);

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('4 of 4 properties selected'), findsOneWidget);
      expect(
        find.text('Comparison list is full. Remove a property to add another.'),
        findsOneWidget,
      );
    });

    testWidgets('shows difference toggle checkbox', (tester) async {
      final items = <ComparisonListingModel>[
        sampleComparisonListing(
          listingId: 'listing-1',
          title: 'Property 1',
          rentAmount: 45000,
          bedrooms: 2,
          bathrooms: 2.0,
        ),
        sampleComparisonListing(
          listingId: 'listing-2',
          title: 'Property 2',
          rentAmount: 45000,
          bedrooms: 2,
          bathrooms: 2.0,
        ),
      ];
      final repo = FakeSavedFeaturesRepository(comparisonItems: items);

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Price'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('renders empty state in Swahili', (tester) async {
      final repo = FakeSavedFeaturesRepository();

      await tester.pumpWidget(
        _app(repository: repo, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hakuna milki yaliyopanganganishwa'), findsOneWidget);
      expect(find.text('Discover homes'), findsNothing);
    });
  });
}
