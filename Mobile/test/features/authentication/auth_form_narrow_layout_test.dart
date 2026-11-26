import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/password_recovery/presentation/pages/reset_password_page.dart';
import 'package:get_keja_mobile/features/verification/presentation/pages/phone_verification_page.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('phone verification scrolls on a narrow screen with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _TestAuthNotifier()),
        ],
        child: const MaterialApp(home: PhoneVerificationPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Verify phone'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.text('Verify phone'));
    await tester.pump();
    expect(
      tester.getRect(find.text('Verify phone')).bottom,
      lessThanOrEqualTo(360),
    );
  });

  testWidgets('password reset scrolls on a narrow screen with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _TestAuthNotifier()),
        ],
        child: const MaterialApp(home: ResetPasswordPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Update password'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.text('Update password'));
    await tester.pump();
    expect(
      tester.getRect(find.text('Update password')).bottom,
      lessThanOrEqualTo(360),
    );
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier()
    : super(
        ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
        AuthTokenStorage(_MemoryStorage()),
      );

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> handleAction(AuthAction action) async {}
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
  Future<void> writeAll(Map<String, String> entries) async {
    _values.addAll(entries);
  }
}
