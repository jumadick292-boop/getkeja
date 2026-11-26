library features.property_management.data.models.property_model;

import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

class PropertyModel extends Property {
  const PropertyModel({
    required super.id,
    required super.title,
    required super.propertyType,
    required super.status,
    required super.address,
    required super.city,
    required super.county,
    required super.country,
    super.organisationId,
    super.description,
    super.latitude,
    super.longitude,
    super.totalUnits = 0,
    super.amenities,
    super.features,
    super.images,
    super.createdBy,
    super.publishedAt,
    super.archivedAt,
    super.createdAt,
    super.updatedAt,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] as String,
      organisationId: json['organisationId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      propertyType: json['propertyType'] as String,
      status: json['status'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      county: json['county'] as String,
      country: json['country'] as String? ?? 'KE',
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      totalUnits: _asInt(json['totalUnits']),
      amenities: _asMap(json['amenities']),
      features: _asMap(json['features']),
      images: _asMap(json['images']),
      createdBy: json['createdBy'] as String?,
      publishedAt: _asDate(json['publishedAt']),
      archivedAt: _asDate(json['archivedAt']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'organisationId': organisationId,
      'title': title,
      'description': description,
      'propertyType': propertyType,
      'status': status,
      'address': address,
      'city': city,
      'county': county,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'totalUnits': totalUnits,
      'amenities': amenities,
      'features': features,
      'images': images,
      'createdBy': createdBy,
      'publishedAt': publishedAt?.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class PropertyUnitModel extends PropertyUnit {
  const PropertyUnitModel({
    required super.id,
    required super.propertyId,
    required super.unitNumber,
    required super.unitType,
    required super.status,
    super.building,
    super.floor,
    super.bedrooms,
    super.bathrooms,
    super.areaSqm,
    super.rentAmount,
    super.depositAmount = 0,
    super.amenities,
    super.description,
    super.hasSeparateMeter = false,
    super.meterNumber,
    super.createdAt,
    super.updatedAt,
  });

  factory PropertyUnitModel.fromJson(Map<String, dynamic> json) {
    return PropertyUnitModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitNumber: json['unitNumber'] as String,
      building: json['building'] as String?,
      floor: json['floor'] == null ? null : _asInt(json['floor']),
      unitType: json['unitType'] as String,
      bedrooms: json['bedrooms'] == null ? null : _asInt(json['bedrooms']),
      bathrooms: json['bathrooms'] == null ? null : _asInt(json['bathrooms']),
      areaSqm: _asDouble(json['areaSqm']),
      rentAmount: _asDouble(json['rentAmount']),
      depositAmount: _asDouble(json['depositAmount']) ?? 0,
      amenities: _asMap(json['amenities']),
      description: json['description'] as String?,
      hasSeparateMeter: json['hasSeparateMeter'] as bool? ?? false,
      meterNumber: json['meterNumber'] as String?,
      status: json['status'] as String,
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'propertyId': propertyId,
      'unitNumber': unitNumber,
      'building': building,
      'floor': floor,
      'unitType': unitType,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'areaSqm': areaSqm,
      'rentAmount': rentAmount,
      'depositAmount': depositAmount,
      'amenities': amenities,
      'description': description,
      'hasSeparateMeter': hasSeparateMeter,
      'meterNumber': meterNumber,
      'status': status,
    };
  }
}

class PropertyListingModel extends PropertyListing {
  const PropertyListingModel({
    required super.id,
    required super.propertyId,
    required super.title,
    required super.status,
    super.unitId,
    super.description,
    super.rentAmount,
    super.depositAmount = 0,
    super.availableFrom,
    super.availableTo,
    super.furnished = false,
    super.petPolicy,
    super.smokingAllowed = false,
    super.images,
    super.publishedAt,
    super.createdAt,
    super.updatedAt,
  });

  factory PropertyListingModel.fromJson(Map<String, dynamic> json) {
    return PropertyListingModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      rentAmount: _asDouble(json['rentAmount']),
      depositAmount: _asDouble(json['depositAmount']) ?? 0,
      availableFrom: _asDate(json['availableFrom']),
      availableTo: _asDate(json['availableTo']),
      furnished: json['furnished'] as bool? ?? false,
      petPolicy: json['petPolicy'] as String?,
      smokingAllowed: json['smokingAllowed'] as bool? ?? false,
      images: _asMap(json['images']),
      publishedAt: _asDate(json['publishedAt']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'propertyId': propertyId,
      'unitId': unitId,
      'title': title,
      'description': description,
      'status': status,
      'rentAmount': rentAmount,
      'depositAmount': depositAmount,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableTo': availableTo?.toIso8601String(),
      'furnished': furnished,
      'petPolicy': petPolicy,
      'smokingAllowed': smokingAllowed,
    };
  }
}

class PropertyEnquiryModel extends PropertyEnquiry {
  const PropertyEnquiryModel({
    required super.id,
    required super.propertyId,
    required super.prospectiveRenterName,
    required super.prospectiveRenterPhone,
    required super.enquirySource,
    required super.status,
    super.unitId,
    super.listingId,
    super.prospectiveRenterId,
    super.prospectiveRenterEmail,
    super.message,
    super.followUpDate,
    super.lastContactAt,
    super.createdAt,
    super.updatedAt,
  });

  factory PropertyEnquiryModel.fromJson(Map<String, dynamic> json) {
    return PropertyEnquiryModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      listingId: json['listingId'] as String?,
      prospectiveRenterId: json['prospectiveRenterId'] as String?,
      prospectiveRenterName: json['prospectiveRenterName'] as String,
      prospectiveRenterEmail: json['prospectiveRenterEmail'] as String?,
      prospectiveRenterPhone: json['prospectiveRenterPhone'] as String,
      enquirySource: json['enquirySource'] as String,
      message: json['message'] as String?,
      status: json['status'] as String,
      followUpDate: _asDate(json['followUpDate']),
      lastContactAt: _asDate(json['lastContactAt']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'propertyId': propertyId,
      'unitId': unitId,
      'listingId': listingId,
      'prospectiveRenterId': prospectiveRenterId,
      'prospectiveRenterName': prospectiveRenterName,
      'prospectiveRenterEmail': prospectiveRenterEmail,
      'prospectiveRenterPhone': prospectiveRenterPhone,
      'enquirySource': enquirySource,
      'message': message,
      'status': status,
      'followUpDate': followUpDate?.toIso8601String(),
      'lastContactAt': lastContactAt?.toIso8601String(),
    };
  }
}

class SiteVisitModel extends SiteVisit {
  const SiteVisitModel({
    required super.id,
    required super.propertyId,
    super.unitId,
    super.userId,
    super.visitorName,
    super.visitorPhone,
    super.visitorEmail,
    super.scheduledAt,
    super.durationMinutes,
    required super.status,
    super.visitorNotes,
    super.hostNotes,
    super.outcome,
    super.enquiryId,
    super.assignedToUserId,
    super.createdAt,
    super.updatedAt,
  });

  factory SiteVisitModel.fromJson(Map<String, dynamic> json) {
    return SiteVisitModel(
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'propertyId': propertyId,
      'unitId': unitId,
      'userId': userId,
      'visitorName': visitorName,
      'visitorPhone': visitorPhone,
      'visitorEmail': visitorEmail,
      'scheduledAt': scheduledAt,
      'durationMinutes': durationMinutes,
      'status': status,
      'visitorNotes': visitorNotes,
      'hostNotes': hostNotes,
      'outcome': outcome,
      'enquiryId': enquiryId,
      'assignedToUserId': assignedToUserId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class LandlordDashboardStatsModel extends LandlordDashboardStats {
  const LandlordDashboardStatsModel({
    super.totalProperties = 0,
    super.totalListings = 0,
    super.publishedListings = 0,
    super.totalUnits = 0,
    super.vacantUnits = 0,
    super.occupiedUnits = 0,
    super.activeTenancies = 0,
    super.totalTenants = 0,
    super.pendingSiteVisits = 0,
    super.activeGarbageAssignments = 0,
    super.pendingGarbageRequests = 0,
  });

  factory LandlordDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return LandlordDashboardStatsModel(
      totalProperties: _asInt(json['totalProperties']),
      totalListings: _asInt(json['totalListings']),
      publishedListings: _asInt(json['publishedListings']),
      totalUnits: _asInt(json['totalUnits']),
      vacantUnits: _asInt(json['vacantUnits']),
      occupiedUnits: _asInt(json['occupiedUnits']),
      activeTenancies: _asInt(json['activeTenancies']),
      totalTenants: _asInt(json['totalTenants']),
      pendingSiteVisits: _asInt(json['pendingSiteVisits']),
      activeGarbageAssignments: _asInt(json['activeGarbageAssignments']),
      pendingGarbageRequests: _asInt(json['pendingGarbageRequests']),
    );
  }
}
