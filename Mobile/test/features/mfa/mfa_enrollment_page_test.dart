import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/mfa/presentation/pages/mfa_enrollment_page.dart';

void main() {
  testWidgets('MFA enrollment fits a phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _EnrollmentAuthNotifier()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const MfaEnrollmentPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Authenticator app (TOTP)'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
  });
}

class _EnrollmentAuthNotifier extends AuthNotifier {
  _EnrollmentAuthNotifier()
    : super(
        ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
        AuthTokenStorage(_MemoryStorage()),
      ) {
    state = const AuthState.mfaEnrollmentRequired(
      enrollmentToken: 'enrollment-token',
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
  Future<void> writeAll(Map<String, String> entries) async {
    _values.addAll(entries);
  }
}
