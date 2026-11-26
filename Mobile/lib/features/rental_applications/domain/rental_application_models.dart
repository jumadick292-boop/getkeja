// Domain models for the rental application workflow (applicant + manager).

class RentalApplicationDetailModel {
  RentalApplicationDetailModel({
    required this.application,
    this.history = const <ApplicationHistoryEntry>[],
    this.notes = const <ApplicationNoteModel>[],
    this.documents = const <ApplicationDocumentModel>[],
  });

  final RentalApplicationRecord application;
  final List<ApplicationHistoryEntry> history;
  final List<ApplicationNoteModel> notes;
  final List<ApplicationDocumentModel> documents;

  factory RentalApplicationDetailModel.fromJson(Map<String, dynamic> json) {
    final history = (json['history'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ApplicationHistoryEntry.fromJson)
        .toList(growable: false);
    final notes = (json['notes'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ApplicationNoteModel.fromJson)
        .toList(growable: false);
    final documents = (json['documents'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ApplicationDocumentModel.fromJson)
        .toList(growable: false);
    return RentalApplicationDetailModel(
      application: RentalApplicationRecord.fromJson(
        (json['application'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      history: history,
      notes: notes,
      documents: documents,
    );
  }
}

class RentalApplicationRecord {
  RentalApplicationRecord({
    required this.id,
    required this.propertyId,
    required this.status,
    this.unitId,
    this.applicantName,
    this.applicantEmail,
    this.applicantPhone,
    this.proposedRentAmount,
    this.preferredStartDate,
    this.preferredEndDate,
    this.propertyTitle,
    this.city,
    this.county,
    this.tenancyId,
    this.rejectionReason,
    this.reviewNotes,
    this.approvedRentAmount,
    this.approvedStartDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String status;
  final String? applicantName;
  final String? applicantEmail;
  final String? applicantPhone;
  final num? proposedRentAmount;
  final String? preferredStartDate;
  final String? preferredEndDate;
  final String? propertyTitle;
  final String? city;
  final String? county;
  final String? tenancyId;
  final String? rejectionReason;
  final String? reviewNotes;
  final num? approvedRentAmount;
  final String? approvedStartDate;
  final String? createdAt;
  final String? updatedAt;

  bool get canWithdraw =>
      !<String>['approved', 'rejected', 'withdrawn', 'expired', 'cancelled']
          .contains(status);
  bool get canRespondToInfo =>
      <String>['information_requested', 'pending_documents'].contains(status);
  bool get isOnboarded => tenancyId != null;

  factory RentalApplicationRecord.fromJson(Map<String, dynamic> json) {
    return RentalApplicationRecord(
      id: json['id'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      unitId: json['unitId'] as String?,
      status: json['status'] as String? ?? 'submitted',
      applicantName: json['applicantName'] as String?,
      applicantEmail: json['applicantEmail'] as String?,
      applicantPhone: json['applicantPhone'] as String?,
      proposedRentAmount: json['proposedRentAmount'] as num?,
      preferredStartDate: json['preferredStartDate'] as String?,
      preferredEndDate: json['preferredEndDate'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      tenancyId: json['tenancyId'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      reviewNotes: json['reviewNotes'] as String?,
      approvedRentAmount: json['approvedRentAmount'] as num?,
      approvedStartDate: json['approvedStartDate'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class ApplicationHistoryEntry {
  ApplicationHistoryEntry({
    required this.action,
    this.previousStatus,
    this.newStatus,
    this.createdAt,
  });

  final String action;
  final String? previousStatus;
  final String? newStatus;
  final String? createdAt;

  factory ApplicationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ApplicationHistoryEntry(
      action: json['action'] as String? ?? '',
      previousStatus: json['previousStatus'] as String?,
      newStatus: json['newStatus'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ApplicationNoteModel {
  ApplicationNoteModel({
    required this.note,
    this.isInternal = false,
    this.createdAt,
  });

  final String note;
  final bool isInternal;
  final String? createdAt;

  factory ApplicationNoteModel.fromJson(Map<String, dynamic> json) {
    return ApplicationNoteModel(
      note: json['note'] as String? ?? '',
      isInternal: json['isInternal'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ApplicationDocumentModel {
  ApplicationDocumentModel({
    required this.id,
    this.fileName,
    this.category,
    this.verificationStatus,
  });

  final String id;
  final String? fileName;
  final String? category;
  final String? verificationStatus;

  factory ApplicationDocumentModel.fromJson(Map<String, dynamic> json) {
    return ApplicationDocumentModel(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String?,
      category: json['category'] as String?,
      verificationStatus: json['verificationStatus'] as String?,
    );
  }
}

/// Manager inbox / list item (application + property title).
class ManagedApplicationModel {
  ManagedApplicationModel({
    required this.id,
    required this.propertyId,
    required this.status,
    this.applicantName,
    this.propertyTitle,
    this.city,
    this.county,
    this.proposedRentAmount,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String status;
  final String? applicantName;
  final String? propertyTitle;
  final String? city;
  final String? county;
  final num? proposedRentAmount;
  final String? createdAt;

  factory ManagedApplicationModel.fromJson(Map<String, dynamic> json) {
    return ManagedApplicationModel(
      id: json['id'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      applicantName: json['applicantName'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      proposedRentAmount: json['proposedRentAmount'] as num?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ManagedApplicationListModel {
  ManagedApplicationListModel({
    this.items = const <ManagedApplicationModel>[],
    this.total = 0,
    this.limit = 20,
    this.offset = 0,
  });

  final List<ManagedApplicationModel> items;
  final int total;
  final int limit;
  final int offset;

  factory ManagedApplicationListModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ManagedApplicationModel.fromJson)
        .toList(growable: false);
    return ManagedApplicationListModel(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnboardingResultModel {
  OnboardingResultModel({
    this.tenancyId,
    this.tenantId,
    this.alreadyOnboarded = false,
  });

  final String? tenancyId;
  final String? tenantId;
  final bool alreadyOnboarded;

  factory OnboardingResultModel.fromJson(Map<String, dynamic> json) {
    return OnboardingResultModel(
      tenancyId: json['tenancyId'] as String?,
      tenantId: json['tenantId'] as String?,
      alreadyOnboarded: json['alreadyOnboarded'] as bool? ?? false,
    );
  }
}