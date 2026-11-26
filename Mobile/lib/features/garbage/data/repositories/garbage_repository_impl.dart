// Garbage repository implementation.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/garbage/data/datasources/garbage_remote_datasource.dart';
import 'package:get_keja_mobile/features/garbage/domain/entities/garbage_service_model.dart';
import 'package:get_keja_mobile/features/garbage/domain/repositories/garbage_repository.dart';

class GarbageRepositoryImpl implements GarbageRepository {
  GarbageRepositoryImpl(this._remote);

  final GarbageRemoteDataSource _remote;

  @override
  Future<List<GarbageServiceModel>> getGarbageRequests() async {
    try {
      return await _remote.getGarbageRequests();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load garbage requests.',
        originalError: error,
      );
    }
  }

  @override
  Future<GarbageServiceModel> submitGarbageRequest({
    required String unitId,
    required String category,
    required String description,
    String? preferredDate,
  }) async {
    try {
      return await _remote.submitGarbageRequest(
        unitId: unitId,
        category: category,
        description: description,
        preferredDate: preferredDate,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to submit garbage request.',
        originalError: error,
      );
    }
  }
}
