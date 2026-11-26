// Provider home maintenance jobs list + detail (Task 13.12).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/home_maintenance_state.dart';

class ProviderHomeMaintenanceJobsPage extends ConsumerWidget {
  const ProviderHomeMaintenanceJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final jobsAsync = ref.watch(providerHomeMaintenanceJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMaintenance)),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(child: Text(l10n.homeMaintenanceEmpty, style: AppTypography.bodyMedium));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(providerHomeMaintenanceJobsProvider),
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final job = jobs[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => context.push('/home-maintenance/provider/jobs/${job['id']}'),
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
          onAction: () => ref.invalidate(providerHomeMaintenanceJobsProvider),
        ),
      ),
    );
  }
}

class ProviderHomeMaintenanceJobDetailPage extends ConsumerStatefulWidget {
  const ProviderHomeMaintenanceJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ProviderHomeMaintenanceJobDetailPage> createState() =>
      _ProviderHomeMaintenanceJobDetailPageState();
}

class _ProviderHomeMaintenanceJobDetailPageState
    extends ConsumerState<ProviderHomeMaintenanceJobDetailPage> {
  bool _busy = false;

  Future<void> _progress(String to) async {
    setState(() => _busy = true);
    try {
      await ref.read(homeMaintenanceRemoteDataSourceProvider).updateProgress(widget.jobId, to);
      ref.invalidate(providerHomeMaintenanceJobDetailProvider(widget.jobId));
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

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await ref.read(homeMaintenanceRemoteDataSourceProvider).submitCompletion(widget.jobId);
      ref.invalidate(providerHomeMaintenanceJobDetailProvider(widget.jobId));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(providerHomeMaintenanceJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMaintenance)),
      body: detailAsync.when(
        data: (job) {
          final status = job['status']?.toString() ?? '';
          final inspections = (job['inspections'] as List<dynamic>? ?? <dynamic>[]);
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
              if (inspections.isEmpty)
                PrimaryButton(
                  label: l10n.recordInspection,
                  onPressed: _busy
                      ? null
                      : () async {
                          await ref.read(homeMaintenanceRemoteDataSourceProvider).recordInspection(
                                widget.jobId,
                                <String, dynamic>{'complete': true, 'findings': 'Inspected', 'customerVisibleReport': 'Inspected on site'},
                              );
                          ref.invalidate(providerHomeMaintenanceJobDetailProvider(widget.jobId));
                        },
                ),
              const SizedBox(height: 8),
              if (status == 'confirmed' || status == 'work_scheduled' || status == 'assigned')
                PrimaryButton(label: l10n.startWork, onPressed: _busy ? null : () => _progress('in_progress')),
              if (status == 'in_progress' || status == 'awaiting_parts')
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
          onAction: () => ref.invalidate(providerHomeMaintenanceJobDetailProvider(widget.jobId)),
        ),
      ),
    );
  }
}