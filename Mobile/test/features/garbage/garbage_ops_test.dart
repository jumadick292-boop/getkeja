import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/garbage/data/datasources/garbage_ops_remote_datasource.dart';
import 'package:get_keja_mobile/features/garbage/data/repositories/garbage_ops_repository_impl.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_ops_state.dart';
import 'package:get_keja_mobile/features/garbage/presentation/pages/garbage_jobs_page.dart';
import 'package:get_keja_mobile/features/garbage/presentation/pages/provider_garbage_jobs_page.dart';

class _FakeGarbageOpsRepository extends GarbageOpsRepository {
  _FakeGarbageOpsRepository() : super(GarbageOpsRemoteDataSource(Dio()));

  final List<Map<String, dynamic>> customerJobs = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'job-1', 'status': 'collecting', 'scheduledDate': '2026-12-10'},
  ];
  final List<Map<String, dynamic>> providerJobs = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'job-2', 'status': 'confirmed', 'scheduledDate': '2026-12-11'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) async => customerJobs;

  @override
  Future<List<Map<String, dynamic>>> listProviderJobs({String? status}) async => providerJobs;

  @override
  Future<Map<String, dynamic>> getCustomerJob(String jobId) async => <String, dynamic>{
        'id': jobId,
        'status': 'awaiting_customer_confirmation',
        'scheduledDate': '2026-12-10',
        'currency': 'KES',
        'agreedPrice': '2500.00',
        'checklist': <String, dynamic>{'bins_present': true},
      };

  @override
  Future<Map<String, dynamic>> getProviderJob(String jobId) async => <String, dynamic>{
        'id': jobId,
        'status': 'confirmed',
        'canViewLocations': true,
        'collectionAddress': 'Site A',
        'scheduledDate': '2026-12-10',
      };
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [garbageOpsRepositoryProvider.overrideWithValue(_FakeGarbageOpsRepository())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('customer garbage jobs list renders status', (tester) async {
    await tester.pumpWidget(_app(const GarbageJobsPage()));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTING'), findsOneWidget);
  });

  testWidgets('provider garbage jobs list renders status', (tester) async {
    await tester.pumpWidget(_app(const ProviderGarbageJobsPage()));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRMED'), findsOneWidget);
  });
}