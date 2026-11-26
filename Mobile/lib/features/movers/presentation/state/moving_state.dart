// Movers state management.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/movers/data/datasources/moving_remote_datasource.dart';
import 'package:get_keja_mobile/features/movers/data/repositories/moving_repository_impl.dart';
import 'package:get_keja_mobile/features/movers/domain/entities/moving_service_model.dart';
import 'package:get_keja_mobile/features/movers/domain/repositories/moving_repository.dart';

final movingRemoteDataSourceProvider =
    Provider<MovingRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MovingRemoteDataSource(apiClient.dio);
});

final movingRepositoryProvider = Provider<MovingRepository>((ref) {
  return MovingRepositoryImpl(ref.watch(movingRemoteDataSourceProvider));
});

class MovingSubmitState {
  const MovingSubmitState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  final bool isLoading;
  final AppException? error;
  final MovingServiceModel? success;
}

class MovingNotifier extends Notifier<AsyncValue<List<MovingServiceModel>>> {
  @override
  AsyncValue<List<MovingServiceModel>> build() {
    return const AsyncValue.loading();
  }

  MovingRepository get _repo => ref.read(movingRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final requests = await _repo.getMovingRequests();
      state = AsyncValue.data(requests);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

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
      final created = await _repo.submitMovingRequest(
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
      await load();
      return created;
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

final movingProvider =
    NotifierProvider<MovingNotifier, AsyncValue<List<MovingServiceModel>>>(
      MovingNotifier.new,
    );

final movingSubmitStateProvider =
    StateProvider<MovingSubmitState>((ref) => const MovingSubmitState());
