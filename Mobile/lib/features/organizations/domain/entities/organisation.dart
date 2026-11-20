library features.organizations.domain.entities.organisation;

import 'package:equatable/equatable.dart';

class Organisation extends Equatable {
  const Organisation({
    required this.id,
    required this.name,
    required this.slug,
    this.type,
    this.description,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.city,
    this.county,
    this.country,
    this.registrationNumber,
    this.taxId,
    this.logoUrl,
    this.websiteUrl,
    this.isVerified = false,
    this.verificationStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? type;
  final String? description;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? city;
  final String? county;
  final String? country;
  final String? registrationNumber;
  final String? taxId;
  final String? logoUrl;
  final String? websiteUrl;
  final bool isVerified;
  final String? verificationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Organisation copyWith({
    String? id,
    String? name,
    String? slug,
    String? type,
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? city,
    final String? county,
    final String? country,
    final String? registrationNumber,
    final String? taxId,
    final String? logoUrl,
    final String? websiteUrl,
    final bool? isVerified,
    final String? verificationStatus,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) {
    return Organisation(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      type: type ?? this.type,
      description: description ?? this.description,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      city: city ?? this.city,
      county: county ?? this.county,
      country: country ?? this.country,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      taxId: taxId ?? this.taxId,
      logoUrl: logoUrl ?? this.logoUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        type,
        description,
        contactEmail,
        contactPhone,
        address,
        city,
        county,
        country,
        registrationNumber,
        taxId,
        logoUrl,
        websiteUrl,
        isVerified,
        verificationStatus,
        createdAt,
        updatedAt,
      ];
}

class OrganisationMember extends Equatable {
  const OrganisationMember({
    required this.id,
    required this.organisationId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.invitedAt,
    this.joinedAt,
    this.removedAt,
    this.removedBy,
    this.createdAt,
    this.updatedAt,
    this.email,
  });

  final String id;
  final String organisationId;
  final String userId;
  final String role;
  final String status;
  final String? invitedBy;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final DateTime? removedAt;
  final String? removedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? email;

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isActive => status.toLowerCase() == 'active';

  OrganisationMember copyWith({
    String? id,
    String? organisationId,
    String? userId,
    String? role,
    String? status,
    String? invitedBy,
    DateTime? invitedAt,
    DateTime? joinedAt,
    DateTime? removedAt,
    String? removedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
  }) {
    return OrganisationMember(
      id: id ?? this.id,
      organisationId: organisationId ?? this.organisationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedAt: invitedAt ?? this.invitedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      removedAt: removedAt ?? this.removedAt,
      removedBy: removedBy ?? this.removedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organisationId,
        userId,
        role,
        status,
        invitedBy,
        invitedAt,
        joinedAt,
        removedAt,
        removedBy,
        createdAt,
        updatedAt,
        email,
      ];
}

class OrganisationInvitation extends Equatable {
  const OrganisationInvitation({
    required this.id,
    required this.organisationId,
    required this.email,
    required this.role,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
    this.revokedAt,
    this.revokedBy,
    this.revokedReason,
    this.createdAt,
    this.updatedAt,
    this.invitedAt,
  });

  final String id;
  final String organisationId;
  final String email;
  final String role;
  final String invitedBy;
  final String status;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revokedReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? invitedAt;

  bool get isPending => status.toLowerCase() == 'pending';

  OrganisationInvitation copyWith({
    String? id,
    String? organisationId,
    String? email,
    String? role,
    String? invitedBy,
    String? status,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    DateTime? revokedAt,
    String? revokedBy,
    String? revokedReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? invitedAt,
  }) {
    return OrganisationInvitation(
      id: id ?? this.id,
      organisationId: organisationId ?? this.organisationId,
      email: email ?? this.email,
      role: role ?? this.role,
      invitedBy: invitedBy ?? this.invitedBy,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedBy: revokedBy ?? this.revokedBy,
      revokedReason: revokedReason ?? this.revokedReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invitedAt: invitedAt ?? this.invitedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organisationId,
        email,
        role,
        invitedBy,
        status,
        expiresAt,
        acceptedAt,
        acceptedBy,
        revokedAt,
        revokedBy,
        revokedReason,
        createdAt,
        updatedAt,
        invitedAt,
      ];
}
