// Garbage collection operations state (Task 13.7) — Riverpod providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/garbage/data/datasources/garbage_ops_remote_datasource.dart';
import 'package:get_keja_mobile/features/garbage/data/repositories/garbage_ops_repository_impl.dart';

final garbageOpsRemoteDataSourceProvider = Provider<GarbageOpsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GarbageOpsRemoteDataSource(apiClient.dio);
});

final garbageOpsRepositoryProvider = Provider<GarbageOpsRepository>((ref) {
  return GarbageOpsRepository(ref.watch(garbageOpsRemoteDataSourceProvider));
});

class CustomerGarbageJobsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listCustomerJobs(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final customerGarbageJobsProvider =
    NotifierProvider<CustomerGarbageJobsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  CustomerGarbageJobsNotifier.new,
);

class CustomerGarbageJobDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  CustomerGarbageJobDetailNotifier(this.jobId);

  final String jobId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

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

final customerGarbageJobDetailProvider = NotifierProvider.family<
    CustomerGarbageJobDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  CustomerGarbageJobDetailNotifier.new,
);

class CustomerGarbageAgreementsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listCustomerAgreements());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> decide(String agreementId, bool accept) async {
    await _repo.decideAgreement(agreementId, accept);
    await load();
  }
}

final customerGarbageAgreementsProvider =
    NotifierProvider<CustomerGarbageAgreementsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  CustomerGarbageAgreementsNotifier.new,
);

class ProviderGarbageJobsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listProviderJobs(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerGarbageJobsProvider =
    NotifierProvider<ProviderGarbageJobsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderGarbageJobsNotifier.new,
);

class ProviderGarbageJobDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  ProviderGarbageJobDetailNotifier(this.jobId);

  final String jobId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

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

final providerGarbageJobDetailProvider = NotifierProvider.family<
    ProviderGarbageJobDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  ProviderGarbageJobDetailNotifier.new,
);

class ProviderGarbageAgreementsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  GarbageOpsRepository get _repo => ref.read(garbageOpsRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listProviderAgreements());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerGarbageAgreementsProvider =
    NotifierProvider<ProviderGarbageAgreementsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderGarbageAgreementsNotifier.new,
);