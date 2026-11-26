// Maintenance state management.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/maintenance/data/datasources/maintenance_remote_datasource.dart';
import 'package:get_keja_mobile/features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'package:get_keja_mobile/features/maintenance/domain/entities/maintenance_service_model.dart';
import 'package:get_keja_mobile/features/maintenance/domain/repositories/maintenance_repository.dart';

final maintenanceRemoteDataSourceProvider =
    Provider<MaintenanceRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MaintenanceRemoteDataSource(apiClient.dio);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepositoryImpl(ref.watch(maintenanceRemoteDataSourceProvider));
});

class MaintenanceSubmitState {
  const MaintenanceSubmitState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  final bool isLoading;
  final AppException? error;
  final MaintenanceServiceModel? success;
}

class MaintenanceNotifier extends Notifier<AsyncValue<List<MaintenanceServiceModel>>> {
  @override
  AsyncValue<List<MaintenanceServiceModel>> build() {
    return const AsyncValue.loading();
  }

  MaintenanceRepository get _repo => ref.read(maintenanceRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final requests = await _repo.getMaintenanceRequests();
      state = AsyncValue.data(requests);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<MaintenanceServiceModel> submitMaintenanceRequest({
    required String unitId,
    required String title,
    required String category,
    required String priority,
    required String description,
    List<String>? photos,
    String? accessInstructions,
    String? preferredAvailability,
  }) async {
    try {
      final created = await _repo.submitMaintenanceRequest(
        unitId: unitId,
        title: title,
        category: category,
        priority: priority,
        description: description,
        photos: photos,
        accessInstructions: accessInstructions,
        preferredAvailability: preferredAvailability,
      );
      await load();
      return created;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to submit maintenance request.',
        originalError: error,
      );
    }
  }
}

final maintenanceProvider =
    NotifierProvider<MaintenanceNotifier, AsyncValue<List<MaintenanceServiceModel>>>(
      MaintenanceNotifier.new,
    );

final maintenanceSubmitStateProvider =
    StateProvider<MaintenanceSubmitState>((ref) => const MaintenanceSubmitState());
