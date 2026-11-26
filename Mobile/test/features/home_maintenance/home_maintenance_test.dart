import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/home_maintenance/data/datasources/home_maintenance_remote_datasource.dart';
import 'package:get_keja_mobile/features/home_maintenance/presentation/state/home_maintenance_state.dart';
import 'package:get_keja_mobile/features/home_maintenance/presentation/pages/customer_home_maintenance_jobs_page.dart';
import 'package:get_keja_mobile/features/home_maintenance/presentation/pages/customer_home_maintenance_job_detail_page.dart';
import 'package:get_keja_mobile/features/home_maintenance/presentation/pages/provider_home_maintenance_jobs_page.dart';

class _FakeHomeMaintenanceDataSource extends HomeMaintenanceRemoteDataSource {
  _FakeHomeMaintenanceDataSource() : super(Dio());

  final Map<String, dynamic> job = <String, dynamic>{
    'id': 'job-1',
    'categoryId': 'plumbing_general',
    'status': 'completed_pending_confirmation',
    'currency': 'KES',
    'agreedPrice': '1500.00',
    'serviceAddress': '12 Nairobi',
    'inspections': <dynamic>[
      <String, dynamic>{'customerVisibleReport': 'Leak fixed', 'safetyConcerns': 'none'},
    ],
    'amendments': <dynamic>[],
  };

  @override
  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) async => [job];

  @override
  Future<Map<String, dynamic>> getCustomerJob(String jobId) async => job;

  @override
  Future<List<Map<String, dynamic>>> listProviderJobs({String? status, String? organizationId}) async => [job];

  @override
  Future<Map<String, dynamic>> getProviderJob(String jobId, {String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> updateProgress(String jobId, String to, {String? reason, String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> submitCompletion(String jobId, {String? notes, String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> recordInspection(String jobId, Map<String, dynamic> body, {String? organizationId}) async => job;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      homeMaintenanceRemoteDataSourceProvider
          .overrideWithValue(_FakeHomeMaintenanceDataSource()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('customer jobs list renders a job', (tester) async {
    await tester.pumpWidget(_app(const CustomerHomeMaintenanceJobsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('plumbing_general'), findsOneWidget);
  });

  testWidgets('customer detail shows inspection + confirm button', (tester) async {
    await tester.pumpWidget(_app(CustomerHomeMaintenanceJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leak fixed'), findsOneWidget);
    expect(find.textContaining('Confirm completion'), findsOneWidget);
  });

  testWidgets('provider detail shows start/quality actions', (tester) async {
    await tester.pumpWidget(_app(ProviderHomeMaintenanceJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('plumbing_general'), findsOneWidget);
    expect(find.textContaining('12 Nairobi'), findsOneWidget);
  });
}