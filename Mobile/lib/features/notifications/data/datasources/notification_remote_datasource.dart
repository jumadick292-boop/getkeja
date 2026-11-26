// Notification remote datasource.
// Communicates with the existing /api/auth/notifications backend endpoints.

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._dio);

  final Dio _dio;

  // Notification routes are mounted under the auth router.
  String get _basePath => '${ApiConfig.authBaseUrl}/notifications';

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

  Future<List<NotificationModel>> getNotifications({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: <String, dynamic>{
          if (category != null) 'category': category,
          if (isRead != null) 'isRead': isRead ? 'true' : 'false',
          'limit': limit,
          'offset': offset,
        },
      );
      return NotificationListResponse.fromJson(response.data ?? <String, dynamic>{})
          .notifications;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/unread-count',
      );
      return UnreadCountResponse.fromJson(response.data ?? <String, dynamic>{}).count;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<int> markAsRead(List<String> notificationIds) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/mark-read',
        data: <String, dynamic>{
          'notificationIds': notificationIds,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return (data['data']?['markedCount'] as int? ?? 0);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/mark-all-read',
      );
      final data = response.data ?? <String, dynamic>{};
      return (data['data']?['markedCount'] as int? ?? 0);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<bool> delete(String notificationId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/$notificationId',
      );
      return true;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<NotificationModel?> getById(String notificationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/$notificationId',
      );
      final data = response.data ?? <String, dynamic>{};
      final notificationData = data['data'] as Map<String, dynamic>?;
      if (notificationData == null) return null;
      return NotificationModel.fromJson(notificationData.cast<String, dynamic>());
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/preferences');
      final data = response.data ?? <String, dynamic>{};
      return (data['data'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> updates) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/preferences',
        data: updates,
      );
      final data = response.data ?? <String, dynamic>{};
      return (data['data'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}
