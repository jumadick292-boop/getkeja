// Maintenance service repository interface.
import 'package:get_keja_mobile/features/maintenance/domain/entities/maintenance_service_model.dart';

abstract class MaintenanceRepository {
  Future<List<MaintenanceServiceModel>> getMaintenanceRequests();

  Future<MaintenanceServiceModel> submitMaintenanceRequest({
    required String unitId,
    required String title,
    required String category,
    required String priority,
    required String description,
    List<String>? photos,
    String? accessInstructions,
    String? preferredAvailability,
  });
}
