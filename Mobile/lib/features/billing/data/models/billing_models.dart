// Recurring billing models (Task 14.1) — landlord-facing.
// Mirrors the JSON returned by /api/v1/rms/billing.

class BillingScheduleModel {
  BillingScheduleModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.tenancyId,
    required this.tenantId,
    required this.rentAmount,
    required this.currency,
    required this.billingFrequency,
    required this.billingDay,
    required this.firstBillingDate,
    required this.nextBillingDate,
    required this.status,
    this.dueDayOfMonth,
    this.gracePeriodDays = 0,
  });

  final String id;
  final String propertyId;
  final String unitId;
  final String tenancyId;
  final String tenantId;
  final num rentAmount;
  final String currency;
  final String billingFrequency;
  final int billingDay;
  final String firstBillingDate;
  final String nextBillingDate;
  final String status;
  final int? dueDayOfMonth;
  final int gracePeriodDays;

  bool get isActive => status == 'active';

  factory BillingScheduleModel.fromJson(Map<String, dynamic> json) {
    return BillingScheduleModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String,
      tenancyId: json['tenancyId'] as String,
      tenantId: json['tenantId'] as String,
      rentAmount: json['rentAmount'] as num,
      currency: json['currency'] as String? ?? 'KES',
      billingFrequency: json['billingFrequency'] as String? ?? 'monthly',
      billingDay: (json['billingDay'] as num?)?.toInt() ?? 1,
      firstBillingDate: json['firstBillingDate'] as String,
      nextBillingDate: json['nextBillingDate'] as String,
      status: json['status'] as String,
      dueDayOfMonth: (json['dueDayOfMonth'] as num?)?.toInt(),
      gracePeriodDays: (json['gracePeriodDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class RentTermModel {
  RentTermModel({
    required this.id,
    required this.rentAmount,
    required this.currency,
    required this.effectiveDate,
    this.notes,
  });

  final String id;
  final num rentAmount;
  final String currency;
  final String effectiveDate;
  final String? notes;

  factory RentTermModel.fromJson(Map<String, dynamic> json) {
    return RentTermModel(
      id: json['id'] as String,
      rentAmount: json['rentAmount'] as num,
      currency: json['currency'] as String? ?? 'KES',
      effectiveDate: json['effectiveDate'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class BillingInvoiceModel {
  BillingInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    required this.amountOutstanding,
    this.amountPaid,
    this.source,
  });

  final String id;
  final String invoiceNumber;
  final String status;
  final num totalAmount;
  final String currency;
  final String billingPeriodStart;
  final String billingPeriodEnd;
  final String dueDate;
  final num amountOutstanding;
  final num? amountPaid;
  final String? source;

  bool get isVoid => status == 'void';
  bool get isPaid => status == 'paid';

  factory BillingInvoiceModel.fromJson(Map<String, dynamic> json) {
    return BillingInvoiceModel(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      status: json['status'] as String,
      totalAmount: json['totalAmount'] as num,
      currency: json['currency'] as String? ?? 'KES',
      billingPeriodStart: json['billingPeriodStart'] as String,
      billingPeriodEnd: json['billingPeriodEnd'] as String,
      dueDate: json['dueDate'] as String,
      amountOutstanding: (json['amountOutstanding'] as num?) ?? 0,
      amountPaid: json['amountPaid'] as num?,
      source: json['source'] as String?,
    );
  }
}

class InvoicePreviewModel {
  InvoicePreviewModel({
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    required this.proratedAmount,
    required this.currency,
    required this.fullPeriod,
    required this.invoiceNumber,
  });

  final String billingPeriodStart;
  final String billingPeriodEnd;
  final String dueDate;
  final num proratedAmount;
  final String currency;
  final bool fullPeriod;
  final String invoiceNumber;

  factory InvoicePreviewModel.fromJson(Map<String, dynamic> json) {
    return InvoicePreviewModel(
      billingPeriodStart: json['billingPeriodStart'] as String,
      billingPeriodEnd: json['billingPeriodEnd'] as String,
      dueDate: json['dueDate'] as String,
      proratedAmount: (json['proratedAmount'] as num?) ?? 0,
      currency: json['currency'] as String? ?? 'KES',
      fullPeriod: json['fullPeriod'] as bool? ?? true,
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
    );
  }
}