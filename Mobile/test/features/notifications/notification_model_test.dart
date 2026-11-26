// Notification model parsing tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/notifications/domain/entities/notification_model.dart';

void main() {
  group('NotificationModel.fromJson', () {
    test('parses a complete notification JSON', () {
      final json = <String, dynamic>{
        'id': 'n1',
        'userId': 'u1',
        'organisationId': 'org1',
        'eventType': 'saved_search.match',
        'category': 'property',
        'title': 'New match: Nairobi 2BR',
        'body': 'A new property matches your saved search.',
        'metadata': <String, dynamic>{
          'savedSearchId': 's1',
          'listingId': 'l1',
          'listingTitle': '2BR in Kilimani',
          'listingLocation': 'Nairobi',
          'listingPrice': 45000,
          'searchName': 'Nairobi 2BR',
          'summary': '2-bedroom apartment · Nairobi · KES 45000',
        },
        'priority': 'normal',
        'isRead': false,
        'readAt': null,
        'expiresAt': null,
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final notification = NotificationModel.fromJson(json);

      expect(notification.id, 'n1');
      expect(notification.userId, 'u1');
      expect(notification.organisationId, 'org1');
      expect(notification.eventType, 'saved_search.match');
      expect(notification.category, 'property');
      expect(notification.title, 'New match: Nairobi 2BR');
      expect(notification.body, 'A new property matches your saved search.');
      expect(notification.metadata['savedSearchId'], 's1');
      expect(notification.metadata['listingId'], 'l1');
      expect(notification.priority, 'normal');
      expect(notification.isRead, false);
      expect(notification.createdAt, '2026-01-01T00:00:00Z');
    });

    test('extracts saved search metadata getters', () {
      final json = <String, dynamic>{
        'id': 'n1',
        'userId': 'u1',
        'eventType': 'saved_search.match',
        'category': 'property',
        'title': 'New match',
        'body': 'A new property matches.',
        'metadata': <String, dynamic>{
          'savedSearchId': 's1',
          'listingId': 'l1',
          'listingTitle': '2BR in Kilimani',
          'listingLocation': 'Nairobi',
          'listingPrice': 45000,
        },
        'priority': 'normal',
        'isRead': false,
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final notification = NotificationModel.fromJson(json);

      expect(notification.savedSearchId, 's1');
      expect(notification.listingId, 'l1');
      expect(notification.listingTitle, '2BR in Kilimani');
      expect(notification.listingLocation, 'Nairobi');
      expect(notification.listingPrice, 45000);
      expect(notification.isSearchAlert, true);
    });

    test('returns null metadata getters when absent', () {
      final json = <String, dynamic>{
        'id': 'n1',
        'userId': 'u1',
        'eventType': 'account.login',
        'category': 'security',
        'title': 'New sign-in',
        'body': 'New sign-in detected.',
        'metadata': <String, dynamic>{},
        'priority': 'high',
        'isRead': true,
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final notification = NotificationModel.fromJson(json);

      expect(notification.savedSearchId, isNull);
      expect(notification.listingId, isNull);
      expect(notification.listingTitle, isNull);
      expect(notification.listingLocation, isNull);
      expect(notification.listingPrice, isNull);
      expect(notification.isSearchAlert, false);
    });

    test('handles missing optional fields', () {
      final json = <String, dynamic>{
        'id': 'n1',
        'userId': 'u1',
        'eventType': 'saved_search.match',
        'category': 'property',
        'title': 'New match',
        'body': 'A new property matches.',
        'priority': 'normal',
        'isRead': false,
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final notification = NotificationModel.fromJson(json);

      expect(notification.organisationId, isNull);
      expect(notification.metadata, isEmpty);
      expect(notification.readAt, isNull);
      expect(notification.expiresAt, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = NotificationModel(
        id: 'n1',
        userId: 'u1',
        eventType: 'saved_search.match',
        category: 'property',
        title: 'New match',
        body: 'A new property matches.',
        priority: 'normal',
        isRead: false,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final json = original.toJson();
      final reparsed = NotificationModel.fromJson(json);

      expect(reparsed.id, original.id);
      expect(reparsed.userId, original.userId);
      expect(reparsed.eventType, original.eventType);
      expect(reparsed.category, original.category);
      expect(reparsed.title, original.title);
      expect(reparsed.body, original.body);
      expect(reparsed.priority, original.priority);
      expect(reparsed.isRead, original.isRead);
      expect(reparsed.createdAt, original.createdAt);
    });
  });

  group('NotificationListResponse.fromJson', () {
    test('parses a list of notifications', () {
      final json = <String, dynamic>{
        'success': true,
        'data': [
          <String, dynamic>{
            'id': 'n1',
            'userId': 'u1',
            'eventType': 'saved_search.match',
            'category': 'property',
            'title': 'Match 1',
            'body': 'Body 1',
            'priority': 'normal',
            'isRead': false,
            'createdAt': '2026-01-01T00:00:00Z',
          },
          <String, dynamic>{
            'id': 'n2',
            'userId': 'u1',
            'eventType': 'security.login',
            'category': 'security',
            'title': 'Login',
            'body': 'New login.',
            'priority': 'high',
            'isRead': true,
            'createdAt': '2026-01-02T00:00:00Z',
          },
        ],
      };

      final response = NotificationListResponse.fromJson(json);

      expect(response.success, true);
      expect(response.notifications, hasLength(2));
      expect(response.notifications[0].id, 'n1');
      expect(response.notifications[1].id, 'n2');
    });

    test('returns empty list when data is absent', () {
      final json = <String, dynamic>{
        'success': true,
      };

      final response = NotificationListResponse.fromJson(json);

      expect(response.notifications, isEmpty);
    });
  });

  group('UnreadCountResponse.fromJson', () {
    test('parses unread count', () {
      final json = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'count': 3,
        },
      };

      final response = UnreadCountResponse.fromJson(json);

      expect(response.success, true);
      expect(response.count, 3);
    });

    test('returns zero when count is absent', () {
      final json = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{},
      };

      final response = UnreadCountResponse.fromJson(json);

      expect(response.count, 0);
    });
  });
}
