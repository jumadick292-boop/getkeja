// Marketplace state (Task 13.5) — Riverpod providers + notifiers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/marketplace/data/datasources/marketplace_remote_datasource.dart';
import 'package:get_keja_mobile/features/marketplace/data/repositories/marketplace_repository_impl.dart';

final marketplaceRemoteDataSourceProvider = Provider<MarketplaceRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MarketplaceRemoteDataSource(apiClient.dio);
});

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(marketplaceRemoteDataSourceProvider));
});

class MarketplaceCategoriesNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  MarketplaceRepository get _repo => ref.read(marketplaceRepositoryProvider);

  Future<void> load({String? domain}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getCategories(domain: domain));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final marketplaceCategoriesProvider = NotifierProvider<
    MarketplaceCategoriesNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  MarketplaceCategoriesNotifier.new,
);

class MarketplaceRequestsNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  MarketplaceRepository get _repo => ref.read(marketplaceRepositoryProvider);

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.listRequests(status: status);
      state = AsyncValue.data((result['rows'] as List).cast<Map<String, dynamic>>());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final marketplaceRequestsProvider = NotifierProvider<
    MarketplaceRequestsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  MarketplaceRequestsNotifier.new,
);

class MarketplaceRequestDetailNotifier
    extends Notifier<AsyncValue<Map<String, dynamic>>> {
  MarketplaceRequestDetailNotifier(this.requestId);

  final String requestId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  MarketplaceRepository get _repo => ref.read(marketplaceRepositoryProvider);

  Future<void> load(String requestId) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getRequest(requestId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> acceptQuotation(String requestId, String quotationId, {int? expectedVersion}) async {
    final data = await _repo.acceptQuotation(requestId, quotationId, expectedVersion: expectedVersion);
    state = AsyncValue.data(data);
  }

  Future<void> cancel(String requestId, {String? reason}) async {
    final data = await _repo.cancelRequest(requestId, reason: reason);
    state = AsyncValue.data(data);
  }
}

final marketplaceRequestDetailProvider = NotifierProvider.family<
    MarketplaceRequestDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  MarketplaceRequestDetailNotifier.new,
);

class ProviderMarketplaceInboxNotifier
    extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  @override
  AsyncValue<List<Map<String, dynamic>>> build() => const AsyncValue.loading();

  MarketplaceRepository get _repo => ref.read(marketplaceRepositoryProvider);

  Future<void> load({String? domain}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.providerInbox(domain: domain);
      state = AsyncValue.data((result['rows'] as List).cast<Map<String, dynamic>>());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerMarketplaceInboxProvider = NotifierProvider<
    ProviderMarketplaceInboxNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  ProviderMarketplaceInboxNotifier.new,
);

class ProviderMarketplaceDetailNotifier
    extends Notifier<AsyncValue<Map<String, dynamic>>> {
  ProviderMarketplaceDetailNotifier(this.requestId);

  final String requestId;

  @override
  AsyncValue<Map<String, dynamic>> build() => const AsyncValue.loading();

  MarketplaceRepository get _repo => ref.read(marketplaceRepositoryProvider);

  Future<void> load(String requestId) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.providerRequest(requestId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> submitQuotation(String requestId, Map<String, dynamic> body) async {
    final data = await _repo.submitQuotation(requestId, body);
    state = AsyncValue.data(data);
  }

  Future<void> advance(String requestId, String action) async {
    final data = await _repo.advanceJob(requestId, action);
    state = AsyncValue.data(data);
  }
}

final providerMarketplaceDetailProvider = NotifierProvider.family<
    ProviderMarketplaceDetailNotifier, AsyncValue<Map<String, dynamic>>, String>(
  ProviderMarketplaceDetailNotifier.new,
);