// Provider reports (Task 13.16) — operational time-series + service performance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class ProviderReportsPage extends ConsumerWidget {
  const ProviderReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(providerOperationalReportProvider);
    final perfAsync = ref.watch(providerServicePerformanceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports)),
      body: reportAsync.when(
        data: (rows) => perfAsync.when(
          data: (perf) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(providerOperationalReportProvider);
              ref.invalidate(providerServicePerformanceProvider);
            },
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                AppSectionHeader(title: l10n.operationalReport),
                if (rows.isEmpty)
                  Center(child: Text(l10n.noData, style: AppTypography.bodyMedium))
                else
                  for (final r in rows.take(30))
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['period']}', style: AppTypography.titleMedium),
                          const SizedBox(height: 4),
                          Text('${l10n.jobsCreated}: ${r['jobsCreated']}  ${l10n.completed}: ${r['jobsCompleted']}  ${l10n.cancelled}: ${r['jobsCancelled']}',
                              style: AppTypography.bodySmall),
                          Text('${l10n.quotations}: ${r['quotations']}  ${l10n.accepted}: ${r['accepted']}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.servicePerformance),
                if (perf.isEmpty)
                  Center(child: Text(l10n.noData, style: AppTypography.bodyMedium))
                else
                  for (final p in perf)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['domain']} / ${p['categoryId'] ?? '-'}', style: AppTypography.titleMedium),
                          const SizedBox(height: 4),
                          Text('${l10n.completed}: ${p['completed']}  ${l10n.cancelled}: ${p['cancelled']}  ${l10n.averageRating}: ${p['averageRating']?.toStringAsFixed(2) ?? '-'}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          loading: () => const AppListSkeleton(rows: 6),
          error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(providerServicePerformanceProvider)),
        ),
        loading: () => const AppListSkeleton(rows: 6),
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(providerOperationalReportProvider)),
      ),
    );
  }
}