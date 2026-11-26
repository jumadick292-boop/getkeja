// Home Maintenance state (Task 13.12) — Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/home_maintenance/data/datasources/home_maintenance_remote_datasource.dart';

final homeMaintenanceRemoteDataSourceProvider =
    Provider<HomeMaintenanceRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HomeMaintenanceRemoteDataSource(apiClient.dio);
});

final customerHomeMaintenanceJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(homeMaintenanceRemoteDataSourceProvider).listCustomerJobs();
});

final customerHomeMaintenanceJobDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(homeMaintenanceRemoteDataSourceProvider).getCustomerJob(jobId),
);

final providerHomeMaintenanceJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(homeMaintenanceRemoteDataSourceProvider).listProviderJobs();
});

final providerHomeMaintenanceJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(homeMaintenanceRemoteDataSourceProvider).getProviderJob(jobId),
);