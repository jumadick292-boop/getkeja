// House Seeker rental applications widget tests.
//
// Exercises the applications page:
//   - loading skeleton
//   - empty state
//   - data state with application terms and withdraw action (when withdrawable)
//   - read-only state when the application cannot be withdrawn
//   - withdraw flow calls repository after confirmation
//   - AppNotice error rendering (in isolation)
//
// Overrides houseSeekerApplicationsProvider and houseSeekerRepositoryProvider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_applications_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

import 'house_seeker_test_utils.dart';

void main() {
  group('HouseSeekerApplicationsPage', () {
    testWidgets('shows a loading skeleton while applications load', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerApplicationsProvider.overrideWith(
                (ref) => Completer<List<RentalApplicationModel>>().future,
              ),
            ],
            child: const HouseSeekerApplicationsPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppListSkeleton), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no applications', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerApplicationsProvider.overrideWith(
                (ref) async => <RentalApplicationModel>[],
              ),
            ],
            child: const HouseSeekerApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No applications yet'), findsOneWidget);
    });

    testWidgets('renders an application and a withdraw action when withdrawable',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerApplicationsProvider.overrideWith(
                (ref) async => <RentalApplicationModel>[_submittedApplication()],
              ),
            ],
            child: const HouseSeekerApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('hides the withdraw action when the application is not withdrawable',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerApplicationsProvider.overrideWith(
                (ref) async => <RentalApplicationModel>[
                  RentalApplicationModel(
                    id: 'a-approved',
                    propertyId: 'prop-1',
                    status: 'approved',
                    propertyTitle: 'Riverside Apartments',
                  ),
                ],
              ),
            ],
            child: const HouseSeekerApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.text('Withdraw'), findsNothing);
    });

    testWidgets('withdrawing an application confirms then calls the repository',
        (tester) async {
      final repo = _ApplicationsFakeRepository();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerApplicationsProvider.overrideWith(
                (ref) async => <RentalApplicationModel>[_submittedApplication()],
              ),
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const HouseSeekerApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      // Confirm in dialog (scope to the dialog to avoid the tile's Withdraw).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Withdraw'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.withdrawnIds, contains('a-1'));
    });

    testWidgets('AppNotice renders the applications error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: Scaffold(
            body: AppNotice(
              message: 'Could not load your applications.',
              type: NoticeType.error,
              actionLabel: 'Retry',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load your applications.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

RentalApplicationModel _submittedApplication() => RentalApplicationModel(
      id: 'a-1',
      propertyId: 'prop-1',
      status: 'submitted',
      propertyTitle: 'Riverside Apartments',
      proposedRentAmount: 45000,
      city: 'Nairobi',
    );

class _ApplicationsFakeRepository implements HouseSeekerRepository {
  final List<String> withdrawnIds = <String>[];

  @override
  Future<void> withdrawApplication(String applicationId) async {
    withdrawnIds.add(applicationId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used in this test');
}