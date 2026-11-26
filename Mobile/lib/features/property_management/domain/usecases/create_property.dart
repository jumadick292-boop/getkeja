library features.property_management.domain.usecases.create_property;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CreateProperty {
  CreateProperty(this._repository);

  final PropertyRepository _repository;

  Future<Property> call({
    required String title,
    required String propertyType,
    required String address,
    required String city,
    required String county,
    String? description,
    String? country,
    int? totalUnits,
    String? status,
  }) {
    return _repository.createProperty(
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
  }
}
