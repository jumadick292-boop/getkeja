import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';

void main() {
  testWidgets('settings list skeleton fits a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const Scaffold(body: AppListSkeleton(rows: 6)),
      ),
    );

    expect(find.byType(AppListSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
