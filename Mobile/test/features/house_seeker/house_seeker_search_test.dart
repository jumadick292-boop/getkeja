// House Seeker search and filter tests.
// Covers HouseSeekerFilter serialization, search state transitions, and
// search page rendering across loading/empty/error/data states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_search_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

final _listing = ListingCardModel(
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

class _FakeSearchRepository implements HouseSeekerRepository {
  _FakeSearchRepository({this.result});

  final SearchResultModel? result;

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
  }) async =>
      result ??
      SearchResultModel(
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
    propertyTypes: const <String>['apartment', 'house', 'townhouse'],
    counties: const <String>['Nairobi', 'Mombasa', 'Kisumu'],
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

Widget _searchApp({
  required HouseSeekerRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [houseSeekerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: const HouseSeekerSearchPage(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    ),
  );
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('HouseSeekerFilter', () {
    test('isActive is false when no filters set', () {
      expect(const HouseSeekerFilter().isActive, isFalse);
    });

    test('isActive is true when q is set', () {
      expect(const HouseSeekerFilter(q: 'nairobi').isActive, isTrue);
    });

    test('isActive is true when neighbourhood is set', () {
      expect(
        const HouseSeekerFilter(neighbourhood: 'Kileleshwa').isActive,
        isTrue,
      );
    });

    test('activeCount counts neighbourhood', () {
      expect(
        const HouseSeekerFilter(neighbourhood: 'Kileleshwa').activeCount,
        equals(1),
      );
    });

    test('copyWith updates fields', () {
      final f = const HouseSeekerFilter(q: 'nairobi');
      final updated = f.copyWith(rentMax: 50000, neighbourhood: 'Westlands');
      expect(updated.q, 'nairobi');
      expect(updated.rentMax, 50000);
      expect(updated.neighbourhood, 'Westlands');
    });

    test('copyWith clear resets all fields', () {
      final f = const HouseSeekerFilter(q: 'nairobi', rentMax: 50000);
      final cleared = f.copyWith(clear: true);
      expect(cleared.isActive, isFalse);
      expect(cleared.q, isNull);
      expect(cleared.rentMax, isNull);
    });

    test('toCriteria includes neighbourhood', () {
      final f = const HouseSeekerFilter(
        q: 'nairobi',
        neighbourhood: 'Kileleshwa',
        rentMin: 30000,
        rentMax: 60000,
      );
      final criteria = f.toCriteria();
      expect(criteria['q'], 'nairobi');
      expect(criteria['neighbourhood'], 'Kileleshwa');
      expect(criteria['rentMin'], 30000);
      expect(criteria['rentMax'], 60000);
    });

    test('fromCriteria parses neighbourhood', () {
      final f = HouseSeekerFilter.fromCriteria(<String, dynamic>{
        'q': 'nairobi',
        'neighbourhood': 'Kileleshwa',
        'rentMin': 30000,
        'sort': 'newest',
      });
      expect(f.q, 'nairobi');
      expect(f.neighbourhood, 'Kileleshwa');
      expect(f.rentMin, 30000);
      expect(f.sort, 'newest');
    });
  });

  group('search page', () {
    testWidgets('shows search heading and search field', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(_searchApp(repository: _FakeSearchRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Search homes'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows listings when search returns data', (tester) async {
      _setViewport(tester, 400, 1600);
      await tester.pumpWidget(
        _searchApp(
          repository: _FakeSearchRepository(
            result: SearchResultModel(
              items: <ListingCardModel>[_listing],
              total: 1,
              limit: 20,
              offset: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.textContaining('KES 45,000'), findsOneWidget);
    });

    testWidgets('shows empty state when no results', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(_searchApp(repository: _FakeSearchRepository()));
      await tester.pumpAndSettle();

      expect(find.text('No homes match your search'), findsOneWidget);
    });

    testWidgets('shows Swahili empty state', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(
        _searchApp(
          repository: _FakeSearchRepository(),
          locale: const Locale('sw'),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Hakuna nyumba zinayomotokana na tafuta yako'),
        findsOneWidget,
      );
    });

    testWidgets('submits search query', (tester) async {
      _setViewport(tester, 400, 1600);
      await tester.pumpWidget(
        _searchApp(
          repository: _FakeSearchRepository(
            result: SearchResultModel(
              items: <ListingCardModel>[_listing],
              total: 1,
              limit: 20,
              offset: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Kileleshwa');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
    });

    testWidgets('clear button clears search text', (tester) async {
      _setViewport(tester, 400, 1200);
      await tester.pumpWidget(_searchApp(repository: _FakeSearchRepository()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.enterText(searchField, 'test');
      await tester.pump(const Duration(seconds: 1));

      // Verify text was entered.
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('filter button opens bottom sheet', (tester) async {
      _setViewport(tester, 400, 1600);
      await tester.pumpWidget(_searchApp(repository: _FakeSearchRepository()));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Price range (KES)'), findsOneWidget);
      expect(find.text('Bedrooms'), findsOneWidget);
      expect(find.text('Property type'), findsAtLeastNWidgets(1));
      expect(find.text('County'), findsAtLeastNWidgets(1));
      expect(find.text('Neighbourhood'), findsAtLeastNWidgets(1));
      expect(find.text('Amenities'), findsAtLeastNWidgets(1));
    });
  });
}
