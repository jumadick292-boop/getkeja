// Shared scheduling state (Task 13.9) — Riverpod providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/scheduling/data/datasources/scheduling_remote_datasource.dart';
import 'package:get_keja_mobile/features/scheduling/data/repositories/scheduling_repository_impl.dart';

final schedulingRemoteDataSourceProvider = Provider<SchedulingRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SchedulingRemoteDataSource(apiClient.dio);
});

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  return SchedulingRepository(ref.watch(schedulingRemoteDataSourceProvider));
});

// Value-stable key (records with only scalar fields compare by value, so the
// family does not rebuild in a loop). domainsKey is a comma-joined list.
typedef ProviderCalendarKey = ({String from, String to, String domainsKey, String? staffUserId});
typedef CustomerCalendarKey = ({String from, String to});

class ProviderCalendarNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  ProviderCalendarNotifier(this.key);

  final ProviderCalendarKey key;

  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    Future<void>.microtask(load);
    return const AsyncValue.loading();
  }

  SchedulingRepository get _repo => ref.read(schedulingRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final domains = key.domainsKey.isEmpty ? null : key.domainsKey.split(',');
      state = AsyncValue.data(await _repo.providerCalendar(
        from: key.from,
        to: key.to,
        domains: domains,
        staffUserId: key.staffUserId,
      ));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final providerCalendarProvider = NotifierProvider.family<
    ProviderCalendarNotifier, AsyncValue<List<Map<String, dynamic>>>, ProviderCalendarKey>(
  ProviderCalendarNotifier.new,
);

class CustomerAppointmentsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  CustomerAppointmentsNotifier(this.key);

  final CustomerCalendarKey key;

  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    Future<void>.microtask(load);
    return const AsyncValue.loading();
  }

  SchedulingRepository get _repo => ref.read(schedulingRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.customerCalendar(from: key.from, to: key.to));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final customerAppointmentsProvider = NotifierProvider.family<
    CustomerAppointmentsNotifier, AsyncValue<List<Map<String, dynamic>>>, CustomerCalendarKey>(
  CustomerAppointmentsNotifier.new,
);