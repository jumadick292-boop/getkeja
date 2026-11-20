import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/constants/app_constants.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/onboarding/presentation/pages/services_onboarding_page.dart';
import 'package:get_keja_mobile/features/splash/presentation/pages/splash_page.dart';

void main() {
  testWidgets('shows service introductions and advances between them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(_MemorySecureStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Find a place to call home'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Laundry, made easier'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('skipping saves completion and opens the welcome screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _MemorySecureStorage();

    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(storage.values[AppConstants.onboardingCompletedKey], 'true');
    expect(find.text('Welcome screen'), findsOneWidget);
  });

  testWidgets('finishing the last slide saves completion and opens welcome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _MemorySecureStorage();

    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();
    for (var page = 0; page < 4; page++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Support for rental management'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(storage.values[AppConstants.onboardingCompletedKey], 'true');
    expect(find.text('Welcome screen'), findsOneWidget);
  });

  testWidgets('shows an error and stays on onboarding if saving fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _MemorySecureStorage()..failWrites = true;

    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save your progress. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Find a place to call home'), findsOneWidget);
    expect(find.text('Welcome screen'), findsNothing);
  });

  test('splash destination depends on the saved first-run completion flag', () {
    expect(resolveUnauthenticatedStartupDestination('true'), '/welcome');
    expect(resolveUnauthenticatedStartupDestination('false'), '/onboarding');
    expect(resolveUnauthenticatedStartupDestination(null), '/onboarding');
  });
}

Widget _app(_MemorySecureStorage storage) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const ServicesOnboardingPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Welcome screen'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _MemorySecureStorage implements SecureStorageService {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw const StorageException('simulated storage failure');
    values[key] = value;
  }

  @override
  Future<void> writeAll(Map<String, String> entries) async {
    if (failWrites) throw const StorageException('simulated storage failure');
    values.addAll(entries);
  }
}
