// Finishing & Building Services state (Task 13.15) — Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/finishing_operations/data/datasources/finishing_operations_remote_datasource.dart';

final finishingOperationsRemoteDataSourceProvider =
    Provider<FinishingOperationsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FinishingOperationsRemoteDataSource(apiClient.dio);
});

final customerFinishingJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(finishingOperationsRemoteDataSourceProvider).listCustomerJobs();
});

final customerFinishingJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(finishingOperationsRemoteDataSourceProvider).getCustomerJob(jobId),
);

final providerFinishingJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(finishingOperationsRemoteDataSourceProvider).listProviderJobs();
});

final providerFinishingJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(finishingOperationsRemoteDataSourceProvider).getProviderJob(jobId),
);