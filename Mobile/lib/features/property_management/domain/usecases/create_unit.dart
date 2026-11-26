library features.property_management.domain.usecases.create_unit;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CreateUnit {
  CreateUnit(this._repository);

  final PropertyRepository _repository;

  Future<PropertyUnit> call({
    required String propertyId,
    required String unitNumber,
    required String unitType,
    String? building,
    int? floor,
    int? bedrooms,
    int? bathrooms,
    double? areaSqm,
    double? rentAmount,
    double? depositAmount,
    String? description,
    String? status,
    bool? hasSeparateMeter,
    String? meterNumber,
  }) {
    return _repository.createUnit(
      propertyId: propertyId,
      unitNumber: unitNumber,
      unitType: unitType,
      building: building,
      floor: floor,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      areaSqm: areaSqm,
      rentAmount: rentAmount,
      depositAmount: depositAmount,
      description: description,
      status: status,
      hasSeparateMeter: hasSeparateMeter,
      meterNumber: meterNumber,
    );
  }
}
