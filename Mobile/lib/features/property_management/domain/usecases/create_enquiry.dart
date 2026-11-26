library features.property_management.domain.usecases.create_enquiry;

import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CreateEnquiry {
  CreateEnquiry(this._repository);

  final PropertyRepository _repository;

  Future<PropertyEnquiry> call({
    required String propertyId,
    required String prospectiveRenterName,
    required String prospectiveRenterPhone,
    String? unitId,
    String? listingId,
    String? prospectiveRenterEmail,
    String? enquirySource,
    String? message,
  }) {
    return _repository.createEnquiry(
      propertyId: propertyId,
      prospectiveRenterName: prospectiveRenterName,
      prospectiveRenterPhone: prospectiveRenterPhone,
      unitId: unitId,
      listingId: listingId,
      prospectiveRenterEmail: prospectiveRenterEmail,
      enquirySource: enquirySource,
      message: message,
    );
  }
}
