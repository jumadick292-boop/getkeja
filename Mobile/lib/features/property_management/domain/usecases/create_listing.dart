library features.property_management.domain.usecases.create_listing;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CreateListing {
  CreateListing(this._repository);

  final PropertyRepository _repository;

  Future<PropertyListing> call({
    required String propertyId,
    required String title,
    double? rentAmount,
    double? depositAmount,
    String? unitId,
    String? description,
    DateTime? availableFrom,
    bool? furnished,
    String? petPolicy,
    bool? smokingAllowed,
  }) {
    return _repository.createListing(
      propertyId: propertyId,
      title: title,
      rentAmount: rentAmount,
      depositAmount: depositAmount,
      unitId: unitId,
      description: description,
      availableFrom: availableFrom,
      furnished: furnished,
      petPolicy: petPolicy,
      smokingAllowed: smokingAllowed,
    );
  }
}
