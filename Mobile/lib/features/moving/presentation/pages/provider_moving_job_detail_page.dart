// Provider moving job detail + operational management (Task 13.6).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/moving/presentation/state/moving_state.dart';

class ProviderMovingJobDetailPage extends ConsumerStatefulWidget {
  const ProviderMovingJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ProviderMovingJobDetailPage> createState() => _ProviderMovingJobDetailPageState();
}

class _ProviderMovingJobDetailPageState extends ConsumerState<ProviderMovingJobDetailPage> {
  static const _next = <String, String>{
    'confirmed': 'preparation',
    'awaiting_customer_details': 'preparation',
    'preparation': 'ready_for_move',
    'ready_for_move': 'in_progress',
    'in_progress': 'arrived_at_destination',
    'arrived_at_destination': 'unloading',
  };

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(providerMovingJobDetailProvider(widget.jobId).notifier).load());
  }

  Future<void> _advance(String to) async {
    try {
      await ref.read(providerMovingJobDetailProvider(widget.jobId).notifier).updateProgress(to);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _submitCompletion() async {
    try {
      await ref.read(providerMovingJobDetailProvider(widget.jobId).notifier).submitCompletion(notes: 'Move completed');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(providerMovingJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.movingJobDetails)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (job) {
          final status = job['status'] as String? ?? '';
          final canViewLocations = job['canViewLocations'] == true;
          final checklist = (job['checklist'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final next = _next[status];
          final atUnloading = status == 'unloading';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.movingStatus}: ${status.replaceAll('_', ' ').toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (canViewLocations) ...[
                Text('${l10n.movingOrigin}: ${job['originAddress'] ?? '-'}'),
                Text('${l10n.movingDestination}: ${job['destinationAddress'] ?? '-'}'),
              ] else
                Text(l10n.movingOrigin),
              Text('${l10n.movingSchedule}: ${job['agreedMoveDate'] ?? '-'}'),
              const SizedBox(height: 16),
              Text(l10n.movingChecklist, style: Theme.of(context).textTheme.titleMedium),
              ...checklist.entries.map((e) => CheckboxListTile(
                    dense: true,
                    value: e.value == true,
                    onChanged: null,
                    title: Text(e.key.replaceAll('_', ' ')),
                  )),
              const SizedBox(height: 24),
              if (next != null)
                FilledButton(
                  onPressed: () => _advance(next),
                  child: Text(next.replaceAll('_', ' ')),
                ),
              if (atUnloading)
                FilledButton(
                  onPressed: _submitCompletion,
                  child: Text(l10n.movingConfirmCompletion),
                ),
            ],
          );
        },
      ),
    );
  }
}