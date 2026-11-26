// Tenancy model for the GetKeja mobile app.
// Represents a tenant's tenancy record returned by the /api/v1/tenant API.
class TenancyModel {
  TenancyModel({
    required this.id,
    required this.propertyId,
    this.unitId,
    required this.tenancyType,
    required this.status,
    this.startDate,
    this.endDate,
    this.rentAmount,
    this.depositAmount,
    this.depositHeldBy,
    this.depositSchemeReference,
    this.rentDueDay,
    this.paymentMethod,
    this.paymentReference,
    this.termsDocumentUrl,
    this.specialConditions,
    this.managedByUserId,
    this.managedByOrganisationId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String tenancyType;
  final String status;
  final String? startDate;
  final String? endDate;
  final num? rentAmount;
  final num? depositAmount;
  final String? depositHeldBy;
  final String? depositSchemeReference;
  final int? rentDueDay;
  final String? paymentMethod;
  final String? paymentReference;
  final String? termsDocumentUrl;
  final String? specialConditions;
  final String? managedByUserId;
  final String? managedByOrganisationId;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  /// Whether this tenancy is currently active.
  bool get isActive => status == 'active';

  /// Whether this tenancy is historical (not active).
  bool get isHistorical => status != 'active';

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Pending';
      case 'active':
        return 'Active';
      case 'terminated':
        return 'Terminated';
      case 'expired':
        return 'Expired';
      case 'historical':
        return 'Historical';
      default:
        return status;
    }
  }

  factory TenancyModel.fromJson(Map<String, dynamic> json) {
    return TenancyModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      tenancyType: json['tenancyType'] as String,
      status: json['status'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      rentAmount: json['rentAmount'] as num?,
      depositAmount: json['depositAmount'] as num?,
      depositHeldBy: json['depositHeldBy'] as String?,
      depositSchemeReference: json['depositSchemeReference'] as String?,
      rentDueDay: json['rentDueDay'] as int?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentReference: json['paymentReference'] as String?,
      termsDocumentUrl: json['termsDocumentUrl'] as String?,
      specialConditions: json['specialConditions'] as String?,
      managedByUserId: json['managedByUserId'] as String?,
      managedByOrganisationId: json['managedByOrganisationId'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'propertyId': propertyId,
      if (unitId != null) 'unitId': unitId,
      'tenancyType': tenancyType,
      'status': status,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (rentAmount != null) 'rentAmount': rentAmount,
      if (depositAmount != null) 'depositAmount': depositAmount,
      if (depositHeldBy != null) 'depositHeldBy': depositHeldBy,
      if (depositSchemeReference != null)
        'depositSchemeReference': depositSchemeReference,
      if (rentDueDay != null) 'rentDueDay': rentDueDay,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (paymentReference != null) 'paymentReference': paymentReference,
      if (termsDocumentUrl != null) 'termsDocumentUrl': termsDocumentUrl,
      if (specialConditions != null) 'specialConditions': specialConditions,
      if (managedByUserId != null) 'managedByUserId': managedByUserId,
      if (managedByOrganisationId != null)
        'managedByOrganisationId': managedByOrganisationId,
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class TenancyListResponse {
  TenancyListResponse({
    required this.tenancies,
    required this.success,
  });

  final List<TenancyModel> tenancies;
  final bool success;

  factory TenancyListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List<dynamic>? ?? <dynamic>[]);
    return TenancyListResponse(
      tenancies: raw
          .whereType<Map<String, dynamic>>()
          .map(TenancyModel.fromJson)
          .toList(growable: false),
      success: json['success'] as bool? ?? true,
    );
  }
}

class TenancyDetailResponse {
  TenancyDetailResponse({
    required this.tenancy,
    required this.property,
    required this.unit,
    required this.success,
  });

  final TenancyModel tenancy;
  final PropertyModel property;
  final UnitModel? unit;
  final bool success;

  factory TenancyDetailResponse.fromJson(Map<String, dynamic> json) {
    return TenancyDetailResponse(
      tenancy: TenancyModel.fromJson(
        (json['tenancy'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      property: PropertyModel.fromJson(
        (json['property'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      unit: json['unit'] != null
          ? UnitModel.fromJson(
              (json['unit'] as Map<String, dynamic>? ?? <String, dynamic>{}),
            )
          : null,
      success: json['success'] as bool? ?? true,
    );
  }
}

class PropertyModel {
  PropertyModel({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.address,
    required this.city,
    required this.county,
    required this.country,
    required this.status,
  });

  final String id;
  final String title;
  final String propertyType;
  final String address;
  final String city;
  final String county;
  final String country;
  final String status;

  String get fullAddress =>
      '$address, $city, $county, $country';

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] as String,
      title: json['title'] as String,
      propertyType: json['propertyType'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      county: json['county'] as String,
      country: json['country'] as String,
      status: json['status'] as String,
    );
  }
}

class UnitModel {
  UnitModel({
    required this.id,
    required this.unitNumber,
    required this.unitType,
    this.bedrooms,
    this.bathrooms,
    this.areaSqm,
    this.rentAmount,
    this.depositAmount,
    required this.status,
  });

  final String id;
  final String unitNumber;
  final String unitType;
  final int? bedrooms;
  final int? bathrooms;
  final num? areaSqm;
  final num? rentAmount;
  final num? depositAmount;
  final String status;

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] as String,
      unitNumber: json['unitNumber'] as String,
      unitType: json['unitType'] as String,
      bedrooms: json['bedrooms'] as int?,
      bathrooms: json['bathrooms'] as int?,
      areaSqm: json['areaSqm'] as num?,
      rentAmount: json['rentAmount'] as num?,
      depositAmount: json['depositAmount'] as num?,
      status: json['status'] as String,
    );
  }
}

class TenantDashboardModel {
  TenantDashboardModel({
    required this.tenant,
    required this.activeTenancy,
    required this.property,
    required this.unit,
    required this.historicalTenancies,
    required this.invoiceCount,
    required this.outstandingBalance,
    required this.unreadNotificationCount,
  });

  final TenantModel? tenant;
  final TenancyModel? activeTenancy;
  final PropertyModel? property;
  final UnitModel? unit;
  final List<TenancyModel> historicalTenancies;
  final int invoiceCount;
  final num? outstandingBalance;
  final int unreadNotificationCount;

  bool get hasActiveTenancy => activeTenancy != null && activeTenancy!.isActive;

  factory TenantDashboardModel.fromJson(Map<String, dynamic> json) {
    return TenantDashboardModel(
      tenant: json['tenant'] != null
          ? TenantModel.fromJson(
              (json['tenant'] as Map<String, dynamic>? ?? <String, dynamic>{}),
            )
          : null,
      activeTenancy: json['activeTenancy'] != null
          ? TenancyModel.fromJson(
              (json['activeTenancy'] as Map<String, dynamic>? ??
                  <String, dynamic>{}),
            )
          : null,
      property: json['property'] != null
          ? PropertyModel.fromJson(
              (json['property'] as Map<String, dynamic>? ??
                  <String, dynamic>{}),
            )
          : null,
      unit: json['unit'] != null
          ? UnitModel.fromJson(
              (json['unit'] as Map<String, dynamic>? ?? <String, dynamic>{}),
            )
          : null,
      historicalTenancies: (json['historicalTenancies'] as List<dynamic>? ??
              <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TenancyModel.fromJson)
          .toList(growable: false),
      invoiceCount: json['invoiceCount'] as int? ?? 0,
      outstandingBalance: json['outstandingBalance'] as num?,
      unreadNotificationCount: json['unreadNotificationCount'] as int? ?? 0,
    );
  }
}

class TenantModel {
  TenantModel({
    required this.id,
    required this.userId,
    required this.propertyId,
    this.unitId,
    this.tenancyId,
    required this.fullName,
    this.email,
    this.phone,
    this.idNumber,
    this.idType,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String propertyId;
  final String? unitId;
  final String? tenancyId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? idNumber;
  final String? idType;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  bool get isActive => status == 'active';

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      tenancyId: json['tenancyId'] as String?,
      fullName: json['fullName'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      idNumber: json['idNumber'] as String?,
      idType: json['idType'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
