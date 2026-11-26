// Movers repository implementation.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/movers/data/datasources/moving_remote_datasource.dart';
import 'package:get_keja_mobile/features/movers/domain/entities/moving_service_model.dart';
import 'package:get_keja_mobile/features/movers/domain/repositories/moving_repository.dart';

class MovingRepositoryImpl implements MovingRepository {
  MovingRepositoryImpl(this._remote);

  final MovingRemoteDataSource _remote;

  @override
  Future<List<MovingServiceModel>> getMovingRequests() async {
    try {
      return await _remote.getMovingRequests();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load moving requests.',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remote.submitMovingRequest(
        pickupUnitId: pickupUnitId,
        destinationAddress: destinationAddress,
        preferredDateTime: preferredDateTime,
        itemDescription: itemDescription,
        specialInstructions: specialInstructions,
        providerId: providerId,
        contactName: contactName,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to submit moving request.',
        originalError: error,
      );
    }
  }
}
