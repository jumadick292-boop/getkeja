// Payment state management.
// Provides Riverpod providers for fetching and managing tenant payment data.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:get_keja_mobile/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/domain/repositories/payment_repository.dart';

final paymentRemoteDataSourceProvider =
    Provider<PaymentRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentRemoteDataSource(apiClient.dio);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(
    ref.watch(paymentRemoteDataSourceProvider),
  );
});

/// FutureProvider for receipts list.
final receiptsProvider = FutureProvider<List<ReceiptModel>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  final result = await repo.listReceipts();
  return result.receipts;
});

/// FutureProvider for invoices list.
final invoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  final result = await repo.listInvoices();
  return result.invoices;
});

/// FutureProvider for payment history.
final paymentHistoryProvider = FutureProvider<List<PaymentHistoryModel>>(
  (ref) async {
    final repo = ref.watch(paymentRepositoryProvider);
    final result = await repo.listPayments();
    return result.payments;
  },
);

/// FutureProvider for available payment providers.
final paymentProvidersProvider = FutureProvider<List<PaymentProviderModel>>(
  (ref) async {
    final repo = ref.watch(paymentRepositoryProvider);
    final result = await repo.getProviders();
    return result.providers;
  },
);

/// FutureProvider for tenant dashboard.
final tenantDashboardProvider =
    FutureProvider<TenantDashboardResponse>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getTenantDashboard();
});

/// FutureProvider for invoice detail.
final invoiceDetailProvider =
    FutureProvider.family<InvoiceDetailResponse, String>((ref, invoiceId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getInvoice(invoiceId);
});

/// FutureProvider for payment status.
final paymentStatusProvider =
    FutureProvider.family<MpesaPaymentStatusResponse, String>(
      (ref, providerTransactionId) async {
    final repo = ref.watch(paymentRepositoryProvider);
    return repo.getPaymentStatus(providerTransactionId);
  },
);

/// FutureProvider for statement.
final statementProvider = FutureProvider<StatementResponse>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getStatement();
});

/// FutureProvider for deposits.
final depositsProvider = FutureProvider<DepositListResponse>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.listDeposits();
});
