// Movers repository interface.
import 'package:get_keja_mobile/features/movers/domain/entities/moving_service_model.dart';

abstract class MovingRepository {
  Future<List<MovingServiceModel>> getMovingRequests();

  Future<MovingServiceModel> submitMovingRequest({
    required String pickupUnitId,
    required String destinationAddress,
    required String preferredDateTime,
    required String itemDescription,
    String? specialInstructions,
    String? providerId,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  });
}
