// Complaint detail (Task 13.16) — shared customer/provider/admin view with
// messages, corrective actions and lifecycle actions. Internal notes are only
// present in the response for admins (enforced server-side).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class ComplaintDetailPage extends ConsumerStatefulWidget {
  const ComplaintDetailPage({super.key, required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends ConsumerState<ComplaintDetailPage> {
  final _message = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(complaintDetailProvider(widget.complaintId));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadNotifications)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _corrective() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.correctiveAction),
        content: TextField(controller: c, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: Text(AppLocalizations.of(context)!.save)),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await _run(() => ref.read(providerPlatformRemoteDataSourceProvider).recordCorrectiveAction(widget.complaintId, text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(complaintDetailProvider(widget.complaintId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.complaintDetail)),
      body: async.when(
        data: (c) {
          final messages = (c['messages'] as List<dynamic>? ?? <dynamic>[]);
          final actions = (c['correctiveActions'] as List<dynamic>? ?? <dynamic>[]);
          final notes = (c['internalNotes'] as List<dynamic>? ?? <dynamic>[]);
          final status = c['status']?.toString() ?? '';
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['reasonId']}', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(status, style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Text('${c['description']}', style: AppTypography.bodyMedium),
                ]),
              ),
              AppSectionHeader(title: l10n.conversation),
              for (final m in messages)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['authorRole']}', style: AppTypography.bodySmall),
                      const SizedBox(height: 2),
                      Text('${m['body']}', style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
              TextField(
                controller: _message,
                decoration: InputDecoration(labelText: l10n.typeMessage),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: l10n.send,
                onPressed: _busy ? null : () async {
                  final body = _message.text.trim();
                  if (body.isEmpty) return;
                  _message.clear();
                  await _run(() => ref.read(providerPlatformRemoteDataSourceProvider).postComplaintMessage(widget.complaintId, body));
                },
              ),
              if (actions.isNotEmpty) ...[
                AppSectionHeader(title: l10n.correctiveActions),
                for (final a in actions)
                  AppCard(margin: const EdgeInsets.only(bottom: 8), child: Text('${a['action']}', style: AppTypography.bodyMedium)),
              ],
              if (notes.isNotEmpty) ...[
                AppSectionHeader(title: l10n.internalNotes),
                for (final n in notes)
                  AppCard(margin: const EdgeInsets.only(bottom: 8), child: Text('${n['body']}', style: AppTypography.bodySmall)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrimaryButton(label: l10n.acknowledge, onPressed: _busy ? null : () => _run(() => ref.read(providerPlatformRemoteDataSourceProvider).changeComplaintStatus(widget.complaintId, 'acknowledged'))),
                  PrimaryButton(label: l10n.proposeResolution, onPressed: _busy ? null : () => _run(() => ref.read(providerPlatformRemoteDataSourceProvider).changeComplaintStatus(widget.complaintId, 'resolution_proposed'))),
                  PrimaryButton(label: l10n.recordCorrective, onPressed: _busy ? null : _corrective),
                  PrimaryButton(label: l10n.resolve, onPressed: _busy ? null : () => _run(() => ref.read(providerPlatformRemoteDataSourceProvider).changeComplaintStatus(widget.complaintId, 'resolved', resolutionSummary: 'Resolved'))),
                ],
              ),
            ],
          );
        },
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(complaintDetailProvider(widget.complaintId))),
      ),
    );
  }
}