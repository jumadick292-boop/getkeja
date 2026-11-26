// Provider navigation & Explore/Visits regression tests (Task 13.18).
//
// Proves that provider setup/onboarding and the provider dashboard are
// reachable through normal navigation from the home dashboard, that Explore and
// Visits open real implemented destinations (not "coming soon" dead taps), and
// that Android back returns to the previous page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

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
  Future<void> writeAll(Map<String, String> entries) async => _values.addAll(entries);
}

class _AuthNotifier extends AuthNotifier {
  _AuthNotifier()
      : super(
          ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
          AuthTokenStorage(_MemoryStorage()),
        );
}

Widget _app() {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
      for (final path in const [
        '/provider/onboarding',
        '/provider/dashboard',
        '/house-seeker/search',
        '/house-seeker/visits',
        '/laundry/orders',
        '/moving/jobs',
        '/garbage/jobs',
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text('${state.path} destination')),
        ),
    ],
  );
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith((ref) => _AuthNotifier())],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('provider onboarding is reachable from the home dashboard', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider onboarding & setup'));
    await tester.pumpAndSettle();
    expect(find.text('/provider/onboarding destination'), findsOneWidget);
  });

  testWidgets('provider dashboard is reachable and back returns home', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open provider dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('/provider/dashboard destination'), findsOneWidget);

    // Android back returns to the dashboard.
    final router = GoRouter.of(tester.element(find.text('/provider/dashboard destination')));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('What do you need?'), findsOneWidget);
  });

  testWidgets('Explore tab opens the real property search (no coming soon)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('Browse homes'), findsOneWidget);
    await tester.tap(find.text('Browse homes'));
    await tester.pumpAndSettle();
    expect(find.text('/house-seeker/search destination'), findsOneWidget);
  });

  testWidgets('Visits tab opens the real site-visits screen (no coming soon)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visits'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNothing);
    expect(find.text('View site visits'), findsOneWidget);
    await tester.tap(find.text('View site visits'));
    await tester.pumpAndSettle();
    expect(find.text('/house-seeker/visits destination'), findsOneWidget);
  });

  testWidgets('dashboard service tiles navigate to valid destinations', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laundries'));
    await tester.pumpAndSettle();
    expect(find.text('/laundry/orders destination'), findsOneWidget);
  });
}