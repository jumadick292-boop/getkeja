// Payment models for the GetKeja mobile app.
// Represents financial data returned by the /api/v1/payments and
// /api/v1/tenant APIs.

class PaymentTransactionModel {
  PaymentTransactionModel({
    required this.id,
    required this.checkoutRequestId,
    required this.status,
    required this.amount,
    required this.currency,
    this.transactionReference,
    this.providerReceipt,
    this.failureReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? checkoutRequestId;
  final String status;
  final num amount;
  final String currency;
  final String? transactionReference;
  final String? providerReceipt;
  final String? failureReason;
  final String? createdAt;
  final String? updatedAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'reversed':
        return 'Reversed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] as String,
      checkoutRequestId: json['checkoutRequestId'] as String?,
      status: json['status'] as String,
      amount: json['amount'] as num,
      currency: json['currency'] as String,
      transactionReference: json['transactionReference'] as String?,
      providerReceipt: json['providerReceipt'] as String?,
      failureReason: json['failureReason'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'checkoutRequestId': checkoutRequestId,
      'status': status,
      'amount': amount,
      'currency': currency,
      if (transactionReference != null) 'transactionReference': transactionReference,
      if (providerReceipt != null) 'providerReceipt': providerReceipt,
      if (failureReason != null) 'failureReason': failureReason,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class InvoiceItemModel {
  InvoiceItemModel({
    required this.id,
    required this.chargeType,
    required this.description,
    required this.amount,
    required this.currency,
    this.billingPeriodStart,
    this.billingPeriodEnd,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
  });

  final String id;
  final String chargeType;
  final String description;
  final num amount;
  final String currency;
  final String? billingPeriodStart;
  final String? billingPeriodEnd;
  final num quantity;
  final num unitPrice;
  final String createdAt;

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id'] as String,
      chargeType: json['chargeType'] as String,
      description: json['description'] as String,
      amount: json['amount'] as num,
      currency: json['currency'] as String,
      billingPeriodStart: json['billingPeriodStart'] as String?,
      billingPeriodEnd: json['billingPeriodEnd'] as String?,
      quantity: json['quantity'] as num,
      unitPrice: json['unitPrice'] as num,
      createdAt: json['createdAt'] as String,
    );
  }
}

class InvoiceModel {
  InvoiceModel({
    required this.id,
    required this.unitId,
    required this.invoiceNumber,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.dueDate,
    required this.issuedAt,
    this.description,
    this.lineItems,
    this.amountPaid,
    this.amountOutstanding,
  });

  final String id;
  final String unitId;
  final String invoiceNumber;
  final String status;
  final num totalAmount;
  final String currency;
  final String dueDate;
  final String issuedAt;
  final String? description;
  final List<InvoiceItemModel>? lineItems;
  final num? amountPaid;
  final num? amountOutstanding;

  num get outstanding => amountOutstanding ?? 0;
  num get paid => amountPaid ?? 0;

  bool get isFullyPaid => status == 'paid';
  bool get isCancelled => status == 'cancelled';
  bool get isPayable => status != 'paid' && status != 'cancelled' && status != 'void' && status != 'refunded';

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      status: json['status'] as String,
      totalAmount: json['totalAmount'] as num,
      currency: json['currency'] as String,
      dueDate: json['dueDate'] as String,
      issuedAt: json['issuedAt'] as String,
      description: json['description'] as String?,
      lineItems: (json['lineItems'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceItemModel.fromJson)
          .toList(growable: false),
      amountPaid: json['amountPaid'] as num?,
      amountOutstanding: json['amountOutstanding'] as num?,
    );
  }
}

class InvoiceListResponse {
  InvoiceListResponse({
    required this.success,
    required this.invoices,
  });

  final bool success;
  final List<InvoiceModel> invoices;

  factory InvoiceListResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceListResponse(
      success: json['success'] as bool? ?? false,
      invoices: (json['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceModel.fromJson)
          .toList(growable: false),
    );
  }
}

class InvoiceDetailResponse {
  InvoiceDetailResponse({
    required this.success,
    required this.invoice,
  });

  final bool success;
  final InvoiceModel invoice;

  factory InvoiceDetailResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceDetailResponse(
      success: json['success'] as bool? ?? false,
      invoice: InvoiceModel.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}

class PaymentProviderModel {
  PaymentProviderModel({
    required this.id,
    required this.name,
    required this.type,
    required this.displayName,
    required this.requiresPhoneNumber,
    this.businessShortCode,
    this.accountReferenceLabel,
    this.accountReferencePlaceholder,
    required this.description,
    this.instruction,
  });

  final String id;
  final String name;
  final String type; // 'stk_push' | 'manual' | 'hosted_checkout'
  final String displayName;
  final bool requiresPhoneNumber;
  final String? businessShortCode;
  final String? accountReferenceLabel;
  final String? accountReferencePlaceholder;
  final String description;
  final String? instruction;

  bool get isStkPush => type == 'stk_push';
  bool get isManual => type == 'manual';
  bool get isHostedCheckout => type == 'hosted_checkout';

  factory PaymentProviderModel.fromJson(Map<String, dynamic> json) {
    return PaymentProviderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      displayName: json['displayName'] as String,
      requiresPhoneNumber: json['requiresPhoneNumber'] as bool? ?? false,
      businessShortCode: json['businessShortCode'] as String?,
      accountReferenceLabel: json['accountReferenceLabel'] as String?,
      accountReferencePlaceholder: json['accountReferencePlaceholder'] as String?,
      description: json['description'] as String,
      instruction: json['instruction'] as String?,
    );
  }
}

class ProvidersResponse {
  ProvidersResponse({
    required this.success,
    required this.providers,
  });

  final bool success;
  final List<PaymentProviderModel> providers;

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    return ProvidersResponse(
      success: json['success'] as bool? ?? false,
      providers: (json['data']?['providers'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PaymentProviderModel.fromJson)
          .toList(growable: false),
    );
  }
}

class PaymentHistoryModel {
  PaymentHistoryModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentReference,
    required this.status,
    required this.paidAt,
    required this.createdAt,
  });

  final String id;
  final String invoiceId;
  final num amount;
  final String currency;
  final String paymentMethod;
  final String paymentReference;
  final String status;
  final String paidAt;
  final String createdAt;

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryModel(
      id: json['id'] as String,
      invoiceId: json['invoiceId'] as String,
      amount: json['amount'] as num,
      currency: json['currency'] as String,
      paymentMethod: json['paymentMethod'] as String,
      paymentReference: json['paymentReference'] as String,
      status: json['status'] as String,
      paidAt: json['paidAt'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class PaymentHistoryResponse {
  PaymentHistoryResponse({
    required this.success,
    required this.payments,
  });

  final bool success;
  final List<PaymentHistoryModel> payments;

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryResponse(
      success: json['success'] as bool? ?? false,
      payments: (json['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PaymentHistoryModel.fromJson)
          .toList(growable: false),
    );
  }
}

class TenantDashboardModel {
  TenantDashboardModel({
    required this.tenantId,
    required this.activeTenancyId,
    required this.propertyName,
    required this.unitNumber,
    required this.outstandingBalance,
    required this.invoiceCount,
    required this.currency,
    this.propertyAddress,
    this.tenancyStatus,
  });

  final String tenantId;
  final String activeTenancyId;
  final String propertyName;
  final String unitNumber;
  final num outstandingBalance;
  final int invoiceCount;
  final String currency;
  final String? propertyAddress;
  final String? tenancyStatus;

  bool get hasOutstandingBalance => outstandingBalance > 0;
  bool get hasUnpaidInvoices => invoiceCount > 0;

  factory TenantDashboardModel.fromJson(Map<String, dynamic> json) {
    final unit = json['unit'] as Map<String, dynamic>?;
    final property = json['property'] as Map<String, dynamic>?;
    final tenancy = json['activeTenancy'] as Map<String, dynamic>?;

    return TenantDashboardModel(
      tenantId: json['tenant']?['id'] as String? ?? '',
      activeTenancyId: tenancy?['id'] as String? ?? '',
      propertyName: property?['title'] as String? ?? 'Property',
      unitNumber: unit?['unitNumber'] as String? ?? 'Unit',
      outstandingBalance: json['outstandingBalance'] as num? ?? 0,
      invoiceCount: json['invoiceCount'] as int? ?? 0,
      currency: 'KES',
      propertyAddress: property?['fullAddress'] as String?,
      tenancyStatus: tenancy?['status'] as String?,
    );
  }
}

class TenantDashboardResponse {
  TenantDashboardResponse({
    required this.success,
    required this.dashboard,
  });

  final bool success;
  final TenantDashboardModel dashboard;

  factory TenantDashboardResponse.fromJson(Map<String, dynamic> json) {
    return TenantDashboardResponse(
      success: json['success'] as bool? ?? false,
      dashboard: TenantDashboardModel.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}

class ReceiptModel {
  ReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.paymentTransactionId,
    this.invoiceId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentDate,
    required this.transactionReference,
    required this.outstandingBalanceAfter,
    required this.createdAt,
  });

  final String id;
  final String receiptNumber;
  final String paymentTransactionId;
  final String? invoiceId;
  final num amount;
  final String currency;
  final String paymentMethod;
  final String paymentDate;
  final String transactionReference;
  final num outstandingBalanceAfter;
  final String createdAt;

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String,
      receiptNumber: json['receiptNumber'] as String,
      paymentTransactionId: json['paymentTransactionId'] as String,
      invoiceId: json['invoiceId'] as String?,
      amount: json['amount'] as num,
      currency: json['currency'] as String,
      paymentMethod: json['paymentMethod'] as String,
      paymentDate: json['paymentDate'] as String,
      transactionReference: json['transactionReference'] as String,
      outstandingBalanceAfter: json['outstandingBalanceAfter'] as num,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'receiptNumber': receiptNumber,
      'paymentTransactionId': paymentTransactionId,
      if (invoiceId != null) 'invoiceId': invoiceId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paymentDate': paymentDate,
      'transactionReference': transactionReference,
      'outstandingBalanceAfter': outstandingBalanceAfter,
      'createdAt': createdAt,
    };
  }
}

class StatementModel {
  StatementModel({
    required this.tenantId,
    required this.tenancyId,
    required this.fromDate,
    required this.toDate,
    required this.openingBalance,
    required this.totalCharges,
    required this.totalPaid,
    required this.closingBalance,
    required this.currency,
    required this.charges,
    required this.payments,
  });

  final String tenantId;
  final String tenancyId;
  final String fromDate;
  final String toDate;
  final num openingBalance;
  final num totalCharges;
  final num totalPaid;
  final num closingBalance;
  final String currency;
  final List<Map<String, dynamic>> charges;
  final List<Map<String, dynamic>> payments;

  num get netBalance => totalCharges - totalPaid;

  factory StatementModel.fromJson(Map<String, dynamic> json) {
    return StatementModel(
      tenantId: json['tenantId'] as String,
      tenancyId: json['tenancyId'] as String,
      fromDate: json['fromDate'] as String,
      toDate: json['toDate'] as String,
      openingBalance: json['openingBalance'] as num,
      totalCharges: json['totalCharges'] as num,
      totalPaid: json['totalPaid'] as num,
      closingBalance: json['closingBalance'] as num,
      currency: json['currency'] as String,
      charges: (json['charges'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      payments: (json['payments'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }
}

class DepositModel {
  DepositModel({
    required this.id,
    required this.expectedAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
    required this.currency,
    required this.status,
    this.depositSchemeReference,
    this.heldBy,
    this.refundDueDate,
    this.refundAmount,
    this.refundedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final num expectedAmount;
  final num receivedAmount;
  final num outstandingAmount;
  final String currency;
  final String status;
  final String? depositSchemeReference;
  final String? heldBy;
  final String? refundDueDate;
  final num? refundAmount;
  final String? refundedAt;
  final String createdAt;
  final String updatedAt;

  bool get isFullyPaid => outstandingAmount <= 0;

  factory DepositModel.fromJson(Map<String, dynamic> json) {
    return DepositModel(
      id: json['id'] as String,
      expectedAmount: json['expectedAmount'] as num,
      receivedAmount: json['receivedAmount'] as num,
      outstandingAmount: json['outstandingAmount'] as num,
      currency: json['currency'] as String,
      status: json['status'] as String,
      depositSchemeReference: json['depositSchemeReference'] as String?,
      heldBy: json['heldBy'] as String?,
      refundDueDate: json['refundDueDate'] as String?,
      refundAmount: json['refundAmount'] as num?,
      refundedAt: json['refundedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class DepositTransactionModel {
  DepositTransactionModel({
    required this.id,
    required this.depositId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String depositId;
  final String transactionType;
  final num amount;
  final String currency;
  final String transactionDate;
  final String? reference;
  final String? notes;
  final String createdAt;

  factory DepositTransactionModel.fromJson(Map<String, dynamic> json) {
    return DepositTransactionModel(
      id: json['id'] as String,
      depositId: json['depositId'] as String,
      transactionType: json['transactionType'] as String,
      amount: json['amount'] as num,
      currency: json['currency'] as String,
      transactionDate: json['transactionDate'] as String,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}

class MpesaInitiateRequest {
  MpesaInitiateRequest({
    required this.invoiceId,
    required this.amount,
    this.phoneNumber,
    this.idempotencyKey,
    this.provider = 'mpesa',
    this.merchantReference,
  });

  final String invoiceId;
  final num amount;
  final String? phoneNumber;
  final String? idempotencyKey;
  final String provider;
  final String? merchantReference;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'invoiceId': invoiceId,
      'amount': amount,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      'provider': provider,
      if (merchantReference != null) 'merchantReference': merchantReference,
    };
  }
}

class MpesaInitiateResponse {
  MpesaInitiateResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final PaymentInitiationData data;

  factory MpesaInitiateResponse.fromJson(Map<String, dynamic> json) {
    return MpesaInitiateResponse(
      success: json['success'] as bool? ?? false,
      data: PaymentInitiationData.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}

class PaymentInitiationData {
  PaymentInitiationData({
    required this.status,
    required this.paymentTransactionId,
    required this.providerTransactionId,
    this.merchantRequestId,
    this.checkoutUrl,
    required this.amount,
    this.invoiceId,
    required this.provider,
    required this.message,
  });

  final String status;
  final String paymentTransactionId;
  final String providerTransactionId;
  final String? merchantRequestId;
  final String? checkoutUrl;
  final num amount;
  final String? invoiceId;
  final String provider;
  final String message;

  factory PaymentInitiationData.fromJson(Map<String, dynamic> json) {
    return PaymentInitiationData(
      status: json['status'] as String,
      paymentTransactionId: json['paymentTransactionId'] as String,
      providerTransactionId: json['providerTransactionId'] as String,
      merchantRequestId: json['merchantRequestId'] as String?,
      checkoutUrl: json['checkoutUrl'] as String?,
      amount: json['amount'] as num,
      invoiceId: json['invoiceId'] as String?,
      provider: json['provider'] as String,
      message: json['message'] as String,
    );
  }
}

class MpesaPaymentStatusResponse {
  MpesaPaymentStatusResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final PaymentTransactionModel data;

  factory MpesaPaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return MpesaPaymentStatusResponse(
      success: json['success'] as bool? ?? false,
      data: PaymentTransactionModel.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}

class CallbackResponse {
  CallbackResponse({
    required this.status,
  });

  final String status;

  factory CallbackResponse.fromJson(Map<String, dynamic> json) {
    return CallbackResponse(
      status: json['status'] as String,
    );
  }
}

class SignedReceiptUrl {
  SignedReceiptUrl({
    required this.success,
    required this.url,
    required this.expiresInSeconds,
  });

  final bool success;
  final String url;
  final int expiresInSeconds;

  factory SignedReceiptUrl.fromJson(Map<String, dynamic> json) {
    return SignedReceiptUrl(
      success: json['success'] as bool? ?? false,
      url: json['url'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
    );
  }
}

class StatementResponse {
  StatementResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final StatementModel data;

  factory StatementResponse.fromJson(Map<String, dynamic> json) {
    return StatementResponse(
      success: json['success'] as bool? ?? false,
      data: StatementModel.fromJson(
        (json['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}

class DepositListResponse {
  DepositListResponse({
    required this.success,
    required this.deposits,
    required this.transactions,
  });

  final bool success;
  final List<DepositModel> deposits;
  final List<DepositTransactionModel> transactions;

  factory DepositListResponse.fromJson(Map<String, dynamic> json) {
    return DepositListResponse(
      success: json['success'] as bool? ?? false,
      deposits: (json['deposits'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DepositModel.fromJson)
          .toList(growable: false),
      transactions: (json['transactions'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DepositTransactionModel.fromJson)
          .toList(growable: false),
    );
  }
}

class ReceiptListResponse {
  ReceiptListResponse({
    required this.success,
    required this.receipts,
  });

  final bool success;
  final List<ReceiptModel> receipts;

  factory ReceiptListResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptListResponse(
      success: json['success'] as bool? ?? false,
      receipts: (json['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ReceiptModel.fromJson)
          .toList(growable: false),
    );
  }
}
