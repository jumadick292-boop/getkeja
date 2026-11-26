// Garbage remote datasource.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/garbage/domain/entities/garbage_service_model.dart';

class GarbageRemoteDataSource {
  GarbageRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/tenant/garbage-requests';

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

  Future<List<GarbageServiceModel>> getGarbageRequests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_basePath);
      return GarbageServiceListResponse.fromJson(
        response.data ?? <String, dynamic>{},
      ).services;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<GarbageServiceModel> submitGarbageRequest({
    required String unitId,
    required String category,
    required String description,
    String? preferredDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _basePath,
        data: <String, dynamic>{
          'unitId': unitId,
          'category': category,
          'description': description,
          if (preferredDate != null) 'preferredDate': preferredDate,
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
      return GarbageServiceModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}
