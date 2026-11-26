// Laundries remote datasource.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/laundries/domain/entities/laundry_service_model.dart';

class LaundryRemoteDataSource {
  LaundryRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/tenant/laundry-requests';

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
    if (statusCode != null && statusCode >= 500) {
      return ServerException(
        message: message,
        statusCode: statusCode,
        originalError: error,
      );
    }
    return ServerException(
      message: message,
      statusCode: statusCode ?? 500,
      originalError: error,
    );
  }

  Future<List<LaundryServiceModel>> getLaundryRequests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_basePath);
      final raw = (response.data?['data'] as List<dynamic>? ?? <dynamic>[]);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LaundryServiceModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<LaundryServiceModel> submitLaundryRequest({
    required String providerId,
    required String serviceCategory,
    required String collectionPreference,
    required String preferredDateTime,
    required int garmentCount,
    String? specialInstructions,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _basePath,
        data: <String, dynamic>{
          'providerId': providerId,
          'serviceCategory': serviceCategory,
          'collectionPreference': collectionPreference,
          'preferredDateTime': preferredDateTime,
          'garmentCount': garmentCount,
          if (specialInstructions != null) 'specialInstructions': specialInstructions,
          if (contactName != null) 'contactName': contactName,
          if (contactPhone != null) 'contactPhone': contactPhone,
          if (contactEmail != null) 'contactEmail': contactEmail,
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
      return LaundryServiceModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}
