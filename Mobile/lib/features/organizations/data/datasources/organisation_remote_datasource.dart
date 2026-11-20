library features.organizations.data.datasources.organisation_remote_datasource;

import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/organizations/data/models/organisation_model.dart';

class OrganisationRemoteDataSource {
  OrganisationRemoteDataSource(this._dio);

  final Dio _dio;

  static const String _basePath = '/organisations';

  Future<List<OrganisationModel>> getOrganisations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_basePath);
      final data = response.data?['organisations'] as List<dynamic>?;
      if (data == null) return <OrganisationModel>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => OrganisationModel.fromJson(json))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationModel> getOrganisation(String organisationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/$organisationId',
      );
      final data = response.data?['organisation'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Organization not found',
          statusCode: 404,
        );
      }
      return OrganisationModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationModel> createOrganisation({
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
      final response = await _dio.post<Map<String, dynamic>>(
        _basePath,
        data: <String, dynamic>{
          'name': name,
          'slug': slug,
          if (type != null) 'type': type,
          if (description != null) 'description': description,
          if (contactEmail != null) 'contactEmail': contactEmail,
          if (contactPhone != null) 'contactPhone': contactPhone,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (county != null) 'county': county,
          if (country != null) 'country': country,
          if (registrationNumber != null)
            'registrationNumber': registrationNumber,
          if (taxId != null) 'taxId': taxId,
          if (logoUrl != null) 'logoUrl': logoUrl,
          if (websiteUrl != null) 'websiteUrl': websiteUrl,
        },
      );
      final data = response.data?['organisation'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Failed to create organization',
          statusCode: 500,
        );
      }
      return OrganisationModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationModel> updateOrganisation({
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
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/$organisationId',
        data: <String, dynamic>{
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (contactEmail != null) 'contactEmail': contactEmail,
          if (contactPhone != null) 'contactPhone': contactPhone,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (county != null) 'county': county,
          if (country != null) 'country': country,
          if (registrationNumber != null)
            'registrationNumber': registrationNumber,
          if (taxId != null) 'taxId': taxId,
          if (logoUrl != null) 'logoUrl': logoUrl,
          if (websiteUrl != null) 'websiteUrl': websiteUrl,
        },
      );
      final data = response.data?['organisation'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Failed to update organization',
          statusCode: 500,
        );
      }
      return OrganisationModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<OrganisationMemberModel>> getMembers(
    String organisationId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/$organisationId/members',
      );
      final data = response.data?['members'] as List<dynamic>?;
      if (data == null) return <OrganisationMemberModel>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => OrganisationMemberModel.fromJson(json))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationMemberModel> updateMember({
    required String organisationId,
    required String memberId,
    String? role,
    String? status,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '$_basePath/$organisationId/members/$memberId',
        data: <String, dynamic>{
          if (role != null) 'role': role,
          if (status != null) 'status': status,
        },
      );
      final data = response.data?['member'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Member not found',
          statusCode: 404,
        );
      }
      return OrganisationMemberModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> removeMember({
    required String organisationId,
    required String memberId,
  }) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/$organisationId/members/$memberId',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<OrganisationInvitationModel>> getInvitations(
    String organisationId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/$organisationId/invitations',
      );
      final data = response.data?['invitations'] as List<dynamic>?;
      if (data == null) return <OrganisationInvitationModel>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => OrganisationInvitationModel.fromJson(json))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationInvitationModel> createInvitation({
    required String organisationId,
    required String email,
    required String role,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/$organisationId/invitations',
        data: <String, dynamic>{
          'email': email,
          'role': role,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        },
      );
      final data = response.data?['invitation'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Failed to create invitation',
          statusCode: 500,
        );
      }
      return OrganisationInvitationModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<OrganisationMemberModel> acceptInvitation({
    required String organisationId,
    required String token,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/$organisationId/invitations/accept',
        data: <String, dynamic>{'token': token},
      );
      final data = response.data?['member'];
      if (data == null || data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Invalid invitation',
          statusCode: 404,
        );
      }
      return OrganisationMemberModel.fromJson(data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> revokeInvitation({
    required String organisationId,
    required String invitationId,
    String? reason,
  }) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '$_basePath/$organisationId/invitations/$invitationId',
        data: reason != null ? <String, dynamic>{'reason': reason} : null,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  AppException _mapError(final Object error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      final message =
          (data is Map<String, dynamic> && data['message'] is String)
              ? data['message'] as String
              : 'An error occurred';
      final statusCode = response?.statusCode;
      switch (statusCode) {
        case 401:
          return UnauthorizedException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        case 403:
          return ForbiddenException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        case 429:
          return RateLimitException(
            message: message,
            statusCode: statusCode ?? 0,
            originalError: error,
          );
        case 404:
          return ServerException(
            message: message,
            statusCode: statusCode ?? 0,
            originalError: error,
          );
        case 400:
        case 409:
        case 422:
          return ValidationException(
            message,
            statusCode: statusCode,
            originalError: error,
          );
        default:
          return ServerException(
            message: message,
            statusCode: statusCode ?? 500,
            originalError: error,
          );
      }
    }
    return ServerException(
      message: error.toString(),
      originalError: error,
    );
  }
}
