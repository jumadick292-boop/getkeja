import 'package:get_keja_mobile/features/provider/domain/entities/provider_dashboard.dart';

abstract class ProviderRepository {
  Future<ProviderDashboard> getDashboard({String? organizationId});

  Future<List<Map<String, dynamic>>> listProfiles();
  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body);

  Future<List<Map<String, dynamic>>> listOrganizations();
  Future<Map<String, dynamic>> createOrganization(Map<String, dynamic> body);

  Future<List<Map<String, dynamic>>> listStaff(String organizationId);
  Future<Map<String, dynamic>> inviteStaff(
    String organizationId,
    Map<String, dynamic> body,
  );

  // ---- Service catalogue (Task 13.4) ----
  Future<Map<String, dynamic>> getCatalogue({String? domain});
  Future<List<Map<String, dynamic>>> listOfferings({
    String? organizationId,
    String? domain,
    String? status,
  });
  Future<Map<String, dynamic>> createOffering(Map<String, dynamic> body);
  Future<Map<String, dynamic>> getOffering(String serviceId);
  Future<Map<String, dynamic>> updateOffering(
    String serviceId,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> setOfferingStatus(
    String serviceId,
    String action, {
    Map<String, dynamic>? body,
  });

  Future<List<Map<String, dynamic>>> getCapabilities(String serviceId);
  Future<List<Map<String, dynamic>>> replaceCapabilities(
    String serviceId,
    List<Map<String, dynamic>> caps,
  );
  Future<Map<String, dynamic>?> getPricing(String serviceId);
  Future<Map<String, dynamic>> setPricing(
    String serviceId,
    Map<String, dynamic> body,
  );

  Future<List<Map<String, dynamic>>> listLocations({String? organizationId});
  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> body);
  Future<Map<String, dynamic>> updateLocation(
    String locationId,
    Map<String, dynamic> body,
  );
  Future<void> deleteLocation(String locationId);
  Future<Map<String, dynamic>> setPrimaryLocation(String locationId);

  Future<List<Map<String, dynamic>>> listServiceAreas({
    String? profileId,
    String? offeringId,
  });
  Future<Map<String, dynamic>> createServiceArea(Map<String, dynamic> body);
  Future<void> deleteServiceArea(String areaId);

  Future<List<Map<String, dynamic>>> getAvailability({
    String? profileId,
    String? offeringId,
  });
  Future<List<Map<String, dynamic>>> putAvailability(Map<String, dynamic> body);
  Future<List<Map<String, dynamic>>> listExceptions(
    String profileId, {
    String? offeringId,
  });
  Future<Map<String, dynamic>> createException(Map<String, dynamic> body);
  Future<void> deleteException(String exceptionId);
}