// Tenancy remote datasource.
// Communicates with the /api/v1/tenant backend endpoints.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';
import 'package:get_keja_mobile/features/tenancies/domain/repositories/tenancy_repository.dart';

class TenancyRemoteDataSource {
  TenancyRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/tenant';

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

  Future<TenantDashboardModel> getDashboard() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/dashboard',
      );
      return TenantDashboardModel.fromJson(
        (response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<TenancyModel>> getTenancies({String? status}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/tenancies',
        queryParameters: <String, dynamic>{
          if (status != null) 'status': status,
        },
      );
      return TenancyListResponse.fromJson(
        response.data ?? <String, dynamic>{},
      ).tenancies;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<TenancyDetailResponse?> getTenancyById(String tenancyId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/tenancies/$tenancyId',
      );
      return TenancyDetailResponse.fromJson(
        (response.data?['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}

class TenancyListResponse {
  TenancyListResponse({
    required this.tenancies,
    required this.success,
  });

  final List<TenancyModel> tenancies;
  final bool success;

  factory TenancyListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List<dynamic>? ?? <dynamic>[]);
    return TenancyListResponse(
      tenancies: raw
          .whereType<Map<String, dynamic>>()
          .map(TenancyModel.fromJson)
          .toList(growable: false),
      success: json['success'] as bool? ?? true,
    );
  }
}
