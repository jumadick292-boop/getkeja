// Customer finishing job detail (Task 13.15) — assessment report, plan,
// equipment summary, test/commissioning results, approvals and confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/finishing_operations_state.dart';

class CustomerFinishingJobDetailPage extends ConsumerWidget {
  const CustomerFinishingJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(customerFinishingJobDetailProvider(jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.finishingOperations)),
      body: detailAsync.when(
        data: (job) {
          final assessments = (job['assessments'] as List<dynamic>? ?? <dynamic>[]);
          final plans = (job['plans'] as List<dynamic>? ?? <dynamic>[]);
          final materials = (job['materials'] as List<dynamic>? ?? <dynamic>[]);
          final inspections = (job['inspections'] as List<dynamic>? ?? <dynamic>[]);
          final amendments = (job['amendments'] as List<dynamic>? ?? <dynamic>[]);
          final pendingAmendments = amendments.where((a) => (a as Map)['status'] == 'pending').toList();
          final pendingMaterials = materials.where((e) => (e as Map)['approvalStatus'] == 'pending').toList();
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
              if (assessments.isNotEmpty) ...[
                AppSectionHeader(title: l10n.assessmentReport),
                for (final a in assessments) ...[
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((a as Map)['customerVisibleReport']?.toString() ??
                          a['findings']?.toString() ?? ''),
                      if ((a['safetyConcerns']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${l10n.safetyConcerns}: ${a['safetyConcerns']}', style: AppTypography.bodySmall),
                      ],
                    ]),
                  ),
                ],
              ],
              if (plans.isNotEmpty) ...[
                AppSectionHeader(title: l10n.workPlan),
                for (final p in plans) ...[
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((p as Map)['summary']?.toString() ?? ''),
                      if ((p['deliverables']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${l10n.deliverables}: ${p['deliverables']}', style: AppTypography.bodySmall),
                      ],
                    ]),
                  ),
                ],
              ],
              if (materials.isNotEmpty) ...[
                AppSectionHeader(title: l10n.materials),
                for (final e in materials.where((e) => (e as Map)['customerVisible'] == true)) ...[
                  AppCard(
                    child: Text('${(e as Map)['description'] ?? ''} x${e['quantity'] ?? ''}',
                        style: AppTypography.bodyMedium),
                  ),
                ],
              ],
              if (inspections.isNotEmpty) ...[
                AppSectionHeader(title: l10n.qualityInspection),
                for (final t in inspections.where((t) => (t as Map)['customerVisible'] == true)) ...[
                  AppCard(
                    child: Text('${t['name'] ?? ''}: ${t['outcome'] ?? ''}', style: AppTypography.bodyMedium),
                  ),
                ],
              ],
              for (final e in pendingMaterials) ...[
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l10n.materials}: ${(e as Map)['description'] ?? ''}', style: AppTypography.bodyMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: PrimaryButton(label: l10n.approve, onPressed: () async {
                        await ref.read(finishingOperationsRemoteDataSourceProvider).decideMaterial(jobId, e['id'] as String, approve: true);
                        ref.invalidate(customerFinishingJobDetailProvider(jobId));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: PrimaryButton(label: l10n.reject, onPressed: () async {
                        await ref.read(finishingOperationsRemoteDataSourceProvider).decideMaterial(jobId, e['id'] as String, approve: false);
                        ref.invalidate(customerFinishingJobDetailProvider(jobId));
                      })),
                    ]),
                  ]),
                ),
              ],
              for (final a in pendingAmendments) ...[
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['reason']?.toString() ?? '', style: AppTypography.bodyMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: PrimaryButton(label: l10n.approve, onPressed: () async {
                        await ref.read(finishingOperationsRemoteDataSourceProvider).decideAmendment(jobId, a['id'] as String, approve: true);
                        ref.invalidate(customerFinishingJobDetailProvider(jobId));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: PrimaryButton(label: l10n.reject, onPressed: () async {
                        await ref.read(finishingOperationsRemoteDataSourceProvider).decideAmendment(jobId, a['id'] as String, approve: false);
                        ref.invalidate(customerFinishingJobDetailProvider(jobId));
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
                    await ref.read(finishingOperationsRemoteDataSourceProvider).confirmCompletion(jobId, confirm: true);
                    ref.invalidate(customerFinishingJobDetailProvider(jobId));
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
          onAction: () => ref.invalidate(customerFinishingJobDetailProvider(jobId)),
        ),
      ),
    );
  }
}