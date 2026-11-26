// Messaging remote datasource.
// Talks to the existing /api/v1/messaging backend (contextual conversations).

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class MessagingRemoteDataSource {
  MessagingRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/messaging';

  AppException _mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String message = 'Something went wrong. Please try again.';
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
    if (statusCode == 404) {
      return ServerException(message: message, code: 'NOT_FOUND', statusCode: 404, originalError: error);
    }
    if (statusCode != null && statusCode >= 500) {
      return ServerException(message: message, statusCode: statusCode, originalError: error);
    }
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  /// Start (or reuse) an authorized contextual conversation. Exactly one of the
  /// context ids should be provided, matching the business record.
  Future<Map<String, dynamic>> startConversation({
    required String type,
    String? movingJobId,
    String? marketplaceRequestId,
    String? garbageJobId,
    String? laundryOrderId,
    String? schedulingActivityId,
    String? message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/conversations',
        data: <String, dynamic>{
          'type': type,
          if (movingJobId != null) 'movingJobId': movingJobId,
          if (marketplaceRequestId != null) 'marketplaceRequestId': marketplaceRequestId,
          if (garbageJobId != null) 'garbageJobId': garbageJobId,
          if (laundryOrderId != null) 'laundryOrderId': laundryOrderId,
          if (schedulingActivityId != null) 'schedulingActivityId': schedulingActivityId,
          if (message != null) 'message': message,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final conversation = data['conversation'] as Map<String, dynamic>?;
      if (conversation == null) {
        throw const ServerException(message: 'Unable to start conversation', code: 'INVALID_RESPONSE');
      }
      return conversation.cast<String, dynamic>();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/conversations/$conversationId/messages',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      final data = response.data ?? <String, dynamic>{};
      final items = (data['data']?['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      return items;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> sendMessage(String conversationId, String content) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/conversations/$conversationId/messages',
        data: <String, dynamic>{'content': content},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post<Map<String, dynamic>>('$_basePath/conversations/$conversationId/read');
    } on DioException catch (_) {
      // Non-fatal: read-state is best-effort.
    }
  }
}