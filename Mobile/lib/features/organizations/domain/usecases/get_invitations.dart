library features.organizations.domain.usecases.get_invitations;

import '../entities/organisation.dart';
import '../repositories/organisation_repository.dart';

class GetInvitations {
  GetInvitations(this._repository);

  final OrganisationRepository _repository;

  Future<List<OrganisationInvitation>> call(String organisationId) =>
      _repository.getInvitations(organisationId);
}
