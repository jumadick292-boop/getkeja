library features.property_management.domain.usecases.get_dashboard_stats;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetDashboardStats {
  GetDashboardStats(this._repository);

  final PropertyRepository _repository;

  Future<LandlordDashboardStats> call({String? propertyId}) =>
      _repository.getDashboardStats(propertyId: propertyId);
}
