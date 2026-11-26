import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/marketplace/data/datasources/marketplace_remote_datasource.dart';
import 'package:get_keja_mobile/features/marketplace/data/repositories/marketplace_repository_impl.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/pages/marketplace_browse_page.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/pages/marketplace_requests_page.dart';

class _FakeMarketplaceRepository extends MarketplaceRepository {
  _FakeMarketplaceRepository()
      : super(MarketplaceRemoteDataSource(Dio()));

  final List<Map<String, dynamic>> categories = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'clean_home', 'domain': 'cleaning', 'name': 'Home cleaning', 'description': 'Routine cleaning'},
    <String, dynamic>{'id': 'plumbing_general', 'domain': 'plumbing', 'name': 'Plumbing', 'description': 'Repairs'},
  ];

  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'req-1', 'title': 'Deep clean', 'categoryName': 'Home cleaning', 'status': 'quoted'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getCategories({String? domain}) async => categories;

  @override
  Future<Map<String, dynamic>> listRequests({String? status, int limit = 20, int offset = 0}) async =>
      <String, dynamic>{'rows': requests, 'total': requests.length};

  @override
  Future<Map<String, dynamic>> getRequest(String requestId) async =>
      <String, dynamic>{'id': requestId, 'status': 'quoted', 'description': 'desc', 'quotations': <dynamic>[]};
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [marketplaceRepositoryProvider.overrideWithValue(_FakeMarketplaceRepository())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('browse lists service categories', (tester) async {
    await tester.pumpWidget(_app(const MarketplaceBrowsePage()));
    await tester.pumpAndSettle();
    expect(find.text('Home cleaning'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
  });

  testWidgets('requests list shows customer requests with status', (tester) async {
    await tester.pumpWidget(_app(const MarketplaceRequestsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Deep clean'), findsOneWidget);
    expect(find.text('QUOTED'), findsOneWidget);
  });
}