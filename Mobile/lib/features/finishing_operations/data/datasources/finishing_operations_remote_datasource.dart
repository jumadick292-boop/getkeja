// Finishing & Building Services remote datasource (Task 13.15).
// Talks to the existing /api/v1/finishing-operations backend.

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class FinishingOperationsRemoteDataSource {
  FinishingOperationsRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/finishing-operations';

  AppException _mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String message = 'Something went wrong. Please try again.';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (error.message != null) {
      message = error.message!;
    }
    if (statusCode == 401) return UnauthorizedException(message, statusCode: statusCode, originalError: error);
    if (statusCode == 403) return ForbiddenException(message, statusCode: statusCode, originalError: error);
    if (statusCode == 404) return ServerException(message: message, code: 'NOT_FOUND', statusCode: 404, originalError: error);
    if (statusCode == 409) return ServerException(message: message, code: 'CONFLICT', statusCode: 409, originalError: error);
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/jobs',
        queryParameters: <String, dynamic>{if (status != null) 'status': status, 'limit': 50},
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getCustomerJob(String jobId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_basePath/jobs/$jobId');
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> confirmCompletion(String jobId, {required bool confirm, String? notes}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/jobs/$jobId/confirm-completion',
        data: <String, dynamic>{'confirm': confirm, if (notes != null) 'notes': notes},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> decideAmendment(String jobId, String amendmentId, {required bool approve}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/jobs/$jobId/amendments/$amendmentId/decide',
        data: <String, dynamic>{'decision': approve ? 'approve' : 'reject'},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> decideMaterial(String jobId, String materialId, {required bool approve}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/jobs/$jobId/materials/$materialId/decide',
        data: <String, dynamic>{'decision': approve ? 'approve' : 'reject'},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listProviderJobs({String? status, String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/provider/jobs',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        queryParameters: <String, dynamic>{if (status != null) 'status': status, 'limit': 50},
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getProviderJob(String jobId, {String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> updateProgress(String jobId, String to, {String? reason, String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/progress',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'to': to, if (reason != null) 'reason': reason},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> submitCompletion(String jobId, {String? notes, String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/completion',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{if (notes != null) 'notes': notes},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> recordAssessment(String jobId, Map<String, dynamic> body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/assessments',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: body,
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> createPlan(String jobId, Map<String, dynamic> body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/plans',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: body,
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> addMaterial(String jobId, Map<String, dynamic> body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/materials',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: body,
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> recordInspection(String jobId, Map<String, dynamic> body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/inspections',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: body,
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> addAttachment(String jobId, Map<String, dynamic> body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/attachments',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: body,
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> assignStaff(String jobId, String userId, {String? label, String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/staff',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'userId': userId, if (label != null) 'label': label},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> revokeStaff(String jobId, String staffUserId, {String? organizationId}) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/staff/$staffUserId',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}