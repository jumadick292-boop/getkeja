library features.property_management.domain.usecases.get_property;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetProperty {
  GetProperty(this._repository);

  final PropertyRepository _repository;

  Future<Property?> call(String propertyId) =>
      _repository.getProperty(propertyId);
}
