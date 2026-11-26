// Landlord / manager rental proposal review widget tests (Task 10.4 entry point 3).
//
// Verifies the proposal review surface reuses the shared messaging flow:
//   - renders proposals with their terms
//   - the "Message renter" action reuses startConversation with the proposal
//     context (never a private duplicate thread)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/pages/landlord_proposals_page.dart';

void main() {
  group('LandlordProposalsPage', () {
    testWidgets('renders proposals and the message renter action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            landlordProposalsProvider.overrideWith(
              (ref) async => <RentalProposalModel>[_proposal()],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LandlordProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Message renter'), findsOneWidget);
    });

    testWidgets('message renter reuses the proposal conversation', (tester) async {
      final repo = _MessagingFakeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            landlordProposalsProvider.overrideWith(
              (ref) async => <RentalProposalModel>[_proposal()],
            ),
            houseSeekerRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LandlordProposalsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Message renter'));
      await tester.pumpAndSettle();

      expect(repo.startCalls.length, 1);
      expect(repo.startCalls.single.propertyId, 'prop-1');
      expect(repo.startCalls.single.rentalProposalId, 'p-1');
      expect(repo.startCalls.single.rentalApplicationId, isNull);
    });
  });
}

RentalProposalModel _proposal() => RentalProposalModel(
      id: 'p-1',
      propertyId: 'prop-1',
      status: 'sent',
      propertyTitle: 'Riverside Apartments',
      proposedRentAmount: 45000,
      proposedDepositAmount: 90000,
      proposedRentDueDay: 1,
    );

class _StartCall {
  _StartCall(this.propertyId, this.rentalApplicationId, this.rentalProposalId);
  final String propertyId;
  final String? rentalApplicationId;
  final String? rentalProposalId;
}

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