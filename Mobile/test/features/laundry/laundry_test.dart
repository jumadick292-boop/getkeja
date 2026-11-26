import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/laundry/data/datasources/laundry_remote_datasource.dart';
import 'package:get_keja_mobile/features/laundry/data/repositories/laundry_repository_impl.dart';
import 'package:get_keja_mobile/features/laundry/presentation/state/laundry_state.dart';
import 'package:get_keja_mobile/features/laundry/presentation/pages/laundry_orders_page.dart';
import 'package:get_keja_mobile/features/laundry/presentation/pages/provider_laundry_orders_page.dart';

class _FakeLaundryRepository extends LaundryRepository {
  _FakeLaundryRepository() : super(LaundryRemoteDataSource(Dio()));

  final List<Map<String, dynamic>> customerOrders = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'ord-1', 'status': 'processing', 'collectionDate': '2026-12-10'},
  ];
  final List<Map<String, dynamic>> providerOrders = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'ord-2', 'status': 'confirmed', 'collectionDate': '2026-12-11'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listCustomerOrders({String? status}) async => customerOrders;

  @override
  Future<List<Map<String, dynamic>>> listProviderOrders({String? status}) async => providerOrders;

  @override
  Future<Map<String, dynamic>> getCustomerOrder(String orderId) async => <String, dynamic>{
        'id': orderId,
        'status': 'awaiting_customer_confirmation',
        'collectionDate': '2026-12-10',
        'items': <dynamic>[],
      };

  @override
  Future<Map<String, dynamic>> getProviderOrder(String orderId) async => <String, dynamic>{
        'id': orderId,
        'status': 'confirmed',
        'canViewLocations': true,
        'collectionAddress': 'Home',
        'items': <dynamic>[],
      };
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [laundryRepositoryProvider.overrideWithValue(_FakeLaundryRepository())],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('customer laundry orders list renders status', (tester) async {
    await tester.pumpWidget(_app(const LaundryOrdersPage()));
    await tester.pumpAndSettle();
    expect(find.text('PROCESSING'), findsOneWidget);
  });

  testWidgets('provider laundry orders list renders status', (tester) async {
    await tester.pumpWidget(_app(const ProviderLaundryOrdersPage()));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRMED'), findsOneWidget);
  });
}