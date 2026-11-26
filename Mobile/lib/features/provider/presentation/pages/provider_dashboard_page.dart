import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider foundation dashboard.
///
/// This is a real, API-backed foundation screen (not a finished provider
/// dashboard). It displays live provider-scoped counts from
/// GET /api/v1/provider/dashboard. Full provider workflows arrive in later
/// tasks.
class ProviderDashboardPage extends ConsumerStatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  ConsumerState<ProviderDashboardPage> createState() =>
      _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends ConsumerState<ProviderDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerDashboardProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Dashboard')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
          ),
        ),
        data: (dashboard) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tile('New eligible requests', dashboard.newEligibleRequests),
            _tile('Assigned requests', dashboard.assignedRequests),
            _tile('Pending responses', dashboard.pendingResponses),
            _tile('Accepted jobs', dashboard.acceptedJobs),
            _tile('Upcoming jobs', dashboard.upcomingJobs),
            _tile('Active jobs', dashboard.activeJobs),
            _tile('Completed jobs', dashboard.completedJobs),
            _tile('Cancelled jobs', dashboard.cancelledJobs),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}