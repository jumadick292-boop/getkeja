library features.property_management.domain.usecases.get_listings;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetListings {
  GetListings(this._repository);

  final PropertyRepository _repository;

  Future<List<PropertyListing>> call({String? propertyId, String? status}) {
    return _repository.getListings(propertyId: propertyId, status: status);
  }
}
