import 'package:get_keja_mobile/features/house_seeker/data/datasources/house_seeker_remote_datasource.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';

class HouseSeekerRepositoryImpl implements HouseSeekerRepository {
  HouseSeekerRepositoryImpl(this._remote);

  final HouseSeekerRemoteDataSource _remote;

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
  }) {
    return _remote.searchListings(
      q: q,
      city: city,
      county: county,
      propertyType: propertyType,
      rentMin: rentMin,
      rentMax: rentMax,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      furnished: furnished,
      amenities: amenities,
      sort: sort,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<ListingCardModel>> getFeatured() => _remote.getFeatured();

  @override
  Future<List<ListingCardModel>> getRecentlyPublished() =>
      _remote.getRecentlyPublished();

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
  }) {
    return _remote.getMapListings(
      north: north,
      south: south,
      east: east,
      west: west,
      q: q,
      propertyType: propertyType,
      rentMin: rentMin,
      rentMax: rentMax,
      bedrooms: bedrooms,
      limit: limit,
    );
  }

  @override
  Future<FilterFacetsModel> getFilterFacets() => _remote.getFilterFacets();

  @override
  Future<ListingDetailModel> getListingDetail(String listingId) =>
      _remote.getListingDetail(listingId);

  @override
  Future<List<ListingCardModel>> getRelatedListings(String listingId) =>
      _remote.getRelatedListings(listingId);

  @override
  Future<void> saveListing(
    String listingId, {
    String? collection,
    String? notes,
  }) => _remote.saveListing(listingId, collection: collection, notes: notes);

  @override
  Future<void> removeSavedListing(String listingId) =>
      _remote.removeSavedListing(listingId);

  @override
  Future<List<SavedListingModel>> getSavedListings({
    int limit = 20,
    int offset = 0,
  }) => _remote.getSavedListings(limit: limit, offset: offset);

  @override
  Future<List<SavedSearchModel>> getSavedSearches() =>
      _remote.getSavedSearches();

  @override
  Future<SavedSearchModel> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = true,
    String? alertFrequency,
  }) => _remote.createSavedSearch(
    name: name,
    criteria: criteria,
    alertsEnabled: alertsEnabled,
    alertFrequency: alertFrequency,
  );

  @override
  Future<void> deleteSavedSearch(String searchId) =>
      _remote.deleteSavedSearch(searchId);

  @override
  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) => _remote.updateSavedSearch(
    searchId: searchId,
    name: name,
    criteria: criteria,
    alertsEnabled: alertsEnabled,
    alertFrequency: alertFrequency,
  );

  @override
  Future<SavedSearchModel> runSavedSearch(String searchId) =>
      _remote.runSavedSearch(searchId);

  @override
  Future<EnquiryModel> submitEnquiry({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String message,
    String? phone,
  }) => _remote.submitEnquiry(
    propertyId: propertyId,
    listingId: listingId,
    unitId: unitId,
    message: message,
    phone: phone,
  );

  @override
  Future<List<EnquiryModel>> getEnquiries({int limit = 20, int offset = 0}) =>
      _remote.getEnquiries(limit: limit, offset: offset);

  @override
  Future<void> withdrawEnquiry(String enquiryId) =>
      _remote.withdrawEnquiry(enquiryId);

  @override
  Future<HouseSeekerPreferencesModel?> getPreferences() =>
      _remote.getPreferences();

  @override
  Future<void> updatePreferences(Map<String, dynamic> body) =>
      _remote.updatePreferences(body);

  @override
  Future<void> reportListing({
    required String listingId,
    required String reason,
    String? details,
  }) => _remote.reportListing(
    listingId: listingId,
    reason: reason,
    details: details,
  );

  @override
  Future<SiteVisitModel> requestSiteVisit({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String scheduledAt,
    int durationMinutes = 30,
    String? visitorNotes,
    String? phone,
  }) => _remote.requestSiteVisit(
    propertyId: propertyId,
    listingId: listingId,
    unitId: unitId,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    visitorNotes: visitorNotes,
    phone: phone,
  );

  @override
  Future<List<SiteVisitModel>> getSiteVisits({
    int limit = 20,
    int offset = 0,
  }) => _remote.getSiteVisits(limit: limit, offset: offset);

  @override
  Future<void> cancelSiteVisit(String visitId) =>
      _remote.cancelSiteVisit(visitId);

  @override
  Future<void> rescheduleSiteVisit(
    String visitId, {
    required String scheduledAt,
  }) => _remote.rescheduleSiteVisit(visitId, scheduledAt: scheduledAt);

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
  }) => _remote.startConversation(
    propertyId: propertyId,
    landlordUserId: landlordUserId,
    listingId: listingId,
    unitId: unitId,
    subject: subject,
    rentalApplicationId: rentalApplicationId,
    rentalProposalId: rentalProposalId,
    message: message,
  );

  @override
  Future<List<ConversationModel>> getConversations({
    int limit = 20,
    int offset = 0,
  }) => _remote.getConversations(limit: limit, offset: offset);

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) => _remote.getMessages(conversationId, limit: limit, offset: offset);

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  }) => _remote.sendMessage(conversationId: conversationId, content: content);

  @override
  Future<void> markConversationRead(String conversationId) =>
      _remote.markConversationRead(conversationId);

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
  }) => _remote.submitApplication(
    propertyId: propertyId,
    listingId: listingId,
    unitId: unitId,
    preferredStartDate: preferredStartDate,
    preferredEndDate: preferredEndDate,
    proposedRentAmount: proposedRentAmount,
    employerName: employerName,
    employerContact: employerContact,
    monthlyIncome: monthlyIncome,
  );

  @override
  Future<List<RentalApplicationModel>> getApplications({
    int limit = 20,
    int offset = 0,
  }) => _remote.getApplications(limit: limit, offset: offset);

  @override
  Future<void> withdrawApplication(String applicationId) =>
      _remote.withdrawApplication(applicationId);

  @override
  Future<List<RentalProposalModel>> getProposals({
    String? status,
    int limit = 20,
    int offset = 0,
  }) => _remote.getProposals(status: status, limit: limit, offset: offset);

  @override
  Future<RentalProposalModel> respondToProposal({
    required String proposalId,
    required String action,
    String? reason,
    Map<String, dynamic>? counter,
  }) => _remote.respondToProposal(
    proposalId: proposalId,
    action: action,
    reason: reason,
    counter: counter,
  );

  @override
  Future<RentalJourneyModel> getJourney() => _remote.getJourney();

  @override
  Future<ComparisonListModel> getComparison({int limit = 20, int offset = 0}) =>
      _remote.getComparison(limit: limit, offset: offset);

  @override
  Future<ComparisonAddResult> addToComparison(String listingId) =>
      _remote.addToComparison(listingId);

  @override
  Future<ComparisonRemoveResult> removeFromComparison(String listingId) =>
      _remote.removeFromComparison(listingId);

  @override
  Future<ComparisonClearResult> clearComparison() => _remote.clearComparison();
}
