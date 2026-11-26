// Notification repository interface.
// Defines the contract for fetching and managing user notifications.

import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';

abstract class NotificationRepository {
  /// Fetch the authenticated user's notifications with optional pagination and filters.
  Future<List<NotificationModel>> getNotifications({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  });

  /// Fetch the count of unread notifications for the authenticated user.
  Future<int> getUnreadCount();

  /// Mark specific notifications as read. Returns the number marked.
  Future<int> markAsRead(List<String> notificationIds);

  /// Mark all notifications as read. Returns the number marked.
  Future<int> markAllAsRead();

  /// Delete a notification. Returns true if deleted.
  Future<bool> delete(String notificationId);

  /// Fetch a single notification by ID.
  Future<NotificationModel?> getById(String notificationId);
}
