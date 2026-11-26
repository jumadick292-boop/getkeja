// Moving operations state (Task 13.6) — Riverpod providers + notifiers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/moving/data/datasources/moving_remote_datasource.dart';
import 'package:get_keja_mobile/features/moving/data/repositories/moving_repository_impl.dart';

final movingRemoteDataSourceProvider = Provider<MovingRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MovingRemoteDataSource(apiClient.dio);
});

final movingRepositoryProvider = Provider<MovingRepository>((ref) {
  return MovingRepository(ref.watch(movingRemoteDataSourceProvider));
});

class CustomerMovingJobsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  MovingRepository get _repo => ref.read(movingRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listCustomerJobs(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final customerMovingJobsProvider =
    NotifierProvider<CustomerMovingJobsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  CustomerMovingJobsNotifier.new,
);

class CustomerMovingJobDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  CustomerMovingJobDetailNotifier(this.jobId);

  final String jobId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  MovingRepository get _repo => ref.read(movingRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getCustomerJob(jobId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> confirmCompletion({required bool confirm, String? notes}) async {
    state = AsyncValue.data(await _repo.confirmCompletion(jobId, confirm: confirm, notes: notes));
  }

  Future<void> cancel(String reason) async {
    state = AsyncValue.data(await _repo.cancelJob(jobId, reason));
  }
}

final customerMovingJobDetailProvider = NotifierProvider.family<
    CustomerMovingJobDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  CustomerMovingJobDetailNotifier.new,
);

class ProviderMovingJobsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  MovingRepository get _repo => ref.read(movingRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listProviderJobs(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerMovingJobsProvider =
    NotifierProvider<ProviderMovingJobsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderMovingJobsNotifier.new,
);

class ProviderMovingJobDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  ProviderMovingJobDetailNotifier(this.jobId);

  final String jobId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  MovingRepository get _repo => ref.read(movingRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getProviderJob(jobId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateProgress(String toStatus) async {
    state = AsyncValue.data(await _repo.updateProgress(jobId, toStatus));
  }

  Future<void> submitCompletion({String? notes, bool outstandingIssue = false, List<String> evidence = const []}) async {
    state = AsyncValue.data(await _repo.submitCompletion(jobId, notes: notes, outstandingIssue: outstandingIssue, evidence: evidence));
  }
}

final providerMovingJobDetailProvider = NotifierProvider.family<
    ProviderMovingJobDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  ProviderMovingJobDetailNotifier.new,
);