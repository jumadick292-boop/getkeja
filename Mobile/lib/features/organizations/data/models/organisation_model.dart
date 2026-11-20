library features.organizations.data.models.organisation_model;

import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';

class OrganisationModel extends Organisation {
  const OrganisationModel({
    required super.id,
    required super.name,
    required super.slug,
    super.type,
    super.description,
    super.contactEmail,
    super.contactPhone,
    super.address,
    super.city,
    super.county,
    super.country,
    super.registrationNumber,
    super.taxId,
    super.logoUrl,
    super.websiteUrl,
    super.isVerified = false,
    super.verificationStatus,
    super.createdAt,
    super.updatedAt,
  });

  factory OrganisationModel.fromJson(Map<String, dynamic> json) {
    return OrganisationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String?,
      description: json['description'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      country: json['country'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      taxId: json['taxId'] as String?,
      logoUrl: json['logoUrl'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'type': type,
      'description': description,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'address': address,
      'city': city,
      'county': county,
      'country': country,
      'registrationNumber': registrationNumber,
      'taxId': taxId,
      'logoUrl': logoUrl,
      'websiteUrl': websiteUrl,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class OrganisationMemberModel extends OrganisationMember {
  const OrganisationMemberModel({
    required super.id,
    required super.organisationId,
    required super.userId,
    required super.role,
    required super.status,
    super.invitedBy,
    super.invitedAt,
    super.joinedAt,
    super.removedAt,
    super.removedBy,
    super.createdAt,
    super.updatedAt,
    super.email,
  });

  factory OrganisationMemberModel.fromJson(Map<String, dynamic> json) {
    return OrganisationMemberModel(
      id: json['id'] as String,
      organisationId: json['organisationId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      invitedBy: json['invitedBy'] as String?,
      invitedAt: json['invitedAt'] != null
          ? DateTime.parse(json['invitedAt'] as String)
          : null,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
      removedAt: json['removedAt'] != null
          ? DateTime.parse(json['removedAt'] as String)
          : null,
      removedBy: json['removedBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'organisationId': organisationId,
      'userId': userId,
      'role': role,
      'status': status,
      'invitedBy': invitedBy,
      'invitedAt': invitedAt?.toIso8601String(),
      'joinedAt': joinedAt?.toIso8601String(),
      'removedAt': removedAt?.toIso8601String(),
      'removedBy': removedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'email': email,
    };
  }
}

class OrganisationInvitationModel extends OrganisationInvitation {
  const OrganisationInvitationModel({
    required super.id,
    required super.organisationId,
    required super.email,
    required super.role,
    required super.invitedBy,
    required super.status,
    required super.expiresAt,
    super.acceptedAt,
    super.acceptedBy,
    super.revokedAt,
    super.revokedBy,
    super.revokedReason,
    super.createdAt,
    super.updatedAt,
    super.invitedAt,
  });

  factory OrganisationInvitationModel.fromJson(Map<String, dynamic> json) {
    return OrganisationInvitationModel(
      id: json['id'] as String,
      organisationId: json['organisationId'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      invitedBy: json['invitedBy'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      acceptedBy: json['acceptedBy'] as String?,
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String)
          : null,
      revokedBy: json['revokedBy'] as String?,
      revokedReason: json['revokedReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      invitedAt: json['invitedAt'] != null
          ? DateTime.parse(json['invitedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'organisationId': organisationId,
      'email': email,
      'role': role,
      'invitedBy': invitedBy,
      'status': status,
      'expiresAt': expiresAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'acceptedBy': acceptedBy,
      'revokedAt': revokedAt?.toIso8601String(),
      'revokedBy': revokedBy,
      'revokedReason': revokedReason,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'invitedAt': invitedAt?.toIso8601String(),
    };
  }
}
