library features.property_management.presentation.state.property_state;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/property_management/data/repositories/property_repository_impl.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';
import 'package:get_keja_mobile/features/property_management/domain/repositories/property_repository.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/create_enquiry.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/create_listing.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/create_property.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/create_unit.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/cancel_site_visit.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/confirm_site_visit.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/decline_site_visit.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_dashboard_stats.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_enquiries.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_listings.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_properties.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_property.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_site_visit.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_site_visits.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/get_units.dart';
import 'package:get_keja_mobile/features/property_management/domain/usecases/reschedule_site_visit.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PropertyRepositoryImpl.fromApiClient(apiClient);
});

class PropertyState {
  const PropertyState({
    this.properties = const [],
    this.units = const [],
    this.listings = const [],
    this.enquiries = const [],
    this.siteVisits = const [],
    this.selectedSiteVisit,
    this.selectedProperty,
    this.dashboardStats,
    this.isLoading = false,
    this.error,
  });

  final List<Property> properties;
  final List<PropertyUnit> units;
  final List<PropertyListing> listings;
  final List<PropertyEnquiry> enquiries;
  final List<SiteVisit> siteVisits;
  final SiteVisit? selectedSiteVisit;
  final Property? selectedProperty;
  final LandlordDashboardStats? dashboardStats;
  final bool isLoading;
  final String? error;

  PropertyState copyWith({
    List<Property>? properties,
    List<PropertyUnit>? units,
    List<PropertyListing>? listings,
    List<PropertyEnquiry>? enquiries,
    List<SiteVisit>? siteVisits,
    SiteVisit? selectedSiteVisit,
    Property? selectedProperty,
    LandlordDashboardStats? dashboardStats,
    bool? isLoading,
    String? error,
  }) {
    return PropertyState(
      properties: properties ?? this.properties,
      units: units ?? this.units,
      listings: listings ?? this.listings,
      enquiries: enquiries ?? this.enquiries,
      siteVisits: siteVisits ?? this.siteVisits,
      selectedSiteVisit: selectedSiteVisit ?? this.selectedSiteVisit,
      selectedProperty: selectedProperty ?? this.selectedProperty,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PropertyNotifier extends Notifier<PropertyState> {
  @override
  PropertyState build() => const PropertyState();

  PropertyRepository get _repository => ref.read(propertyRepositoryProvider);

  GetProperties get _getProperties => GetProperties(_repository);
  GetProperty get _getProperty => GetProperty(_repository);
  CreateProperty get _createProperty => CreateProperty(_repository);
  GetUnits get _getUnits => GetUnits(_repository);
  CreateUnit get _createUnit => CreateUnit(_repository);
  GetListings get _getListings => GetListings(_repository);
  CreateListing get _createListing => CreateListing(_repository);
  GetEnquiries get _getEnquiries => GetEnquiries(_repository);
  CreateEnquiry get _createEnquiry => CreateEnquiry(_repository);
  GetDashboardStats get _getDashboardStats => GetDashboardStats(_repository);
  GetSiteVisits get _getSiteVisits => GetSiteVisits(_repository);
  GetSiteVisit get _getSiteVisit => GetSiteVisit(_repository);
  ConfirmSiteVisit get _confirmSiteVisit => ConfirmSiteVisit(_repository);
  DeclineSiteVisit get _declineSiteVisit => DeclineSiteVisit(_repository);
  RescheduleSiteVisit get _rescheduleSiteVisit =>
      RescheduleSiteVisit(_repository);
  CancelSiteVisit get _cancelSiteVisit => CancelSiteVisit(_repository);

  Future<void> loadProperties({String? status, String? city}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final properties = await _getProperties(status: status, city: city);
      state = state.copyWith(properties: properties, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadProperty(String propertyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final property = await _getProperty(propertyId);
      state = state.copyWith(selectedProperty: property, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> createProperty({
    required String title,
    required String propertyType,
    required String address,
    required String city,
    required String county,
    String? description,
    int? totalUnits,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final property = await _createProperty(
        title: title,
        propertyType: propertyType,
        address: address,
        city: city,
        county: county,
        description: description,
        totalUnits: totalUnits,
      );
      state = state.copyWith(
        properties: [...state.properties, property],
        selectedProperty: property,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<void> loadUnits({String? propertyId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final units = await _getUnits(propertyId: propertyId);
      state = state.copyWith(units: units, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> createUnit({
    required String propertyId,
    required String unitNumber,
    required String unitType,
    double? rentAmount,
    int? bedrooms,
    int? bathrooms,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final unit = await _createUnit(
        propertyId: propertyId,
        unitNumber: unitNumber,
        unitType: unitType,
        rentAmount: rentAmount,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
      );
      state = state.copyWith(units: [...state.units, unit], isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<void> loadListings({String? propertyId, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final listings = await _getListings(
        propertyId: propertyId,
        status: status,
      );
      state = state.copyWith(listings: listings, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> createListing({
    required String propertyId,
    required String title,
    double? rentAmount,
    double? depositAmount,
    String? unitId,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final listing = await _createListing(
        propertyId: propertyId,
        title: title,
        rentAmount: rentAmount,
        depositAmount: depositAmount,
        unitId: unitId,
        description: description,
      );
      state = state.copyWith(
        listings: [...state.listings, listing],
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<void> loadEnquiries({String? propertyId, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final enquiries = await _getEnquiries(
        propertyId: propertyId,
        status: status,
      );
      state = state.copyWith(enquiries: enquiries, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> createEnquiry({
    required String propertyId,
    required String prospectiveRenterName,
    required String prospectiveRenterPhone,
    String? message,
    String? enquirySource,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final enquiry = await _createEnquiry(
        propertyId: propertyId,
        prospectiveRenterName: prospectiveRenterName,
        prospectiveRenterPhone: prospectiveRenterPhone,
        message: message,
        enquirySource: enquirySource,
      );
      state = state.copyWith(
        enquiries: [...state.enquiries, enquiry],
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<void> loadDashboardStats({String? propertyId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stats = await _getDashboardStats(propertyId: propertyId);
      state = state.copyWith(dashboardStats: stats, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadSiteVisits({String? propertyId, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visits = await _getSiteVisits(
        propertyId: propertyId,
        status: status,
      );
      state = state.copyWith(siteVisits: visits, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadSiteVisit(String visitId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visit = await _getSiteVisit(visitId);
      state = state.copyWith(selectedSiteVisit: visit, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> confirmSiteVisit({
    required String visitId,
    String? hostNotes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visit = await _confirmSiteVisit(
        visitId: visitId,
        hostNotes: hostNotes,
      );
      state = state.copyWith(
        siteVisits: state.siteVisits
            .map((v) => v.id == visitId ? visit : v)
            .toList(),
        selectedSiteVisit: state.selectedSiteVisit?.id == visitId
            ? visit
            : state.selectedSiteVisit,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<bool> declineSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visit = await _declineSiteVisit(visitId: visitId, reason: reason);
      state = state.copyWith(
        siteVisits: state.siteVisits
            .map((v) => v.id == visitId ? visit : v)
            .toList(),
        selectedSiteVisit: state.selectedSiteVisit?.id == visitId
            ? visit
            : state.selectedSiteVisit,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<bool> rescheduleSiteVisit({
    required String visitId,
    String? scheduledAt,
    int? durationMinutes,
    String? hostNotes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visit = await _rescheduleSiteVisit(
        visitId: visitId,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        hostNotes: hostNotes,
      );
      state = state.copyWith(
        siteVisits: state.siteVisits
            .map((v) => v.id == visitId ? visit : v)
            .toList(),
        selectedSiteVisit: state.selectedSiteVisit?.id == visitId
            ? visit
            : state.selectedSiteVisit,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  Future<bool> cancelSiteVisit({
    required String visitId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final visit = await _cancelSiteVisit(visitId: visitId, reason: reason);
      state = state.copyWith(
        siteVisits: state.siteVisits
            .map((v) => v.id == visitId ? visit : v)
            .toList(),
        selectedSiteVisit: state.selectedSiteVisit?.id == visitId
            ? visit
            : state.selectedSiteVisit,
        isLoading: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final propertyNotifierProvider =
    NotifierProvider<PropertyNotifier, PropertyState>(PropertyNotifier.new);

final propertiesProvider = Provider<List<Property>>((ref) {
  return ref.watch(propertyNotifierProvider).properties;
});

final propertyLoadingProvider = Provider<bool>((ref) {
  return ref.watch(propertyNotifierProvider).isLoading;
});

final propertyErrorProvider = Provider<String?>((ref) {
  return ref.watch(propertyNotifierProvider).error;
});

final unitsProvider = Provider<List<PropertyUnit>>((ref) {
  return ref.watch(propertyNotifierProvider).units;
});

final listingsProvider = Provider<List<PropertyListing>>((ref) {
  return ref.watch(propertyNotifierProvider).listings;
});

final enquiriesProvider = Provider<List<PropertyEnquiry>>((ref) {
  return ref.watch(propertyNotifierProvider).enquiries;
});

final dashboardStatsProvider = Provider<LandlordDashboardStats?>((ref) {
  return ref.watch(propertyNotifierProvider).dashboardStats;
});

final siteVisitsProvider = Provider<List<SiteVisit>>((ref) {
  return ref.watch(propertyNotifierProvider).siteVisits;
});

final selectedSiteVisitProvider = Provider<SiteVisit?>((ref) {
  return ref.watch(propertyNotifierProvider).selectedSiteVisit;
});

final siteVisitLoadingProvider = Provider<bool>((ref) {
  return ref.watch(propertyNotifierProvider).isLoading;
});

final siteVisitErrorProvider = Provider<String?>((ref) {
  return ref.watch(propertyNotifierProvider).error;
});
