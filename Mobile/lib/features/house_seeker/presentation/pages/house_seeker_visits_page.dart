import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerVisitsPage extends ConsumerWidget {
  const HouseSeekerVisitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final visitsAsync = ref.watch(houseSeekerSiteVisitsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: Text(l10n.siteVisitMyVisits)),
      body: visitsAsync.when(
        data: (visits) => visits.isEmpty
            ? _EmptyVisits(l10n: l10n)
            : _VisitList(
                visits: visits,
                l10n: l10n,
                ref: ref,
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: l10n.siteVisitRequestError,
          type: NoticeType.error,
          actionLabel: l10n.cancel,
          onAction: () => ref.invalidate(houseSeekerSiteVisitsProvider),
        ),
      ),
    );
  }
}

class _VisitList extends ConsumerWidget {
  const _VisitList({
    required this.visits,
    required this.l10n,
    required this.ref,
  });

  final List<SiteVisitModel> visits;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: visits.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final visit = visits[index];
        return _VisitTile(
          visit: visit,
          l10n: l10n,
          ref: ref,
          onCancel: visit.canCancel ? () => _cancel(context, ref, visit) : null,
          onReschedule: visit.canReschedule ? () => _reschedule(context, ref, visit) : null,
        );
      },
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, SiteVisitModel visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.siteVisitCancelTitle),
        content: Text(l10n.siteVisitCancelDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.siteVisitCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.siteVisitCancelConfirm,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(houseSeekerRepositoryProvider).cancelSiteVisit(visit.id);
      ref.invalidate(houseSeekerSiteVisitsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteVisitCancelledSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteVisitRequestError)),
        );
      }
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref, SiteVisitModel visit) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;
    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await ref.read(houseSeekerRepositoryProvider).rescheduleSiteVisit(
            visit.id,
            scheduledAt: scheduled.toUtc().toIso8601String(),
          );
      ref.invalidate(houseSeekerSiteVisitsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteVisitRescheduledSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteVisitRequestError)),
        );
      }
    }
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({
    required this.visit,
    required this.l10n,
    required this.ref,
    this.onCancel,
    this.onReschedule,
  });

  final SiteVisitModel visit;
  final AppLocalizations l10n;
  final WidgetRef ref;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  Color get _statusColor {
    switch (visit.status) {
      case 'confirmed':
      case 'rescheduled':
        return AppColors.success;
      case 'cancelled':
      case 'no_show':
      case 'declined':
        return AppColors.inactive;
      case 'completed':
        return AppColors.brand;
      default:
        return AppColors.pending;
    }
  }

  String get _statusLabel {
    switch (visit.status) {
      case 'scheduled':
        return l10n.siteVisitPending;
      case 'confirmed':
        return l10n.siteVisitUpcoming;
      case 'completed':
        return l10n.siteVisitCompleted;
      case 'cancelled':
        return l10n.siteVisitCancelled;
      case 'no_show':
        return l10n.siteVisitNoShow;
      case 'rescheduled':
        return l10n.siteVisitRescheduled;
      case 'declined':
        return l10n.siteVisitDeclined;
      default:
        return humanizeEnum(visit.status);
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
              const Icon(Icons.event_outlined, size: 20, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      visit.scheduledAt != null
                          ? _formatDateTime(visit.scheduledAt!)
                          : l10n.siteVisit,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: AppBorderRadius.roundRadius,
                          ),
                          child: Text(
                            _statusLabel,
                            style: AppTypography.labelSmall.copyWith(
                              color: _statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visit.durationMinutes != null)
            Text(
              '${visit.durationMinutes} ${l10n.siteVisitDurationMin}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
            ),
          if (visit.visitorNotes != null && visit.visitorNotes!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              visit.visitorNotes!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (visit.hostNotes != null && visit.hostNotes!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.siteVisitHostNotes}: ${visit.hostNotes}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (onCancel != null || onReschedule != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (onReschedule != null)
                  TextButton(onPressed: onReschedule, child: Text(l10n.siteVisitRescheduleSubmit)),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(l10n.siteVisitCancelConfirm, style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute';
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.event_available_outlined, size: 56, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.siteVisitNoVisits, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.siteVisitNoVisitsDesc,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
