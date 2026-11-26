// Tests for recurring billing models (Task 14.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/billing/data/models/billing_models.dart';

void main() {
  group('BillingScheduleModel', () {
    test('fromJson parses all fields and defaults', () {
      final model = BillingScheduleModel.fromJson(<String, dynamic>{
        'id': 'sched_1',
        'propertyId': 'prop_1',
        'unitId': 'unit_1',
        'tenancyId': 'ten_1',
        'tenantId': 't_1',
        'rentAmount': 15000,
        'currency': 'KES',
        'billingFrequency': 'monthly',
        'billingDay': 1,
        'firstBillingDate': '2026-01-01',
        'nextBillingDate': '2026-02-01',
        'status': 'active',
        'dueDayOfMonth': 5,
        'gracePeriodDays': 3,
      });

      expect(model.id, 'sched_1');
      expect(model.rentAmount, 15000);
      expect(model.billingFrequency, 'monthly');
      expect(model.status, 'active');
      expect(model.isActive, isTrue);
      expect(model.dueDayOfMonth, 5);
      expect(model.gracePeriodDays, 3);
    });

    test('fromJson tolerates missing optional fields', () {
      final model = BillingScheduleModel.fromJson(<String, dynamic>{
        'id': 'sched_2',
        'propertyId': 'p',
        'unitId': 'u',
        'tenancyId': 'ten',
        'tenantId': 't',
        'rentAmount': 1,
        'firstBillingDate': '2026-01-01',
        'nextBillingDate': '2026-02-01',
        'status': 'pending',
      });

      expect(model.currency, 'KES');
      expect(model.billingDay, 1);
      expect(model.gracePeriodDays, 0);
      expect(model.isActive, isFalse);
    });
  });

  group('BillingInvoiceModel', () {
    test('fromJson parses invoice and computes flags', () {
      final model = BillingInvoiceModel.fromJson(<String, dynamic>{
        'id': 'inv_1',
        'invoiceNumber': 'INV-202601-ABCD1234',
        'status': 'issued',
        'totalAmount': 15000,
        'currency': 'KES',
        'billingPeriodStart': '2026-01-01',
        'billingPeriodEnd': '2026-01-31',
        'dueDate': '2026-01-01',
        'amountOutstanding': 15000,
        'amountPaid': 0,
        'source': 'recurring',
      });

      expect(model.invoiceNumber, 'INV-202601-ABCD1234');
      expect(model.source, 'recurring');
      expect(model.isPaid, isFalse);
      expect(model.isVoid, isFalse);
      expect(model.amountOutstanding, 15000);
    });
  });

  group('InvoicePreviewModel', () {
    test('fromJson parses prorated preview', () {
      final preview = InvoicePreviewModel.fromJson(<String, dynamic>{
        'billingPeriodStart': '2026-01-01',
        'billingPeriodEnd': '2026-01-31',
        'dueDate': '2026-01-01',
        'proratedAmount': 8000,
        'currency': 'KES',
        'fullPeriod': false,
        'invoiceNumber': 'INV-202601-ABCD1234',
      });

      expect(preview.proratedAmount, 8000);
      expect(preview.fullPeriod, isFalse);
    });
  });
}