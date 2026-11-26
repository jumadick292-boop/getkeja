// Payment remote data source.
// Calls the /api/v1/payments and /api/v1/tenant endpoints via Dio.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';

class PaymentRemoteDataSource {
  PaymentRemoteDataSource(this._dio);

  final Dio _dio;

  /// Initiate a payment for an invoice through any configured provider.
  Future<MpesaInitiateResponse> initiatePayment({
    required String invoiceId,
    required num amount,
    String? phoneNumber,
    String? idempotencyKey,
    String provider = 'mpesa',
    String? merchantReference,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/payments/initiate',
      data: MpesaInitiateRequest(
        invoiceId: invoiceId,
        amount: amount,
        phoneNumber: phoneNumber,
        idempotencyKey: idempotencyKey,
        provider: provider,
        merchantReference: merchantReference,
      ).toJson(),
    );
    return MpesaInitiateResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Backward-compatible alias: M-Pesa STK Push initiation.
  Future<MpesaInitiateResponse> initiateMpesaPayment({
    required String invoiceId,
    required num amount,
    required String phoneNumber,
    String? idempotencyKey,
  }) async {
    return initiatePayment(
      invoiceId: invoiceId,
      amount: amount,
      phoneNumber: phoneNumber,
      idempotencyKey: idempotencyKey,
      provider: 'mpesa',
    );
  }

  /// Get the status of a payment initiation (safe to poll).
  Future<MpesaPaymentStatusResponse> getPaymentStatus(
    String providerTransactionId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/status/$providerTransactionId',
    );
    return MpesaPaymentStatusResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Backward-compatible alias: M-Pesa status polling.
  Future<MpesaPaymentStatusResponse> getMpesaPaymentStatus(
    String checkoutRequestId,
  ) async {
    return getPaymentStatus(checkoutRequestId);
  }

  /// Return the list of configured payment providers for the tenant UI.
  Future<ProvidersResponse> getProviders() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/providers',
    );
    return ProvidersResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// List tenant invoices.
  Future<InvoiceListResponse> listInvoices() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/tenant/invoices',
    );
    return InvoiceListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get a single invoice with line items.
  Future<InvoiceDetailResponse> getInvoice(String invoiceId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/tenant/invoices/$invoiceId',
    );
    return InvoiceDetailResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// List tenant payment history.
  Future<PaymentHistoryResponse> listPayments() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/tenant/payments',
    );
    return PaymentHistoryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get tenant financial dashboard summary.
  Future<TenantDashboardResponse> getTenantDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/tenant/dashboard',
    );
    return TenantDashboardResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// List receipts.
  Future<ReceiptListResponse> listReceipts({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/receipts',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ReceiptListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get a single receipt by ID.
  Future<ReceiptModel?> getReceipt(String receiptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/receipts/$receiptId',
    );
    final data = response.data as Map<String, dynamic>;
    final receiptData = data['data'];
    if (receiptData is! Map<String, dynamic>) return null;
    return ReceiptModel.fromJson(receiptData);
  }

  /// Get a signed download URL for a receipt.
  Future<SignedReceiptUrl> downloadReceipt(String receiptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/receipts/$receiptId/download',
    );
    return SignedReceiptUrl.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get tenant financial statement.
  Future<StatementResponse> getStatement({
    String? fromDate,
    String? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/statement',
      queryParameters: {
        if (fromDate != null) 'fromDate': fromDate,
        if (toDate != null) 'toDate': toDate,
      }..removeWhere((_, v) => v == null),
    );
    return StatementResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// List tenant deposits and deposit transactions.
  Future<DepositListResponse> listDeposits() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/payments/deposits',
    );
    return DepositListResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
