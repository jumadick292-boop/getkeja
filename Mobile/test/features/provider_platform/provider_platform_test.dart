import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider_platform/data/datasources/provider_platform_remote_datasource.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/state/provider_platform_state.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/provider_dashboard_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/provider_reports_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/provider_reviews_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/customer_complaints_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/provider_complaints_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/complaint_detail_page.dart';
import 'package:get_keja_mobile/features/provider_platform/presentation/pages/staff_workload_page.dart';

class _FakeProviderPlatformDataSource extends ProviderPlatformRemoteDataSource {
  _FakeProviderPlatformDataSource() : super(Dio());

  static final Map<String, dynamic> _dashboard = <String, dynamic>{
    'overview': <String, dynamic>{'active': 4, 'completed': 12, 'averageRating': 4.6},
    'byDomain': <dynamic>[
      <String, dynamic>{'domain': 'moving', 'active': 2, 'completed': 5},
      <String, dynamic>{'domain': 'cleaning', 'active': 2, 'completed': 7},
    ],
  };

  static final Map<String, dynamic> _complaint = <String, dynamic>{
    'id': 'c1',
    'reasonId': 'damaged_item',
    'status': 'open',
    'description': 'Item arrived broken',
    'messages': <dynamic>[
      <String, dynamic>{'authorRole': 'customer', 'body': 'Please help'},
    ],
    'correctiveActions': <dynamic>[],
    'internalNotes': <dynamic>[],
  };

  @override
  Future<Map<String, dynamic>> getDashboard({String? domain, String? categoryId, String? status, String? from, String? to, String? organizationId}) async => _dashboard;

  @override
  Future<List<Map<String, dynamic>>> getStaffWorkload({String? organizationId}) async => <Map<String, dynamic>>[
        <String, dynamic>{'userId': 'u1', 'assignedJobs': 5, 'activeJobs': 2, 'completedJobs': 3},
      ];

  @override
  Future<List<Map<String, dynamic>>> getOperationalReport({String? domain, String? categoryId, String? from, String? to, String? organizationId}) async => <Map<String, dynamic>>[
        <String, dynamic>{'period': '2026-11', 'jobsCreated': 10, 'jobsCompleted': 8, 'jobsCancelled': 1, 'quotations': 6, 'accepted': 5},
      ];

  @override
  Future<List<Map<String, dynamic>>> getServicePerformance({String? organizationId}) async => <Map<String, dynamic>>[
        <String, dynamic>{'domain': 'moving', 'categoryId': null, 'completed': 5, 'cancelled': 1, 'averageRating': 4.5},
      ];

  @override
  Future<List<Map<String, dynamic>>> listProviderReviews({String? organizationId}) async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'r1', 'overallRating': 5, 'status': 'published', 'comment': 'Great job', 'response': ''},
      ];

  @override
  Future<List<Map<String, dynamic>>> listMyReviews() async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'r1', 'overallRating': 4, 'comment': 'Good'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getComplaintReasons() async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'damaged_item', 'label': 'Damaged item'},
      ];

  @override
  Future<List<Map<String, dynamic>>> listMyComplaints() async => <Map<String, dynamic>>[_complaint];

  @override
  Future<List<Map<String, dynamic>>> listProviderComplaints({String? organizationId}) async => <Map<String, dynamic>>[_complaint];

  @override
  Future<List<Map<String, dynamic>>> listAdminComplaints() async => <Map<String, dynamic>>[_complaint];

  @override
  Future<Map<String, dynamic>> getComplaint(String complaintId, {String? organizationId}) async => _complaint;
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      providerPlatformRemoteDataSourceProvider.overrideWithValue(_FakeProviderPlatformDataSource()),
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
  testWidgets('dashboard renders overview + by-domain metrics', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ProviderDashboardPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('moving'), findsWidgets);
    expect(find.textContaining('cleaning'), findsWidgets);
  });

  testWidgets('dashboard exposes setup, marketplace and operations entry points', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ProviderDashboardPage()));
    await tester.pumpAndSettle();
    expect(find.text('Provider setup'), findsOneWidget);
    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('Service catalogue'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Moving'), findsOneWidget);
    expect(find.text('Finishing'), findsOneWidget);
  });

  testWidgets('reports renders operational + performance sections', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ProviderReportsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-11'), findsOneWidget);
    expect(find.textContaining('moving'), findsWidgets);
  });

  testWidgets('provider reviews renders a review + respond action', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ProviderReviewsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Great job'), findsOneWidget);
    expect(find.textContaining('Respond to review'), findsOneWidget);
  });

  testWidgets('customer complaints renders a complaint card', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const CustomerComplaintsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Item arrived broken'), findsOneWidget);
    expect(find.textContaining('Open complaint'), findsOneWidget);
  });

  testWidgets('provider complaints renders the inbox card', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ProviderComplaintsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('damaged_item'), findsOneWidget);
  });

  testWidgets('complaint detail shows conversation + actions', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const ComplaintDetailPage(complaintId: 'c1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Please help'), findsOneWidget);
    expect(find.textContaining('Acknowledge'), findsOneWidget);
  });

  testWidgets('staff workload renders a staff row', (tester) async {
    tester.view.physicalSize = const Size(2000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const StaffWorkloadPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('u1'), findsOneWidget);
  });
}