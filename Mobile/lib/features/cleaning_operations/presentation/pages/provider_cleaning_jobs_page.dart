// Provider cleaning jobs list + detail (Task 13.13).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/cleaning_operations_state.dart';

class ProviderCleaningJobsPage extends ConsumerWidget {
  const ProviderCleaningJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final jobsAsync = ref.watch(providerCleaningJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cleaningOperations)),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(child: Text(l10n.cleaningOperationsEmpty, style: AppTypography.bodyMedium));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(providerCleaningJobsProvider),
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final job = jobs[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => context.push('/cleaning-operations/provider/jobs/${job['id']}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text('${job['status']}', style: AppTypography.bodySmall),
                  ]),
                );
              },
            ),
          );
        },
        loading: () => const AppListSkeleton(rows: 5),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerCleaningJobsProvider),
        ),
      ),
    );
  }
}

class ProviderCleaningJobDetailPage extends ConsumerStatefulWidget {
  const ProviderCleaningJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ProviderCleaningJobDetailPage> createState() =>
      _ProviderCleaningJobDetailPageState();
}

class _ProviderCleaningJobDetailPageState
    extends ConsumerState<ProviderCleaningJobDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(providerCleaningJobDetailProvider(widget.jobId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadNotifications)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _progress(String to) =>
      _run(() => ref.read(cleaningOperationsRemoteDataSourceProvider).updateProgress(widget.jobId, to));

  Future<void> _complete() =>
      _run(() => ref.read(cleaningOperationsRemoteDataSourceProvider).submitCompletion(widget.jobId));

  Future<void> _assess() => _run(() => ref
      .read(cleaningOperationsRemoteDataSourceProvider)
      .recordAssessment(widget.jobId, <String, dynamic>{
        'complete': true,
        'findings': 'Assessed',
        'customerVisibleReport': 'Assessed on site',
      }));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(providerCleaningJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cleaningOperations)),
      body: detailAsync.when(
        data: (job) {
          final status = job['status']?.toString() ?? '';
          final assessments = (job['assessments'] as List<dynamic>? ?? <dynamic>[]);
          final checklists = (job['checklists'] as List<dynamic>? ?? <dynamic>[]);
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(status, style: AppTypography.bodyMedium),
                  if ((job['serviceAddress']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(job['serviceAddress'].toString(), style: AppTypography.bodySmall),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              if (assessments.isEmpty)
                PrimaryButton(label: l10n.recordAssessment, onPressed: _busy ? null : _assess),
              for (final cl in checklists) ...[
                AppSectionHeader(title: (cl as Map)['title']?.toString() ?? l10n.checklist),
                for (final item in (cl['items'] as List<dynamic>? ?? <dynamic>[])) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: (item as Map)['done'] == true,
                    onChanged: _busy
                        ? null
                        : (v) => _run(() => ref
                            .read(cleaningOperationsRemoteDataSourceProvider)
                            .toggleChecklistItem(
                              widget.jobId,
                              cl['id'] as String,
                              item['id'] as String,
                              v ?? false,
                            )),
                    title: Text(item['label']?.toString() ?? ''),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              if (status == 'confirmed' || status == 'scheduled' || status == 'assigned')
                PrimaryButton(label: l10n.startWork, onPressed: _busy ? null : () => _progress('in_progress')),
              if (status == 'in_progress' || status == 'awaiting_supplies')
                PrimaryButton(label: l10n.qualityCheck, onPressed: _busy ? null : () => _progress('quality_check')),
              if (status == 'quality_check')
                PrimaryButton(label: l10n.confirmCompletion, onPressed: _busy ? null : _complete),
            ],
          );
        },
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerCleaningJobDetailProvider(widget.jobId)),
        ),
      ),
    );
  }
}