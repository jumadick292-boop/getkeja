// Laundries repository implementation.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/laundries/data/datasources/laundry_remote_datasource.dart';
import 'package:get_keja_mobile/features/laundries/domain/entities/laundry_service_model.dart';
import 'package:get_keja_mobile/features/laundries/domain/repositories/laundry_repository.dart';

class LaundryRepositoryImpl implements LaundryRepository {
  LaundryRepositoryImpl(this._remote);

  final LaundryRemoteDataSource _remote;

  @override
  Future<List<LaundryServiceModel>> getLaundryRequests() async {
    try {
      return await _remote.getLaundryRequests();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load laundry requests.',
        originalError: error,
      );
    }
  }

  @override
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
  }) async {
    try {
      return await _remote.submitLaundryRequest(
        providerId: providerId,
        serviceCategory: serviceCategory,
        collectionPreference: collectionPreference,
        preferredDateTime: preferredDateTime,
        garmentCount: garmentCount,
        specialInstructions: specialInstructions,
        contactName: contactName,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to submit laundry request.',
        originalError: error,
      );
    }
  }
}
