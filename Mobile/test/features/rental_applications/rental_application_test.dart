// Widget tests for the rental application workflow (seeker detail + landlord inbox).
//
// Overrides rentalApplicationRepositoryProvider with a fake so the pages render
// backend-shaped data and exercise loading / data / status-timeline states.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_repository.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/application_detail_page.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/application_review_page.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/applications_inbox_page.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/rental_application_providers.dart';

import '../house_seeker/house_seeker_test_utils.dart';

class _FakeRentalRepo implements RentalApplicationRepository {
  _FakeRentalRepo.data(this._detail)
      : _inbox = ManagedApplicationListModel(items: <ManagedApplicationModel>[
          ManagedApplicationModel.fromJson(<String, dynamic>{
            'id': 'a1',
            'propertyId': 'p1',
            'status': 'submitted',
            'applicantName': 'Jane',
            'propertyTitle': 'Riverside Apartments',
            'city': 'Nairobi',
            'proposedRentAmount': 45000,
            'createdAt': '2026-11-01T10:00:00Z',
          }),
        ]);
  _FakeRentalRepo.loading()
      : _detail = null,
        _inbox = null;
  _FakeRentalRepo.empty()
      : _detail = _detailFrom('submitted'),
        _inbox = ManagedApplicationListModel(items: <ManagedApplicationModel>[]);

  RentalApplicationDetailModel? _detail;
  ManagedApplicationListModel? _inbox;

  static RentalApplicationDetailModel _detailFrom(String status) =>
      RentalApplicationDetailModel.fromJson(<String, dynamic>{
        'application': <String, dynamic>{
          'id': 'app-1',
          'propertyId': 'p1',
          'status': status,
          'applicantName': 'Jane',
          'proposedRentAmount': 45000,
          'propertyTitle': 'Riverside Apartments',
          'createdAt': '2026-11-01T10:00:00Z',
        },
        'history': <dynamic>[
          <String, dynamic>{'action': 'submitted', 'newStatus': 'submitted', 'createdAt': '2026-11-01'},
          <String, dynamic>{'action': 'status_change', 'previousStatus': 'submitted', 'newStatus': 'under_review', 'createdAt': '2026-11-02'},
        ],
        'notes': <dynamic>[],
        'documents': <dynamic>[],
      });

  @override
  Future<RentalApplicationRecord> saveDraft(Map<String, dynamic> body) async =>
      _detail!.application;

  @override
  Future<RentalApplicationRecord> submitApplication(Map<String, dynamic> body) async =>
      _detail!.application;

  @override
  Future<RentalApplicationRecord> submitDraft(String applicationId) async =>
      _detail!.application;

  @override
  Future<RentalApplicationRecord> resubmit(
    String applicationId,
    Map<String, dynamic> body,
  ) async =>
      _detail!.application;

  @override
  Future<RentalApplicationRecord> withdraw(String applicationId) async =>
      _detail!.application;

  @override
  Future<RentalApplicationDetailModel> getDetail(String applicationId) async {
    if (_detail == null) {
      throw Exception('load failed');
    }
    return _detail!;
  }

  @override
  Future<ManagedApplicationListModel> listInbox({
    String? status,
    String? propertyId,
    int limit = 20,
    int offset = 0,
  }) async =>
      _inbox ?? ManagedApplicationListModel(items: <ManagedApplicationModel>[]);

  @override
  Future<RentalApplicationDetailModel> getManagedDetail(String applicationId) async =>
      _detail!;

  @override
  Future<RentalApplicationRecord> transition(
    String applicationId,
    String action, {
    String? reason,
  }) async =>
      _detail!.application;

  @override
  Future<({RentalApplicationRecord application, OnboardingResultModel? onboarding})>
      approve(String applicationId, Map<String, dynamic> body) async =>
          (application: _detail!.application, onboarding: null);

  @override
  Future<OnboardingResultModel> onboard(String applicationId) async =>
      OnboardingResultModel();

  @override
  Future<void> addNote(String applicationId, String note) async {}

  @override
  Future<ApplicationDocumentModel> uploadDocument(
    String applicationId,
    String filePath,
    String fileName,
    String mimeType, {
    String? category,
  }) async =>
      ApplicationDocumentModel(id: 'doc1', fileName: fileName);

  @override
  Future<List<ApplicationDocumentModel>> listDocuments(String applicationId) async =>
      <ApplicationDocumentModel>[];

  @override
  Future<String> downloadDocumentUrl(String documentId) async => '';
}

void main() {
  group('RentalApplicationDetailPage', () {
    testWidgets('shows loading indicator while the application loads', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.loading()),
            ],
            child: const RentalApplicationDetailPage(applicationId: 'app-1'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the status and a timeline of history entries', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.data(_FakeRentalRepo._detailFrom('submitted'))),
            ],
            child: const RentalApplicationDetailPage(applicationId: 'app-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      // Status chip + timeline rows render backend statuses (capitalized).
      expect(find.textContaining('Submitted'), findsWidgets);
      expect(find.textContaining('Under review'), findsWidgets);
    });

    testWidgets('offers a withdraw action for a withdrawable application', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.data(_FakeRentalRepo._detailFrom('submitted'))),
            ],
            child: const RentalApplicationDetailPage(applicationId: 'app-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Withdraw application'), findsOneWidget);
    });

    testWidgets('offers a document upload action for a draft application', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.data(_FakeRentalRepo._detailFrom('draft'))),
            ],
            child: const RentalApplicationDetailPage(applicationId: 'app-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Upload document'), findsOneWidget);
    });
  });

  group('RentalApplicationsInboxPage', () {
    testWidgets('renders an empty state when there are no applications', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.empty()),
            ],
            child: const RentalApplicationsInboxPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No applications yet.'), findsOneWidget);
    });

    testWidgets('renders an inbox row from backend data', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider
                  .overrideWithValue(_FakeRentalRepo.data(_FakeRentalRepo._detailFrom('submitted'))),
            ],
            child: const RentalApplicationsInboxPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Riverside Apartments'), findsOneWidget);
      expect(find.textContaining('Jane'), findsOneWidget);
    });
  });

  group('ApplicationReviewPage messaging entry point', () {
    testWidgets('message applicant reuses the application conversation', (tester) async {
      final repo = _MessagingFakeRepository();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              rentalApplicationRepositoryProvider.overrideWithValue(
                _FakeRentalRepo.data(_FakeRentalRepo._detailFrom('submitted')),
              ),
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const RentalApplicationReviewPage(applicationId: 'app-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(OutlinedButton, 'Message applicant');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(repo.startCalls.length, 1);
      expect(repo.startCalls.single.propertyId, 'p1');
      expect(repo.startCalls.single.rentalApplicationId, 'app-1');
      expect(repo.startCalls.single.rentalProposalId, isNull);
    });
  });
}

class _StartCall {
  _StartCall(this.propertyId, this.rentalApplicationId, this.rentalProposalId);
  final String propertyId;
  final String? rentalApplicationId;
  final String? rentalProposalId;
}

/// Records startConversation calls, then throws to stop navigation (the test
/// harness has no GoRouter) so the messaging context can be asserted.
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