import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/finishing_operations/data/datasources/finishing_operations_remote_datasource.dart';
import 'package:get_keja_mobile/features/finishing_operations/presentation/state/finishing_operations_state.dart';
import 'package:get_keja_mobile/features/finishing_operations/presentation/pages/customer_finishing_jobs_page.dart';
import 'package:get_keja_mobile/features/finishing_operations/presentation/pages/customer_finishing_job_detail_page.dart';
import 'package:get_keja_mobile/features/finishing_operations/presentation/pages/provider_finishing_jobs_page.dart';

class _FakeFinishingDataSource extends FinishingOperationsRemoteDataSource {
  _FakeFinishingDataSource() : super(Dio());

  final Map<String, dynamic> job = <String, dynamic>{
    'id': 'job-1',
    'categoryId': 'roofing',
    'status': 'completed_pending_confirmation',
    'currency': 'KES',
    'agreedPrice': '20000.00',
    'serviceAddress': '12 Nairobi',
    'assessments': <dynamic>[
      <String, dynamic>{'customerVisibleReport': 'Site ready', 'safetyConcerns': 'none'},
    ],
    'plans': <dynamic>[
      <String, dynamic>{'summary': 'Mount panels', 'deliverables': 'Working system'},
    ],
    'materials': <dynamic>[
      <String, dynamic>{'description': 'Ceramic tile', 'quantity': '6', 'customerVisible': true, 'approvalStatus': 'pending'},
    ],
    'inspections': <dynamic>[
      <String, dynamic>{'name': 'Water ingress', 'outcome': 'passed', 'customerVisible': true},
    ],
    'staff': <dynamic>[
      <String, dynamic>{'userId': 'u1', 'label': 'Tech', 'isActive': true},
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
  Future<Map<String, dynamic>> recordAssessment(String jobId, Map<String, dynamic> body, {String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> addMaterial(String jobId, Map<String, dynamic> body, {String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> assignStaff(String jobId, String userId, {String? label, String? organizationId}) async => job;

  @override
  Future<Map<String, dynamic>> revokeStaff(String jobId, String staffUserId, {String? organizationId}) async => job;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      finishingOperationsRemoteDataSourceProvider
          .overrideWithValue(_FakeFinishingDataSource()),
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
    await tester.pumpWidget(_app(const CustomerFinishingJobsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('roofing'), findsOneWidget);
  });

  testWidgets('customer detail shows assessment, materials + confirm', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(CustomerFinishingJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Site ready'), findsOneWidget);
    expect(find.textContaining('Ceramic tile'), findsWidgets);
    expect(find.textContaining('Confirm completion'), findsOneWidget);
  });

  testWidgets('provider detail shows materials/staff/inspection + actions', (tester) async {
    await tester.pumpWidget(_app(ProviderFinishingJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ceramic tile'), findsOneWidget);
    expect(find.textContaining('Tech'), findsOneWidget);
    expect(find.textContaining('Add materials'), findsOneWidget);
    expect(find.textContaining('Assign staff'), findsOneWidget);
  });
}