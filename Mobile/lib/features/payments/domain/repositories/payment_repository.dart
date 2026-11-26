// Payment repository interface.
// Defines the contract for fetching and managing tenant payment data.
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';

abstract class PaymentRepository {
  /// Initiate a payment for an invoice through any configured provider.
  Future<MpesaInitiateResponse> initiatePayment({
    required String invoiceId,
    required num amount,
    String? phoneNumber,
    String? idempotencyKey,
    String provider,
    String? merchantReference,
  });

  /// Backward-compatible alias: M-Pesa STK Push initiation.
  Future<MpesaInitiateResponse> initiateMpesaPayment({
    required String invoiceId,
    required num amount,
    required String phoneNumber,
    String? idempotencyKey,
  });

  /// Get the status of a payment initiation (safe to poll).
  Future<MpesaPaymentStatusResponse> getPaymentStatus(
    String providerTransactionId,
  );

  /// Backward-compatible alias: M-Pesa status polling.
  Future<MpesaPaymentStatusResponse> getMpesaPaymentStatus(
    String checkoutRequestId,
  );

  /// Return the list of configured payment providers for the tenant UI.
  Future<ProvidersResponse> getProviders();

  /// List tenant invoices.
  Future<InvoiceListResponse> listInvoices();

  /// Get a single invoice with line items.
  Future<InvoiceDetailResponse> getInvoice(String invoiceId);

  /// List tenant payment history.
  Future<PaymentHistoryResponse> listPayments();

  /// Get tenant financial dashboard summary.
  Future<TenantDashboardResponse> getTenantDashboard();

  /// List receipts for the authenticated tenant.
  Future<ReceiptListResponse> listReceipts({
    int limit = 20,
    int offset = 0,
  });

  /// Get a single receipt by ID.
  Future<ReceiptModel?> getReceipt(String receiptId);

  /// Get a signed download URL for a receipt.
  Future<SignedReceiptUrl> downloadReceipt(String receiptId);

  /// Get tenant statement (charges, payments, balances).
  Future<StatementResponse> getStatement({
    String? fromDate,
    String? toDate,
  });

  /// Get tenant deposits and transaction history.
  Future<DepositListResponse> listDeposits();
}
