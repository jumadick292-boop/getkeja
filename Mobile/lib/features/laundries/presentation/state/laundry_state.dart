// Laundries state management.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/laundries/data/datasources/laundry_remote_datasource.dart';
import 'package:get_keja_mobile/features/laundries/data/repositories/laundry_repository_impl.dart';
import 'package:get_keja_mobile/features/laundries/domain/entities/laundry_service_model.dart';
import 'package:get_keja_mobile/features/laundries/domain/repositories/laundry_repository.dart';

final laundryRemoteDataSourceProvider =
    Provider<LaundryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LaundryRemoteDataSource(apiClient.dio);
});

final laundryRepositoryProvider = Provider<LaundryRepository>((ref) {
  return LaundryRepositoryImpl(ref.watch(laundryRemoteDataSourceProvider));
});

class LaundrySubmitState {
  const LaundrySubmitState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  final bool isLoading;
  final AppException? error;
  final LaundryServiceModel? success;
}

class LaundryNotifier extends Notifier<AsyncValue<List<LaundryServiceModel>>> {
  @override
  AsyncValue<List<LaundryServiceModel>> build() {
    return const AsyncValue.loading();
  }

  LaundryRepository get _repo => ref.read(laundryRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final requests = await _repo.getLaundryRequests();
      state = AsyncValue.data(requests);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

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
      final created = await _repo.submitLaundryRequest(
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
      await load();
      return created;
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

final laundryProvider =
    NotifierProvider<LaundryNotifier, AsyncValue<List<LaundryServiceModel>>>(
      LaundryNotifier.new,
    );

final laundrySubmitStateProvider =
    StateProvider<LaundrySubmitState>((ref) => const LaundrySubmitState());
