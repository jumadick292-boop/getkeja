// Provider garbage collection detail + operational controls (Task 13.7).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_ops_state.dart';

class ProviderGarbageJobDetailPage extends ConsumerStatefulWidget {
  const ProviderGarbageJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ProviderGarbageJobDetailPage> createState() => _ProviderGarbageJobDetailPageState();
}

class _ProviderGarbageJobDetailPageState extends ConsumerState<ProviderGarbageJobDetailPage> {
  // Allowed provider-driven transitions from the current status.
  static const Map<String, List<String>> _next = <String, List<String>>{
    'confirmed': ['scheduled', 'provider_assigned'],
    'scheduled': ['provider_assigned'],
    'provider_assigned': ['en_route'],
    'en_route': ['arrived'],
    'arrived': ['collecting'],
    'collecting': ['awaiting_customer_confirmation'],
  };

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerGarbageJobDetailProvider(widget.jobId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(providerGarbageJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.garbageJobDetails)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (job) {
          final status = job['status'] as String? ?? '';
          final canView = job['canViewLocations'] == true;
          final next = _next[status] ?? const <String>[];
          final notifier = ref.read(providerGarbageJobDetailProvider(widget.jobId).notifier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.garbageStatus}: ${status.replaceAll('_', ' ').toUpperCase()}'),
              const SizedBox(height: 8),
              if (canView && (job['collectionAddress'] as String?) != null)
                Text('${job['collectionAddress']}'),
              const SizedBox(height: 16),
              if (status == 'collecting')
                FilledButton(
                  onPressed: () => notifier.submitCompletion(outstandingIssue: false),
                  child: Text(l10n.garbageConfirmCompletion),
                ),
              for (final to in next)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => notifier.updateProgress(to),
                    child: Text(to.replaceAll('_', ' ').toUpperCase()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}