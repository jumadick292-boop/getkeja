// Notification repository implementation.
// Delegates to the remote datasource and maps errors to domain exceptions.

import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';
import 'package:get_keja_mobile/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote);

  final NotificationRemoteDataSource _remote;

  @override
  Future<List<NotificationModel>> getNotifications({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _remote.getNotifications(
        category: category,
        isRead: isRead,
        limit: limit,
        offset: offset,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load notifications.',
        originalError: error,
      );
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      return await _remote.getUnreadCount();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load unread count.',
        originalError: error,
      );
    }
  }

  @override
  Future<int> markAsRead(List<String> notificationIds) async {
    try {
      return await _remote.markAsRead(notificationIds);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to mark notifications as read.',
        originalError: error,
      );
    }
  }

  @override
  Future<int> markAllAsRead() async {
    try {
      return await _remote.markAllAsRead();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to mark all notifications as read.',
        originalError: error,
      );
    }
  }

  @override
  Future<bool> delete(String notificationId) async {
    try {
      return await _remote.delete(notificationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to delete notification.',
        originalError: error,
      );
    }
  }

  @override
  Future<NotificationModel?> getById(String notificationId) async {
    try {
      return await _remote.getById(notificationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load notification.',
        originalError: error,
      );
    }
  }
}
