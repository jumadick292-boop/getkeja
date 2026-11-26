// Shared scheduling remote datasource (Task 13.9).
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class SchedulingRemoteDataSource {
  SchedulingRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/scheduling';

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

  Future<List<Map<String, dynamic>>> _list(String path, Map<String, dynamic> query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> providerCalendar({
    required String from,
    required String to,
    List<String>? domains,
    String? status,
    String? staffUserId,
  }) {
    return _list('$_basePath/provider/calendar', <String, dynamic>{
      'from': from,
      'to': to,
      if (domains != null && domains.isNotEmpty) 'domains': domains,
      if (status != null) 'status': status,
      if (staffUserId != null) 'staffUserId': staffUserId,
    });
  }

  Future<List<Map<String, dynamic>>> customerCalendar({required String from, required String to}) {
    return _list('$_basePath/customer/calendar', <String, dynamic>{'from': from, 'to': to});
  }

  Future<Map<String, dynamic>> getActivity(String activityId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/activities/$activityId');
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(message: 'Invalid response from server.', statusCode: 500, originalError: null);
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> requestReschedule(String activityId, {required String requestedStartAt, required String requestedEndAt, String? reason}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/activities/$activityId/reschedule',
        data: <String, dynamic>{'requestedStartAt': requestedStartAt, 'requestedEndAt': requestedEndAt, if (reason != null) 'reason': reason},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(message: 'Invalid response from server.', statusCode: 500, originalError: null);
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> decideReschedule(String activityId, String requestId, bool accept) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/activities/$activityId/reschedule/$requestId/decide',
        data: <String, dynamic>{'accept': accept},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(message: 'Invalid response from server.', statusCode: 500, originalError: null);
      }
      return data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}