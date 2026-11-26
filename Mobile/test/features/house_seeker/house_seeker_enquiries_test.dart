// Widget tests for House Seeker enquiry centre page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_enquiries_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

import 'house_seeker_test_utils.dart';

Widget _app({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const HouseSeekerEnquiriesPage(),
    ),
  );
}

class EnquiryFakeRepository implements HouseSeekerRepository {
  EnquiryFakeRepository({this.enquiries = const <EnquiryModel>[]});

  final List<EnquiryModel> enquiries;
  final List<String> withdrawnIds = <String>[];

  @override
  Future<SearchResultModel> searchListings({
    String? q,
    String? city,
    String? county,
    String? propertyType,
    num? rentMin,
    num? rentMax,
    int? bedrooms,
    int? bathrooms,
    String? furnished,
    String? amenities,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async => SearchResultModel(
    items: <ListingCardModel>[],
    total: 0,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<ListingCardModel>> getFeatured() async => <ListingCardModel>[];

  @override
  Future<List<ListingCardModel>> getRecentlyPublished() async =>
      <ListingCardModel>[];

  @override
  Future<List<ListingCardModel>> getMapListings({
    required double north,
    required double south,
    required double east,
    required double west,
    String? q,
    String? propertyType,
    num? rentMin,
    num? rentMax,
    int? bedrooms,
    int limit = 100,
  }) async => <ListingCardModel>[];

  @override
  Future<FilterFacetsModel> getFilterFacets() async => FilterFacetsModel(
    propertyTypes: const <String>[],
    counties: const <String>[],
  );

  @override
  Future<ListingDetailModel> getListingDetail(String listingId) async =>
      throw UnimplementedError();

  @override
  Future<List<ListingCardModel>> getRelatedListings(String listingId) async =>
      <ListingCardModel>[];

  @override
  Future<void> saveListing(
    String listingId, {
    String? collection,
    String? notes,
  }) async {}

  @override
  Future<void> removeSavedListing(String listingId) async {}

  @override
  Future<List<SavedListingModel>> getSavedListings({
    int limit = 20,
    int offset = 0,
  }) async => <SavedListingModel>[];

  @override
  Future<List<SavedSearchModel>> getSavedSearches() async =>
      <SavedSearchModel>[];

  @override
  Future<SavedSearchModel> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = true,
    String? alertFrequency,
  }) async => SavedSearchModel(
    id: 's-1',
    name: name,
    criteria: criteria,
    alertsEnabled: alertsEnabled,
    alertFrequency: alertFrequency,
  );

  @override
  Future<void> deleteSavedSearch(String searchId) async {}

  @override
  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) async => SavedSearchModel(
    id: searchId,
    name: name ?? '',
    criteria: criteria ?? const <String, dynamic>{},
    alertsEnabled: alertsEnabled ?? true,
  );

  @override
  Future<SavedSearchModel> runSavedSearch(String searchId) async =>
      SavedSearchModel(
        id: searchId,
        name: '',
        criteria: const <String, dynamic>{},
        alertsEnabled: true,
      );

  @override
  Future<EnquiryModel> submitEnquiry({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String message,
    String? phone,
  }) async => EnquiryModel(
    id: 'enq-new',
    propertyId: propertyId,
    listingId: listingId,
    unitId: unitId,
    message: message,
    status: 'new',
  );

  @override
  Future<List<EnquiryModel>> getEnquiries({int limit = 20, int offset = 0}) =>
      Future.value(enquiries);

  @override
  Future<void> withdrawEnquiry(String enquiryId) async {
    withdrawnIds.add(enquiryId);
  }

  @override
  Future<HouseSeekerPreferencesModel?> getPreferences() async => null;

  @override
  Future<void> updatePreferences(Map<String, dynamic> body) async {}

  @override
  Future<void> reportListing({
    required String listingId,
    required String reason,
    String? details,
  }) async {}

  @override
  Future<SiteVisitModel> requestSiteVisit({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String scheduledAt,
    int durationMinutes = 30,
    String? visitorNotes,
    String? phone,
  }) async => throw UnimplementedError();

  @override
  Future<List<SiteVisitModel>> getSiteVisits({
    int limit = 20,
    int offset = 0,
  }) async => <SiteVisitModel>[];

  @override
  Future<void> cancelSiteVisit(String visitId) async {}

  @override
  Future<void> rescheduleSiteVisit(
    String visitId, {
    required String scheduledAt,
  }) async {}

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
  }) async => throw UnimplementedError();

  @override
  Future<List<ConversationModel>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async => <ConversationModel>[];

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async => <MessageModel>[];

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  }) async => throw UnimplementedError();

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<RentalApplicationModel> submitApplication({
    required String propertyId,
    String? listingId,
    String? unitId,
    String? preferredStartDate,
    String? preferredEndDate,
    num? proposedRentAmount,
    String? employerName,
    String? employerContact,
    num? monthlyIncome,
  }) async => throw UnimplementedError();

  @override
  Future<List<RentalApplicationModel>> getApplications({
    int limit = 20,
    int offset = 0,
  }) async => <RentalApplicationModel>[];

  @override
  Future<void> withdrawApplication(String applicationId) async {}

  @override
  Future<List<RentalProposalModel>> getProposals({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async => <RentalProposalModel>[];

  @override
  Future<RentalProposalModel> respondToProposal({
    required String proposalId,
    required String action,
    String? reason,
    Map<String, dynamic>? counter,
  }) async => throw UnimplementedError();

  @override
  Future<RentalJourneyModel> getJourney() async =>
      RentalJourneyModel(counts: JourneyCounts());

  @override
  Future<ComparisonListModel> getComparison({
    int limit = 20,
    int offset = 0,
  }) async => throw UnimplementedError();

  @override
  Future<ComparisonAddResult> addToComparison(String listingId) async =>
      ComparisonAddResult(added: true, listingId: listingId);

  @override
  Future<ComparisonRemoveResult> removeFromComparison(String listingId) async =>
      ComparisonRemoveResult(removed: true);

  @override
  Future<ComparisonClearResult> clearComparison() async =>
      ComparisonClearResult(cleared: true, removedCount: 0);
}

void main() {
  group('HouseSeekerEnquiriesPage', () {
    testWidgets('shows empty state when no enquiries', (tester) async {
      final repo = EnquiryFakeRepository();

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No enquiries yet'), findsOneWidget);
    });

    testWidgets('renders enquiry list with status badges', (tester) async {
      final repo = EnquiryFakeRepository(
        enquiries: <EnquiryModel>[
          EnquiryModel(
            id: 'enq-1',
            propertyId: 'prop-1',
            listingId: 'listing-1',
            message: 'Is the property still available?',
            status: 'new',
            propertyTitle: 'Cosy 1BR Riverside',
            listingTitle: 'Cosy 1BR Riverside',
            city: 'Nairobi',
            county: 'Nairobi',
            source: 'public_listing',
            createdAt: '2026-01-10T10:00:00Z',
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.text('Is the property still available?'), findsOneWidget);
    });

    testWidgets('withdraws enquiry when confirmed', (tester) async {
      final repo = EnquiryFakeRepository(
        enquiries: <EnquiryModel>[
          EnquiryModel(
            id: 'enq-1',
            propertyId: 'prop-1',
            message: 'Test enquiry',
            status: 'new',
            propertyTitle: 'Test Property',
          ),
        ],
      );

      await tester.pumpWidget(_app(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Withdraw'), findsOneWidget);
      await tester.tap(find.text('Withdraw').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();

      expect(repo.withdrawnIds, contains('enq-1'));
    });

    testWidgets('shows loading skeleton initially', (tester) async {
      final repo = EnquiryFakeRepository();

      await tester.pumpWidget(_app(repository: repo));
      await tester.pump();
    });
  });
}
