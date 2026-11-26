// House Seeker property detail tests.
// Covers ListingDetailModel parsing and widget tests for the detail page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_listing_detail_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'house_seeker_test_utils.dart';

final _detailListing = ListingDetailModel(
  listingId: '00000000-0000-0000-0000-000000000001',
  propertyId: '00000000-0000-0000-0000-000000000002',
  title: 'Cosy 1BR Riverside',
  propertyType: 'apartment',
  city: 'Nairobi',
  county: 'Nairobi',
  rentAmount: 45000,
  images: const <String>[
    'https://example.com/img1.jpg',
    'https://example.com/img2.jpg',
  ],
  amenities: const <String>['wifi', 'parking'],
  bedrooms: 1,
  bathrooms: 1,
  furnished: true,
  landlordFirstName: 'John',
  address: '123 Riverside Drive, Nairobi',
  description: 'A beautiful test property with garden.',
  features: const <String>['balcony'],
  pricingFrequency: 'monthly',
);

class _DetailFakeRepository implements HouseSeekerRepository {
  _DetailFakeRepository(this._detail);

  final ListingDetailModel? _detail;

  @override
  Future<ListingDetailModel> getListingDetail(String listingId) async {
    if (_detail == null) throw Exception('Listing not found');
    return _detail!;
  }

  @override
  Future<List<ListingCardModel>> getRelatedListings(String listingId) async =>
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

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _detailApp({
  required ListingDetailModel? detail,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      houseSeekerRepositoryProvider.overrideWithValue(
        _DetailFakeRepository(detail),
      ),
    ],
    child: houseSeekerApp(
      child: const HouseSeekerListingDetailPage(listingId: 'any-id'),
      locale: locale,
    ),
  );
}

void main() {
  group('ListingDetailModel parsing', () {
    test('parses pricingFrequency and computes pricingLabel', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
        'pricingFrequency': 'weekly',
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.pricingFrequency, 'weekly');
      expect(model.pricingLabel, '/week');
    });

    test('pricingLabel defaults to /month for monthly', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
        'pricingFrequency': 'monthly',
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.pricingLabel, '/month');
    });

    test('pricingLabel returns /year for annual', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
        'pricingFrequency': 'annual',
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.pricingLabel, '/year');
    });

    test('pricingLabel returns for sale for sale frequency', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
        'pricingFrequency': 'sale',
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.pricingLabel, 'for sale');
    });

    test('pricingLabel defaults to /month when frequency is null', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.pricingFrequency, isNull);
      expect(model.pricingLabel, '/month');
    });

    test('parses optional fields as null when missing', () {
      final json = <String, dynamic>{
        'listingId': 'l1',
        'propertyId': 'p1',
        'title': 'Test',
        'propertyType': 'apartment',
        'city': 'Nairobi',
        'county': 'Nairobi',
        'rentAmount': 50000,
        'images': <String>[],
        'amenities': <String>[],
      };
      final model = ListingDetailModel.fromJson(json);
      expect(model.bedrooms, isNull);
      expect(model.bathrooms, isNull);
      expect(model.address, isNull);
      expect(model.landlordFirstName, isNull);
      expect(model.latitude, isNull);
      expect(model.longitude, isNull);
      expect(model.features, isEmpty);
    });
  });

  group('Detail page widget tests', () {
    testWidgets('loaded state shows title, price, and location', (
      tester,
    ) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(_detailApp(detail: _detailListing));
      await tester.pumpAndSettle();
      expect(find.text('Cosy 1BR Riverside'), findsOneWidget);
      expect(find.text('KES 45,000/month'), findsOneWidget);
      expect(find.text('123 Riverside Drive, Nairobi'), findsOneWidget);
      expect(find.text('Property owner'), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('loaded state shows Swahili localization', (tester) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(
        _detailApp(detail: _detailListing, locale: const Locale('sw')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mwenye milki'), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('error state shows property not found when detail is null', (
      tester,
    ) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(_detailApp(detail: null));
      await tester.pumpAndSettle();
      expect(find.text('Property not found.'), findsOneWidget);
    });

    testWidgets('gallery renders images without broken icons', (tester) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(_detailApp(detail: _detailListing));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsWidgets);
    });

    testWidgets('amenities section shows chips', (tester) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(_detailApp(detail: _detailListing));
      await tester.pumpAndSettle();
      expect(find.text('Wifi'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
    });

    testWidgets('shows pricing on request when rent is null', (tester) async {
      _setViewport(tester, 390, 844);
      final listing = _detailListing.copyWith(null);
      await tester.pumpWidget(_detailApp(detail: listing));
      await tester.pumpAndSettle();
      expect(find.text('Price on request'), findsOneWidget);
    });

    testWidgets('displays description', (tester) async {
      _setViewport(tester, 390, 844);
      await tester.pumpWidget(_detailApp(detail: _detailListing));
      await tester.pumpAndSettle();
      expect(
        find.text('A beautiful test property with garden.'),
        findsOneWidget,
      );
    });
  });
}

extension on ListingDetailModel {
  ListingDetailModel copyWith(num? rentAmount) {
    return ListingDetailModel(
      listingId: listingId,
      propertyId: propertyId,
      title: title,
      propertyType: propertyType,
      city: city,
      county: county,
      rentAmount: rentAmount,
      images: images,
      amenities: amenities,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      furnished: furnished,
      landlordFirstName: landlordFirstName,
      address: address,
      description: description,
      features: features,
      pricingFrequency: pricingFrequency,
    );
  }
}
