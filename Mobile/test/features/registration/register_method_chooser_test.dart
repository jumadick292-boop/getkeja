import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/registration/presentation/pages/register_page.dart';

void main() {
  testWidgets('signup starts with clear email, phone, and Google choices', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/register/email',
          builder: (context, state) =>
              const Scaffold(body: Text('Email registration form')),
        ),
        GoRoute(
          path: '/register/phone',
          builder: (context, state) =>
              const Scaffold(body: Text('Phone registration form')),
        ),
        GoRoute(
          path: '/register/google',
          builder: (context, state) =>
              const Scaffold(body: Text('Google registration setup')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _TestAuthNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('First name'), findsNothing);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    expect(find.text('Email registration form'), findsOneWidget);

    router.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with phone'));
    await tester.pumpAndSettle();
    expect(find.text('Phone registration form'), findsOneWidget);

    router.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google registration setup'), findsOneWidget);
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
