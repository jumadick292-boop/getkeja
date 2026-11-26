import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/moving/data/datasources/moving_remote_datasource.dart';
import 'package:get_keja_mobile/features/moving/data/repositories/moving_repository_impl.dart';
import 'package:get_keja_mobile/features/moving/presentation/state/moving_state.dart';
import 'package:get_keja_mobile/features/moving/presentation/pages/moving_jobs_page.dart';
import 'package:get_keja_mobile/features/moving/presentation/pages/provider_moving_jobs_page.dart';

class _FakeMovingRepository extends MovingRepository {
  _FakeMovingRepository() : super(MovingRemoteDataSource(Dio()));

  final List<Map<String, dynamic>> customerJobs = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'job-1', 'status': 'in_progress', 'agreedMoveDate': '2026-12-10'},
  ];
  final List<Map<String, dynamic>> providerJobs = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'job-2', 'status': 'confirmed', 'agreedMoveDate': '2026-12-11'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) async => customerJobs;

  @override
  Future<List<Map<String, dynamic>>> listProviderJobs({String? status}) async => providerJobs;

  @override
  Future<Map<String, dynamic>> getCustomerJob(String jobId) async => <String, dynamic>{
        'id': jobId,
        'status': 'awaiting_customer_confirmation',
        'originAddress': 'A',
        'destinationAddress': 'B',
        'agreedMoveDate': '2026-12-10',
        'currency': 'KES',
        'agreedPrice': '18000.00',
        'checklist': <String, dynamic>{'move_date': true},
        'history': <dynamic>[],
      };

  @override
  Future<Map<String, dynamic>> getProviderJob(String jobId) async => <String, dynamic>{
        'id': jobId,
        'status': 'confirmed',
        'canViewLocations': true,
        'originAddress': 'A',
        'destinationAddress': 'B',
        'agreedMoveDate': '2026-12-10',
        'checklist': <String, dynamic>{'move_date': false},
      };
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [movingRepositoryProvider.overrideWithValue(_FakeMovingRepository())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('customer moving jobs list renders status', (tester) async {
    await tester.pumpWidget(_app(const MovingJobsPage()));
    await tester.pumpAndSettle();
    expect(find.text('IN PROGRESS'), findsOneWidget);
  });

  testWidgets('provider moving jobs list renders status', (tester) async {
    await tester.pumpWidget(_app(const ProviderMovingJobsPage()));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRMED'), findsOneWidget);
  });
}