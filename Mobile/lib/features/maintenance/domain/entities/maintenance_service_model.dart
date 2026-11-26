// Maintenance service model.
class MaintenanceServiceModel {
  MaintenanceServiceModel({
    required this.id,
    required this.propertyId,
    required this.unitId,
    required this.tenancyId,
    required this.reporterId,
    required this.reporterRole,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedToUserId,
    this.assignedToOrganisationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? unitId;
  final String? tenancyId;
  final String reporterId;
  final String reporterRole;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedToUserId;
  final String? assignedToOrganisationId;
  final String createdAt;
  final String updatedAt;

  factory MaintenanceServiceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceServiceModel(
      id: json['id'] as String,
      propertyId: json['propertyId'] as String,
      unitId: json['unitId'] as String?,
      tenancyId: json['tenancyId'] as String?,
      reporterId: json['reporterId'] as String,
      reporterRole: json['reporterRole'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      assignedToUserId: json['assignedToUserId'] as String?,
      assignedToOrganisationId: json['assignedToOrganisationId'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class MaintenanceServiceListResponse {
  MaintenanceServiceListResponse({
    required this.services,
    required this.success,
  });

  final List<MaintenanceServiceModel> services;
  final bool success;

  factory MaintenanceServiceListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List<dynamic>? ?? <dynamic>[]);
    return MaintenanceServiceListResponse(
      services: raw
          .whereType<Map<String, dynamic>>()
          .map(MaintenanceServiceModel.fromJson)
          .toList(growable: false),
      success: json['success'] as bool? ?? true,
    );
  }
}
