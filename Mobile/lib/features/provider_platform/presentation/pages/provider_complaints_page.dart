// Provider complaint inbox (Task 13.16).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class ProviderComplaintsPage extends ConsumerWidget {
  const ProviderComplaintsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(providerComplaintsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.complaints)),
      body: async.when(
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.noComplaints, style: AppTypography.bodyMedium))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(providerComplaintsProvider),
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
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(providerComplaintsProvider)),
      ),
    );
  }
}