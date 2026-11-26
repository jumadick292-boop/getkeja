// Notification repository behavior tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:get_keja_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';
import 'package:get_keja_mobile/features/notifications/domain/repositories/notification_repository.dart';

class _FakeRemoteDataSource implements NotificationRemoteDataSource {
  _FakeRemoteDataSource({
    this.notifications = const [],
    this.unreadCount = 0,
    this.shouldFail = false,
    this.failureException,
  });

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool shouldFail;
  final Exception? failureException;

  int getNotificationsCallCount = 0;
  int getUnreadCountCallCount = 0;
  int markAsReadCallCount = 0;
  int markAllAsReadCallCount = 0;
  int deleteCallCount = 0;
  int getByIdCallCount = 0;

  @override
  Future<Map<String, dynamic>> getPreferences() async => <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> updates) async =>
      updates;

  List<String>? lastMarkedIds;
  String? lastDeletedId;
  String? lastGetByIdId;

  @override
  Future<List<NotificationModel>> getNotifications({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    getNotificationsCallCount++;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return notifications;
  }

  @override
  Future<int> getUnreadCount() async {
    getUnreadCountCallCount++;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return unreadCount;
  }

  @override
  Future<int> markAsRead(List<String> notificationIds) async {
    markAsReadCallCount++;
    lastMarkedIds = notificationIds;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return notificationIds.length;
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCallCount++;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return unreadCount;
  }

  @override
  Future<bool> delete(String notificationId) async {
    deleteCallCount++;
    lastDeletedId = notificationId;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return true;
  }

  @override
  Future<NotificationModel?> getById(String notificationId) async {
    getByIdCallCount++;
    lastGetByIdId = notificationId;
    if (shouldFail) throw failureException ?? const ServerException(message: 'Failed');
    return notifications.isNotEmpty ? notifications.first : null;
  }
}

final _testNotification = NotificationModel(
  id: 'n1',
  userId: 'u1',
  eventType: 'saved_search.match',
  category: 'property',
  title: 'New match: Nairobi 2BR',
  body: 'A new property matches your saved search.',
  metadata: <String, dynamic>{
    'savedSearchId': 's1',
    'listingId': 'l1',
    'listingTitle': '2BR in Kilimani',
  },
  priority: 'normal',
  isRead: false,
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  group('NotificationRepositoryImpl', () {
    test('getNotifications delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource(notifications: [_testNotification]);
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.getNotifications();

      expect(remote.getNotificationsCallCount, 1);
      expect(result, hasLength(1));
      expect(result.first.id, 'n1');
    });

    test('getNotifications passes filters to remote datasource', () async {
      final remote = _FakeRemoteDataSource();
      final repo = NotificationRepositoryImpl(remote);

      await repo.getNotifications(
        category: 'property',
        isRead: false,
        limit: 20,
        offset: 0,
      );

      expect(remote.getNotificationsCallCount, 1);
    });

    test('getUnreadCount delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource(unreadCount: 3);
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.getUnreadCount();

      expect(remote.getUnreadCountCallCount, 1);
      expect(result, 3);
    });

    test('markAsRead delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource(unreadCount: 2);
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.markAsRead(['n1', 'n2']);

      expect(remote.markAsReadCallCount, 1);
      expect(remote.lastMarkedIds, ['n1', 'n2']);
      expect(result, 2);
    });

    test('markAllAsRead delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource(unreadCount: 5);
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.markAllAsRead();

      expect(remote.markAllAsReadCallCount, 1);
      expect(result, 5);
    });

    test('delete delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource();
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.delete('n1');

      expect(remote.deleteCallCount, 1);
      expect(remote.lastDeletedId, 'n1');
      expect(result, true);
    });

    test('getById delegates to remote datasource', () async {
      final remote = _FakeRemoteDataSource(notifications: [_testNotification]);
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.getById('n1');

      expect(remote.getByIdCallCount, 1);
      expect(remote.lastGetByIdId, 'n1');
      expect(result?.id, 'n1');
    });

    test('getById returns null when remote returns null', () async {
      final remote = _FakeRemoteDataSource();
      final repo = NotificationRepositoryImpl(remote);

      final result = await repo.getById('nonexistent');

      expect(result, isNull);
    });

    test('getNotifications rethrows AppException', () async {
      final remote = _FakeRemoteDataSource(
        shouldFail: true,
        failureException: const UnauthorizedException('Token expired'),
      );
      final repo = NotificationRepositoryImpl(remote);

      expect(
        () => repo.getNotifications(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('getNotifications wraps unexpected errors in ServerException', () async {
      final remote = _FakeRemoteDataSource(
        shouldFail: true,
        failureException: Exception('Unexpected'),
      );
      final repo = NotificationRepositoryImpl(remote);

      expect(
        () => repo.getNotifications(),
        throwsA(isA<ServerException>()),
      );
    });

    test('markAsRead rethrows AppException', () async {
      final remote = _FakeRemoteDataSource(
        shouldFail: true,
        failureException: const ForbiddenException('Not allowed'),
      );
      final repo = NotificationRepositoryImpl(remote);

      expect(
        () => repo.markAsRead(['n1']),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('delete rethrows AppException', () async {
      final remote = _FakeRemoteDataSource(
        shouldFail: true,
        failureException: const ServerException(message: 'Not found', statusCode: 404),
      );
      final repo = NotificationRepositoryImpl(remote);

      expect(
        () => repo.delete('n1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
