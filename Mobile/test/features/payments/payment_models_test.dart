// Tests for payment models.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';

void main() {
  group('PaymentTransactionModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'txn_123',
        'checkoutRequestId': 'ws_CO_abc123',
        'status': 'completed',
        'amount': 45000,
        'currency': 'KES',
        'transactionReference': 'MPL123456789',
        'providerReceipt': 'MPL123456789',
        'failureReason': null,
        'createdAt': '2026-12-01T12:00:00Z',
        'updatedAt': '2026-12-01T12:05:00Z',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.id, 'txn_123');
      expect(model.checkoutRequestId, 'ws_CO_abc123');
      expect(model.status, 'completed');
      expect(model.amount, 45000);
      expect(model.currency, 'KES');
      expect(model.transactionReference, 'MPL123456789');
      expect(model.providerReceipt, 'MPL123456789');
      expect(model.isCompleted, isTrue);
      expect(model.isPending, isFalse);
      expect(model.isFailed, isFalse);
      expect(model.statusLabel, 'Completed');
    });

    test('statusLabel returns correct labels', () {
      expect(PaymentTransactionModel(
        id: '1', checkoutRequestId: '', status: 'pending', amount: 0,
        currency: 'KES',
      ).statusLabel, 'Pending');
      expect(PaymentTransactionModel(
        id: '1', checkoutRequestId: '', status: 'processing', amount: 0,
        currency: 'KES',
      ).statusLabel, 'Processing');
      expect(PaymentTransactionModel(
        id: '1', checkoutRequestId: '', status: 'failed', amount: 0,
        currency: 'KES',
      ).statusLabel, 'Failed');
      expect(PaymentTransactionModel(
        id: '1', checkoutRequestId: '', status: 'reversed', amount: 0,
        currency: 'KES',
      ).statusLabel, 'Reversed');
    });
  });

  group('InvoiceModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'inv_123',
        'unitId': 'unit_456',
        'invoiceNumber': 'INV-2026-001',
        'status': 'issued',
        'totalAmount': 45000,
        'currency': 'KES',
        'dueDate': '2027-01-05',
        'issuedAt': '2026-12-01T10:00:00Z',
        'description': 'December rent',
        'amountPaid': 0,
        'amountOutstanding': 45000,
      };

      final model = InvoiceModel.fromJson(json);

      expect(model.id, 'inv_123');
      expect(model.invoiceNumber, 'INV-2026-001');
      expect(model.status, 'issued');
      expect(model.totalAmount, 45000);
      expect(model.currency, 'KES');
      expect(model.outstanding, 45000);
      expect(model.paid, 0);
      expect(model.isPayable, isTrue);
      expect(model.isFullyPaid, isFalse);
      expect(model.isCancelled, isFalse);
    });

    test('isPayable is false for paid invoices', () {
      final model = InvoiceModel(
        id: '1', unitId: 'u1', invoiceNumber: 'INV-1', status: 'paid',
        totalAmount: 1000, currency: 'KES', dueDate: '2027-01-01',
        issuedAt: '2026-12-01T10:00:00Z', amountPaid: 1000, amountOutstanding: 0,
      );
      expect(model.isPayable, isFalse);
      expect(model.isFullyPaid, isTrue);
    });

    test('isPayable is false for cancelled invoices', () {
      final model = InvoiceModel(
        id: '1', unitId: 'u1', invoiceNumber: 'INV-1', status: 'cancelled',
        totalAmount: 1000, currency: 'KES', dueDate: '2027-01-01',
        issuedAt: '2026-12-01T10:00:00Z',
      );
      expect(model.isPayable, isFalse);
    });
  });

  group('PaymentProviderModel', () {
    test('fromJson parses STK push provider correctly', () {
      final json = {
        'id': 'mpesa',
        'name': 'M-Pesa STK Push',
        'type': 'stk_push',
        'displayName': 'M-Pesa STK Push',
        'requiresPhoneNumber': true,
        'description': 'Pay directly from your M-Pesa phone',
      };

      final model = PaymentProviderModel.fromJson(json);

      expect(model.id, 'mpesa');
      expect(model.isStkPush, isTrue);
      expect(model.isManual, isFalse);
      expect(model.isHostedCheckout, isFalse);
      expect(model.requiresPhoneNumber, isTrue);
    });

    test('fromJson parses manual provider correctly', () {
      final json = {
        'id': 'mpesa_paybill',
        'name': 'M-Pesa Paybill',
        'type': 'manual',
        'displayName': 'M-Pesa Paybill',
        'requiresPhoneNumber': false,
        'businessShortCode': '123456',
        'accountReferenceLabel': 'Account Reference',
        'accountReferencePlaceholder': 'Invoice number',
        'description': 'Pay via M-Pesa Paybill',
      };

      final model = PaymentProviderModel.fromJson(json);

      expect(model.id, 'mpesa_paybill');
      expect(model.isManual, isTrue);
      expect(model.businessShortCode, '123456');
    });

    test('fromJson parses hosted checkout provider correctly', () {
      final json = {
        'id': 'pesapal',
        'name': 'Pesapal',
        'type': 'hosted_checkout',
        'displayName': 'Pesapal',
        'requiresPhoneNumber': false,
        'description': 'Pay via Pesapal hosted checkout',
      };

      final model = PaymentProviderModel.fromJson(json);

      expect(model.id, 'pesapal');
      expect(model.isHostedCheckout, isTrue);
    });
  });

  group('ReceiptModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'receipt_123',
        'receiptNumber': 'RCP-2026-001',
        'paymentTransactionId': 'txn_123',
        'invoiceId': 'inv_123',
        'amount': 45000,
        'currency': 'KES',
        'paymentMethod': 'M-Pesa STK Push',
        'paymentDate': '2026-12-01T12:00:00Z',
        'transactionReference': 'MPL123456789',
        'outstandingBalanceAfter': 0,
        'createdAt': '2026-12-01T12:00:00Z',
      };

      final model = ReceiptModel.fromJson(json);

      expect(model.id, 'receipt_123');
      expect(model.receiptNumber, 'RCP-2026-001');
      expect(model.amount, 45000);
      expect(model.currency, 'KES');
      expect(model.outstandingBalanceAfter, 0);
    });
  });

  group('DepositModel', () {
    test('isFullyPaid is true when outstanding is 0', () {
      final model = DepositModel(
        id: 'dep_1', expectedAmount: 50000, receivedAmount: 50000,
        outstandingAmount: 0, currency: 'KES', status: 'paid',
        createdAt: '2026-12-01T10:00:00Z', updatedAt: '2026-12-01T10:00:00Z',
      );
      expect(model.isFullyPaid, isTrue);
    });

    test('isFullyPaid is false when outstanding > 0', () {
      final model = DepositModel(
        id: 'dep_1', expectedAmount: 50000, receivedAmount: 30000,
        outstandingAmount: 20000, currency: 'KES', status: 'partial',
        createdAt: '2026-12-01T10:00:00Z', updatedAt: '2026-12-01T10:00:00Z',
      );
      expect(model.isFullyPaid, isFalse);
    });
  });
}
