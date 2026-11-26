// House Seeker rental proposals widget tests.
//
// Exercises the proposals page:
//   - loading skeleton
//   - empty state
//   - data state with proposal terms and respond actions (accept/decline/counter)
//   - read-only state when the proposal cannot be responded to
//   - accept flow calls repository and invalidates the provider
//   - AppNotice error rendering (in isolation)
//
// Overrides houseSeekerProposalsProvider and houseSeekerRepositoryProvider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_proposals_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

import 'house_seeker_test_utils.dart';

void main() {
  group('HouseSeekerProposalsPage', () {
    testWidgets('shows a loading skeleton while proposals load', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) => Completer<List<RentalProposalModel>>().future,
              ),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppListSkeleton), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no proposals', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) async => <RentalProposalModel>[],
              ),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No proposals yet'), findsOneWidget);
      expect(
        find.text('When a landlord sends you rental terms, you can review them here.'),
        findsOneWidget,
      );
    });

    testWidgets('renders proposal terms and respond actions when actionable',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) async => <RentalProposalModel>[_sentProposal()],
              ),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);
    });

    testWidgets('hides respond actions when the proposal is not actionable',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) async => <RentalProposalModel>[
                  RentalProposalModel(
                    id: 'p-accepted',
                    propertyId: 'prop-1',
                    status: 'accepted',
                    propertyTitle: 'Riverside Apartments',
                  ),
                ],
              ),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      expect(find.text('Counter'), findsNothing);
    });

    testWidgets('accepting a proposal confirms then calls the repository',
        (tester) async {
      final repo = _ProposalsFakeRepository();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) async => <RentalProposalModel>[_sentProposal()],
              ),
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      // Confirm in dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Accept'));
      await tester.pumpAndSettle();

      expect(repo.respondCalls, contains('accept:p-1'));
    });

    testWidgets('message landlord reuses the proposal conversation', (tester) async {
      final repo = _MessagingFakeRepository();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerProposalsProvider.overrideWith(
                (ref) async => <RentalProposalModel>[_sentProposal()],
              ),
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const HouseSeekerProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final messageButton = find.widgetWithText(TextButton, 'Message landlord');
      expect(messageButton, findsOneWidget);
      await tester.tap(messageButton);
      await tester.pumpAndSettle();

      // The entry point must reuse startConversation with the proposal context,
      // never a private duplicate thread.
      expect(repo.startCalls.length, 1);
      expect(repo.startCalls.single.propertyId, 'prop-1');
      expect(repo.startCalls.single.rentalProposalId, 'p-1');
      expect(repo.startCalls.single.rentalApplicationId, isNull);
    });

    testWidgets('AppNotice renders the proposals error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: Scaffold(
            body: AppNotice(
              message: 'Could not load your proposals.',
              type: NoticeType.error,
              actionLabel: 'Retry',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load your proposals.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

RentalProposalModel _sentProposal() => RentalProposalModel(
      id: 'p-1',
      propertyId: 'prop-1',
      status: 'sent',
      propertyTitle: 'Riverside Apartments',
      proposedRentAmount: 45000,
      proposedDepositAmount: 90000,
      proposedRentDueDay: 1,
      city: 'Nairobi',
    );

class _ProposalsFakeRepository implements HouseSeekerRepository {
  final List<String> respondCalls = <String>[];

  @override
  Future<RentalProposalModel> respondToProposal({
    required String proposalId,
    required String action,
    String? reason,
    Map<String, dynamic>? counter,
  }) async {
    respondCalls.add('$action:$proposalId');
    return RentalProposalModel(id: proposalId, propertyId: 'prop-1', status: 'accepted');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used in this test');
}

class _StartCall {
  _StartCall(this.propertyId, this.rentalApplicationId, this.rentalProposalId);
  final String propertyId;
  final String? rentalApplicationId;
  final String? rentalProposalId;
}

/// Records startConversation calls and then throws to stop the page before it
/// navigates (the test harness has no GoRouter), so we can assert the messaging
/// context without a full navigation stack.
class _MessagingFakeRepository implements HouseSeekerRepository {
  final List<_StartCall> startCalls = <_StartCall>[];

  @override
  Future<StartConversationResult> startConversation({
    required String propertyId,
    String landlordUserId = '',
    String? listingId,
    String? unitId,
    String? subject,
    String? rentalApplicationId,
    String? rentalProposalId,
    String message = '',
  }) async {
    startCalls.add(_StartCall(propertyId, rentalApplicationId, rentalProposalId));
    throw StateError('stop-before-navigate');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used in this test');
}