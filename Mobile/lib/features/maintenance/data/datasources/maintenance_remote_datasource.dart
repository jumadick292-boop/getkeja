// Maintenance remote datasource.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/maintenance/domain/entities/maintenance_service_model.dart';

class MaintenanceRemoteDataSource {
  MaintenanceRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/tenant/maintenance-requests';

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

  Future<List<MaintenanceServiceModel>> getMaintenanceRequests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_basePath);
      return MaintenanceServiceListResponse.fromJson(
        response.data ?? <String, dynamic>{},
      ).services;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<MaintenanceServiceModel> submitMaintenanceRequest({
    required String unitId,
    required String title,
    required String category,
    required String priority,
    required String description,
    List<String>? photos,
    String? accessInstructions,
    String? preferredAvailability,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _basePath,
        data: <String, dynamic>{
          'unitId': unitId,
          'title': title,
          'category': category,
          'priority': priority,
          'description': description,
          if (photos != null && photos.isNotEmpty) 'photos': photos,
          if (accessInstructions != null)
            'accessInstructions': accessInstructions,
          if (preferredAvailability != null)
            'preferredAvailability': preferredAvailability,
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
      return MaintenanceServiceModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}
