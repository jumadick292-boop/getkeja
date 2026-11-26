// Customer home maintenance job detail (Task 13.12) — timeline, inspection
// report, amendment approval and completion confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/home_maintenance_state.dart';

class CustomerHomeMaintenanceJobDetailPage extends ConsumerWidget {
  const CustomerHomeMaintenanceJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(customerHomeMaintenanceJobDetailProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMaintenance)),
      body: detailAsync.when(
        data: (job) {
          final inspections = (job['inspections'] as List<dynamic>? ?? <dynamic>[]);
          final amendments = (job['amendments'] as List<dynamic>? ?? <dynamic>[]);
          final pendingAmendments = amendments.where((a) => (a as Map)['status'] == 'pending').toList();
          final canConfirm = job['status'] == 'completed_pending_confirmation';
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text('${job['status']}', style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Text('${job['currency'] ?? 'KES'} ${job['agreedPrice'] ?? ''}', style: AppTypography.bodyMedium),
                ]),
              ),
              if (inspections.isNotEmpty) ...[
                AppSectionHeader(title: l10n.inspectionReport),
                for (final insp in inspections) ...[
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((insp as Map)['customerVisibleReport']?.toString() ??
                          insp['findings']?.toString() ?? ''),
                      if ((insp['safetyConcerns']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${l10n.safetyConcerns}: ${insp['safetyConcerns']}', style: AppTypography.bodySmall),
                      ],
                    ]),
                  ),
                ],
              ],
              for (final a in pendingAmendments) ...[
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['reason']?.toString() ?? '', style: AppTypography.bodyMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: PrimaryButton(label: l10n.approve, onPressed: () async {
                        await ref.read(homeMaintenanceRemoteDataSourceProvider).decideAmendment(jobId, a['id'] as String, approve: true);
                        ref.invalidate(customerHomeMaintenanceJobDetailProvider(jobId));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: PrimaryButton(label: l10n.reject, onPressed: () async {
                        await ref.read(homeMaintenanceRemoteDataSourceProvider).decideAmendment(jobId, a['id'] as String, approve: false);
                        ref.invalidate(customerHomeMaintenanceJobDetailProvider(jobId));
                      })),
                    ]),
                  ]),
                ),
              ],
              if (canConfirm) ...[
                const SizedBox(height: 8),
                PrimaryButton(
                  label: l10n.confirmCompletion,
                  onPressed: () async {
                    await ref.read(homeMaintenanceRemoteDataSourceProvider).confirmCompletion(jobId, confirm: true);
                    ref.invalidate(customerHomeMaintenanceJobDetailProvider(jobId));
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(customerHomeMaintenanceJobDetailProvider(jobId)),
        ),
      ),
    );
  }
}