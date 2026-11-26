// Customer moving job detail (Task 13.6).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/moving/presentation/state/moving_state.dart';
import 'package:get_keja_mobile/features/messaging/presentation/conversation_launcher.dart';

class MovingJobDetailPage extends ConsumerStatefulWidget {
  const MovingJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<MovingJobDetailPage> createState() => _MovingJobDetailPageState();
}

class _MovingJobDetailPageState extends ConsumerState<MovingJobDetailPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(customerMovingJobDetailProvider(widget.jobId).notifier).load());
  }

  Future<void> _confirm() async {
    try {
      await ref.read(customerMovingJobDetailProvider(widget.jobId).notifier).confirmCompletion(confirm: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _reportIncomplete() async {
    try {
      await ref.read(customerMovingJobDetailProvider(widget.jobId).notifier).confirmCompletion(confirm: false, notes: 'Reported incomplete');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(customerMovingJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.movingJobDetails),
        actions: [
          IconButton(
            tooltip: l10n.contactProvider,
            icon: const Icon(Icons.message_outlined),
            onPressed: () => startContextualConversation(
              context,
              ref,
              type: 'moving_job',
              movingJobId: widget.jobId,
              subject: l10n.movingJobDetails,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (job) {
          final status = (job['status'] as String? ?? '').replaceAll('_', ' ');
          final checklist = (job['checklist'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final history = (job['history'] as List? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList();
          final awaiting = job['status'] == 'awaiting_customer_confirmation';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.movingStatus}: ${status.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${l10n.movingOrigin}: ${job['originAddress'] ?? '-'}'),
              Text('${l10n.movingDestination}: ${job['destinationAddress'] ?? '-'}'),
              Text('${l10n.movingSchedule}: ${job['agreedMoveDate'] ?? '-'}'),
              Text('${l10n.movingAcceptedQuotation}: ${job['currency'] ?? 'KES'} ${job['agreedPrice'] ?? '-'}'),
              const SizedBox(height: 16),
              Text(l10n.movingChecklist, style: Theme.of(context).textTheme.titleMedium),
              ...checklist.entries.map((e) => CheckboxListTile(
                    dense: true,
                    value: e.value == true,
                    onChanged: null,
                    title: Text(e.key.replaceAll('_', ' ')),
                  )),
              const SizedBox(height: 16),
              Text(l10n.movingProgress, style: Theme.of(context).textTheme.titleMedium),
              ...history.map((h) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.timeline, size: 18),
                    title: Text((h['action'] as String? ?? '').replaceAll('_', ' ')),
                    subtitle: Text(h['createdAt']?.toString() ?? ''),
                  )),
              const SizedBox(height: 24),
              if (awaiting) ...[
                FilledButton(onPressed: _confirm, child: Text(l10n.movingConfirmCompletion)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _reportIncomplete, child: Text(l10n.movingReportIncomplete)),
              ],
            ],
          );
        },
      ),
    );
  }
}