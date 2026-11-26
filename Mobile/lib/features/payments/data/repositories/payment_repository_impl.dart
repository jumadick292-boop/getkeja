// Payment repository implementation.
// Delegates to the remote datasource and maps errors to domain exceptions.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._remote);

  final PaymentRemoteDataSource _remote;

  @override
  Future<MpesaInitiateResponse> initiatePayment({
    required String invoiceId,
    required num amount,
    String? phoneNumber,
    String? idempotencyKey,
    String provider = 'mpesa',
    String? merchantReference,
  }) async {
    try {
      return await _remote.initiatePayment(
        invoiceId: invoiceId,
        amount: amount,
        phoneNumber: phoneNumber,
        idempotencyKey: idempotencyKey,
        provider: provider,
        merchantReference: merchantReference,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to initiate payment.',
        originalError: error,
      );
    }
  }

  @override
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

  @override
  Future<MpesaPaymentStatusResponse> getPaymentStatus(
    String providerTransactionId,
  ) async {
    try {
      return await _remote.getPaymentStatus(providerTransactionId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load payment status.',
        originalError: error,
      );
    }
  }

  @override
  Future<MpesaPaymentStatusResponse> getMpesaPaymentStatus(
    String checkoutRequestId,
  ) async {
    return getPaymentStatus(checkoutRequestId);
  }

  @override
  Future<ProvidersResponse> getProviders() async {
    try {
      return await _remote.getProviders();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load payment providers.',
        originalError: error,
      );
    }
  }

  @override
  Future<InvoiceListResponse> listInvoices() async {
    try {
      return await _remote.listInvoices();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load invoices.',
        originalError: error,
      );
    }
  }

  @override
  Future<InvoiceDetailResponse> getInvoice(String invoiceId) async {
    try {
      return await _remote.getInvoice(invoiceId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load invoice details.',
        originalError: error,
      );
    }
  }

  @override
  Future<PaymentHistoryResponse> listPayments() async {
    try {
      return await _remote.listPayments();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load payment history.',
        originalError: error,
      );
    }
  }

  @override
  Future<TenantDashboardResponse> getTenantDashboard() async {
    try {
      return await _remote.getTenantDashboard();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load financial dashboard.',
        originalError: error,
      );
    }
  }

  @override
  Future<ReceiptListResponse> listReceipts({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _remote.listReceipts(limit: limit, offset: offset);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load receipts.',
        originalError: error,
      );
    }
  }

  @override
  Future<ReceiptModel?> getReceipt(String receiptId) async {
    try {
      return await _remote.getReceipt(receiptId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load receipt.',
        originalError: error,
      );
    }
  }

  @override
  Future<SignedReceiptUrl> downloadReceipt(String receiptId) async {
    try {
      return await _remote.downloadReceipt(receiptId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to get receipt download URL.',
        originalError: error,
      );
    }
  }

  @override
  Future<StatementResponse> getStatement({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      return await _remote.getStatement(fromDate: fromDate, toDate: toDate);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load statement.',
        originalError: error,
      );
    }
  }

  @override
  Future<DepositListResponse> listDeposits() async {
    try {
      return await _remote.listDeposits();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load deposits.',
        originalError: error,
      );
    }
  }
}
