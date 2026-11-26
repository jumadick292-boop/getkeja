import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_home_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class _FakeHouseSeekerRepository implements HouseSeekerRepository {
  _FakeHouseSeekerRepository({List<ListingCardModel>? featured})
    : _featured = featured ?? <ListingCardModel>[];

  final List<ListingCardModel> _featured;

  @override
  Future<List<ListingCardModel>> getFeatured() async => _featured;

  @override
  Future<List<ListingCardModel>> getRecentlyPublished() async =>
      <ListingCardModel>[];

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
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSavedSearch(String searchId) async {}

  @override
  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) async => throw UnimplementedError();

  @override
  Future<SavedSearchModel> runSavedSearch(String searchId) async =>
      throw UnimplementedError();

  @override
  Future<EnquiryModel> submitEnquiry({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String message,
    String? phone,
  }) async => throw UnimplementedError();

  @override
  Future<List<EnquiryModel>> getEnquiries({
    int limit = 20,
    int offset = 0,
  }) async => <EnquiryModel>[];

  @override
  Future<void> withdrawEnquiry(String enquiryId) async {}

  @override
  Future<void> withdrawApplication(String applicationId) async {}

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
  }) async => ComparisonListModel(
        items: <ComparisonListingModel>[],
        total: 0,
        limit: limit,
        offset: offset,
      );

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

Widget _app({required HouseSeekerRepository repository}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: const HouseSeekerHomePage(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('house seeker home shows the discovery heading', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(repository: _FakeHouseSeekerRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to GetKeja'), findsOneWidget);
    expect(find.byType(HouseSeekerHomePage), findsOneWidget);
  });

  testWidgets(
    'house seeker home renders featured listings from the repository',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final listing = ListingCardModel(
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
      await tester.pumpWidget(
        _app(
          repository: _FakeHouseSeekerRepository(
            featured: <ListingCardModel>[listing],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.textContaining('KES 45,000'), findsOneWidget);
    },
  );

  testWidgets(
    'house seeker home shows the empty state when no featured homes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(repository: _FakeHouseSeekerRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Featured homes'), findsWidgets);
    },
  );
}
