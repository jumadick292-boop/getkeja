// Provider state management (foundation).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/provider/data/datasources/provider_remote_datasource.dart';
import 'package:get_keja_mobile/features/provider/data/repositories/provider_repository_impl.dart';
import 'package:get_keja_mobile/features/provider/domain/entities/provider_dashboard.dart';
import 'package:get_keja_mobile/features/provider/domain/repositories/provider_repository.dart';

final providerRemoteDataSourceProvider = Provider<ProviderRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProviderRemoteDataSource(apiClient.dio);
});

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepositoryImpl(ref.watch(providerRemoteDataSourceProvider));
});

class ProviderDashboardNotifier
    extends Notifier<AsyncValue<ProviderDashboard>> {
  @override
  AsyncValue<ProviderDashboard> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load({String? organizationId}) async {
    state = const AsyncValue.loading();
    try {
      final dashboard = await _repo.getDashboard(organizationId: organizationId);
      state = AsyncValue.data(dashboard);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerDashboardProvider = NotifierProvider<
    ProviderDashboardNotifier, AsyncValue<ProviderDashboard>>(
  ProviderDashboardNotifier.new,
);

class ProviderOrganizationsNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listOrganizations());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerOrganizationsProvider = NotifierProvider<
    ProviderOrganizationsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderOrganizationsNotifier.new,
);

class ProviderServicesNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load({String? organizationId, String? domain, String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repo.listOfferings(
          organizationId: organizationId,
          domain: domain,
          status: status,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerServicesProvider = NotifierProvider<
    ProviderServicesNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderServicesNotifier.new,
);

class ProviderLocationsNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load({String? organizationId}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listLocations(organizationId: organizationId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerLocationsProvider = NotifierProvider<
    ProviderLocationsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderLocationsNotifier.new,
);

class ProviderServiceAreasNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load({String? profileId, String? offeringId}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repo.listServiceAreas(profileId: profileId, offeringId: offeringId),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerServiceAreasProvider = NotifierProvider<
    ProviderServiceAreasNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderServiceAreasNotifier.new,
);

class ProviderAvailabilityNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    return const AsyncValue.loading();
  }

  ProviderRepository get _repo => ref.read(providerRepositoryProvider);

  Future<void> load({String? profileId, String? offeringId}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repo.getAvailability(profileId: profileId, offeringId: offeringId),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerAvailabilityProvider = NotifierProvider<
    ProviderAvailabilityNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderAvailabilityNotifier.new,
);