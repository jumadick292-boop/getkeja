// Garbage service model.
class GarbageServiceModel {
  GarbageServiceModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.status,
    this.description,
    this.preferredDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String category;
  final String status;
  final String? description;
  final String? preferredDate;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;

  factory GarbageServiceModel.fromJson(Map<String, dynamic> json) {
    return GarbageServiceModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      preferredDate: json['preferredDate'] as String?,
      completedAt: json['completedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class GarbageServiceListResponse {
  GarbageServiceListResponse({
    required this.services,
    required this.success,
  });

  final List<GarbageServiceModel> services;
  final bool success;

  factory GarbageServiceListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] as List<dynamic>? ?? <dynamic>[]);
    return GarbageServiceListResponse(
      services: raw
          .whereType<Map<String, dynamic>>()
          .map(GarbageServiceModel.fromJson)
          .toList(growable: false),
      success: json['success'] as bool? ?? true,
    );
  }
}
