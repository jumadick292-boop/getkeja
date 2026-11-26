import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';

class HouseSeekerApplicationsPage extends ConsumerWidget {
  const HouseSeekerApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(houseSeekerApplicationsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('My applications')),
      body: applicationsAsync.when(
        data: (applications) => applications.isEmpty
            ? const _EmptyApplications()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: applications.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final application = applications[index];
                  return _ApplicationTile(
                    application: application,
                    onWithdraw: application.canWithdraw ? () => _withdraw(context, ref, application) : null,
                  );
                },
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: 'Could not load your applications.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerApplicationsProvider),
        ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, RentalApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text('The landlord will no longer consider this application.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(houseSeekerRepositoryProvider).withdrawApplication(application.id);
      ref.invalidate(houseSeekerApplicationsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not withdraw the application. Please try again.')),
        );
      }
    }
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application, this.onWithdraw});

  final RentalApplicationModel application;
  final VoidCallback? onWithdraw;

  Color get _statusColor {
    switch (application.status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
      case 'withdrawn':
      case 'expired':
        return AppColors.inactive;
      case 'submitted':
      case 'under_review':
        return AppColors.pending;
      default:
        return AppColors.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  application.displayTitle,
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(label: humanizeEnum(application.status), color: _statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (application.city != null)
            Text(
              application.city!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
            ),
          if (application.proposedRentAmount != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Proposed rent: ${formatPrice(application.proposedRentAmount)}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.text),
            ),
          ],
          if (application.employerName != null && application.employerName!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Employer: ${application.employerName}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
            ),
          ],
          if (application.rejectionReason != null && application.rejectionReason!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reason: ${application.rejectionReason}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (application.createdAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Submitted ${formatDateLabel(application.createdAt)}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
            ),
          ],
          if (onWithdraw != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onWithdraw,
                child: const Text('Withdraw', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.assignment_outlined, size: 56, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text('No applications yet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'When you apply for a property, you can track its status here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}