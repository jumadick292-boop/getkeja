// Reusable House Seeker test utilities.
// Establishes patterns for Riverpod provider overrides, API repository
// mocking, loading/empty/error states, navigation, responsive layouts and
// localization without implementing new product features.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

/// Builds a MaterialApp for House Seeker widget tests.
///
/// Configures [AppLocalizations] so en/sw localization can be exercised and
/// applies the shared design-system theme. Callers wrap the returned widget in
/// a [ProviderScope] (with any desired provider overrides) so Riverpod
/// providers can be read.
Widget houseSeekerApp({
  required Widget child,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: child,
  );
}

/// Mock [HouseSeekerRepository] whose [getFeatured] future can be controlled
/// to exercise data, empty, loading and error rendering paths.
class FakeHouseSeekerRepository implements HouseSeekerRepository {
  FakeHouseSeekerRepository.data(this._listings) : _mode = _Mode.data;
  FakeHouseSeekerRepository.empty() : _listings = null, _mode = _Mode.empty;
  FakeHouseSeekerRepository.loading() : _listings = null, _mode = _Mode.loading;
  FakeHouseSeekerRepository.error() : _listings = null, _mode = _Mode.error;

  final List<ListingCardModel>? _listings;
  final _Mode _mode;
  late final Completer<List<ListingCardModel>> _completer = Completer();

  /// Completes a [loading] repository's featured future with [listings].
  void complete(List<ListingCardModel> listings) {
    assert(_mode == _Mode.loading);
    _completer.complete(listings);
  }

  /// Fails a [loading] repository's featured future.
  void fail(Object error, [StackTrace? stackTrace]) {
    assert(_mode == _Mode.loading);
    _completer.completeError(error, stackTrace);
  }

  @override
  Future<List<ListingCardModel>> getFeatured() async {
    switch (_mode) {
      case _Mode.data:
        return _listings ?? <ListingCardModel>[];
      case _Mode.empty:
        return <ListingCardModel>[];
      case _Mode.loading:
        return _completer.future;
      case _Mode.error:
        throw Exception('featured load failed');
    }
  }

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
  Future<ListingDetailModel> getListingDetail(String listingId) async {
    switch (_mode) {
      case _Mode.data:
        if (_listings?.isNotEmpty == true) {
          return ListingDetailModel.fromJson(_detailJson);
        }
        throw UnimplementedError();
      case _Mode.empty:
        throw Exception('Listing not found');
      case _Mode.loading:
        throw UnimplementedError();
      case _Mode.error:
        throw Exception('detail load failed');
    }
  }

  @override
  Future<List<ListingCardModel>> getRelatedListings(String listingId) async =>
      <ListingCardModel>[];

  /// JSON used to build a [ListingDetailModel] in data mode.
  Map<String, dynamic> get _detailJson => <String, dynamic>{
    'listingId': '00000000-0000-0000-0000-000000000001',
    'propertyId': '00000000-0000-0000-0000-000000000002',
    'title': 'Test Listing',
    'description': 'A beautiful test property',
    'propertyTitle': 'Test Property',
    'propertyType': 'apartment',
    'city': 'Nairobi',
    'county': 'Nairobi',
    'rentAmount': 50000,
    'depositAmount': 100000,
    'latitude': -1.2921,
    'longitude': 36.8219,
    'bedrooms': 2,
    'bathrooms': 2.0,
    'unitNumber': 'A101',
    'unitId': '00000000-0000-0000-0000-000000000003',
    'furnished': true,
    'availableFrom': '2026-12-01',
    'publishedAt': '2026-01-01T00:00:00Z',
    'images': <String>['https://example.com/img1.jpg'],
    'amenities': <String>['wifi', 'parking'],
    'address': '123 Test Street, Nairobi',
    'propertyDescription': 'A beautiful test property',
    'unitDescription': 'Unit A101',
    'landlordFirstName': 'John',
    'landlordUserId': '00000000-0000-0000-0000-000000000004',
    'petPolicy': 'allowed',
    'smokingAllowed': false,
    'listingFeatures': <String>['balcony', 'garden'],
    'pricingFrequency': 'monthly',
    'listingStatus': 'published',
  };

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

enum _Mode { data, empty, loading, error }
