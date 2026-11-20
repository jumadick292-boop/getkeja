// Application bootstrap and initialization.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app/router/app_router.dart';
import '../app/theme/app_theme.dart';
import '../app/preferences/app_preferences.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/storage/secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../core/api/api_client.dart';
import '../features/authentication/presentation/state/auth_state.dart';

String? _preferencesLoadAttemptedForUser;

class GetKejaApp extends ConsumerWidget {
  const GetKejaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      final userId = next.user?.id;
      if (userId != null) {
        unawaited(_loadAccountPreferences(ref, userId));
      } else if (next.maybeWhen(
        unauthenticated: () => true,
        orElse: () => false,
      )) {
        _preferencesLoadAttemptedForUser = null;
        const preferences = AppPreferences();
        AppFormatters.update(preferences);
        ref.read(appPreferencesProvider.notifier).state = preferences;
      }
    });

    final userId = authState.user?.id;
    if (userId != null) unawaited(_loadAccountPreferences(ref, userId));

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preferences.themeMode,
      locale: preferences.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

Future<void> _loadAccountPreferences(WidgetRef ref, String? userId) async {
  if (userId == null) {
    const preferences = AppPreferences();
    AppFormatters.update(preferences);
    ref.read(appPreferencesProvider.notifier).state = preferences;
    return;
  }
  if (_preferencesLoadAttemptedForUser == userId) return;
  _preferencesLoadAttemptedForUser = userId;

  try {
    final response = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/account/preferences');
    final data = response.data?['data'];
    if (ref.read(authNotifierProvider).user?.id == userId && data is Map) {
      final preferences = AppPreferences.fromJson(
        Map<String, dynamic>.from(data),
      );
      AppFormatters.update(preferences);
      ref.read(appPreferencesProvider.notifier).state = preferences;
    }
  } catch (_) {
    // Keep the system theme when saved preferences cannot be loaded.
    if (_preferencesLoadAttemptedForUser == userId) {
      _preferencesLoadAttemptedForUser = null;
    }
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }

  // Initialize secure storage
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // encryptedSharedPreferences deprecated in v11.x, using default secure storage
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(),
  );

  // Run app with ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        // Override secure storage with initialized instance
        secureStorageProvider.overrideWithValue(storage),
      ],
      child: const GetKejaApp(),
    ),
  );
}
