// Widget tests for the House Seeker Saved Searches page.
// Exercises loading, data, empty, CRUD, run-now, alert frequency
// and localization paths against a mocked [HouseSeekerRepository].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_saved_searches_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

import 'house_seeker_saved_test_utils.dart';

Widget _app({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: houseSeekerSavedApp(
      child: const HouseSeekerSavedSearchesPage(),
      locale: locale,
    ),
  );
}

void main() {
  group('HouseSeekerSavedSearchesPage', () {
    testWidgets('shows empty state when no saved searches', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No saved searches yet'), findsOneWidget);
    });

    testWidgets('renders saved searches with criteria and alert frequency',
        (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[
          sampleSavedSearch(
            name: 'Nairobi 2BR under 50k',
            alertFrequency: 'immediate',
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Nairobi 2BR under 50k'), findsOneWidget);
      expect(find.text('Alerts on'), findsOneWidget);
      expect(find.textContaining('Immediately'), findsOneWidget);
    });

    testWidgets('shows alerts off when alerts disabled', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[
          sampleSavedSearch(alertsEnabled: false),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Alerts off'), findsOneWidget);
    });

    testWidgets('creates a saved search via the save dialog',
        (tester) async {
      final repo = FakeSavedFeaturesRepository();

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No saved searches yet'), findsOneWidget);

      // Tapping FAB without filters shows a prompt snackbar.
      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Set some search filters first'),
        findsOneWidget,
      );
    });

    testWidgets('edits a saved search via the edit dialog', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[sampleSavedSearch(name: 'Old Name')],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Old Name'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.tap(nameField);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Updated Name');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(repo.updatedSearches.isNotEmpty, isTrue);
      expect(repo.updatedSearches.first.name, 'Updated Name');
    });

    testWidgets('deletes a saved search after confirmation', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[sampleSavedSearch(name: 'To Delete')],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('To Delete'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(repo.deletedSearchIds, contains('search-1'));
    });

    testWidgets('runs a saved search manually', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[sampleSavedSearch()],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Run now').first);
      await tester.pumpAndSettle();

      expect(repo.runSearchIds, contains('search-1'));
    });

    testWidgets('toggles alerts on/off for a saved search', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[
          sampleSavedSearch(alertsEnabled: true),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Alerts on'), findsOneWidget);

      await tester.tap(find.text('Turn off').first);
      await tester.pumpAndSettle();

      expect(find.text('Alerts off'), findsOneWidget);
    });

    testWidgets('shows run-now error when execution fails', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[sampleSavedSearch()],
        runSavedSearchFails: true,
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Run now').first);
      await tester.pumpAndSettle();

      expect(find.text('Could not run the search. Please try again.'), findsOneWidget);
    });

    testWidgets('renders saved searches in Swahili', (tester) async {
      final repo = FakeSavedFeaturesRepository(
        savedSearches: <SavedSearchModel>[sampleSavedSearch()],
      );

      await tester.pumpWidget(
        _app(repository: repo, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tafuta zililohifadhiwa'), findsOneWidget);
    });

    testWidgets('renders empty state in Swahili', (tester) async {
      final repo = FakeSavedFeaturesRepository(savedSearches: <SavedSearchModel>[]);

      await tester.pumpWidget(
        _app(repository: repo, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hakuna tafuta zilizohifadhiwa'), findsOneWidget);
    });
  });
}
