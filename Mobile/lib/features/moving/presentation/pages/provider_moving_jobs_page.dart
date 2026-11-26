// Provider assigned moving jobs list (Task 13.6).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/moving/presentation/state/moving_state.dart';

class ProviderMovingJobsPage extends ConsumerStatefulWidget {
  const ProviderMovingJobsPage({super.key});

  @override
  ConsumerState<ProviderMovingJobsPage> createState() => _ProviderMovingJobsPageState();
}

class _ProviderMovingJobsPageState extends ConsumerState<ProviderMovingJobsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(providerMovingJobsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jobs = ref.watch(providerMovingJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerMovingJobs)),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(providerMovingJobsProvider.notifier).load(),
                child: Text(l10n.movingRetry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return Center(child: Text(l10n.movingNoJobs));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final job = items[index];
              final id = job['id'] as String? ?? '';
              final status = (job['status'] as String? ?? '').replaceAll('_', ' ');
              final date = job['agreedMoveDate'] as String? ?? '';
              return ListTile(
                title: Text(status.isEmpty ? id : status.toUpperCase()),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/provider/moving/jobs/$id'),
              );
            },
          );
        },
      ),
    );
  }
}