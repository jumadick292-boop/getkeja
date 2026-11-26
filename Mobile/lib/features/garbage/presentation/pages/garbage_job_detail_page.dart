// Customer garbage collection detail (Task 13.7).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_ops_state.dart';
import 'package:get_keja_mobile/features/messaging/presentation/conversation_launcher.dart';

class GarbageJobDetailPage extends ConsumerStatefulWidget {
  const GarbageJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<GarbageJobDetailPage> createState() => _GarbageJobDetailPageState();
}

class _GarbageJobDetailPageState extends ConsumerState<GarbageJobDetailPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(customerGarbageJobDetailProvider(widget.jobId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(customerGarbageJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.garbageJobDetails),
        actions: [
          IconButton(
            tooltip: l10n.contactProvider,
            icon: const Icon(Icons.message_outlined),
            onPressed: () => startContextualConversation(
              context,
              ref,
              type: 'garbage_job',
              garbageJobId: widget.jobId,
              subject: l10n.garbageJobDetails,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (job) {
          final status = (job['status'] as String? ?? '').replaceAll('_', ' ');
          final awaiting = job['status'] == 'awaiting_customer_confirmation';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.garbageStatus}: ${status.toUpperCase()}'),
              const SizedBox(height: 8),
              if ((job['scheduledDate'] as String?) != null) Text('${l10n.garbageSchedule}: ${job['scheduledDate']}'),
              const SizedBox(height: 16),
              if (awaiting)
                FilledButton(
                  onPressed: () => ref
                      .read(customerGarbageJobDetailProvider(widget.jobId).notifier)
                      .confirmCompletion(confirm: true),
                  child: Text(l10n.garbageConfirmCompletion),
                ),
            ],
          );
        },
      ),
    );
  }
}