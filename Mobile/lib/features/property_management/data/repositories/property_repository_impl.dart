library features.property_management.data.repositories.property_repository_impl;

import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/property_management/data/datasources/property_remote_datasource.dart';
import 'package:get_keja_mobile/features/property_management/data/models/property_model.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';
import 'package:get_keja_mobile/features/property_management/domain/repositories/property_repository.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  PropertyRepositoryImpl(this._remoteDataSource);

  final PropertyRemoteDataSource _remoteDataSource;

  factory PropertyRepositoryImpl.fromApiClient(ApiClient apiClient) {
    return PropertyRepositoryImpl(PropertyRemoteDataSource(apiClient.dio));
  }

  @override
  Future<List<Property>> getProperties({String? status, String? city}) async {
    try {
      return await _remoteDataSource.getProperties(status: status, city: city);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load properties',
        originalError: error,
      );
    }
  }

  @override
  Future<Property?> getProperty(String propertyId) async {
    try {
      return await _remoteDataSource.getProperty(propertyId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load property',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.createProperty(
        title: title,
        propertyType: propertyType,
        address: address,
        city: city,
        county: county,
        description: description,
        country: country,
        totalUnits: totalUnits,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create property',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.updateProperty(
        propertyId: propertyId,
        title: title,
        description: description,
        propertyType: propertyType,
        status: status,
        address: address,
        city: city,
        county: county,
        country: country,
        totalUnits: totalUnits,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update property',
        originalError: error,
      );
    }
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    try {
      await _remoteDataSource.deleteProperty(propertyId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to delete property',
        originalError: error,
      );
    }
  }

  @override
  Future<List<PropertyUnit>> getUnits({
    String? propertyId,
    String? status,
    String? unitType,
  }) async {
    try {
      return await _remoteDataSource.getUnits(
        propertyId: propertyId,
        status: status,
        unitType: unitType,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load units',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyUnit?> getUnit(String unitId) async {
    try {
      return await _remoteDataSource.getUnit(unitId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load unit',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.createUnit(
        propertyId: propertyId,
        unitNumber: unitNumber,
        unitType: unitType,
        building: building,
        floor: floor,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        areaSqm: areaSqm,
        rentAmount: rentAmount,
        depositAmount: depositAmount,
        description: description,
        status: status,
        hasSeparateMeter: hasSeparateMeter,
        meterNumber: meterNumber,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create unit',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyUnit> updateUnit({
    required String unitId,
    String? unitNumber,
    String? unitType,
    int? bedrooms,
    int? bathrooms,
    double? rentAmount,
    double? depositAmount,
    String? status,
  }) async {
    try {
      return await _remoteDataSource.updateUnit(
        unitId: unitId,
        unitNumber: unitNumber,
        unitType: unitType,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        rentAmount: rentAmount,
        depositAmount: depositAmount,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update unit',
        originalError: error,
      );
    }
  }

  @override
  Future<void> deleteUnit(String unitId) async {
    try {
      await _remoteDataSource.deleteUnit(unitId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to delete unit',
        originalError: error,
      );
    }
  }

  @override
  Future<List<PropertyListing>> getListings({
    String? propertyId,
    String? status,
  }) async {
    try {
      return await _remoteDataSource.getListings(
        propertyId: propertyId,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load listings',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyListing?> getListing(String listingId) async {
    try {
      return await _remoteDataSource.getListing(listingId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load listing',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.createListing(
        propertyId: propertyId,
        title: title,
        rentAmount: rentAmount,
        depositAmount: depositAmount,
        unitId: unitId,
        description: description,
        availableFrom: availableFrom,
        furnished: furnished,
        petPolicy: petPolicy,
        smokingAllowed: smokingAllowed,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create listing',
        originalError: error,
      );
    }
  }

  @override
  Future<void> deleteListing(String listingId) async {
    try {
      await _remoteDataSource.deleteListing(listingId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to delete listing',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyListing> setListingStatus({
    required String listingId,
    required String action,
    String? reason,
  }) async {
    try {
      return await _remoteDataSource.setListingStatus(
        listingId: listingId,
        action: action,
        reason: reason,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update listing status',
        originalError: error,
      );
    }
  }

  @override
  Future<List<PropertyEnquiry>> getEnquiries({
    String? propertyId,
    String? status,
  }) async {
    try {
      return await _remoteDataSource.getEnquiries(
        propertyId: propertyId,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load enquiries',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyEnquiry?> getEnquiry(String enquiryId) async {
    try {
      return await _remoteDataSource.getEnquiry(enquiryId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load enquiry',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyEnquiry> createEnquiry({
    required String propertyId,
    required String prospectiveRenterName,
    required String prospectiveRenterPhone,
    String? unitId,
    String? listingId,
    String? prospectiveRenterEmail,
    String? enquirySource,
    String? message,
  }) async {
    try {
      return await _remoteDataSource.createEnquiry(
        propertyId: propertyId,
        prospectiveRenterName: prospectiveRenterName,
        prospectiveRenterPhone: prospectiveRenterPhone,
        unitId: unitId,
        listingId: listingId,
        prospectiveRenterEmail: prospectiveRenterEmail,
        enquirySource: enquirySource,
        message: message,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create enquiry',
        originalError: error,
      );
    }
  }

  @override
  Future<PropertyEnquiry> updateEnquiry({
    required String enquiryId,
    String? status,
    String? message,
  }) async {
    try {
      return await _remoteDataSource.updateEnquiry(
        enquiryId: enquiryId,
        status: status,
        message: message,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update enquiry',
        originalError: error,
      );
    }
  }

  @override
  Future<LandlordDashboardStats> getDashboardStats({String? propertyId}) async {
    try {
      return await _remoteDataSource.getDashboardStats(propertyId: propertyId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load dashboard stats',
        originalError: error,
      );
    }
  }

  @override
  Future<List<SiteVisit>> getSiteVisits({
    String? propertyId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _remoteDataSource.getSiteVisits(
        propertyId: propertyId,
        status: status,
        limit: limit,
        offset: offset,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load site visits',
        originalError: error,
      );
    }
  }

  @override
  Future<SiteVisit?> getSiteVisit(String visitId) async {
    try {
      return await _remoteDataSource.getSiteVisit(visitId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load site visit',
        originalError: error,
      );
    }
  }

  @override
  Future<SiteVisit> confirmSiteVisit({
    required String visitId,
    String? hostNotes,
  }) async {
    try {
      return await _remoteDataSource.confirmSiteVisit(
        visitId: visitId,
        hostNotes: hostNotes,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to confirm site visit',
        originalError: error,
      );
    }
  }

  @override
  Future<SiteVisit> declineSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    try {
      return await _remoteDataSource.declineSiteVisit(
        visitId: visitId,
        reason: reason,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to decline site visit',
        originalError: error,
      );
    }
  }

  @override
  Future<SiteVisit> rescheduleSiteVisit({
    required String visitId,
    String? scheduledAt,
    int? durationMinutes,
    String? hostNotes,
  }) async {
    try {
      return await _remoteDataSource.rescheduleSiteVisit(
        visitId: visitId,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        hostNotes: hostNotes,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to reschedule site visit',
        originalError: error,
      );
    }
  }

  @override
  Future<SiteVisit> cancelSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    try {
      return await _remoteDataSource.cancelSiteVisit(
        visitId: visitId,
        reason: reason,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to cancel site visit',
        originalError: error,
      );
    }
  }
}
