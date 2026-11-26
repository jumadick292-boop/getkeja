// Tests for payment repository using a fake datasource.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:get_keja_mobile/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/domain/repositories/payment_repository.dart';

class FakeRemoteDataSource implements PaymentRemoteDataSource {
  @override
  Future<MpesaInitiateResponse> initiatePayment({
    required String invoiceId,
    required num amount,
    String? phoneNumber,
    String? idempotencyKey,
    String provider = 'mpesa',
    String? merchantReference,
  }) async {
    return MpesaInitiateResponse(
      success: true,
      data: PaymentInitiationData(
        status: 'pending',
        paymentTransactionId: 'txn_123',
        providerTransactionId: 'ws_CO_abc',
        amount: amount,
        provider: provider,
        message: 'STK push sent',
      ),
    );
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
    return MpesaPaymentStatusResponse(
      success: true,
      data: PaymentTransactionModel(
        id: 'txn_123',
        checkoutRequestId: providerTransactionId,
        status: 'completed',
        amount: 45000,
        currency: 'KES',
      ),
    );
  }

  @override
  Future<MpesaPaymentStatusResponse> getMpesaPaymentStatus(
    String checkoutRequestId,
  ) async {
    return getPaymentStatus(checkoutRequestId);
  }

  @override
  Future<ProvidersResponse> getProviders() async {
    return ProvidersResponse(
      success: true,
      providers: [
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
          accountReferenceLabel: 'Account Reference',
          accountReferencePlaceholder: 'Invoice number',
          description: 'Pay via Paybill',
        ),
      ],
    );
  }

  @override
  Future<InvoiceListResponse> listInvoices() async {
    return InvoiceListResponse(
      success: true,
      invoices: [
        InvoiceModel(
          id: 'inv_1',
          unitId: 'u1',
          invoiceNumber: 'INV-001',
          status: 'issued',
          totalAmount: 45000,
          currency: 'KES',
          dueDate: '2027-01-05',
          issuedAt: '2026-12-01T10:00:00Z',
          amountPaid: 0,
          amountOutstanding: 45000,
        ),
      ],
    );
  }

  @override
  Future<InvoiceDetailResponse> getInvoice(String invoiceId) async {
    return InvoiceDetailResponse(
      success: true,
      invoice: InvoiceModel(
        id: invoiceId,
        unitId: 'u1',
        invoiceNumber: 'INV-001',
        status: 'issued',
        totalAmount: 45000,
        currency: 'KES',
        dueDate: '2027-01-05',
        issuedAt: '2026-12-01T10:00:00Z',
      ),
    );
  }

  @override
  Future<PaymentHistoryResponse> listPayments() async {
    return PaymentHistoryResponse(
      success: true,
      payments: [
        PaymentHistoryModel(
          id: 'pay_1',
          invoiceId: 'inv_1',
          amount: 45000,
          currency: 'KES',
          paymentMethod: 'M-Pesa STK Push',
          paymentReference: 'MPL123456789',
          status: 'completed',
          paidAt: '2026-12-01T12:00:00Z',
          createdAt: '2026-12-01T12:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<TenantDashboardResponse> getTenantDashboard() async {
    return TenantDashboardResponse(
      success: true,
      dashboard: TenantDashboardModel(
        tenantId: 'tenant_1',
        activeTenancyId: 'tenancy_1',
        propertyName: 'Greenview Apartments',
        unitNumber: 'Unit 4B',
        outstandingBalance: 45000,
        invoiceCount: 1,
        currency: 'KES',
      ),
    );
  }

  @override
  Future<ReceiptListResponse> listReceipts({
    int limit = 20,
    int offset = 0,
  }) async {
    return ReceiptListResponse(
      success: true,
      receipts: [
        ReceiptModel(
          id: 'receipt_1',
          receiptNumber: 'RCP-2026-001',
          paymentTransactionId: 'txn_123',
          invoiceId: 'inv_1',
          amount: 45000,
          currency: 'KES',
          paymentMethod: 'M-Pesa STK Push',
          paymentDate: '2026-12-01T12:00:00Z',
          transactionReference: 'MPL123456789',
          outstandingBalanceAfter: 0,
          createdAt: '2026-12-01T12:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<ReceiptModel?> getReceipt(String receiptId) async {
    return ReceiptModel(
      id: receiptId,
      receiptNumber: 'RCP-2026-001',
      paymentTransactionId: 'txn_123',
      invoiceId: 'inv_1',
      amount: 45000,
      currency: 'KES',
      paymentMethod: 'M-Pesa STK Push',
      paymentDate: '2026-12-01T12:00:00Z',
      transactionReference: 'MPL123456789',
      outstandingBalanceAfter: 0,
      createdAt: '2026-12-01T12:00:00Z',
    );
  }

  @override
  Future<SignedReceiptUrl> downloadReceipt(String receiptId) async {
    return SignedReceiptUrl(
      success: true,
      url: 'https://cdn.getkeja.com/receipts/$receiptId.pdf?sig=abc',
      expiresInSeconds: 300,
    );
  }

  @override
  Future<StatementResponse> getStatement({
    String? fromDate,
    String? toDate,
  }) async {
    return StatementResponse(
      success: true,
      data: StatementModel(
        tenantId: 'tenant_1',
        tenancyId: 'tenancy_1',
        fromDate: '2026-11-01',
        toDate: '2026-11-30',
        openingBalance: 0,
        totalCharges: 45000,
        totalPaid: 45000,
        closingBalance: 0,
        currency: 'KES',
        charges: [],
        payments: [],
      ),
    );
  }

  @override
  Future<DepositListResponse> listDeposits() async {
    return DepositListResponse(
      success: true,
      deposits: [
        DepositModel(
          id: 'dep_1',
          expectedAmount: 50000,
          receivedAmount: 50000,
          outstandingAmount: 0,
          currency: 'KES',
          status: 'paid',
          createdAt: '2026-12-01T10:00:00Z',
          updatedAt: '2026-12-01T10:00:00Z',
        ),
      ],
      transactions: [
        DepositTransactionModel(
          id: 'tx_1',
          depositId: 'dep_1',
          transactionType: 'deposit',
          amount: 50000,
          currency: 'KES',
          transactionDate: '2026-12-01T10:00:00Z',
          reference: 'DEP-2026-001',
          createdAt: '2026-12-01T10:00:00Z',
        ),
      ],
    );
  }
}

void main() {
  late FakeRemoteDataSource fakeRemote;
  late PaymentRepository repository;

  setUp(() {
    fakeRemote = FakeRemoteDataSource();
    repository = PaymentRepositoryImpl(fakeRemote);
  });

  group('PaymentRepositoryImpl', () {
    test('initiatePayment returns pending status', () async {
      final result = await repository.initiatePayment(
        invoiceId: 'inv_123',
        amount: 45000,
        phoneNumber: '+254700000000',
        provider: 'mpesa',
      );

      expect(result.success, isTrue);
      expect(result.data.status, 'pending');
      expect(result.data.paymentTransactionId, 'txn_123');
      expect(result.data.providerTransactionId, 'ws_CO_abc');
      expect(result.data.amount, 45000);
      expect(result.data.provider, 'mpesa');
    });

    test('initiateMpesaPayment delegates to initiatePayment', () async {
      final result = await repository.initiateMpesaPayment(
        invoiceId: 'inv_123',
        amount: 45000,
        phoneNumber: '+254700000000',
      );

      expect(result.success, isTrue);
      expect(result.data.provider, 'mpesa');
    });

    test('getProviders returns all configured providers', () async {
      final result = await repository.getProviders();

      expect(result.success, isTrue);
      expect(result.providers, hasLength(2));
      expect(result.providers[0].isStkPush, isTrue);
      expect(result.providers[1].isManual, isTrue);
      expect(result.providers[1].businessShortCode, '123456');
    });

    test('getPaymentStatus returns completed status', () async {
      final result = await repository.getPaymentStatus('txn_123');

      expect(result.success, isTrue);
      expect(result.data.status, 'completed');
      expect(result.data.isCompleted, isTrue);
    });

    test('listInvoices returns payable invoices', () async {
      final result = await repository.listInvoices();

      expect(result.success, isTrue);
      expect(result.invoices, hasLength(1));
      expect(result.invoices[0].isPayable, isTrue);
      expect(result.invoices[0].outstanding, 45000);
    });

    test('getInvoice returns invoice detail', () async {
      final result = await repository.getInvoice('inv_123');

      expect(result.success, isTrue);
      expect(result.invoice.id, 'inv_123');
      expect(result.invoice.invoiceNumber, 'INV-001');
    });

    test('listPayments returns payment history', () async {
      final result = await repository.listPayments();

      expect(result.success, isTrue);
      expect(result.payments, hasLength(1));
      expect(result.payments[0].status, 'completed');
    });

    test('getTenantDashboard returns dashboard data', () async {
      final result = await repository.getTenantDashboard();

      expect(result.success, isTrue);
      expect(result.dashboard.outstandingBalance, 45000);
      expect(result.dashboard.invoiceCount, 1);
      expect(result.dashboard.hasOutstandingBalance, isTrue);
    });

    test('listReceipts returns receipts', () async {
      final result = await repository.listReceipts();

      expect(result.success, isTrue);
      expect(result.receipts, hasLength(1));
      expect(result.receipts[0].receiptNumber, 'RCP-2026-001');
    });

    test('getReceipt returns a single receipt', () async {
      final result = await repository.getReceipt('receipt_123');

      expect(result, isNotNull);
      expect(result!.id, 'receipt_123');
    });

    test('downloadReceipt returns signed URL', () async {
      final result = await repository.downloadReceipt('receipt_123');

      expect(result.success, isTrue);
      expect(result.url, contains('receipt_123'));
      expect(result.expiresInSeconds, 300);
    });

    test('getStatement returns statement data', () async {
      final result = await repository.getStatement();

      expect(result.success, isTrue);
      expect(result.data.closingBalance, 0);
      expect(result.data.netBalance, 0);
    });

    test('listDeposits returns deposits and transactions', () async {
      final result = await repository.listDeposits();

      expect(result.success, isTrue);
      expect(result.deposits, hasLength(1));
      expect(result.deposits[0].isFullyPaid, isTrue);
      expect(result.transactions, hasLength(1));
    });
  });
}
