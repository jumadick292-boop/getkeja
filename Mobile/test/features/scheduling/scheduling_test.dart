import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/scheduling/data/datasources/scheduling_remote_datasource.dart';
import 'package:get_keja_mobile/features/scheduling/data/repositories/scheduling_repository_impl.dart';
import 'package:get_keja_mobile/features/scheduling/presentation/state/scheduling_state.dart';
import 'package:get_keja_mobile/features/scheduling/presentation/pages/provider_calendar_page.dart';
import 'package:get_keja_mobile/features/scheduling/presentation/pages/customer_appointments_page.dart';

class _FakeSchedulingRepository extends SchedulingRepository {
  _FakeSchedulingRepository() : super(SchedulingRemoteDataSource(Dio()));

  final List<Map<String, dynamic>> provider = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'act-1', 'domain': 'laundry', 'status': 'confirmed', 'startAt': '2026-12-10T09:00:00.000Z', 'resourceId': 'r1'},
    <String, dynamic>{'id': 'act-2', 'domain': 'moving', 'status': 'confirmed', 'startAt': '2026-12-11T09:00:00.000Z', 'resourceId': 'r2'},
  ];
  final List<Map<String, dynamic>> customer = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'act-1', 'domain': 'laundry', 'status': 'confirmed', 'startAt': '2026-12-10T09:00:00.000Z', 'resourceId': 'r1'},
  ];

  @override
  Future<List<Map<String, dynamic>>> providerCalendar({required String from, required String to, List<String>? domains, String? status, String? staffUserId}) async => provider;

  @override
  Future<List<Map<String, dynamic>>> customerCalendar({required String from, required String to}) async => customer;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [schedulingRepositoryProvider.overrideWithValue(_FakeSchedulingRepository())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('provider calendar renders entries', (tester) async {
    await tester.pumpWidget(_app(const ProviderCalendarPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('laundry'), findsWidgets);
  });

  testWidgets('customer appointments render entries', (tester) async {
    await tester.pumpWidget(_app(const CustomerAppointmentsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('CONFIRMED'), findsOneWidget);
  });
}