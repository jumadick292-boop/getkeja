// Movers service model.
class MovingServiceModel {
  MovingServiceModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.status,
    this.description,
    this.preferredDateTime,
    this.itemDescription,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String status;
  final String? description;
  final String? preferredDateTime;
  final String? itemDescription;
  final String createdAt;
  final String updatedAt;

  factory MovingServiceModel.fromJson(Map<String, dynamic> json) {
    return MovingServiceModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      preferredDateTime: json['preferredDateTime'] as String?,
      itemDescription: json['itemDescription'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
