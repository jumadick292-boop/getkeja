// Provider assigned garbage collections list (Task 13.7).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_ops_state.dart';

class ProviderGarbageJobsPage extends ConsumerStatefulWidget {
  const ProviderGarbageJobsPage({super.key});

  @override
  ConsumerState<ProviderGarbageJobsPage> createState() => _ProviderGarbageJobsPageState();
}

class _ProviderGarbageJobsPageState extends ConsumerState<ProviderGarbageJobsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(providerGarbageJobsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jobs = ref.watch(providerGarbageJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerGarbageJobs)),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(providerGarbageJobsProvider.notifier).load(),
                child: Text(l10n.garbageRetry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return Center(child: Text(l10n.garbageNoJobs));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final job = items[index];
              final id = job['id'] as String? ?? '';
              final status = (job['status'] as String? ?? '').replaceAll('_', ' ');
              final date = job['scheduledDate'] as String? ?? '';
              return ListTile(
                title: Text(status.isEmpty ? id : status.toUpperCase()),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/garbage/provider/jobs/$id'),
              );
            },
          );
        },
      ),
    );
  }
}