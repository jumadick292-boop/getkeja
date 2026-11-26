// Moving operations remote datasource (Task 13.6).
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class MovingRemoteDataSource {
  MovingRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/moving';

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
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/jobs',
        queryParameters: <String, dynamic>{if (status != null) 'status': status},
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> getCustomerJob(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/jobs/$jobId');
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> confirmCompletion(String jobId, {required bool confirm, String? notes}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/jobs/$jobId/confirm-completion',
        data: <String, dynamic>{'confirm': confirm, if (notes != null) 'notes': notes},
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> cancelJob(String jobId, String reason) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/jobs/$jobId/cancel',
        data: <String, dynamic>{'reason': reason},
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Provider ----
  Future<List<Map<String, dynamic>>> listProviderJobs({String? status}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/provider/jobs',
        queryParameters: <String, dynamic>{if (status != null) 'status': status},
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> getProviderJob(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/provider/jobs/$jobId');
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updateProgress(String jobId, String toStatus, {Map<String, bool>? checklist}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/progress',
        data: <String, dynamic>{'toStatus': toStatus, if (checklist != null) 'checklist': checklist},
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> submitCompletion(String jobId, {String? notes, bool outstandingIssue = false, List<String> evidence = const []}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/jobs/$jobId/completion',
        data: <String, dynamic>{
          if (notes != null) 'notes': notes,
          'outstandingIssue': outstandingIssue,
          'evidenceDocumentIds': evidence,
        },
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw ServerException(message: 'Invalid response from server.', statusCode: 500, originalError: null);
    }
    return data;
  }
}