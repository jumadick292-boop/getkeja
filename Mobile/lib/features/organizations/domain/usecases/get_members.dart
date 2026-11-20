library features.organizations.domain.usecases.get_members;

import '../entities/organisation.dart';
import '../repositories/organisation_repository.dart';

class GetMembers {
  GetMembers(this._repository);

  final OrganisationRepository _repository;

  Future<List<OrganisationMember>> call(String organisationId) =>
      _repository.getMembers(organisationId);
}
