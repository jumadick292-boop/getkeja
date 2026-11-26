library features.property_management.data.datasources.property_remote_datasource;

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart'
    show RentalProposalModel;
import 'package:get_keja_mobile/features/property_management/data/models/property_model.dart';

class PropertyRemoteDataSource {
  PropertyRemoteDataSource(this._dio);

  final Dio _dio;

  // Absolute base because the shared dio base URL targets the auth service.
  String get _basePath => '${ApiConfig.baseUrl}/api/v1/landlord';

  List<T> _mapList<T>(
    Map<String, dynamic>? data,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data?[key] as List<dynamic>?;
    if (raw == null) return <T>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  // ---- Properties ----

  Future<List<PropertyModel>> getProperties({
    String? status,
    String? city,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/properties',
        queryParameters: <String, dynamic>{
          if (status != null) 'status': status,
          if (city != null) 'city': city,
        },
      );
      final body = response.data;
      // Controller returns a raw array; tolerate wrapped shapes too.
      if (body == null) return <PropertyModel>[];
      if (body['properties'] is List) {
        return _mapList(body, 'properties', PropertyModel.fromJson);
      }
      return <PropertyModel>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyModel> getProperty(String propertyId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/properties/$propertyId',
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException(
          message: 'Property not found',
          statusCode: 404,
        );
      }
      final json = data['property'] is Map<String, dynamic>
          ? data['property'] as Map<String, dynamic>
          : data;
      return PropertyModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyModel> createProperty({
    required String title,
    required String propertyType,
    required String address,
    required String city,
    required String county,
    String? description,
    String? country,
    int? totalUnits,
    String? status,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/properties',
        data: <String, dynamic>{
          'title': title,
          'propertyType': propertyType,
          'address': address,
          'city': city,
          'county': county,
          if (description != null) 'description': description,
          if (country != null) 'country': country,
          if (totalUnits != null) 'totalUnits': totalUnits,
          if (status != null) 'status': status,
        },
      );
      final data = response.data;
      final json = data != null && data['property'] is Map<String, dynamic>
          ? data['property'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to create property',
          statusCode: 500,
        );
      }
      return PropertyModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyModel> updateProperty({
    required String propertyId,
    String? title,
    String? description,
    String? propertyType,
    String? status,
    String? address,
    String? city,
    String? county,
    String? country,
    int? totalUnits,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/properties/$propertyId',
        data: <String, dynamic>{
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (propertyType != null) 'propertyType': propertyType,
          if (status != null) 'status': status,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (county != null) 'county': county,
          if (country != null) 'country': country,
          if (totalUnits != null) 'totalUnits': totalUnits,
        },
      );
      final data = response.data;
      final json = data != null && data['property'] is Map<String, dynamic>
          ? data['property'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to update property',
          statusCode: 500,
        );
      }
      return PropertyModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/properties/$propertyId',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Units ----

  Future<List<PropertyUnitModel>> getUnits({
    String? propertyId,
    String? status,
    String? unitType,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/units',
        queryParameters: <String, dynamic>{
          if (propertyId != null) 'propertyId': propertyId,
          if (status != null) 'status': status,
          if (unitType != null) 'unitType': unitType,
        },
      );
      final body = response.data;
      if (body == null) return <PropertyUnitModel>[];
      if (body['units'] is List) {
        return _mapList(body, 'units', PropertyUnitModel.fromJson);
      }
      return <PropertyUnitModel>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyUnitModel> getUnit(String unitId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/units/$unitId',
      );
      final data = response.data;
      final json = data != null && data['unit'] is Map<String, dynamic>
          ? data['unit'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(message: 'Unit not found', statusCode: 404);
      }
      return PropertyUnitModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyUnitModel> createUnit({
    required String propertyId,
    required String unitNumber,
    required String unitType,
    String? building,
    int? floor,
    int? bedrooms,
    int? bathrooms,
    double? areaSqm,
    double? rentAmount,
    double? depositAmount,
    String? description,
    String? status,
    bool? hasSeparateMeter,
    String? meterNumber,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/units',
        data: <String, dynamic>{
          'propertyId': propertyId,
          'unitNumber': unitNumber,
          'unitType': unitType,
          if (building != null) 'building': building,
          if (floor != null) 'floor': floor,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (bathrooms != null) 'bathrooms': bathrooms,
          if (areaSqm != null) 'areaSqm': areaSqm,
          if (rentAmount != null) 'rentAmount': rentAmount,
          if (depositAmount != null) 'depositAmount': depositAmount,
          if (description != null) 'description': description,
          if (status != null) 'status': status,
          if (hasSeparateMeter != null) 'hasSeparateMeter': hasSeparateMeter,
          if (meterNumber != null) 'meterNumber': meterNumber,
        },
      );
      final data = response.data;
      final json = data != null && data['unit'] is Map<String, dynamic>
          ? data['unit'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to create unit',
          statusCode: 500,
        );
      }
      return PropertyUnitModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyUnitModel> updateUnit({
    required String unitId,
    String? unitNumber,
    String? unitType,
    int? bedrooms,
    int? bathrooms,
    double? rentAmount,
    double? depositAmount,
    String? status,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/units/$unitId',
        data: <String, dynamic>{
          if (unitNumber != null) 'unitNumber': unitNumber,
          if (unitType != null) 'unitType': unitType,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (bathrooms != null) 'bathrooms': bathrooms,
          if (rentAmount != null) 'rentAmount': rentAmount,
          if (depositAmount != null) 'depositAmount': depositAmount,
          if (status != null) 'status': status,
        },
      );
      final data = response.data;
      final json = data != null && data['unit'] is Map<String, dynamic>
          ? data['unit'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to update unit',
          statusCode: 500,
        );
      }
      return PropertyUnitModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteUnit(String unitId) async {
    try {
      await _dio.delete<Map<String, dynamic>>('$_basePath/units/$unitId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Listings ----

  Future<List<PropertyListingModel>> getListings({
    String? propertyId,
    String? status,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings',
        queryParameters: <String, dynamic>{
          if (propertyId != null) 'propertyId': propertyId,
          if (status != null) 'status': status,
        },
      );
      final body = response.data;
      if (body == null) return <PropertyListingModel>[];
      if (body['listings'] is List) {
        return _mapList(body, 'listings', PropertyListingModel.fromJson);
      }
      return <PropertyListingModel>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyListingModel> getListing(String listingId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/listings/$listingId',
      );
      final data = response.data;
      final json = data != null && data['listing'] is Map<String, dynamic>
          ? data['listing'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Listing not found',
          statusCode: 404,
        );
      }
      return PropertyListingModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyListingModel> createListing({
    required String propertyId,
    required String title,
    double? rentAmount,
    double? depositAmount,
    String? unitId,
    String? description,
    DateTime? availableFrom,
    bool? furnished,
    String? petPolicy,
    bool? smokingAllowed,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/listings',
        data: <String, dynamic>{
          'propertyId': propertyId,
          'title': title,
          if (rentAmount != null) 'rentAmount': rentAmount,
          if (depositAmount != null) 'depositAmount': depositAmount,
          if (unitId != null) 'unitId': unitId,
          if (description != null) 'description': description,
          if (availableFrom != null)
            'availableFrom': availableFrom.toIso8601String(),
          if (furnished != null) 'furnished': furnished,
          if (petPolicy != null) 'petPolicy': petPolicy,
          if (smokingAllowed != null) 'smokingAllowed': smokingAllowed,
        },
      );
      final data = response.data;
      final json = data != null && data['listing'] is Map<String, dynamic>
          ? data['listing'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to create listing',
          statusCode: 500,
        );
      }
      return PropertyListingModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteListing(String listingId) async {
    try {
      await _dio.delete<Map<String, dynamic>>('$_basePath/listings/$listingId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyListingModel> setListingStatus({
    required String listingId,
    required String action,
    String? reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/listings/$listingId/$action',
        data: reason != null ? <String, dynamic>{'reason': reason} : null,
      );
      final data = response.data;
      final json = data != null && data['listing'] is Map<String, dynamic>
          ? data['listing'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to update listing status',
          statusCode: 500,
        );
      }
      return PropertyListingModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Rental proposals (landlord review) ----

  Future<List<RentalProposalModel>> getRentalProposals({String? status}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$_basePath/rental-proposals',
        queryParameters: <String, dynamic>{
          if (status != null) 'status': status,
        },
      );
      final raw = response.data ?? <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(RentalProposalModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<RentalProposalModel> actionRentalProposal({
    required String proposalId,
    required String action,
    String? reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/rental-proposals/$proposalId/action',
        data: <String, dynamic>{
          'action': action,
          if (reason != null) 'reason': reason,
        },
      );
      final data = response.data;
      final json = data != null && data['proposal'] is Map<String, dynamic>
          ? data['proposal'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to action proposal',
          statusCode: 500,
        );
      }
      return RentalProposalModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Enquiries ----

  Future<List<PropertyEnquiryModel>> getEnquiries({
    String? propertyId,
    String? status,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/enquiries',
        queryParameters: <String, dynamic>{
          if (propertyId != null) 'propertyId': propertyId,
          if (status != null) 'status': status,
        },
      );
      final body = response.data;
      if (body == null) return <PropertyEnquiryModel>[];
      if (body['enquiries'] is List) {
        return _mapList(body, 'enquiries', PropertyEnquiryModel.fromJson);
      }
      return <PropertyEnquiryModel>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyEnquiryModel> getEnquiry(String enquiryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/enquiries/$enquiryId',
      );
      final data = response.data;
      final json = data != null && data['enquiry'] is Map<String, dynamic>
          ? data['enquiry'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Enquiry not found',
          statusCode: 404,
        );
      }
      return PropertyEnquiryModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyEnquiryModel> createEnquiry({
    required String propertyId,
    required String prospectiveRenterName,
    required String prospectiveRenterPhone,
    String? unitId,
    String? listingId,
    String? prospectiveRenterEmail,
    String? enquirySource,
    String? message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/enquiries',
        data: <String, dynamic>{
          'propertyId': propertyId,
          'prospectiveRenterName': prospectiveRenterName,
          'prospectiveRenterPhone': prospectiveRenterPhone,
          if (unitId != null) 'unitId': unitId,
          if (listingId != null) 'listingId': listingId,
          if (prospectiveRenterEmail != null)
            'prospectiveRenterEmail': prospectiveRenterEmail,
          if (enquirySource != null) 'enquirySource': enquirySource,
          if (message != null) 'message': message,
        },
      );
      final data = response.data;
      final json = data != null && data['enquiry'] is Map<String, dynamic>
          ? data['enquiry'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to create enquiry',
          statusCode: 500,
        );
      }
      return PropertyEnquiryModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PropertyEnquiryModel> updateEnquiry({
    required String enquiryId,
    String? status,
    String? message,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/enquiries/$enquiryId',
        data: <String, dynamic>{
          if (status != null) 'status': status,
          if (message != null) 'message': message,
        },
      );
      final data = response.data;
      final json = data != null && data['enquiry'] is Map<String, dynamic>
          ? data['enquiry'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to update enquiry',
          statusCode: 500,
        );
      }
      return PropertyEnquiryModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Dashboard ----

  Future<LandlordDashboardStatsModel> getDashboardStats({
    String? propertyId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/dashboard',
        queryParameters: <String, dynamic>{
          if (propertyId != null) 'propertyId': propertyId,
        },
      );
      final data = response.data;
      if (data == null) {
        return const LandlordDashboardStatsModel();
      }
      final json = data['stats'] is Map<String, dynamic>
          ? data['stats'] as Map<String, dynamic>
          : data;
      return LandlordDashboardStatsModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Site visits ----

  Future<List<SiteVisitModel>> getSiteVisits({
    String? propertyId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/site-visits',
        queryParameters: <String, dynamic>{
          if (propertyId != null) 'propertyId': propertyId,
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final body = response.data;
      if (body == null) return <SiteVisitModel>[];
      if (body['siteVisits'] is List) {
        return _mapList(body, 'siteVisits', SiteVisitModel.fromJson);
      }
      return <SiteVisitModel>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SiteVisitModel> getSiteVisit(String visitId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/site-visits/$visitId',
      );
      final data = response.data;
      final json = data != null && data['siteVisit'] is Map<String, dynamic>
          ? data['siteVisit'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Site visit not found',
          statusCode: 404,
        );
      }
      return SiteVisitModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SiteVisitModel> confirmSiteVisit({
    required String visitId,
    String? hostNotes,
  }) async {
    return _visitAction('confirm', visitId: visitId, hostNotes: hostNotes);
  }

  Future<SiteVisitModel> declineSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    return _visitAction('decline', visitId: visitId, reason: reason);
  }

  Future<SiteVisitModel> rescheduleSiteVisit({
    required String visitId,
    String? scheduledAt,
    int? durationMinutes,
    String? hostNotes,
  }) async {
    return _visitAction(
      'reschedule',
      visitId: visitId,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      hostNotes: hostNotes,
    );
  }

  Future<SiteVisitModel> cancelSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    return _visitAction('cancel', visitId: visitId, reason: reason);
  }

  Future<SiteVisitModel> _visitAction(
    String action, {
    required String visitId,
    String? hostNotes,
    String? reason,
    String? scheduledAt,
    int? durationMinutes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/site-visits/$visitId/$action',
        data: <String, dynamic>{
          if (hostNotes != null) 'hostNotes': hostNotes,
          if (reason != null) 'reason': reason,
          if (scheduledAt != null) 'scheduledAt': scheduledAt,
          if (durationMinutes != null) 'durationMinutes': durationMinutes,
        },
      );
      final data = response.data;
      final json = data != null && data['siteVisit'] is Map<String, dynamic>
          ? data['siteVisit'] as Map<String, dynamic>
          : data;
      if (json == null) {
        throw const ServerException(
          message: 'Failed to perform site visit action',
          statusCode: 500,
        );
      }
      return SiteVisitModel.fromJson(json);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  AppException _mapError(final Object error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      final message =
          (data is Map<String, dynamic> && data['message'] is String)
          ? data['message'] as String
          : 'An error occurred';
      final statusCode = response?.statusCode;
      switch (statusCode) {
        case 401:
          return UnauthorizedException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        case 403:
          return ForbiddenException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        case 429:
          return RateLimitException(
            message: message,
            statusCode: statusCode ?? 0,
            originalError: error,
          );
        case 404:
          return ServerException(
            message: message,
            statusCode: statusCode ?? 0,
            originalError: error,
          );
        case 400:
        case 409:
        case 422:
          return ValidationException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        default:
          return ServerException(
            message: message,
            statusCode: statusCode ?? 500,
            originalError: error,
          );
      }
    }
    return ServerException(message: error.toString(), originalError: error);
  }
}
