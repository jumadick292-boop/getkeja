// Provider remote datasource.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class ProviderRemoteDataSource {
  ProviderRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/provider';

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
      return UnauthorizedException(message, statusCode: statusCode, originalError: error);
    }
    if (statusCode == 403) {
      return ForbiddenException(message, statusCode: statusCode, originalError: error);
    }
    return ServerException(
      message: message,
      statusCode: statusCode ?? 500,
      originalError: error,
    );
  }

  Future<Map<String, dynamic>> getDashboard({String? organizationId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/dashboard',
        queryParameters: <String, dynamic>{
          if (organizationId != null) 'organizationId': organizationId,
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid response from server.',
          statusCode: 500,
          originalError: null,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listProfiles() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/profiles');
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/profile',
        data: body,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid response from server.',
          statusCode: 500,
          originalError: null,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listOrganizations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/organizations');
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createOrganization(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/organizations',
        data: body,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid response from server.',
          statusCode: 500,
          originalError: null,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listStaff(String organizationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/organizations/$organizationId/staff',
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> inviteStaff(
    String organizationId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/organizations/$organizationId/invitations',
        data: body,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid response from server.',
          statusCode: 500,
          originalError: null,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Service catalogue (Task 13.4) ----
  Future<Map<String, dynamic>> getCatalogue({String? domain}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/services/catalogue',
        queryParameters: <String, dynamic>{
          if (domain != null) 'domain': domain,
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid response from server.',
          statusCode: 500,
          originalError: null,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listOfferings({String? organizationId, String? domain, String? status}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/services',
        queryParameters: <String, dynamic>{
          if (organizationId != null) 'organizationId': organizationId,
          if (domain != null) 'domain': domain,
          if (status != null) 'status': status,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createOffering(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/services', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> getOffering(String serviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/services/$serviceId');
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updateOffering(String serviceId, Map<String, dynamic> body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>('$_basePath/services/$serviceId', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> setOfferingStatus(String serviceId, String action, {Map<String, dynamic>? body}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/services/$serviceId/$action',
        data: body ?? <String, dynamic>{},
      );
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getCapabilities(String serviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/services/$serviceId/capabilities');
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> replaceCapabilities(String serviceId, List<Map<String, dynamic>> caps) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/services/$serviceId/capabilities',
        data: <String, dynamic>{'capabilities': caps},
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>?> getPricing(String serviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/services/$serviceId/pricing');
      final data = response.data?['data'];
      return data is Map<String, dynamic> ? data : null;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> setPricing(String serviceId, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>('$_basePath/services/$serviceId/pricing', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Locations ----
  Future<List<Map<String, dynamic>>> listLocations({String? organizationId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/locations',
        queryParameters: <String, dynamic>{
          if (organizationId != null) 'organizationId': organizationId,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/locations', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updateLocation(String locationId, Map<String, dynamic> body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>('$_basePath/locations/$locationId', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteLocation(String locationId) async {
    try {
      await _dio.delete('$_basePath/locations/$locationId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> setPrimaryLocation(String locationId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/locations/$locationId/set-primary');
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Service areas ----
  Future<List<Map<String, dynamic>>> listServiceAreas({String? profileId, String? offeringId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/service-areas',
        queryParameters: <String, dynamic>{
          if (profileId != null) 'profileId': profileId,
          if (offeringId != null) 'offeringId': offeringId,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createServiceArea(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/service-areas', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteServiceArea(String areaId) async {
    try {
      await _dio.delete('$_basePath/service-areas/$areaId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Availability ----
  Future<List<Map<String, dynamic>>> getAvailability({String? profileId, String? offeringId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/availability',
        queryParameters: <String, dynamic>{
          if (profileId != null) 'profileId': profileId,
          if (offeringId != null) 'offeringId': offeringId,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> putAvailability(Map<String, dynamic> body) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>('$_basePath/availability', data: body);
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listExceptions(String profileId, {String? offeringId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/availability/exceptions',
        queryParameters: <String, dynamic>{
          'profileId': profileId,
          if (offeringId != null) 'offeringId': offeringId,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createException(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/availability/exceptions', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteException(String exceptionId) async {
    try {
      await _dio.delete('$_basePath/availability/exceptions/$exceptionId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _unwrapMap(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Invalid response from server.',
        statusCode: 500,
        originalError: null,
      );
    }
    return data;
  }
}