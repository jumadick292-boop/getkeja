// Staff workload (Task 13.16) — organization owner/admin view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class StaffWorkloadPage extends ConsumerWidget {
  const StaffWorkloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(providerStaffWorkloadProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffWorkload)),
      body: async.when(
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.noData, style: AppTypography.bodyMedium))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(providerStaffWorkloadProvider),
                child: ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['userId']}', style: AppTypography.titleMedium),
                          const SizedBox(height: 4),
                          Text('${l10n.assignedJobs}: ${r['assignedJobs']}  ${l10n.active}: ${r['activeJobs']}  ${l10n.completed}: ${r['completedJobs']}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    );
                  },
                ),
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(message: l10n.unauthorized, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(providerStaffWorkloadProvider)),
      ),
    );
  }
}