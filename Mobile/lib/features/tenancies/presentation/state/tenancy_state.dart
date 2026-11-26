// Tenancy state management.
// Provides Riverpod providers for fetching and managing tenant tenancy data.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/tenancies/data/datasources/tenancy_remote_datasource.dart';
import 'package:get_keja_mobile/features/tenancies/data/repositories/tenancy_repository_impl.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';
import 'package:get_keja_mobile/features/tenancies/domain/repositories/tenancy_repository.dart';

final tenancyRemoteDataSourceProvider =
    Provider<TenancyRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenancyRemoteDataSource(apiClient.dio);
});

final tenancyRepositoryProvider = Provider<TenancyRepository>((ref) {
  return TenancyRepositoryImpl(
    ref.watch(tenancyRemoteDataSourceProvider),
  );
});

class TenancyNotifier extends Notifier<AsyncValue<List<TenancyModel>>> {
  @override
  AsyncValue<List<TenancyModel>> build() {
    return const AsyncValue.loading();
  }

  TenancyRepository get _repo => ref.read(tenancyRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      final tenancies = await _repo.getTenancies(status: status);
      state = AsyncValue.data(tenancies);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }
}

final tenancyProvider =
    NotifierProvider<TenancyNotifier, AsyncValue<List<TenancyModel>>>(
      TenancyNotifier.new,
    );

final tenantDashboardProvider = FutureProvider<TenantDashboardModel>((ref) async {
  final repo = ref.watch(tenancyRepositoryProvider);
  return repo.getDashboard();
});
