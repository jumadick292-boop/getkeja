library features.organizations.domain.usecases.create_organisation;

import '../entities/organisation.dart';
import '../repositories/organisation_repository.dart';

class CreateOrganisation {
  CreateOrganisation(this._repository);

  final OrganisationRepository _repository;

  Future<Organisation> call({
    required String name,
    required String slug,
    String? type,
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? city,
    String? county,
    String? country,
    String? registrationNumber,
    String? taxId,
    String? logoUrl,
    String? websiteUrl,
  }) {
    return _repository.createOrganisation(
      name: name,
      slug: slug,
      type: type,
      description: description,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      address: address,
      city: city,
      county: county,
      country: country,
      registrationNumber: registrationNumber,
      taxId: taxId,
      logoUrl: logoUrl,
      websiteUrl: websiteUrl,
    );
  }
}
