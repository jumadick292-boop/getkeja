// Customer cleaning & property care jobs list (Task 13.13).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/cleaning_operations_state.dart';

class CustomerCleaningJobsPage extends ConsumerWidget {
  const CustomerCleaningJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final jobsAsync = ref.watch(customerCleaningJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cleaningOperations)),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(child: Text(l10n.cleaningOperationsEmpty, style: AppTypography.bodyMedium));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerCleaningJobsProvider),
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final job = jobs[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => context.push('/cleaning-operations/jobs/${job['id']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                      const SizedBox(height: 4),
                      Text('${job['status']}', style: AppTypography.bodySmall),
                      const SizedBox(height: 4),
                      Text('${job['currency'] ?? 'KES'} ${job['agreedPrice'] ?? ''}',
                          style: AppTypography.bodyMedium),
                    ],
                  ),
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
          onAction: () => ref.invalidate(customerCleaningJobsProvider),
        ),
      ),
    );
  }
}