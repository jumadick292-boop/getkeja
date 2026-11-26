import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:get_keja_mobile/features/profile/presentation/widgets/profile_photo_avatar.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('profile fits a narrow viewport and opens saved home location', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/profile/location',
          builder: (context, state) {
            final extra = state.extra! as Map<String, Object?>;
            final location = extra['location']! as Map<String, Object?>;
            return Scaffold(
              body: Text(
                '${extra['locationType']}:${location['formattedAddress']}',
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _ProfileAuthNotifier()),
          personalLocationProvider.overrideWith(
            (ref) async => {
              'locationType': 'personal_residential',
              'formattedAddress': 'Nairobi, Kenya',
              'latitude': -1.286389,
              'longitude': 36.817223,
            },
          ),
          profilePhotoUrlProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My location'), findsOneWidget);
    expect(find.text('Nairobi, Kenya'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My location'));
    await tester.pumpAndSettle();
    expect(find.text('personal_residential:Nairobi, Kenya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ProfileAuthNotifier extends AuthNotifier {
  _ProfileAuthNotifier()
    : super(
        ApiClient(tokenStorage: AuthTokenStorage(_MemoryStorage())),
        AuthTokenStorage(_MemoryStorage()),
      ) {
    state = AuthState.authenticated(
      user: AuthUser(
        id: 'profile-test',
        email: 'person@example.com',
        firstName: 'Example',
        lastName: 'Member',
        phone: '+254712345678',
        emailVerified: true,
        phoneVerified: true,
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
