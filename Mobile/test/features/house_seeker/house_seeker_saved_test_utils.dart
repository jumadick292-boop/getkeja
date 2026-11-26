// Reusable House Seeker saved-features test utilities.
// Extends the patterns in house_seeker_test_utils.dart for saved properties
// and saved searches widget tests without implementing new product features.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

/// Builds a MaterialApp for House Seeker saved-features widget tests.
///
/// Configures [AppLocalizations] so en/sw localization can be exercised and
/// applies the shared design-system theme.
Widget houseSeekerSavedApp({
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

enum SavedMode { data, empty, loading, error }

/// Mock [HouseSeekerRepository] tailored for saved properties and saved
// searches widget tests.
class FakeSavedFeaturesRepository implements HouseSeekerRepository {
  FakeSavedFeaturesRepository({
    List<SavedListingModel>? savedListings,
    List<SavedSearchModel>? savedSearches,
    List<ComparisonListingModel>? comparisonItems,
    SavedMode savedListingsMode = SavedMode.data,
    bool removeSavedListingFails = false,
    bool createSavedSearchFails = false,
    bool updateSavedSearchFails = false,
    bool deleteSavedSearchFails = false,
    bool runSavedSearchFails = false,
    bool addToComparisonFails = false,
    bool removeFromComparisonFails = false,
    bool clearComparisonFails = false,
  }) : _savedListings = savedListings ?? <SavedListingModel>[],
       _savedSearches = savedSearches ?? <SavedSearchModel>[],
       _comparisonItems = comparisonItems ?? <ComparisonListingModel>[],
       _savedListingsMode = savedListingsMode,
       _removeSavedListingFails = removeSavedListingFails,
       _createSavedSearchFails = createSavedSearchFails,
       _updateSavedSearchFails = updateSavedSearchFails,
       _deleteSavedSearchFails = deleteSavedSearchFails,
       _runSavedSearchFails = runSavedSearchFails,
       _addToComparisonFails = addToComparisonFails,
       _removeFromComparisonFails = removeFromComparisonFails,
       _clearComparisonFails = clearComparisonFails;

  final List<SavedListingModel> _savedListings;
  final List<SavedSearchModel> _savedSearches;
  final List<ComparisonListingModel> _comparisonItems;
  final SavedMode _savedListingsMode;
  final bool _removeSavedListingFails;
  final bool _createSavedSearchFails;
  final bool _updateSavedSearchFails;
  final bool _deleteSavedSearchFails;
  final bool _runSavedSearchFails;
  final bool _addToComparisonFails;
  final bool _removeFromComparisonFails;
  final bool _clearComparisonFails;

  // Track mutations for assertions.
  final List<String> removedListingIds = <String>[];
  final List<SavedSearchModel> createdSearches = <SavedSearchModel>[];
  final List<SavedSearchModel> updatedSearches = <SavedSearchModel>[];
  final List<String> deletedSearchIds = <String>[];
  final List<String> runSearchIds = <String>[];
  final List<String> addedComparisonIds = <String>[];
  final List<String> removedComparisonIds = <String>[];

  late final Completer<List<SavedListingModel>> _listingsCompleter =
      Completer();

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
  Future<void> removeSavedListing(String listingId) async {
    removedListingIds.add(listingId);
    if (_removeSavedListingFails) {
      throw Exception('remove saved listing failed');
    }
  }

  @override
  Future<List<SavedListingModel>> getSavedListings({
    int limit = 20,
    int offset = 0,
  }) async {
    switch (_savedListingsMode) {
      case SavedMode.data:
        return _savedListings;
      case SavedMode.empty:
        return <SavedListingModel>[];
      case SavedMode.loading:
        return _listingsCompleter.future;
      case SavedMode.error:
        throw Exception('load failed');
    }
  }

  /// Completes a [loading] saved-listings future with [listings].
  void completeListings(List<SavedListingModel> listings) {
    assert(_savedListingsMode == SavedMode.loading);
    _listingsCompleter.complete(listings);
  }

  /// Fails a [loading] saved-listings future.
  void failListings(Object error, [StackTrace? stackTrace]) {
    assert(_savedListingsMode == SavedMode.loading);
    _listingsCompleter.completeError(error, stackTrace);
  }

  @override
  Future<List<SavedSearchModel>> getSavedSearches() async => _savedSearches;

  @override
  Future<SavedSearchModel> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = true,
    String? alertFrequency,
  }) async {
    if (_createSavedSearchFails) {
      throw Exception('create saved search failed');
    }
    final search = SavedSearchModel(
      id: 'new-search-${createdSearches.length + 1}',
      name: name,
      criteria: criteria,
      alertsEnabled: alertsEnabled,
      alertFrequency: alertFrequency,
    );
    createdSearches.add(search);
    _savedSearches.add(search);
    return search;
  }

  @override
  Future<void> deleteSavedSearch(String searchId) async {
    deletedSearchIds.add(searchId);
    if (_deleteSavedSearchFails) {
      throw Exception('delete saved search failed');
    }
    _savedSearches.removeWhere((s) => s.id == searchId);
  }

  @override
  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) async {
    if (_updateSavedSearchFails) {
      throw Exception('update saved search failed');
    }
    final index = _savedSearches.indexWhere((s) => s.id == searchId);
    if (index >= 0) {
      final existing = _savedSearches[index];
      final updated = SavedSearchModel(
        id: searchId,
        name: name ?? existing.name,
        criteria: criteria ?? existing.criteria,
        alertsEnabled: alertsEnabled ?? existing.alertsEnabled,
        alertFrequency: alertFrequency ?? existing.alertFrequency,
      );
      _savedSearches[index] = updated;
      updatedSearches.add(updated);
      return updated;
    }
    final updated = SavedSearchModel(
      id: searchId,
      name: name ?? '',
      criteria: const <String, dynamic>{},
      alertsEnabled: true,
    );
    _savedSearches.add(updated);
    updatedSearches.add(updated);
    return updated;
  }

  @override
  Future<SavedSearchModel> runSavedSearch(String searchId) async {
    runSearchIds.add(searchId);
    if (_runSavedSearchFails) {
      throw Exception('run saved search failed');
    }
    final existing = _savedSearches.firstWhere(
      (s) => s.id == searchId,
      orElse: () => SavedSearchModel(
        id: searchId,
        name: '',
        criteria: const <String, dynamic>{},
        alertsEnabled: true,
      ),
    );
    return existing;
  }

  // ---- Comparison ----

  @override
  Future<ComparisonListModel> getComparison({
    int limit = 20,
    int offset = 0,
  }) async => ComparisonListModel(
    items: _comparisonItems,
    total: _comparisonItems.length,
    limit: limit,
    offset: offset,
  );

  @override
  Future<ComparisonAddResult> addToComparison(String listingId) async {
    addedComparisonIds.add(listingId);
    if (_addToComparisonFails) {
      throw Exception('add to comparison failed');
    }
    if (_comparisonItems.any((i) => i.listingId == listingId)) {
      return ComparisonAddResult(
        added: false,
        listingId: listingId,
        reason: 'already_in_comparison',
      );
    }
    final item = ComparisonListingModel(
      comparisonItemId: 'compare-$listingId',
      listingId: listingId,
      propertyId: 'property-$listingId',
      title: 'Test Property $listingId',
      propertyType: 'apartment',
      city: 'Nairobi',
      county: 'Nairobi',
      rentAmount: 45000,
      images: const <String>[],
      amenities: const <String>[],
      position: _comparisonItems.length,
      addedAt: DateTime.now().toIso8601String(),
    );
    _comparisonItems.add(item);
    return ComparisonAddResult(
      added: true,
      listingId: listingId,
      listId: 'list-1',
      position: _comparisonItems.length - 1,
      createdAt: item.addedAt,
    );
  }

  @override
  Future<ComparisonRemoveResult> removeFromComparison(String listingId) async {
    removedComparisonIds.add(listingId);
    if (_removeFromComparisonFails) {
      throw Exception('remove from comparison failed');
    }
    final removed = _comparisonItems.any((i) => i.listingId == listingId);
    _comparisonItems.removeWhere((i) => i.listingId == listingId);
    return ComparisonRemoveResult(removed: removed);
  }

  @override
  Future<ComparisonClearResult> clearComparison() async {
    if (_clearComparisonFails) {
      throw Exception('clear comparison failed');
    }
    final count = _comparisonItems.length;
    _comparisonItems.clear();
    return ComparisonClearResult(cleared: true, removedCount: count);
  }

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
}

/// Helper to build a sample [ComparisonListingModel].
ComparisonListingModel sampleComparisonListing({
  String comparisonItemId = 'compare-1',
  String listingId = 'listing-1',
  String propertyId = 'property-1',
  String title = 'Cosy 1BR Riverside',
  String? propertyType = 'apartment',
  String? city = 'Nairobi',
  String? county = 'Nairobi',
  num rentAmount = 45000,
  List<String> images = const <String>['https://example.com/img1.jpg'],
  List<String> amenities = const <String>['wifi', 'parking'],
  String listingStatus = 'published',
  int position = 0,
  String addedAt = '2026-01-01T00:00:00Z',
  int? bedrooms,
  num? bathrooms,
  String? pricingFrequency = 'monthly',
  bool? furnished,
  String? petPolicy,
  bool? smokingAllowed,
  List<String> features = const <String>[],
  String? address,
}) => ComparisonListingModel(
  comparisonItemId: comparisonItemId,
  listingId: listingId,
  propertyId: propertyId,
  title: title,
  propertyType: propertyType,
  city: city,
  county: county,
  rentAmount: rentAmount,
  images: images,
  amenities: amenities,
  listingStatus: listingStatus,
  position: position,
  addedAt: addedAt,
  bedrooms: bedrooms,
  bathrooms: bathrooms,
  pricingFrequency: pricingFrequency,
  furnished: furnished,
  petPolicy: petPolicy,
  smokingAllowed: smokingAllowed,
  features: features,
  address: address,
);

/// Helper to build a sample [SavedListingModel] with full listing data.
SavedListingModel sampleSavedListing({
  String savedId = 'saved-1',
  String listingId = 'listing-1',
  String propertyId = 'property-1',
  String title = 'Cosy 1BR Riverside',
  String? propertyType = 'apartment',
  String? city = 'Nairobi',
  String? county = 'Nairobi',
  num rentAmount = 45000,
  List<String> images = const <String>['https://example.com/img1.jpg'],
  List<String> amenities = const <String>['wifi', 'parking'],
  String? listingStatus = 'published',
  int? bedrooms,
  num? bathrooms,
}) => SavedListingModel(
  savedId: savedId,
  listingId: listingId,
  propertyId: propertyId,
  title: title,
  propertyType: propertyType,
  city: city,
  county: county,
  rentAmount: rentAmount,
  images: images,
  amenities: amenities,
  listingStatus: listingStatus,
  bedrooms: bedrooms,
  bathrooms: bathrooms,
);

/// Helper to build a sample [SavedSearchModel].
SavedSearchModel sampleSavedSearch({
  String id = 'search-1',
  String name = 'Nairobi 2BR under 50k',
  Map<String, dynamic> criteria = const <String, dynamic>{
    'city': 'Nairobi',
    'rentMax': 50000,
    'bedrooms': 2,
  },
  bool alertsEnabled = true,
  String? alertFrequency = 'immediate',
}) => SavedSearchModel(
  id: id,
  name: name,
  criteria: criteria,
  alertsEnabled: alertsEnabled,
  alertFrequency: alertFrequency,
);
