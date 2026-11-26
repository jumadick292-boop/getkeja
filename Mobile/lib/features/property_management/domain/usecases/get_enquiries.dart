library features.property_management.domain.usecases.get_enquiries;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetEnquiries {
  GetEnquiries(this._repository);

  final PropertyRepository _repository;

  Future<List<PropertyEnquiry>> call({String? propertyId, String? status}) {
    return _repository.getEnquiries(propertyId: propertyId, status: status);
  }
}
