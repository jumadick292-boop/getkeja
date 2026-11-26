// House Seeker discovery models.

class ListingCardModel {
  ListingCardModel({
    required this.listingId,
    required this.propertyId,
    required this.title,
    required this.propertyType,
    required this.city,
    required this.county,
    required this.rentAmount,
    required this.images,
    required this.amenities,
    this.description,
    this.propertyTitle,
    this.latitude,
    this.longitude,
    this.depositAmount,
    this.bedrooms,
    this.bathrooms,
    this.unitNumber,
    this.unitId,
    this.furnished,
    this.availableFrom,
    this.availableTo,
    this.publishedAt,
    this.listingStatus,
  });

  final String listingId;
  final String propertyId;
  final String? title;
  final String? description;
  final String? propertyTitle;
  final String? propertyType;
  final String? city;
  final String? county;
  final num? rentAmount;
  final num? depositAmount;
  final double? latitude;
  final double? longitude;
  final int? bedrooms;
  final num? bathrooms;
  final String? unitNumber;
  final String? unitId;
  final bool? furnished;
  final String? availableFrom;
  final String? availableTo;
  final String? publishedAt;
  final List<String> images;
  final List<String> amenities;
  final String? listingStatus;

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  String? get locationLabel {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (county != null && county!.trim().isNotEmpty && county != city)
        county!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory ListingCardModel.fromJson(Map<String, dynamic> json) {
    return ListingCardModel(
      listingId: json['listingId'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      propertyType: json['propertyType'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      rentAmount: (json['rentAmount'] as num?),
      depositAmount: (json['depositAmount'] as num?),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bedrooms: json['bedrooms'] as int?,
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      unitNumber: json['unitNumber'] as String?,
      unitId: json['unitId'] as String?,
      furnished: json['furnished'] as bool?,
      availableFrom: json['availableFrom'] as String?,
      availableTo: json['availableTo'] as String?,
      publishedAt: json['publishedAt'] as String?,
      images: _stringList(json['images']),
      amenities: _stringList(json['amenities']),
      listingStatus: json['listingStatus'] as String?,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    if (value is Map) {
      return value.keys.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }
}

class ListingDetailModel extends ListingCardModel {
  ListingDetailModel({
    required super.listingId,
    required super.propertyId,
    required super.title,
    required super.propertyType,
    required super.city,
    required super.county,
    required super.rentAmount,
    required super.images,
    required super.amenities,
    super.description,
    super.propertyTitle,
    super.latitude,
    super.longitude,
    super.depositAmount,
    super.bedrooms,
    super.bathrooms,
    super.unitNumber,
    super.unitId,
    super.furnished,
    super.availableFrom,
    super.availableTo,
    super.publishedAt,
    super.listingStatus,
    this.address,
    this.propertyDescription,
    this.unitDescription,
    this.landlordFirstName,
    this.landlordUserId,
    this.petPolicy,
    this.smokingAllowed,
    this.features = const <String>[],
    this.pricingFrequency,
  });

  final String? address;
  final String? propertyDescription;
  final String? unitDescription;
  final String? landlordFirstName;
  final String? landlordUserId;
  final String? petPolicy;
  final bool? smokingAllowed;
  final List<String> features;
  final String? pricingFrequency;

  String get pricingLabel {
    switch (pricingFrequency) {
      case 'weekly':
        return '/week';
      case 'annual':
        return '/year';
      case 'sale':
        return 'for sale';
      case 'monthly':
      default:
        return '/month';
    }
  }

  factory ListingDetailModel.fromJson(Map<String, dynamic> json) {
    return ListingDetailModel(
      listingId: json['listingId'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      propertyType: json['propertyType'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      rentAmount: (json['rentAmount'] as num?),
      depositAmount: (json['depositAmount'] as num?),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bedrooms: json['bedrooms'] as int?,
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      unitNumber: json['unitNumber'] as String?,
      unitId: json['unitId'] as String?,
      furnished: json['furnished'] as bool?,
      availableFrom: json['availableFrom'] as String?,
      availableTo: json['availableTo'] as String?,
      publishedAt: json['publishedAt'] as String?,
      images: ListingCardModel._stringList(json['images']),
      amenities: ListingCardModel._stringList(json['amenities']),
      address: json['address'] as String?,
      propertyDescription: json['propertyDescription'] as String?,
      unitDescription: json['unitDescription'] as String?,
      landlordFirstName: json['landlordFirstName'] as String?,
      landlordUserId: json['landlordUserId'] as String?,
      petPolicy: json['petPolicy'] as String?,
      smokingAllowed: json['smokingAllowed'] as bool?,
      features: ListingCardModel._stringList(json['listingFeatures']),
      pricingFrequency: json['pricingFrequency'] as String?,
    );
  }
}

class SearchResultModel {
  SearchResultModel({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<ListingCardModel> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List<dynamic>? ?? <dynamic>[]);
    return SearchResultModel(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(ListingCardModel.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class FilterFacetsModel {
  FilterFacetsModel({
    required this.propertyTypes,
    required this.counties,
    this.minRent,
    this.maxRent,
  });

  final List<String> propertyTypes;
  final List<String> counties;
  final num? minRent;
  final num? maxRent;

  factory FilterFacetsModel.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) {
      final raw = json[key] as List<dynamic>? ?? <dynamic>[];
      return raw
          .map((e) => e is Map ? e['value'] : e)
          .whereType<String>()
          .toList(growable: false);
    }

    final price = json['priceRange'] as Map<String, dynamic>?;
    return FilterFacetsModel(
      propertyTypes: readList('propertyTypes'),
      counties: readList('counties'),
      minRent: (price?['minRent'] as num?),
      maxRent: (price?['maxRent'] as num?),
    );
  }
}

class SavedListingModel {
  SavedListingModel({
    required this.savedId,
    required this.listingId,
    required this.propertyId,
    required this.title,
    required this.propertyType,
    required this.city,
    required this.county,
    required this.rentAmount,
    required this.images,
    required this.amenities,
    this.collection,
    this.notes,
    this.savedAt,
    this.listingStatus,
    this.propertyTitle,
    this.description,
    this.latitude,
    this.longitude,
    this.depositAmount,
    this.bedrooms,
    this.bathrooms,
    this.unitNumber,
    this.unitId,
    this.furnished,
    this.availableFrom,
    this.availableTo,
    this.publishedAt,
  });

  final String savedId;
  final String listingId;
  final String propertyId;
  final String title;
  final String? propertyType;
  final String? city;
  final String? county;
  final num rentAmount;
  final List<String> images;
  final List<String> amenities;
  final String? collection;
  final String? notes;
  final String? savedAt;
  final String? listingStatus;
  final String? propertyTitle;
  final String? description;
  final double? latitude;
  final double? longitude;
  final num? depositAmount;
  final int? bedrooms;
  final num? bathrooms;
  final String? unitNumber;
  final String? unitId;
  final bool? furnished;
  final String? availableFrom;
  final String? availableTo;
  final String? publishedAt;

  bool get isAvailable => listingStatus == 'published';

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  String? get locationLabel {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (county != null && county!.trim().isNotEmpty && county != city)
        county!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory SavedListingModel.fromJson(Map<String, dynamic> json) {
    return SavedListingModel(
      savedId: json['savedId'] as String,
      listingId: json['listingId'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String? ?? '',
      propertyType: json['propertyType'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      rentAmount: (json['rentAmount'] as num?) ?? 0,
      images: ListingCardModel._stringList(json['images']),
      amenities: ListingCardModel._stringList(json['amenities']),
      collection: json['collection'] as String?,
      notes: json['notes'] as String?,
      savedAt: json['savedAt'] as String?,
      listingStatus: json['listingStatus'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      depositAmount: (json['depositAmount'] as num?),
      bedrooms: json['bedrooms'] as int?,
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      unitNumber: json['unitNumber'] as String?,
      unitId: json['unitId'] as String?,
      furnished: json['furnished'] as bool?,
      availableFrom: json['availableFrom'] as String?,
      availableTo: json['availableTo'] as String?,
      publishedAt: json['publishedAt'] as String?,
    );
  }
}

class SavedSearchModel {
  SavedSearchModel({
    required this.id,
    required this.name,
    required this.criteria,
    required this.alertsEnabled,
    this.alertFrequency,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final Map<String, dynamic> criteria;
  final bool alertsEnabled;
  final String? alertFrequency;
  final String? createdAt;
  final String? updatedAt;

  factory SavedSearchModel.fromJson(Map<String, dynamic> json) {
    return SavedSearchModel(
      id: json['id'] as String,
      name: json['name'] as String,
      criteria:
          (json['criteria'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      alertFrequency: json['alertFrequency'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class EnquiryModel {
  EnquiryModel({
    required this.id,
    required this.propertyId,
    required this.message,
    required this.status,
    this.listingId,
    this.unitId,
    this.propertyTitle,
    this.listingTitle,
    this.city,
    this.county,
    this.source,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String? listingId;
  final String? unitId;
  final String message;
  final String status;
  final String? propertyTitle;
  final String? listingTitle;
  final String? city;
  final String? county;
  final String? source;
  final String? createdAt;

  String get displayTitle =>
      listingTitle ?? propertyTitle ?? 'Property enquiry';

  factory EnquiryModel.fromJson(Map<String, dynamic> json) {
    return EnquiryModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      listingId: json['listingId'] as String?,
      unitId: json['unitId'] as String?,
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      propertyTitle: json['propertyTitle'] as String?,
      listingTitle: json['listingTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      source: json['source'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class HouseSeekerPreferencesModel {
  HouseSeekerPreferencesModel({
    this.minBudget,
    this.maxBudget,
    this.preferredPropertyTypes,
    this.preferredBedrooms,
    this.preferredBathrooms,
    this.preferredAmenities,
    this.preferredLocations,
    this.moveInDate,
    this.alertsEnabled,
  });

  final num? minBudget;
  final num? maxBudget;
  final List<String>? preferredPropertyTypes;
  final int? preferredBedrooms;
  final int? preferredBathrooms;
  final List<String>? preferredAmenities;
  final List<Map<String, dynamic>>? preferredLocations;
  final String? moveInDate;
  final bool? alertsEnabled;

  bool get isEmpty =>
      minBudget == null &&
      maxBudget == null &&
      (preferredPropertyTypes == null || preferredPropertyTypes!.isEmpty) &&
      preferredBedrooms == null &&
      preferredBathrooms == null &&
      (preferredAmenities == null || preferredAmenities!.isEmpty);

  factory HouseSeekerPreferencesModel.fromJson(Map<String, dynamic> json) {
    List<String> readStrings(String key) {
      final raw = json[key] as List<dynamic>? ?? <dynamic>[];
      return raw.whereType<String>().toList(growable: false);
    }

    final locs = (json['preferredLocations'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return HouseSeekerPreferencesModel(
      minBudget: (json['minBudget'] as num?),
      maxBudget: (json['maxBudget'] as num?),
      preferredPropertyTypes: readStrings('preferredPropertyTypes'),
      preferredBedrooms: (json['preferredBedrooms'] as num?)?.toInt(),
      preferredBathrooms: (json['preferredBathrooms'] as num?)?.toInt(),
      preferredAmenities: readStrings('preferredAmenities'),
      preferredLocations: locs,
      moveInDate: json['moveInDate'] as String?,
      alertsEnabled: json['alertsEnabled'] as bool?,
    );
  }
}

// ---------------------------------------------------------------------------
// Engagement models: site visits, conversations, applications, proposals, journey
// ---------------------------------------------------------------------------

class SiteVisitModel {
  SiteVisitModel({
    required this.id,
    required this.propertyId,
    required this.status,
    this.unitId,
    this.visitorName,
    this.visitorPhone,
    this.visitorEmail,
    this.scheduledAt,
    this.durationMinutes,
    this.visitorNotes,
    this.hostNotes,
    this.outcome,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String? visitorName;
  final String? visitorPhone;
  final String? visitorEmail;
  final String? scheduledAt;
  final int? durationMinutes;
  final String status;
  final String? visitorNotes;
  final String? hostNotes;
  final String? outcome;
  final String? createdAt;

  bool get canCancel =>
      !<String>['completed', 'cancelled', 'no_show'].contains(status);
  bool get canReschedule => canCancel;

  factory SiteVisitModel.fromJson(Map<String, dynamic> json) {
    return SiteVisitModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      visitorName: json['visitorName'] as String?,
      visitorPhone: json['visitorPhone'] as String?,
      visitorEmail: json['visitorEmail'] as String?,
      scheduledAt: json['scheduledAt'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'scheduled',
      visitorNotes: json['visitorNotes'] as String?,
      hostNotes: json['hostNotes'] as String?,
      outcome: json['outcome'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ConversationModel {
  ConversationModel({
    required this.id,
    required this.status,
    this.type,
    this.subject,
    this.propertyId,
    this.unitId,
    this.propertyTitle,
    this.city,
    this.county,
    this.rentalApplicationId,
    this.rentalProposalId,
    this.lastMessageAt,
    this.unreadCount,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.createdAt,
  });

  final String id;
  final String? type;
  final String? subject;
  final String? propertyId;
  final String? unitId;
  final String? propertyTitle;
  final String? city;
  final String? county;
  final String? rentalApplicationId;
  final String? rentalProposalId;
  final String status;
  final String? lastMessageAt;
  final int? unreadCount;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final String? createdAt;

  String get displayTitle => subject ?? propertyTitle ?? 'Conversation';
  bool get hasUnread => (unreadCount ?? 0) > 0;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String?,
      subject: json['subject'] as String?,
      propertyId: json['propertyId'] as String?,
      unitId: json['unitId'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      rentalApplicationId: json['rentalApplicationId'] as String?,
      rentalProposalId: json['rentalProposalId'] as String?,
      status: json['status'] as String? ?? 'active',
      lastMessageAt: json['lastMessageAt'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt(),
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class MessageModel {
  MessageModel({
    required this.id,
    required this.conversationId,
    required this.content,
    this.senderId,
    this.type,
    this.status,
    this.isRead,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String content;
  final String? senderId;
  final String? type;
  final String? status;
  final bool? isRead;
  final String? createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      content: json['content'] as String? ?? '',
      senderId: json['senderId'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String?,
      isRead: json['isRead'] as bool?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class StartConversationResult {
  StartConversationResult({required this.conversation, this.firstMessage});

  final ConversationModel conversation;
  final MessageModel? firstMessage;

  factory StartConversationResult.fromJson(Map<String, dynamic> json) {
    final conv = json['conversation'] as Map<String, dynamic>?;
    final msg = json['firstMessage'] as Map<String, dynamic>?;
    return StartConversationResult(
      conversation: ConversationModel.fromJson(
        conv ?? <String, dynamic>{'id': '', 'status': 'active'},
      ),
      firstMessage: msg != null ? MessageModel.fromJson(msg) : null,
    );
  }
}

class RentalApplicationModel {
  RentalApplicationModel({
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
    this.employerName,
    this.monthlyIncome,
    this.propertyTitle,
    this.city,
    this.county,
    this.createdAt,
    this.reviewNotes,
    this.rejectionReason,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String? applicantName;
  final String? applicantEmail;
  final String? applicantPhone;
  final num? proposedRentAmount;
  final String? preferredStartDate;
  final String? preferredEndDate;
  final String? employerName;
  final num? monthlyIncome;
  final String status;
  final String? propertyTitle;
  final String? city;
  final String? county;
  final String? createdAt;
  final String? reviewNotes;
  final String? rejectionReason;

  String get displayTitle => propertyTitle ?? 'Rental application';
  bool get canWithdraw => !<String>[
    'approved',
    'rejected',
    'withdrawn',
    'expired',
  ].contains(status);

  factory RentalApplicationModel.fromJson(Map<String, dynamic> json) {
    return RentalApplicationModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      applicantName: json['applicantName'] as String?,
      applicantEmail: json['applicantEmail'] as String?,
      applicantPhone: json['applicantPhone'] as String?,
      proposedRentAmount: (json['proposedRentAmount'] as num?),
      preferredStartDate: json['preferredStartDate'] as String?,
      preferredEndDate: json['preferredEndDate'] as String?,
      employerName: json['employerName'] as String?,
      monthlyIncome: (json['monthlyIncome'] as num?),
      status: json['status'] as String? ?? 'submitted',
      propertyTitle: json['propertyTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      createdAt: json['createdAt'] as String?,
      reviewNotes: json['reviewNotes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}

class RentalProposalModel {
  RentalProposalModel({
    required this.id,
    required this.propertyId,
    required this.status,
    this.landlordUserId,
    this.proposedRentAmount,
    this.proposedDepositAmount,
    this.proposedStartDate,
    this.proposedEndDate,
    this.proposedRentDueDay,
    this.specialConditions,
    this.propertyTitle,
    this.city,
    this.county,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String propertyId;
  final String? landlordUserId;
  final num? proposedRentAmount;
  final num? proposedDepositAmount;
  final String? proposedStartDate;
  final String? proposedEndDate;
  final int? proposedRentDueDay;
  final String? specialConditions;
  final String status;
  final String? propertyTitle;
  final String? city;
  final String? county;
  final String? expiresAt;
  final String? createdAt;

  String get displayTitle => propertyTitle ?? 'Rental proposal';
  bool get canRespond =>
      <String>['sent', 'under_review', 'changes_requested'].contains(status);

  factory RentalProposalModel.fromJson(Map<String, dynamic> json) {
    return RentalProposalModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      landlordUserId: json['landlordUserId'] as String?,
      proposedRentAmount: (json['proposedRentAmount'] as num?),
      proposedDepositAmount: (json['proposedDepositAmount'] as num?),
      proposedStartDate: json['proposedStartDate'] as String?,
      proposedEndDate: json['proposedEndDate'] as String?,
      proposedRentDueDay: (json['proposedRentDueDay'] as num?)?.toInt(),
      specialConditions: json['specialConditions'] as String?,
      status: json['status'] as String? ?? 'sent',
      propertyTitle: json['propertyTitle'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      expiresAt: json['expiresAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class JourneyCounts {
  JourneyCounts({
    this.savedHomes = 0,
    this.activeEnquiries = 0,
    this.upcomingVisits = 0,
    this.pendingProposals = 0,
    this.activeApplications = 0,
  });

  final int savedHomes;
  final int activeEnquiries;
  final int upcomingVisits;
  final int pendingProposals;
  final int activeApplications;

  factory JourneyCounts.fromJson(Map<String, dynamic> json) {
    return JourneyCounts(
      savedHomes: (json['savedHomes'] as num?)?.toInt() ?? 0,
      activeEnquiries: (json['activeEnquiries'] as num?)?.toInt() ?? 0,
      upcomingVisits: (json['upcomingVisits'] as num?)?.toInt() ?? 0,
      pendingProposals: (json['pendingProposals'] as num?)?.toInt() ?? 0,
      activeApplications: (json['activeApplications'] as num?)?.toInt() ?? 0,
    );
  }
}

class JourneyVisitModel {
  JourneyVisitModel({
    required this.id,
    this.propertyId,
    this.scheduledAt,
    this.status,
  });

  final String id;
  final String? propertyId;
  final String? scheduledAt;
  final String? status;

  factory JourneyVisitModel.fromJson(Map<String, dynamic> json) {
    return JourneyVisitModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String?,
      scheduledAt: json['scheduledAt'] as String?,
      status: json['status'] as String?,
    );
  }
}

class JourneyProposalModel {
  JourneyProposalModel({
    required this.id,
    this.status,
    this.proposedRentAmount,
    this.propertyTitle,
  });

  final String id;
  final String? status;
  final num? proposedRentAmount;
  final String? propertyTitle;

  factory JourneyProposalModel.fromJson(Map<String, dynamic> json) {
    return JourneyProposalModel(
      id: json['id'] as String,
      status: json['status'] as String?,
      proposedRentAmount: (json['proposedRentAmount'] as num?),
      propertyTitle: json['propertyTitle'] as String?,
    );
  }
}

class RentalJourneyModel {
  RentalJourneyModel({
    required this.counts,
    this.upcomingVisits = const <JourneyVisitModel>[],
    this.recentProposals = const <JourneyProposalModel>[],
  });

  final JourneyCounts counts;
  final List<JourneyVisitModel> upcomingVisits;
  final List<JourneyProposalModel> recentProposals;

  factory RentalJourneyModel.fromJson(Map<String, dynamic> json) {
    final visits = (json['upcomingVisits'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(JourneyVisitModel.fromJson)
        .toList(growable: false);
    final proposals = (json['recentProposals'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(JourneyProposalModel.fromJson)
        .toList(growable: false);
    return RentalJourneyModel(
      counts: JourneyCounts.fromJson(
        json['counts'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      upcomingVisits: visits,
      recentProposals: proposals,
    );
  }
}

// ---------------------------------------------------------------------------
// Property comparison models
// ---------------------------------------------------------------------------

class ComparisonListingModel extends ListingCardModel {
  ComparisonListingModel({
    required super.listingId,
    required super.propertyId,
    required super.title,
    required super.propertyType,
    required super.city,
    required super.county,
    required super.rentAmount,
    required super.images,
    required super.amenities,
    super.description,
    super.propertyTitle,
    super.latitude,
    super.longitude,
    super.depositAmount,
    super.bedrooms,
    super.bathrooms,
    super.unitNumber,
    super.unitId,
    super.furnished,
    super.availableFrom,
    super.availableTo,
    super.publishedAt,
    super.listingStatus,
    required this.comparisonItemId,
    required this.position,
    required this.addedAt,
    this.address,
    this.propertyDescription,
    this.unitDescription,
    this.landlordFirstName,
    this.landlordUserId,
    this.petPolicy,
    this.smokingAllowed,
    this.features = const <String>[],
    this.pricingFrequency,
    this.floorPlanUrl,
    this.virtualTourUrl,
  });

  final String comparisonItemId;
  final int position;
  final String addedAt;
  final String? address;
  final String? propertyDescription;
  final String? unitDescription;
  final String? landlordFirstName;
  final String? landlordUserId;
  final String? petPolicy;
  final bool? smokingAllowed;
  final List<String> features;
  final String? pricingFrequency;
  final String? floorPlanUrl;
  final String? virtualTourUrl;

  String get pricingLabel {
    switch (pricingFrequency) {
      case 'weekly':
        return '/week';
      case 'annual':
        return '/year';
      case 'sale':
        return 'for sale';
      case 'monthly':
      default:
        return '/month';
    }
  }

  bool get isAvailable => listingStatus == 'published';

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  String? get fullLocation {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (county != null && county!.trim().isNotEmpty && county != city)
        county!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory ComparisonListingModel.fromJson(Map<String, dynamic> json) {
    return ComparisonListingModel(
      listingId: json['listingId'] as String,
      propertyId: json['propertyId'] as String,
      title: json['title'] as String? ?? '',
      propertyType: json['propertyType'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      rentAmount: (json['rentAmount'] as num?),
      images: ListingCardModel._stringList(json['images']),
      amenities: ListingCardModel._stringList(json['amenities']),
      comparisonItemId: json['comparisonItemId'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: json['addedAt'] as String? ?? '',
      description: json['description'] as String?,
      propertyTitle: json['propertyTitle'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      depositAmount: (json['depositAmount'] as num?),
      bedrooms: json['bedrooms'] as int?,
      bathrooms: (json['bathrooms'] as num?)?.toDouble(),
      unitNumber: json['unitNumber'] as String?,
      unitId: json['unitId'] as String?,
      furnished: json['furnished'] as bool?,
      availableFrom: json['availableFrom'] as String?,
      availableTo: json['availableTo'] as String?,
      publishedAt: json['publishedAt'] as String?,
      listingStatus: json['listingStatus'] as String?,
      address: json['address'] as String?,
      propertyDescription: json['propertyDescription'] as String?,
      unitDescription: json['unitDescription'] as String?,
      landlordFirstName: json['landlordFirstName'] as String?,
      landlordUserId: json['landlordUserId'] as String?,
      petPolicy: json['petPolicy'] as String?,
      smokingAllowed: json['smokingAllowed'] as bool?,
      features: ListingCardModel._stringList(json['listingFeatures']),
      pricingFrequency: json['pricingFrequency'] as String?,
      floorPlanUrl: json['floorPlanUrl'] as String?,
      virtualTourUrl: json['virtualTourUrl'] as String?,
    );
  }
}

class ComparisonListModel {
  ComparisonListModel({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<ComparisonListingModel> items;
  final int total;
  final int limit;
  final int offset;

  int get count => items.length;

  factory ComparisonListModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List<dynamic>? ?? <dynamic>[]);
    return ComparisonListModel(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(ComparisonListingModel.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class ComparisonAddResult {
  ComparisonAddResult({
    required this.added,
    required this.listingId,
    this.reason,
    this.listId,
    this.position,
    this.createdAt,
  });

  final bool added;
  final String listingId;
  final String? reason;
  final String? listId;
  final int? position;
  final String? createdAt;

  factory ComparisonAddResult.fromJson(Map<String, dynamic> json) {
    return ComparisonAddResult(
      added: json['added'] as bool? ?? false,
      listingId: json['listingId'] as String,
      reason: json['reason'] as String?,
      listId: json['listId'] as String?,
      position: (json['position'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ComparisonRemoveResult {
  ComparisonRemoveResult({required this.removed});

  final bool removed;

  factory ComparisonRemoveResult.fromJson(Map<String, dynamic> json) {
    return ComparisonRemoveResult(
      removed: json['removed'] as bool? ?? false,
    );
  }
}

class ComparisonClearResult {
  ComparisonClearResult({required this.cleared, required this.removedCount});

  final bool cleared;
  final int removedCount;

  factory ComparisonClearResult.fromJson(Map<String, dynamic> json) {
    return ComparisonClearResult(
      cleared: json['cleared'] as bool? ?? false,
      removedCount: (json['removedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
