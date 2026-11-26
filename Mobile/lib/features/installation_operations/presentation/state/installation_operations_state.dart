// Installation & Technical Services state (Task 13.14) — Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/installation_operations/data/datasources/installation_operations_remote_datasource.dart';

final installationOperationsRemoteDataSourceProvider =
    Provider<InstallationOperationsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InstallationOperationsRemoteDataSource(apiClient.dio);
});

final customerInstallationJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(installationOperationsRemoteDataSourceProvider).listCustomerJobs();
});

final customerInstallationJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(installationOperationsRemoteDataSourceProvider).getCustomerJob(jobId),
);

final providerInstallationJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(installationOperationsRemoteDataSourceProvider).listProviderJobs();
});

final providerInstallationJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(installationOperationsRemoteDataSourceProvider).getProviderJob(jobId),
);