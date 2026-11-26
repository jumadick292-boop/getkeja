// Garbage service repository interface.
import 'package:get_keja_mobile/features/garbage/domain/entities/garbage_service_model.dart';

abstract class GarbageRepository {
  Future<List<GarbageServiceModel>> getGarbageRequests();

  Future<GarbageServiceModel> submitGarbageRequest({
    required String unitId,
    required String category,
    required String description,
    String? preferredDate,
  });
}
