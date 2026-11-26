library features.property_management.domain.entities.property;

import 'package:equatable/equatable.dart';

/// A rental property owned/managed by a landlord.
class Property extends Equatable {
  const Property({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.status,
    required this.address,
    required this.city,
    required this.county,
    required this.country,
    this.organisationId,
    this.description,
    this.latitude,
    this.longitude,
    this.totalUnits = 0,
    this.amenities,
    this.features,
    this.images,
    this.createdBy,
    this.publishedAt,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? organisationId;
  final String title;
  final String? description;
  final String propertyType;
  final String status;
  final String address;
  final String city;
  final String county;
  final String country;
  final double? latitude;
  final double? longitude;
  final int totalUnits;
  final Map<String, dynamic>? amenities;
  final Map<String, dynamic>? features;
  final Map<String, dynamic>? images;
  final String? createdBy;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => status.toLowerCase() == 'published';
  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isArchived => status.toLowerCase() == 'archived';

  String get locationLabel => '$address, $city';

  Property copyWith({
    String? id,
    String? organisationId,
    String? title,
    String? description,
    String? propertyType,
    String? status,
    String? address,
    String? city,
    String? county,
    String? country,
    double? latitude,
    double? longitude,
    int? totalUnits,
    Map<String, dynamic>? amenities,
    Map<String, dynamic>? features,
    Map<String, dynamic>? images,
    String? createdBy,
    DateTime? publishedAt,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      organisationId: organisationId ?? this.organisationId,
      title: title ?? this.title,
      description: description ?? this.description,
      propertyType: propertyType ?? this.propertyType,
      status: status ?? this.status,
      address: address ?? this.address,
      city: city ?? this.city,
      county: county ?? this.county,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalUnits: totalUnits ?? this.totalUnits,
      amenities: amenities ?? this.amenities,
      features: features ?? this.features,
      images: images ?? this.images,
      createdBy: createdBy ?? this.createdBy,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organisationId,
        title,
        description,
        propertyType,
        status,
        address,
        city,
        county,
        country,
        latitude,
        longitude,
        totalUnits,
        amenities,
        features,
        images,
        createdBy,
        publishedAt,
        archivedAt,
        createdAt,
        updatedAt,
      ];
}

/// A rentable unit within a property.
class PropertyUnit extends Equatable {
  const PropertyUnit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.unitType,
    required this.status,
    this.building,
    this.floor,
    this.bedrooms,
    this.bathrooms,
    this.areaSqm,
    this.rentAmount,
    this.depositAmount = 0,
    this.amenities,
    this.description,
    this.hasSeparateMeter = false,
    this.meterNumber,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String unitNumber;
  final String? building;
  final int? floor;
  final String unitType;
  final int? bedrooms;
  final int? bathrooms;
  final double? areaSqm;
  final double? rentAmount;
  final double depositAmount;
  final Map<String, dynamic>? amenities;
  final String? description;
  final bool hasSeparateMeter;
  final String? meterNumber;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isOccupied => status.toLowerCase() == 'occupied';

  String get title {
    final buffer = StringBuffer('Unit $unitNumber');
    if (bedrooms != null) {
      buffer.write(' · $bedrooms bed');
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [
        id,
        propertyId,
        unitNumber,
        building,
        floor,
        unitType,
        bedrooms,
        bathrooms,
        areaSqm,
        rentAmount,
        depositAmount,
        amenities,
        description,
        hasSeparateMeter,
        meterNumber,
        status,
        createdAt,
        updatedAt,
      ];
}

/// A published/unpublished listing for a property or unit.
class PropertyListing extends Equatable {
  const PropertyListing({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.status,
    this.unitId,
    this.description,
    this.rentAmount,
    this.depositAmount = 0,
    this.availableFrom,
    this.availableTo,
    this.furnished = false,
    this.petPolicy,
    this.smokingAllowed = false,
    this.images,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String title;
  final String? description;
  final String status;
  final double? rentAmount;
  final double depositAmount;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final bool furnished;
  final String? petPolicy;
  final bool smokingAllowed;
  final Map<String, dynamic>? images;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => status.toLowerCase() == 'published';

  @override
  List<Object?> get props => [
        id,
        propertyId,
        unitId,
        title,
        description,
        status,
        rentAmount,
        depositAmount,
        availableFrom,
        availableTo,
        furnished,
        petPolicy,
        smokingAllowed,
        images,
        publishedAt,
        createdAt,
        updatedAt,
      ];
}

/// A prospective-renter enquiry (CRM lead).
class PropertyEnquiry extends Equatable {
  const PropertyEnquiry({
    required this.id,
    required this.propertyId,
    required this.prospectiveRenterName,
    required this.prospectiveRenterPhone,
    required this.enquirySource,
    required this.status,
    this.unitId,
    this.listingId,
    this.prospectiveRenterId,
    this.prospectiveRenterEmail,
    this.message,
    this.followUpDate,
    this.lastContactAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String? listingId;
  final String? prospectiveRenterId;
  final String prospectiveRenterName;
  final String? prospectiveRenterEmail;
  final String prospectiveRenterPhone;
  final String enquirySource;
  final String? message;
  final String status;
  final DateTime? followUpDate;
  final DateTime? lastContactAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isNew => status.toLowerCase() == 'new';

  @override
  List<Object?> get props => [
        id,
        propertyId,
        unitId,
        listingId,
        prospectiveRenterId,
        prospectiveRenterName,
        prospectiveRenterEmail,
        prospectiveRenterPhone,
        enquirySource,
        message,
        status,
        followUpDate,
        lastContactAt,
        createdAt,
        updatedAt,
      ];
}

/// Aggregated dashboard statistics for a landlord.
class LandlordDashboardStats extends Equatable {
  const LandlordDashboardStats({
    this.totalProperties = 0,
    this.totalListings = 0,
    this.publishedListings = 0,
    this.totalUnits = 0,
    this.vacantUnits = 0,
    this.occupiedUnits = 0,
    this.activeTenancies = 0,
    this.totalTenants = 0,
    this.pendingSiteVisits = 0,
    this.activeGarbageAssignments = 0,
    this.pendingGarbageRequests = 0,
  });

  final int totalProperties;
  final int totalListings;
  final int publishedListings;
  final int totalUnits;
  final int vacantUnits;
  final int occupiedUnits;
  final int activeTenancies;
  final int totalTenants;
  final int pendingSiteVisits;
  final int activeGarbageAssignments;
  final int pendingGarbageRequests;

  @override
  List<Object?> get props => [
        totalProperties,
        totalListings,
        publishedListings,
        totalUnits,
        vacantUnits,
        occupiedUnits,
        activeTenancies,
        totalTenants,
        pendingSiteVisits,
        activeGarbageAssignments,
        pendingGarbageRequests,
    ];
}

class SiteVisit extends Equatable {
  const SiteVisit({
    required this.id,
    required this.propertyId,
    this.unitId,
    this.userId,
    this.visitorName,
    this.visitorPhone,
    this.visitorEmail,
    this.scheduledAt,
    this.durationMinutes,
    required this.status,
    this.visitorNotes,
    this.hostNotes,
    this.outcome,
    this.enquiryId,
    this.assignedToUserId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String? userId;
  final String? visitorName;
  final String? visitorPhone;
  final String? visitorEmail;
  final String? scheduledAt;
  final int? durationMinutes;
  final String status;
  final String? visitorNotes;
  final String? hostNotes;
  final String? outcome;
  final String? enquiryId;
  final String? assignedToUserId;
  final String? createdAt;
  final String? updatedAt;

  bool get canConfirm => status == 'scheduled';
  bool get canDecline => status == 'scheduled';
  bool get canReschedule => status == 'scheduled' || status == 'rescheduled';
  bool get canComplete => status == 'confirmed';
  bool get canCancel =>
      !<String>['completed', 'cancelled', 'no_show'].contains(status);

  factory SiteVisit.fromJson(Map<String, dynamic> json) {
    return SiteVisit(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      userId: json['userId'] as String?,
      visitorName: json['visitorName'] as String?,
      visitorPhone: json['visitorPhone'] as String?,
      visitorEmail: json['visitorEmail'] as String?,
      scheduledAt: json['scheduledAt'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'scheduled',
      visitorNotes: json['visitorNotes'] as String?,
      hostNotes: json['hostNotes'] as String?,
      outcome: json['outcome'] as String?,
      enquiryId: json['enquiryId'] as String?,
      assignedToUserId: json['assignedToUserId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        propertyId,
        unitId,
        userId,
        visitorName,
        visitorPhone,
        visitorEmail,
        scheduledAt,
        durationMinutes,
        status,
        visitorNotes,
        hostNotes,
        outcome,
        enquiryId,
        assignedToUserId,
        createdAt,
        updatedAt,
      ];
}