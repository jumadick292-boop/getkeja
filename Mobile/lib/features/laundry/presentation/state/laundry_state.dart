// Laundry operations state (Task 13.8) — Riverpod providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/laundry/data/datasources/laundry_remote_datasource.dart';
import 'package:get_keja_mobile/features/laundry/data/repositories/laundry_repository_impl.dart';

final laundryRemoteDataSourceProvider = Provider<LaundryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LaundryRemoteDataSource(apiClient.dio);
});

final laundryRepositoryProvider = Provider<LaundryRepository>((ref) {
  return LaundryRepository(ref.watch(laundryRemoteDataSourceProvider));
});

class CustomerLaundryOrdersNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  LaundryRepository get _repo => ref.read(laundryRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listCustomerOrders(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final customerLaundryOrdersProvider =
    NotifierProvider<CustomerLaundryOrdersNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  CustomerLaundryOrdersNotifier.new,
);

class CustomerLaundryOrderDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  CustomerLaundryOrderDetailNotifier(this.orderId);

  final String orderId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  LaundryRepository get _repo => ref.read(laundryRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getCustomerOrder(orderId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> confirmCompletion({required bool confirm, String? notes}) async {
    state = AsyncValue.data(await _repo.confirmCompletion(orderId, confirm: confirm, notes: notes));
  }

  Future<void> cancel(String reason) async {
    state = AsyncValue.data(await _repo.cancelOrder(orderId, reason));
  }
}

final customerLaundryOrderDetailProvider = NotifierProvider.family<
    CustomerLaundryOrderDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  CustomerLaundryOrderDetailNotifier.new,
);

class ProviderLaundryOrdersNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  LaundryRepository get _repo => ref.read(laundryRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.listProviderOrders(status: status));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerLaundryOrdersProvider =
    NotifierProvider<ProviderLaundryOrdersNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderLaundryOrdersNotifier.new,
);

class ProviderLaundryOrderDetailNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  ProviderLaundryOrderDetailNotifier(this.orderId);

  final String orderId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  LaundryRepository get _repo => ref.read(laundryRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getProviderOrder(orderId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateProgress(String toStatus) async {
    state = AsyncValue.data(await _repo.updateProgress(orderId, toStatus));
  }

  Future<void> submitCompletion({String? notes, bool outstandingIssue = false, List<String> evidence = const []}) async {
    state = AsyncValue.data(await _repo.submitCompletion(orderId, notes: notes, outstandingIssue: outstandingIssue, evidence: evidence));
  }
}

final providerLaundryOrderDetailProvider = NotifierProvider.family<
    ProviderLaundryOrderDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  ProviderLaundryOrderDetailNotifier.new,
);