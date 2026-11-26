import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';

abstract class HouseSeekerRepository {
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
    String sort,
    int limit,
    int offset,
  });

  Future<List<ListingCardModel>> getFeatured();
  Future<List<ListingCardModel>> getRecentlyPublished();
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
    int limit,
  });
  Future<FilterFacetsModel> getFilterFacets();
  Future<ListingDetailModel> getListingDetail(String listingId);
  Future<List<ListingCardModel>> getRelatedListings(String listingId);

  Future<void> saveListing(
    String listingId, {
    String? collection,
    String? notes,
  });
  Future<void> removeSavedListing(String listingId);
  Future<List<SavedListingModel>> getSavedListings({int limit, int offset});

  Future<List<SavedSearchModel>> getSavedSearches();
  Future<SavedSearchModel> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled,
    String? alertFrequency,
  });
  Future<void> deleteSavedSearch(String searchId);
  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  });
  Future<SavedSearchModel> runSavedSearch(String searchId);

  Future<EnquiryModel> submitEnquiry({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String message,
    String? phone,
  });
  Future<List<EnquiryModel>> getEnquiries({int limit, int offset});
  Future<void> withdrawEnquiry(String enquiryId);

  Future<HouseSeekerPreferencesModel?> getPreferences();
  Future<void> updatePreferences(Map<String, dynamic> body);

  Future<void> reportListing({
    required String listingId,
    required String reason,
    String? details,
  });

  // Site visits
  Future<SiteVisitModel> requestSiteVisit({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String scheduledAt,
    int durationMinutes,
    String? visitorNotes,
    String? phone,
  });
  Future<List<SiteVisitModel>> getSiteVisits({int limit, int offset});
  Future<void> cancelSiteVisit(String visitId);
  Future<void> rescheduleSiteVisit(
    String visitId, {
    required String scheduledAt,
  });

  // Conversations & messages
  Future<StartConversationResult> startConversation({
    required String propertyId,
    String landlordUserId = '',
    String? listingId,
    String? unitId,
    String? subject,
    String? rentalApplicationId,
    String? rentalProposalId,
    String message = '',
  });
  Future<List<ConversationModel>> getConversations({int limit, int offset});
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit,
    int offset,
  });
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  });
  Future<void> markConversationRead(String conversationId);

  // Rental applications
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
  });
  Future<List<RentalApplicationModel>> getApplications({int limit, int offset});
  Future<void> withdrawApplication(String applicationId);

  // Rental proposals
  Future<List<RentalProposalModel>> getProposals({
    String? status,
    int limit,
    int offset,
  });
  Future<RentalProposalModel> respondToProposal({
    required String proposalId,
    required String action,
    String? reason,
    Map<String, dynamic>? counter,
  });

  // Rental journey
  Future<RentalJourneyModel> getJourney();

  // Property comparison
  Future<ComparisonListModel> getComparison({int limit, int offset});
  Future<ComparisonAddResult> addToComparison(String listingId);
  Future<ComparisonRemoveResult> removeFromComparison(String listingId);
  Future<ComparisonClearResult> clearComparison();
}
