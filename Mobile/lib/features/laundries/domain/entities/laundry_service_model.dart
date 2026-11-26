// Laundry service model.
class LaundryServiceModel {
  LaundryServiceModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
    required this.status,
    this.collectionPreference,
    this.preferredDateTime,
    this.garmentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String serviceType;
  final String status;
  final String? collectionPreference;
  final String? preferredDateTime;
  final int? garmentCount;
  final String createdAt;
  final String updatedAt;

  factory LaundryServiceModel.fromJson(Map<String, dynamic> json) {
    return LaundryServiceModel(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      serviceType: json['serviceType'] as String,
      status: json['status'] as String,
      collectionPreference: json['collectionPreference'] as String?,
      preferredDateTime: json['preferredDateTime'] as String?,
      garmentCount: json['garmentCount'] as int?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
