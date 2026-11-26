// Laundry service repository interface.
import 'package:get_keja_mobile/features/laundries/domain/entities/laundry_service_model.dart';

abstract class LaundryRepository {
  Future<List<LaundryServiceModel>> getLaundryRequests();

  Future<LaundryServiceModel> submitLaundryRequest({
    required String providerId,
    required String serviceCategory,
    required String collectionPreference,
    required String preferredDateTime,
    required int garmentCount,
    String? specialInstructions,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  });
}
