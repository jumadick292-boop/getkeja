import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('dashboard fits a narrow mobile viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(_RecordingAuthNotifier(), textScaleFactor: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('What do you need?'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Laundries'), findsOneWidget);
    expect(find.text('Movers'), findsOneWidget);
    expect(find.text('Garbage'), findsOneWidget);
  });

  testWidgets('profile tab links to profile and account settings', (
    tester,
  ) async {
    final notifier = _RecordingAuthNotifier();
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);

    GoRouter.of(tester.element(find.text('Profile destination'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account settings destination'), findsOneWidget);
  });

  testWidgets('profile tab signs out and returns to welcome', (tester) async {
    final notifier = _RecordingAuthNotifier();
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(notifier.lastAction, const AuthAction.logout());
    expect(find.text('Welcome destination'), findsOneWidget);
  });
}

Widget _app(_RecordingAuthNotifier notifier, {double textScaleFactor = 1}) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text('Profile destination')),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const Scaffold(body: Text('Account settings destination')),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) =>
            const Scaffold(body: Text('Welcome destination')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith((ref) => notifier)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
        child: child!,
      ),
    ),
  );
}

class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier()
    : super(
        ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
        AuthTokenStorage(_MemoryStorage()),
      );

  AuthAction? lastAction;

  @override
  Future<void> handleAction(AuthAction action) async {
    lastAction = action;
    state = const AuthState.unauthenticated();
  }
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
