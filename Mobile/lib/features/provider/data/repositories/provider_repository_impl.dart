import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/provider/data/datasources/provider_remote_datasource.dart';
import 'package:get_keja_mobile/features/provider/domain/entities/provider_dashboard.dart';
import 'package:get_keja_mobile/features/provider/domain/repositories/provider_repository.dart';

class ProviderRepositoryImpl implements ProviderRepository {
  ProviderRepositoryImpl(this._remote);

  final ProviderRemoteDataSource _remote;

  @override
  Future<ProviderDashboard> getDashboard({String? organizationId}) async {
    try {
      final data = await _remote.getDashboard(organizationId: organizationId);
      return ProviderDashboard.fromJson(data);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load provider dashboard.',
        originalError: error,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listProfiles() async {
    try {
      return await _remote.listProfiles();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load profiles.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> body) async {
    try {
      return await _remote.createProfile(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create profile.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async {
    try {
      return await _remote.listOrganizations();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load organizations.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createOrganization(Map<String, dynamic> body) async {
    try {
      return await _remote.createOrganization(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create organization.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listStaff(String organizationId) async {
    try {
      return await _remote.listStaff(organizationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load staff.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> inviteStaff(
    String organizationId,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _remote.inviteStaff(organizationId, body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to invite staff.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> getCatalogue({String? domain}) async {
    try {
      return await _remote.getCatalogue(domain: domain);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load catalogue.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listOfferings({
    String? organizationId,
    String? domain,
    String? status,
  }) async {
    try {
      return await _remote.listOfferings(
        organizationId: organizationId,
        domain: domain,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load services.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createOffering(Map<String, dynamic> body) async {
    try {
      return await _remote.createOffering(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create service.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> getOffering(String serviceId) async {
    try {
      return await _remote.getOffering(serviceId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load service.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> updateOffering(
    String serviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _remote.updateOffering(serviceId, body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to update service.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> setOfferingStatus(
    String serviceId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    try {
      return await _remote.setOfferingStatus(serviceId, action, body: body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to change service status.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCapabilities(String serviceId) async {
    try {
      return await _remote.getCapabilities(serviceId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load capabilities.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> replaceCapabilities(
    String serviceId,
    List<Map<String, dynamic>> caps,
  ) async {
    try {
      return await _remote.replaceCapabilities(serviceId, caps);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to update capabilities.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>?> getPricing(String serviceId) async {
    try {
      return await _remote.getPricing(serviceId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load pricing.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> setPricing(
    String serviceId,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _remote.setPricing(serviceId, body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to update pricing.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listLocations({String? organizationId}) async {
    try {
      return await _remote.listLocations(organizationId: organizationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load locations.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> body) async {
    try {
      return await _remote.createLocation(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create location.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> updateLocation(
    String locationId,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _remote.updateLocation(locationId, body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to update location.', originalError: error);
    }
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    try {
      await _remote.deleteLocation(locationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to delete location.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> setPrimaryLocation(String locationId) async {
    try {
      return await _remote.setPrimaryLocation(locationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to set primary location.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listServiceAreas({
    String? profileId,
    String? offeringId,
  }) async {
    try {
      return await _remote.listServiceAreas(profileId: profileId, offeringId: offeringId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load service areas.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createServiceArea(Map<String, dynamic> body) async {
    try {
      return await _remote.createServiceArea(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create service area.', originalError: error);
    }
  }

  @override
  Future<void> deleteServiceArea(String areaId) async {
    try {
      await _remote.deleteServiceArea(areaId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to delete service area.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailability({
    String? profileId,
    String? offeringId,
  }) async {
    try {
      return await _remote.getAvailability(profileId: profileId, offeringId: offeringId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load availability.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> putAvailability(Map<String, dynamic> body) async {
    try {
      return await _remote.putAvailability(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to save availability.', originalError: error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listExceptions(
    String profileId, {
    String? offeringId,
  }) async {
    try {
      return await _remote.listExceptions(profileId, offeringId: offeringId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to load exceptions.', originalError: error);
    }
  }

  @override
  Future<Map<String, dynamic>> createException(Map<String, dynamic> body) async {
    try {
      return await _remote.createException(body);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to create exception.', originalError: error);
    }
  }

  @override
  Future<void> deleteException(String exceptionId) async {
    try {
      await _remote.deleteException(exceptionId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(message: 'Failed to delete exception.', originalError: error);
    }
  }
}