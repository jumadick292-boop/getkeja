// Maintenance repository implementation.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/maintenance/data/datasources/maintenance_remote_datasource.dart';
import 'package:get_keja_mobile/features/maintenance/domain/entities/maintenance_service_model.dart';
import 'package:get_keja_mobile/features/maintenance/domain/repositories/maintenance_repository.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._remote);

  final MaintenanceRemoteDataSource _remote;

  @override
  Future<List<MaintenanceServiceModel>> getMaintenanceRequests() async {
    try {
      return await _remote.getMaintenanceRequests();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load maintenance requests.',
        originalError: error,
      );
    }
  }

  @override
  Future<MaintenanceServiceModel> submitMaintenanceRequest({
    required String unitId,
    required String title,
    required String category,
    required String priority,
    required String description,
    List<String>? photos,
    String? accessInstructions,
    String? preferredAvailability,
  }) async {
    try {
      return await _remote.submitMaintenanceRequest(
        unitId: unitId,
        title: title,
        category: category,
        priority: priority,
        description: description,
        photos: photos,
        accessInstructions: accessInstructions,
        preferredAvailability: preferredAvailability,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to submit maintenance request.',
        originalError: error,
      );
    }
  }
}
