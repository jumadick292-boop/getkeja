import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/cleaning_operations/data/datasources/cleaning_operations_remote_datasource.dart';
import 'package:get_keja_mobile/features/cleaning_operations/presentation/state/cleaning_operations_state.dart';
import 'package:get_keja_mobile/features/cleaning_operations/presentation/pages/customer_cleaning_jobs_page.dart';
import 'package:get_keja_mobile/features/cleaning_operations/presentation/pages/customer_cleaning_job_detail_page.dart';
import 'package:get_keja_mobile/features/cleaning_operations/presentation/pages/provider_cleaning_jobs_page.dart';

class _FakeCleaningDataSource extends CleaningOperationsRemoteDataSource {
  _FakeCleaningDataSource() : super(Dio());

  final Map<String, dynamic> job = <String, dynamic>{
    'id': 'job-1',
    'categoryId': 'clean_home',
    'status': 'completed_pending_confirmation',
    'currency': 'KES',
    'agreedPrice': '5000.00',
    'serviceAddress': '12 Nairobi',
    'assessments': <dynamic>[
      <String, dynamic>{'customerVisibleReport': 'Deep clean required', 'safetyConcerns': 'none'},
    ],
    'checklists': <dynamic>[
      <String, dynamic>{
        'id': 'cl-1',
        'title': 'Deep clean checklist',
        'items': <dynamic>[
          <String, dynamic>{'id': 'k1', 'label': 'Kitchen', 'done': false},
        ],
      },
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
  Future<Map<String, dynamic>> toggleChecklistItem(String jobId, String checklistId, String itemId, bool done, {String? organizationId}) async => job;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      cleaningOperationsRemoteDataSourceProvider
          .overrideWithValue(_FakeCleaningDataSource()),
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
    await tester.pumpWidget(_app(const CustomerCleaningJobsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('clean_home'), findsOneWidget);
  });

  testWidgets('customer detail shows assessment + confirm button', (tester) async {
    await tester.pumpWidget(_app(CustomerCleaningJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deep clean required'), findsOneWidget);
    expect(find.textContaining('Confirm completion'), findsOneWidget);
  });

  testWidgets('provider detail shows checklist + progress actions', (tester) async {
    await tester.pumpWidget(_app(ProviderCleaningJobDetailPage(jobId: 'job-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deep clean checklist'), findsOneWidget);
    expect(find.textContaining('Kitchen'), findsOneWidget);
  });
}