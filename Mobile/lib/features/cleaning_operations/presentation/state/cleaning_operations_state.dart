// Cleaning & Property Care state (Task 13.13) — Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/cleaning_operations/data/datasources/cleaning_operations_remote_datasource.dart';

final cleaningOperationsRemoteDataSourceProvider =
    Provider<CleaningOperationsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CleaningOperationsRemoteDataSource(apiClient.dio);
});

final customerCleaningJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(cleaningOperationsRemoteDataSourceProvider).listCustomerJobs();
});

final customerCleaningJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(cleaningOperationsRemoteDataSourceProvider).getCustomerJob(jobId),
);

final providerCleaningJobsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(cleaningOperationsRemoteDataSourceProvider).listProviderJobs();
});

final providerCleaningJobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, jobId) => ref.watch(cleaningOperationsRemoteDataSourceProvider).getProviderJob(jobId),
);