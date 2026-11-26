// House Seeker rental journey dashboard widget tests.
//
// Exercises the journey page:
//   - loading skeleton
//   - data state with counts, upcoming visits and recent proposals
//   - empty state (all zero counts, no lists)
//   - AppNotice error rendering (in isolation, matching saved-page pattern)
//
// Overrides houseSeekerJourneyProvider directly so no repository/api is needed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_journey_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

import 'house_seeker_test_utils.dart';

void main() {
  group('HouseSeekerJourneyPage', () {
    testWidgets('shows a loading skeleton while the journey loads', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerJourneyProvider.overrideWith(
                (ref) => Completer<RentalJourneyModel>().future,
              ),
            ],
            child: const HouseSeekerJourneyPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppListSkeleton), findsOneWidget);
    });

    testWidgets('renders counts, upcoming visits and recent proposals', (tester) async {
      final journey = RentalJourneyModel(
        counts: JourneyCounts(
          savedHomes: 3,
          activeEnquiries: 2,
          upcomingVisits: 1,
          pendingProposals: 4,
          activeApplications: 1,
        ),
        upcomingVisits: <JourneyVisitModel>[
          JourneyVisitModel(
            id: 'visit-1',
            propertyId: 'prop-1',
            scheduledAt: '2026-12-01T10:00:00Z',
            status: 'scheduled',
          ),
        ],
        recentProposals: <JourneyProposalModel>[
          JourneyProposalModel(
            id: 'proposal-1',
            status: 'sent',
            proposedRentAmount: 45000,
            propertyTitle: 'Riverside Apartments',
          ),
        ],
      );

      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerJourneyProvider.overrideWith(
                (ref) async => journey,
              ),
            ],
            child: const HouseSeekerJourneyPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Saved homes'), findsOneWidget);
      expect(find.text('Enquiries'), findsOneWidget);
      expect(find.text('Proposals'), findsOneWidget);
      expect(find.text('Applications'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Upcoming visits section + row (below the stat grid).
      expect(find.text('Upcoming visits'), findsWidgets);
      // Scroll to the bottom to reveal the recent proposals section.
      await tester.scrollUntilVisible(
        find.text('Riverside Apartments'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.text('Recent proposals'), findsOneWidget);
    });

    testWidgets('renders zero counts and no lists when journey is empty', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerJourneyProvider.overrideWith(
                (ref) async => RentalJourneyModel(counts: JourneyCounts()),
              ),
            ],
            child: const HouseSeekerJourneyPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Saved homes'), findsOneWidget);
      // Zero appears once per stat card (5 cards all show 0) -> at least one.
      expect(find.text('0'), findsWidgets);
      // No section headers for empty lists.
      expect(find.text('Recent proposals'), findsNothing);
    });

    testWidgets('AppNotice renders the journey error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: Scaffold(
            body: AppNotice(
              message: 'Could not load your rental journey.',
              type: NoticeType.error,
              actionLabel: 'Retry',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load your rental journey.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}