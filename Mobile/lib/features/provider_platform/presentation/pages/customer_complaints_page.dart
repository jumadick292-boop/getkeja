// Customer complaints (Task 13.16) — list own complaints + open a new one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class CustomerComplaintsPage extends ConsumerWidget {
  const CustomerComplaintsPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final reasons = ref.read(complaintReasonsProvider).asData?.value ?? <Map<String, dynamic>>[];
    if (reasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadNotifications)));
      return;
    }
    final domain = TextEditingController();
    final resourceId = TextEditingController();
    final description = TextEditingController();
    String reasonId = reasons.first['id'] as String;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.openComplaint),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: reasonId,
                  items: [for (final r in reasons) DropdownMenuItem(value: r['id'] as String, child: Text('${r['label']}'))],
                  onChanged: (v) => setLocal(() => reasonId = v!),
                ),
                TextField(controller: domain, decoration: InputDecoration(labelText: l10nDomain(context))),
                TextField(controller: resourceId, decoration: const InputDecoration(labelText: 'Job ID')),
                TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.description)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context)!.cancel)),
            TextButton(
              onPressed: () async {
                await ref.read(providerPlatformRemoteDataSourceProvider).submitComplaint(domain.text.trim(), resourceId.text.trim(), <String, dynamic>{
                  'reasonId': reasonId,
                  'description': description.text.trim(),
                });
                ref.invalidate(myComplaintsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: Text(AppLocalizations.of(context)!.submit),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) context.push('/complaints/mine');
  }

  String l10nDomain(BuildContext context) => AppLocalizations.of(context)!.serviceDomain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(myComplaintsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myComplaints)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.openComplaint),
      ),
      body: async.when(
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.noComplaints, style: AppTypography.bodyMedium))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myComplaintsProvider),
                child: ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      onTap: () => context.push('/complaints/${c['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c['reasonId']}', style: AppTypography.titleMedium),
                          const SizedBox(height: 4),
                          Text('${c['status']}', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          Text('${c['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMedium),
                        ],
                      ),
                    );
                  },
                ),
              ),
        loading: () => const AppListSkeleton(rows: 5),
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(myComplaintsProvider)),
      ),
    );
  }
}