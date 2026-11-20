library features.organizations.data.repositories.organisation_repository_impl;

import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/organizations/data/datasources/organisation_remote_datasource.dart';
import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';
import 'package:get_keja_mobile/features/organizations/domain/repositories/organisation_repository.dart';

class OrganisationRepositoryImpl implements OrganisationRepository {
  OrganisationRepositoryImpl(this._remoteDataSource);

  final OrganisationRemoteDataSource _remoteDataSource;

  factory OrganisationRepositoryImpl.fromApiClient(ApiClient apiClient) {
    return OrganisationRepositoryImpl(
      OrganisationRemoteDataSource(apiClient.dio),
    );
  }

  @override
  Future<List<Organisation>> getOrganisations() async {
    try {
      return await _remoteDataSource.getOrganisations();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load organisations',
        originalError: error,
      );
    }
  }

  @override
  Future<Organisation?> getOrganisation(String organisationId) async {
    try {
      return await _remoteDataSource.getOrganisation(organisationId);
    } on ServerException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load organisation',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.createOrganisation(
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
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create organisation',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remoteDataSource.updateOrganisation(
        organisationId: organisationId,
        name: name,
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
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update organisation',
        originalError: error,
      );
    }
  }

  @override
  Future<List<OrganisationMember>> getMembers(String organisationId) async {
    try {
      return await _remoteDataSource.getMembers(organisationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load members',
        originalError: error,
      );
    }
  }

  @override
  Future<OrganisationMember> updateMember({
    required String organisationId,
    required String memberId,
    String? role,
    String? status,
  }) async {
    try {
      return await _remoteDataSource.updateMember(
        organisationId: organisationId,
        memberId: memberId,
        role: role,
        status: status,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to update member',
        originalError: error,
      );
    }
  }

  @override
  Future<void> removeMember({
    required String organisationId,
    required String memberId,
  }) async {
    try {
      await _remoteDataSource.removeMember(
        organisationId: organisationId,
        memberId: memberId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to remove member',
        originalError: error,
      );
    }
  }

  @override
  Future<List<OrganisationInvitation>> getInvitations(
    String organisationId,
  ) async {
    try {
      return await _remoteDataSource.getInvitations(organisationId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load invitations',
        originalError: error,
      );
    }
  }

  @override
  Future<OrganisationInvitation> createInvitation({
    required String organisationId,
    required String email,
    required String role,
    DateTime? expiresAt,
  }) async {
    try {
      return await _remoteDataSource.createInvitation(
        organisationId: organisationId,
        email: email,
        role: role,
        expiresAt: expiresAt,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to create invitation',
        originalError: error,
      );
    }
  }

  @override
  Future<OrganisationMember> acceptInvitation({
    required String organisationId,
    required String token,
  }) async {
    try {
      return await _remoteDataSource.acceptInvitation(
        organisationId: organisationId,
        token: token,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to accept invitation',
        originalError: error,
      );
    }
  }

  @override
  Future<void> revokeInvitation({
    required String organisationId,
    required String invitationId,
    String? reason,
  }) async {
    try {
      await _remoteDataSource.revokeInvitation(
        organisationId: organisationId,
        invitationId: invitationId,
        reason: reason,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to revoke invitation',
        originalError: error,
      );
    }
  }
}
