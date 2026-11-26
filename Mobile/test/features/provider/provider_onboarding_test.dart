import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/provider/presentation/pages/provider_onboarding_page.dart';

void main() {
  testWidgets('onboarding renders mode + category and validates required name',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProviderOnboardingPage()),
      ),
    );

    expect(find.text('Individual'), findsOneWidget);
    expect(find.text('Organization'), findsOneWidget);
    expect(find.text('Service category'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Submit'), findsOneWidget);

    // Submitting with an empty name should surface validation.
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('switching to organization changes the name label', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProviderOnboardingPage()),
      ),
    );
    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();
    expect(find.text('Business name'), findsOneWidget);
  });
}