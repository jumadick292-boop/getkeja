library features.property_management.domain.usecases.get_units;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetUnits {
  GetUnits(this._repository);

  final PropertyRepository _repository;

  Future<List<PropertyUnit>> call({
    String? propertyId,
    String? status,
    String? unitType,
  }) {
    return _repository.getUnits(
      propertyId: propertyId,
      status: status,
      unitType: unitType,
    );
  }
}
