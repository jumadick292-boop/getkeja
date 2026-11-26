import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/account/presentation/pages/account_overview_page.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/profile/presentation/widgets/profile_photo_avatar.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('account status badges wrap and use distinct verified colors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _AccountAuthNotifier()),
          profilePhotoUrlProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: const AccountOverviewPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('MFA enabled'), findsOneWidget);

    final emailBadge = find
        .ancestor(of: find.text('Email'), matching: find.byType(Row))
        .first;
    final phoneBadge = find
        .ancestor(of: find.text('Phone'), matching: find.byType(Row))
        .first;
    final emailIcon = tester.widget<Icon>(
      find.descendant(
        of: emailBadge,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
    );
    final phoneIcon = tester.widget<Icon>(
      find.descendant(
        of: phoneBadge,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
    );
    expect(emailIcon.color, isNot(phoneIcon.color));
  });
}

class _AccountAuthNotifier extends AuthNotifier {
  _AccountAuthNotifier()
    : super(
        ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
        AuthTokenStorage(_MemoryStorage()),
      ) {
    state = AuthState.authenticated(
      user: AuthUser(
        id: 'account-test',
        email: 'person@example.com',
        firstName: 'Test',
        lastName: 'User',
        emailVerified: true,
        phoneVerified: true,
        mfaEnabled: true,
      ),
      accessToken: 'access',
      refreshToken: 'refresh',
    );
  }

  @override
  Future<void> restoreSession() async {}
}

class _MemoryStorage implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<void> deleteAll() async => _values.clear();
  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> writeAll(Map<String, String> entries) async =>
      _values.addAll(entries);
}
