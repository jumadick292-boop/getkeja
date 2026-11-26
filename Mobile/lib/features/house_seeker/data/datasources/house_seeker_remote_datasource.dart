library features.house_seeker.data.datasources.house_seeker_remote_datasource;

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';

class HouseSeekerRemoteDataSource {
  HouseSeekerRemoteDataSource(this._dio);

  final Dio _dio;

  // Absolute base because the shared dio base URL targets the auth service.
  String get _basePath => '${ApiConfig.baseUrl}/api/v1/house-seeker';

  AppException _mapError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    String message = 'Something went wrong. Please try again.';
    final data = response?.data;
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (error.message != null) {
      message = error.message!;
    }
    if (statusCode == 401) {
      return UnauthorizedException(
        message,
        statusCode: statusCode,
        originalError: error,
      );
    }
    if (statusCode == 403) {
      return ForbiddenException(
        message,
        statusCode: statusCode,
        originalError: error,
      );
    }
    if (statusCode == 404) {
      return ServerException(
        message: message,
        code: 'NOT_FOUND',
        statusCode: 404,
        originalError: error,
      );
    }
    if (statusCode == 409) {
      return ServerException(
        message: message,
        code: 'CONFLICT',
        statusCode: 409,
        originalError: error,
      );
    }
    if (statusCode == 429) {
      return RateLimitException(message: message, originalError: error);
    }
    if (statusCode != null && statusCode >= 500) {
      return ServerException(
        message: message,
        statusCode: statusCode,
        originalError: error,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return NetworkException(message, originalError: error);
    }
    return ServerException(message: message, originalError: error);
  }

  // ---- Discovery ----

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
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings',
        queryParameters: <String, dynamic>{
          if (q != null && q.isNotEmpty) 'q': q,
          if (city != null && city.isNotEmpty) 'city': city,
          if (county != null && county.isNotEmpty) 'county': county,
          if (propertyType != null && propertyType.isNotEmpty)
            'propertyType': propertyType,
          if (rentMin != null) 'rentMin': rentMin,
          if (rentMax != null) 'rentMax': rentMax,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (bathrooms != null) 'bathrooms': bathrooms,
          if (furnished != null) 'furnished': furnished,
          if (amenities != null && amenities.isNotEmpty) 'amenities': amenities,
          'sort': sort,
          'limit': limit,
          'offset': offset,
        },
      );
      return SearchResultModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ListingCardModel>> getFeatured() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/featured',
      );
      return _mapListings(response.data, 'featured');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ListingCardModel>> getRecentlyPublished() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/featured',
      );
      return _mapListings(response.data, 'recent');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

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
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/map',
        queryParameters: <String, dynamic>{
          'north': north,
          'south': south,
          'east': east,
          'west': west,
          if (q != null && q.isNotEmpty) 'q': q,
          if (propertyType != null && propertyType.isNotEmpty)
            'propertyType': propertyType,
          if (rentMin != null) 'rentMin': rentMin,
          if (rentMax != null) 'rentMax': rentMax,
          if (bedrooms != null) 'bedrooms': bedrooms,
          'limit': limit,
        },
      );
      return _mapListings(response.data, 'items');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<FilterFacetsModel> getFilterFacets() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/filters',
      );
      return FilterFacetsModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ListingDetailModel> getListingDetail(String listingId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/$listingId',
      );
      return ListingDetailModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ListingCardModel>> getRelatedListings(String listingId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/$listingId/related',
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ListingCardModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Saved homes ----

  Future<void> saveListing(
    String listingId, {
    String? collection,
    String? notes,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/saved-listings',
        data: <String, dynamic>{
          'listingId': listingId,
          if (collection != null && collection.isNotEmpty)
            'collection': collection,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> removeSavedListing(String listingId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/saved-listings/$listingId',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<SavedListingModel>> getSavedListings({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/saved-listings',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SavedListingModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Saved searches ----

  Future<List<SavedSearchModel>> getSavedSearches() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/saved-searches',
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SavedSearchModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SavedSearchModel> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = true,
    String? alertFrequency,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/saved-searches',
        data: <String, dynamic>{
          'name': name,
          'criteria': criteria,
          'alertsEnabled': alertsEnabled,
          if (alertFrequency != null && alertFrequency.isNotEmpty)
            'alertFrequency': alertFrequency,
        },
      );
      return SavedSearchModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteSavedSearch(String searchId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/saved-searches/$searchId',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SavedSearchModel> updateSavedSearch({
    required String searchId,
    String? name,
    Map<String, dynamic>? criteria,
    bool? alertsEnabled,
    String? alertFrequency,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/saved-searches/$searchId',
        data: <String, dynamic>{
          if (name != null && name.isNotEmpty) 'name': name,
          if (criteria != null) 'criteria': criteria,
          if (alertsEnabled != null) 'alertsEnabled': alertsEnabled,
          if (alertFrequency != null && alertFrequency.isNotEmpty)
            'alertFrequency': alertFrequency,
        },
      );
      return SavedSearchModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SavedSearchModel> runSavedSearch(String searchId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/saved-searches/$searchId/run',
      );
      return SavedSearchModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Enquiries ----

  Future<EnquiryModel> submitEnquiry({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String message,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/enquiries',
        data: <String, dynamic>{
          'propertyId': propertyId,
          if (listingId != null) 'listingId': listingId,
          if (unitId != null) 'unitId': unitId,
          'message': message,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return EnquiryModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<EnquiryModel>> getEnquiries({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/enquiries',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(EnquiryModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> withdrawEnquiry(String enquiryId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/enquiries/$enquiryId/withdraw',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Preferences ----

  Future<HouseSeekerPreferencesModel?> getPreferences() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/preferences',
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return HouseSeekerPreferencesModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> body) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '$_basePath/preferences',
        data: body,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Listing reports ----

  Future<void> reportListing({
    required String listingId,
    required String reason,
    String? details,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/listing-reports',
        data: <String, dynamic>{
          'listingId': listingId,
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        },
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Site visits ----

  Future<SiteVisitModel> requestSiteVisit({
    required String propertyId,
    String? listingId,
    String? unitId,
    required String scheduledAt,
    int durationMinutes = 30,
    String? visitorNotes,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/site-visits',
        data: <String, dynamic>{
          'propertyId': propertyId,
          if (listingId != null) 'listingId': listingId,
          if (unitId != null) 'unitId': unitId,
          'scheduledAt': scheduledAt,
          'durationMinutes': durationMinutes,
          if (visitorNotes != null && visitorNotes.isNotEmpty)
            'visitorNotes': visitorNotes,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return SiteVisitModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<SiteVisitModel>> getSiteVisits({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/site-visits',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SiteVisitModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> cancelSiteVisit(String visitId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/site-visits/$visitId/cancel',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> rescheduleSiteVisit(
    String visitId, {
    required String scheduledAt,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/site-visits/$visitId/reschedule',
        data: <String, dynamic>{'scheduledAt': scheduledAt},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Conversations & messages ----

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
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/conversations',
        data: <String, dynamic>{
          'propertyId': propertyId,
          if (landlordUserId.isNotEmpty) 'landlordUserId': landlordUserId,
          if (listingId != null) 'listingId': listingId,
          if (unitId != null) 'unitId': unitId,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          if (rentalApplicationId != null) 'rentalApplicationId': rentalApplicationId,
          if (rentalProposalId != null) 'rentalProposalId': rentalProposalId,
          if (message.isNotEmpty) 'message': message,
        },
      );
      return StartConversationResult.fromJson(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ConversationModel>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/conversations',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ConversationModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/conversations/$conversationId/messages',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MessageModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/messages',
        data: <String, dynamic>{
          'conversationId': conversationId,
          'content': content,
        },
      );
      return MessageModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/conversations/$conversationId/read',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Rental applications ----

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
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications',
        data: <String, dynamic>{
          'propertyId': propertyId,
          if (listingId != null) 'listingId': listingId,
          if (unitId != null) 'unitId': unitId,
          if (preferredStartDate != null)
            'preferredStartDate': preferredStartDate,
          if (preferredEndDate != null) 'preferredEndDate': preferredEndDate,
          if (proposedRentAmount != null)
            'proposedRentAmount': proposedRentAmount,
          if (employerName != null && employerName.isNotEmpty)
            'employerName': employerName,
          if (employerContact != null && employerContact.isNotEmpty)
            'employerContact': employerContact,
          if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
        },
      );
      return RentalApplicationModel.fromJson(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<RentalApplicationModel>> getApplications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/applications',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(RentalApplicationModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> withdrawApplication(String applicationId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/withdraw',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Rental proposals ----

  Future<List<RentalProposalModel>> getProposals({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/proposals',
        queryParameters: <String, dynamic>{
          if (status != null && status.isNotEmpty) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final raw = (response.data?['items'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(RentalProposalModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<RentalProposalModel> respondToProposal({
    required String proposalId,
    required String action,
    String? reason,
    Map<String, dynamic>? counter,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/proposals/$proposalId/respond',
        data: <String, dynamic>{
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (counter != null) 'counter': counter,
        },
      );
      return RentalProposalModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Rental journey ----

  Future<RentalJourneyModel> getJourney() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/journey',
      );
      return RentalJourneyModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Property comparison ----

  Future<ComparisonListModel> getComparison({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/comparison',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      );
      return ComparisonListModel.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ComparisonAddResult> addToComparison(String listingId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/comparison',
        data: <String, dynamic>{'listingId': listingId},
      );
      return ComparisonAddResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ComparisonRemoveResult> removeFromComparison(String listingId) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '$_basePath/comparison/$listingId',
      );
      return ComparisonRemoveResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ComparisonClearResult> clearComparison() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '$_basePath/comparison',
      );
      return ComparisonClearResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  List<ListingCardModel> _mapListings(Map<String, dynamic>? data, String key) {
    final raw = data?[key] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ListingCardModel.fromJson)
        .toList(growable: false);
  }
}
