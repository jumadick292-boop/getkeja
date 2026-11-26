library features.property_management.domain.usecases.get_properties;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetProperties {
  GetProperties(this._repository);

  final PropertyRepository _repository;

  Future<List<Property>> call({String? status, String? city}) =>
      _repository.getProperties(status: status, city: city);
}
