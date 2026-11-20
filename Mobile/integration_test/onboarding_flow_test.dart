import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:io';
import 'package:get_keja_mobile/core/constants/app_constants.dart';
import 'package:get_keja_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install can skip onboarding and reach welcome', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    const sessionKeys = [
      AppConstants.accessTokenKey,
      AppConstants.refreshTokenKey,
      AppConstants.enrollmentTokenKey,
    ];
    final previousSession = <String, String?>{
      for (final key in sessionKeys) key: await storage.read(key: key),
    };
    final previousCompletion = await storage.read(
      key: AppConstants.onboardingCompletedKey,
    );
    addTearDown(() async {
      if (previousCompletion == null) {
        await storage.delete(key: AppConstants.onboardingCompletedKey);
      } else {
        await storage.write(
          key: AppConstants.onboardingCompletedKey,
          value: previousCompletion,
        );
      }
      for (final entry in previousSession.entries) {
        if (entry.value == null) {
          await storage.delete(key: entry.key);
        } else {
          await storage.write(key: entry.key, value: entry.value!);
        }
      }
    });
    for (final key in sessionKeys) {
      await storage.delete(key: key);
    }
    await storage.delete(key: AppConstants.onboardingCompletedKey);

    app.main();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Find a place to call home'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('GetKeja'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(
      await storage.read(key: AppConstants.onboardingCompletedKey),
      'true',
    );
  });

  testWidgets('USB device can reach the configured backend health endpoint', (
    tester,
  ) async {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:4000',
    );
    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.getUrl(Uri.parse('$baseUrl/health'));
    final response = await request.close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();

    expect(response.statusCode, HttpStatus.ok, reason: body);
    expect(body, contains('"status":"ok"'));
  });
}
