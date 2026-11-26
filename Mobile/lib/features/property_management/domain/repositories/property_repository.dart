library features.property_management.domain.repositories.property_repository;

import '../entities/property.dart';

abstract class PropertyRepository {
  // Properties
  Future<List<Property>> getProperties({String? status, String? city});

  Future<Property?> getProperty(String propertyId);

  Future<Property> createProperty({
    required String title,
    required String propertyType,
    required String address,
    required String city,
    required String county,
    String? description,
    String? country,
    int? totalUnits,
    String? status,
  });

  Future<Property> updateProperty({
    required String propertyId,
    String? title,
    String? description,
    String? propertyType,
    String? status,
    String? address,
    String? city,
    String? county,
    String? country,
    int? totalUnits,
  });

  Future<void> deleteProperty(String propertyId);

  // Units
  Future<List<PropertyUnit>> getUnits({
    String? propertyId,
    String? status,
    String? unitType,
  });

  Future<PropertyUnit?> getUnit(String unitId);

  Future<PropertyUnit> createUnit({
    required String propertyId,
    required String unitNumber,
    required String unitType,
    String? building,
    int? floor,
    int? bedrooms,
    int? bathrooms,
    double? areaSqm,
    double? rentAmount,
    double? depositAmount,
    String? description,
    String? status,
    bool? hasSeparateMeter,
    String? meterNumber,
  });

  Future<PropertyUnit> updateUnit({
    required String unitId,
    String? unitNumber,
    String? unitType,
    int? bedrooms,
    int? bathrooms,
    double? rentAmount,
    double? depositAmount,
    String? status,
  });

  Future<void> deleteUnit(String unitId);

  // Listings
  Future<List<PropertyListing>> getListings({
    String? propertyId,
    String? status,
  });

  Future<PropertyListing?> getListing(String listingId);

  Future<PropertyListing> createListing({
    required String propertyId,
    required String title,
    double? rentAmount,
    double? depositAmount,
    String? unitId,
    String? description,
    DateTime? availableFrom,
    bool? furnished,
    String? petPolicy,
    bool? smokingAllowed,
  });

  Future<void> deleteListing(String listingId);

  Future<PropertyListing> setListingStatus({
    required String listingId,
    required String action,
    String? reason,
  });

  // Enquiries
  Future<List<PropertyEnquiry>> getEnquiries({
    String? propertyId,
    String? status,
  });

  Future<PropertyEnquiry?> getEnquiry(String enquiryId);

  Future<PropertyEnquiry> createEnquiry({
    required String propertyId,
    required String prospectiveRenterName,
    required String prospectiveRenterPhone,
    String? unitId,
    String? listingId,
    String? prospectiveRenterEmail,
    String? enquirySource,
    String? message,
  });

  Future<PropertyEnquiry> updateEnquiry({
    required String enquiryId,
    String? status,
    String? message,
  });

  // Dashboard
  Future<LandlordDashboardStats> getDashboardStats({String? propertyId});

  // Site visits (landlord side)
  Future<List<SiteVisit>> getSiteVisits({
    String? propertyId,
    String? status,
    int limit = 20,
    int offset = 0,
  });

  Future<SiteVisit?> getSiteVisit(String visitId);

  Future<SiteVisit> confirmSiteVisit({
    required String visitId,
    String? hostNotes,
  });

  Future<SiteVisit> declineSiteVisit({required String visitId, String? reason});

  Future<SiteVisit> rescheduleSiteVisit({
    required String visitId,
    String? scheduledAt,
    int? durationMinutes,
    String? hostNotes,
  });

  Future<SiteVisit> cancelSiteVisit({required String visitId, String? reason});
}
