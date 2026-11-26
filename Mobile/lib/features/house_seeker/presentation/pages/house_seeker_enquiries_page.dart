import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';

class HouseSeekerEnquiriesPage extends ConsumerWidget {
  const HouseSeekerEnquiriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enquiriesAsync = ref.watch(houseSeekerEnquiriesProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('My enquiries')),
      body: enquiriesAsync.when(
        data: (enquiries) => enquiries.isEmpty
            ? const _EmptyEnquiries()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: enquiries.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final enquiry = enquiries[index];
                  return _EnquiryTile(
                    enquiry: enquiry,
                    onWithdraw: () => _withdraw(context, ref, enquiry),
                  );
                },
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: 'Could not load your enquiries.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerEnquiriesProvider),
        ),
      ),
    );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    EnquiryModel enquiry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw enquiry?'),
        content: const Text('The landlord will no longer see this enquiry.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Withdraw',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(houseSeekerRepositoryProvider).withdrawEnquiry(enquiry.id);
    ref.invalidate(houseSeekerEnquiriesProvider);
  }
}

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({required this.enquiry, required this.onWithdraw});

  final EnquiryModel enquiry;
  final Future<void> Function() onWithdraw;

  Color get _statusColor {
    switch (enquiry.status) {
      case 'new':
        return AppColors.pending;
      case 'closed':
      case 'lost_declined':
        return AppColors.inactive;
      case 'converted_to_tenant':
      case 'rental_arrangement_confirmed':
        return AppColors.success;
      default:
        return AppColors.brand;
    }
  }

  bool get _canWithdraw => !<String>[
    'converted_to_tenant',
    'closed',
    'lost_declined',
  ].contains(enquiry.status);

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
                  enquiry.displayTitle,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(
                label: humanizeEnum(enquiry.status),
                color: _statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (enquiry.city != null)
            Text(
              enquiry.city!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            enquiry.message,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (enquiry.createdAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sent ${formatDateLabel(enquiry.createdAt)}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
          if (_canWithdraw) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onWithdraw,
                child: const Text(
                  'Withdraw',
                  style: TextStyle(color: AppColors.error),
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyEnquiries extends StatelessWidget {
  const _EmptyEnquiries();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppColors.inactive,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No enquiries yet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'When you contact a landlord about a property, it shows up here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
