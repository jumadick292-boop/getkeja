import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:get_keja_mobile/features/notifications/presentation/pages/notifications_page.dart'
    show notificationDeepLinkToPath;
import 'package:get_keja_mobile/features/notifications/presentation/pages/notification_preferences_page.dart';

class _FakeNotificationDataSource extends NotificationRemoteDataSource {
  _FakeNotificationDataSource() : super(Dio());

  @override
  Future<Map<String, dynamic>> getPreferences() async => <String, dynamic>{
        'emailEnabled': true,
        'smsEnabled': false,
        'pushEnabled': true,
        'inAppEnabled': true,
        'securityEmail': true,
        'marketingEmail': false,
      };

  @override
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> updates) async =>
      updates;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      notificationRemoteDataSourceProvider
          .overrideWithValue(_FakeNotificationDataSource()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('notificationDeepLinkToPath', () {
    test('maps moving job deep link', () {
      expect(notificationDeepLinkToPath('getkeja://moving/jobs/abc'),
          '/moving/jobs/abc');
    });
    test('maps conversation deep link to messaging route', () {
      expect(notificationDeepLinkToPath('getkeja://messaging/conversations/c1'),
          '/messaging/conversations/c1');
    });
    test('maps scheduling to calendar', () {
      expect(notificationDeepLinkToPath('getkeja://scheduling/calendar'),
          '/scheduling/calendar');
    });
    test('returns null for unknown/unsafe links', () {
      expect(notificationDeepLinkToPath('https://evil.example.com'), isNull);
      expect(notificationDeepLinkToPath(null), isNull);
    });
  });

  testWidgets('preferences page renders channel + category switches',
      (tester) async {
    await tester.pumpWidget(_app(const NotificationPreferencesPage()));
    await tester.pumpAndSettle();
    // Global channel switches (Email/SMS/Push/In-app) + category switches.
    expect(find.byType(SwitchListTile), findsWidgets);
    expect(find.textContaining('Marketplace'), findsWidgets);
  });
}