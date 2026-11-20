library features.organizations.domain.repositories.organisation_repository;

import '../entities/organisation.dart';

abstract class OrganisationRepository {
  Future<List<Organisation>> getOrganisations();

  Future<Organisation?> getOrganisation(String organisationId);

  Future<Organisation> createOrganisation({
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
  });

  Future<Organisation> updateOrganisation({
    required String organisationId,
    String? name,
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
  });

  Future<List<OrganisationMember>> getMembers(String organisationId);

  Future<OrganisationMember> updateMember({
    required String organisationId,
    required String memberId,
    String? role,
    String? status,
  });

  Future<void> removeMember({
    required String organisationId,
    required String memberId,
  });

  Future<List<OrganisationInvitation>> getInvitations(String organisationId);

  Future<OrganisationInvitation> createInvitation({
    required String organisationId,
    required String email,
    required String role,
    DateTime? expiresAt,
  });

  Future<OrganisationMember> acceptInvitation({
    required String organisationId,
    required String token,
  });

  Future<void> revokeInvitation({
    required String organisationId,
    required String invitationId,
    String? reason,
  });
}
