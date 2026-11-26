// Notification state management.
// Provides Riverpod providers for fetching and managing user notifications.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:get_keja_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';
import 'package:get_keja_mobile/features/notifications/domain/repositories/notification_repository.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRemoteDataSource(apiClient.dio);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationRemoteDataSourceProvider),
  );
});

class NotificationNotifier extends Notifier<AsyncValue<List<NotificationModel>>> {
  @override
  AsyncValue<List<NotificationModel>> build() {
    return const AsyncValue.loading();
  }

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  Future<void> load({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final notifications = await _repo.getNotifications(
        category: category,
        isRead: isRead,
        limit: limit,
        offset: offset,
      );
      state = AsyncValue.data(notifications);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<int> markAsRead(List<String> notificationIds) async {
    try {
      final count = await _repo.markAsRead(notificationIds);
      state.whenData((notifications) {
        final updated = notifications.map((n) {
          if (notificationIds.contains(n.id)) {
            return NotificationModel(
              id: n.id,
              userId: n.userId,
              organisationId: n.organisationId,
              eventType: n.eventType,
              category: n.category,
              title: n.title,
              body: n.body,
              metadata: n.metadata,
              priority: n.priority,
              isRead: true,
              readAt: DateTime.now().toIso8601String(),
              expiresAt: n.expiresAt,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        state = AsyncValue.data(updated);
      });
      return count;
    } catch (error) {
      rethrow;
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final count = await _repo.markAllAsRead();
      state.whenData((notifications) {
        final updated = notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            organisationId: n.organisationId,
            eventType: n.eventType,
            category: n.category,
            title: n.title,
            body: n.body,
            metadata: n.metadata,
            priority: n.priority,
            isRead: true,
            readAt: DateTime.now().toIso8601String(),
            expiresAt: n.expiresAt,
            createdAt: n.createdAt,
          );
        }).toList();
        state = AsyncValue.data(updated);
      });
      return count;
    } catch (error) {
      rethrow;
    }
  }

  Future<void> markSingleAsRead(String notificationId) async {
    await markAsRead([notificationId]);
  }

  Future<bool> delete(String notificationId) async {
    try {
      final deleted = await _repo.delete(notificationId);
      if (deleted) {
        state.whenData((notifications) {
          final updated = notifications.where((n) => n.id != notificationId).toList();
          state = AsyncValue.data(updated);
        });
      }
      return deleted;
    } catch (error) {
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _repo.getUnreadCount();
    } catch (error) {
      rethrow;
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, AsyncValue<List<NotificationModel>>>(
      NotificationNotifier.new,
    );

final unreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});
