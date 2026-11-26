// Widget tests for payment method selection page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/app/theme/app_theme.dart';
import 'package:get_keja_mobile/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:get_keja_mobile/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/domain/repositories/payment_repository.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/payment_method_selection_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class FakeRemoteDataSource implements PaymentRemoteDataSource {
  FakeRemoteDataSource({this.providers});

  final List<PaymentProviderModel>? providers;

  @override
  Future<MpesaInitiateResponse> initiatePayment({
    required String invoiceId,
    required num amount,
    String? phoneNumber,
    String? idempotencyKey,
    String provider = 'mpesa',
    String? merchantReference,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MpesaInitiateResponse> initiateMpesaPayment({
    required String invoiceId,
    required num amount,
    required String phoneNumber,
    String? idempotencyKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MpesaPaymentStatusResponse> getPaymentStatus(
    String providerTransactionId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<MpesaPaymentStatusResponse> getMpesaPaymentStatus(
    String checkoutRequestId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ProvidersResponse> getProviders() async {
    return ProvidersResponse(
      success: true,
      providers: providers ?? [
        PaymentProviderModel(
          id: 'mpesa',
          name: 'M-Pesa STK Push',
          type: 'stk_push',
          displayName: 'M-Pesa STK Push',
          requiresPhoneNumber: true,
          description: 'Pay via STK Push',
        ),
        PaymentProviderModel(
          id: 'mpesa_paybill',
          name: 'M-Pesa Paybill',
          type: 'manual',
          displayName: 'M-Pesa Paybill',
          requiresPhoneNumber: false,
          businessShortCode: '123456',
          description: 'Pay via Paybill',
        ),
      ],
    );
  }

  @override
  Future<InvoiceListResponse> listInvoices() async {
    throw UnimplementedError();
  }

  @override
  Future<InvoiceDetailResponse> getInvoice(String invoiceId) async {
    throw UnimplementedError();
  }

  @override
  Future<PaymentHistoryResponse> listPayments() async {
    throw UnimplementedError();
  }

  @override
  Future<TenantDashboardResponse> getTenantDashboard() async {
    throw UnimplementedError();
  }

  @override
  Future<ReceiptListResponse> listReceipts({
    int limit = 20,
    int offset = 0,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ReceiptModel?> getReceipt(String receiptId) async {
    throw UnimplementedError();
  }

  @override
  Future<SignedReceiptUrl> downloadReceipt(String receiptId) async {
    throw UnimplementedError();
  }

  @override
  Future<StatementResponse> getStatement({
    String? fromDate,
    String? toDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DepositListResponse> listDeposits() async {
    throw UnimplementedError();
  }
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders payment method selection page with providers',
      (tester) async {
    final fakeRemote = FakeRemoteDataSource();
    final repo = PaymentRepositoryImpl(fakeRemote);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
        ],
        child: _testApp(const PaymentMethodSelectionPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('M-Pesa STK Push'), findsOneWidget);
    expect(find.text('M-Pesa Paybill'), findsOneWidget);
  });

  testWidgets('shows business number for manual providers', (tester) async {
    final fakeRemote = FakeRemoteDataSource();
    final repo = PaymentRepositoryImpl(fakeRemote);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
        ],
        child: _testApp(const PaymentMethodSelectionPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('123456'), findsNWidgets(2));
  });

  testWidgets('shows empty state when no providers', (tester) async {
    final fakeRemote = FakeRemoteDataSource(providers: []);
    final repo = PaymentRepositoryImpl(fakeRemote);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
        ],
        child: _testApp(const PaymentMethodSelectionPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No payment methods available'), findsOneWidget);
  });
}
