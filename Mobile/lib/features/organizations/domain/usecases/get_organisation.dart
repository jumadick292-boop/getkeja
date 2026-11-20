library features.organizations.domain.usecases.get_organisation;

import '../entities/organisation.dart';
import '../repositories/organisation_repository.dart';

class GetOrganisation {
  GetOrganisation(this._repository);

  final OrganisationRepository _repository;

  Future<Organisation?> call(String organisationId) =>
      _repository.getOrganisation(organisationId);
}
