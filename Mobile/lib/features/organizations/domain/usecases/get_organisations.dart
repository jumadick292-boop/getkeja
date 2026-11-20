library features.organizations.domain.usecases.get_organisations;

import '../entities/organisation.dart';
import '../repositories/organisation_repository.dart';

class GetOrganisations {
  GetOrganisations(this._repository);

  final OrganisationRepository _repository;

  Future<List<Organisation>> call() => _repository.getOrganisations();
}
