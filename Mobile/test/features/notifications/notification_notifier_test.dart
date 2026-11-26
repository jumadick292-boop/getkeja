// Notification notifier state management tests.
// Uses ProviderContainer to test Riverpod notifier behavior with repository overrides.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';
import 'package:get_keja_mobile/features/notifications/domain/repositories/notification_repository.dart';
import 'package:get_keja_mobile/features/notifications/presentation/state/notification_state.dart';

class _FakeRepository implements NotificationRepository {
  _FakeRepository({this.notifications = const [], this.unreadCount = 0});

  final List<NotificationModel> notifications;
  final int unreadCount;
  int markAsReadCallCount = 0;
  int markAllAsReadCallCount = 0;
  int deleteCallCount = 0;
  List<String>? lastMarkedIds;
  String? lastDeletedId;

  @override
  Future<List<NotificationModel>> getNotifications({
    String? category,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async => notifications;

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<int> markAsRead(List<String> notificationIds) async {
    markAsReadCallCount++;
    lastMarkedIds = List.from(notificationIds);
    return notificationIds.length;
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCallCount++;
    return unreadCount;
  }

  @override
  Future<bool> delete(String notificationId) async {
    deleteCallCount++;
    lastDeletedId = notificationId;
    return true;
  }

  @override
  Future<NotificationModel?> getById(String notificationId) async {
    try {
      return notifications.firstWhere((n) => n.id == notificationId);
    } on StateError {
      return null;
    }
  }
}

final _testNotifications = [
  NotificationModel(
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
  ),
  NotificationModel(
    id: 'n2',
    userId: 'u1',
    eventType: 'security.login',
    category: 'security',
    title: 'New sign-in',
    body: 'New sign-in detected.',
    priority: 'high',
    isRead: true,
    createdAt: '2026-01-02T00:00:00Z',
  ),
];

void main() {
  group('NotificationNotifier via ProviderContainer', () {
    test('loads notifications on first read', () async {
      final repo = _FakeRepository(notifications: _testNotifications);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();

      final state = container.read(notificationProvider);
      expect(state.value, hasLength(2));
      expect(
        state.value!.firstWhere((n) => n.id == 'n1').title,
        'New match: Nairobi 2BR',
      );
    });

    test('markAsRead updates state optimistically', () async {
      final repo = _FakeRepository(notifications: _testNotifications);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();
      await container.read(notificationProvider.notifier).markAsRead(['n1']);

      expect(repo.markAsReadCallCount, 1);
      expect(repo.lastMarkedIds, ['n1']);

      final state = container.read(notificationProvider);
      expect(state.value?.firstWhere((n) => n.id == 'n1').isRead, true);
      expect(state.value?.firstWhere((n) => n.id == 'n2').isRead, true); // unchanged
    });

    test('markAllAsRead updates all notifications', () async {
      final repo = _FakeRepository(notifications: _testNotifications, unreadCount: 1);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();
      await container.read(notificationProvider.notifier).markAllAsRead();

      expect(repo.markAllAsReadCallCount, 1);

      final state = container.read(notificationProvider);
      expect(state.value?.every((n) => n.isRead), true);
    });

    test('markSingleAsRead marks one notification', () async {
      final repo = _FakeRepository(notifications: _testNotifications);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();
      await container.read(notificationProvider.notifier).markSingleAsRead('n1');

      expect(repo.markAsReadCallCount, 1);
      expect(repo.lastMarkedIds, ['n1']);
    });

    test('delete removes notification from state', () async {
      final repo = _FakeRepository(notifications: _testNotifications);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();
      await container.read(notificationProvider.notifier).delete('n1');

      expect(repo.deleteCallCount, 1);
      expect(repo.lastDeletedId, 'n1');

      final state = container.read(notificationProvider);
      expect(state.value?.length, 1);
      expect(state.value?.any((n) => n.id == 'n1'), false);
    });

    test('getUnreadCount delegates to repository', () async {
      final repo = _FakeRepository(notifications: const [], unreadCount: 3);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final count = await container.read(notificationProvider.notifier).getUnreadCount();

      expect(count, 3);
    });

    test('refresh reloads notifications', () async {
      final repo = _FakeRepository(notifications: _testNotifications);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(notificationProvider.notifier).load();
      await container.read(notificationProvider.notifier).refresh();

      final state = container.read(notificationProvider);
      expect(state.value, hasLength(2));
    });
  });

  group('unreadCountProvider', () {
    test('returns unread count from repository', () async {
      final repo = _FakeRepository(notifications: const [], unreadCount: 5);

      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final count = await container.read(unreadCountProvider.future);

      expect(count, 5);
    });
  });
}
