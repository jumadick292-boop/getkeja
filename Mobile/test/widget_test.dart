import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('home page shows the GetKeja experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GetKejaApp());

    expect(find.text('GetKeja'), findsOneWidget);
    expect(find.text('Find your next home'), findsOneWidget);
    expect(find.text('Featured homes'), findsOneWidget);
    expect(find.text('Nairobi, Kenya'), findsOneWidget);
  });

  testWidgets('default Flutter demo UI is gone', (WidgetTester tester) async {
    await tester.pumpWidget(const GetKejaApp());

    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.text('You have pushed the button this many times:'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('service tiles surface a placeholder message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GetKejaApp());

    await tester.tap(find.text('Laundries'));
    await tester.pump();

    expect(find.text('Laundries is coming soon'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const GetKejaApp());

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('notification button surfaces a placeholder message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GetKejaApp());

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();

    expect(find.text('Notifications is coming soon'), findsOneWidget);
  });

  testWidgets('lays out compact phone screens without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GetKejaApp());

    expect(tester.takeException(), isNull);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Featured homes'), findsOneWidget);
  });
}
