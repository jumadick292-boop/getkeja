// Garbage state management.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/garbage/data/datasources/garbage_remote_datasource.dart';
import 'package:get_keja_mobile/features/garbage/data/repositories/garbage_repository_impl.dart';
import 'package:get_keja_mobile/features/garbage/domain/entities/garbage_service_model.dart';
import 'package:get_keja_mobile/features/garbage/domain/repositories/garbage_repository.dart';

final garbageRemoteDataSourceProvider =
    Provider<GarbageRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GarbageRemoteDataSource(apiClient.dio);
});

final garbageRepositoryProvider = Provider<GarbageRepository>((ref) {
  return GarbageRepositoryImpl(ref.watch(garbageRemoteDataSourceProvider));
});

class GarbageSubmitState {
  const GarbageSubmitState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  final bool isLoading;
  final AppException? error;
  final GarbageServiceModel? success;
}

class GarbageNotifier extends Notifier<AsyncValue<List<GarbageServiceModel>>> {
  @override
  AsyncValue<List<GarbageServiceModel>> build() {
    return const AsyncValue.loading();
  }

  GarbageRepository get _repo => ref.read(garbageRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final services = await _repo.getGarbageRequests();
      state = AsyncValue.data(services);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

  /// Submits a new garbage collection request. Returns the created request on
  /// success, or throws an [AppException] on failure.
  Future<GarbageServiceModel> submitGarbageRequest({
    required String unitId,
    required String category,
    required String description,
    String? preferredDate,
  }) async {
    try {
      final created = await _repo.submitGarbageRequest(
        unitId: unitId,
        category: category,
        description: description,
        preferredDate: preferredDate,
      );
      // Refresh the list so the new request appears without a restart.
      await load();
      return created;
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

final garbageProvider =
    NotifierProvider<GarbageNotifier, AsyncValue<List<GarbageServiceModel>>>(
      GarbageNotifier.new,
    );

final garbageSubmitStateProvider =
    StateProvider<GarbageSubmitState>((ref) => const GarbageSubmitState());
