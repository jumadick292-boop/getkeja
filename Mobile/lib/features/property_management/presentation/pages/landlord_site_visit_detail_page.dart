library features.property_management.presentation.pages.landlord_site_visit_detail_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class LandlordSiteVisitDetailPage extends ConsumerStatefulWidget {
  const LandlordSiteVisitDetailPage({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<LandlordSiteVisitDetailPage> createState() =>
      _LandlordSiteVisitDetailPageState();
}

class _LandlordSiteVisitDetailPageState
    extends ConsumerState<LandlordSiteVisitDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(propertyNotifierProvider.notifier)
          .loadSiteVisit(widget.visitId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visit = ref.watch(selectedSiteVisitProvider);
    final isLoading = ref.watch(siteVisitLoadingProvider);
    final error = ref.watch(siteVisitErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    if (isLoading && visit == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.siteVisitVisitDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && visit == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.siteVisitVisitDetails)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(propertyNotifierProvider.notifier).clearError(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (visit == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.siteVisitVisitDetails)),
        body: const Center(child: Text('Site visit not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.siteVisitVisitDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref
                .read(propertyNotifierProvider.notifier)
                .loadSiteVisit(widget.visitId),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visit.visitorName ?? 'Visitor',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _StatusBadge(status: visit.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.event_rounded,
                      label: 'Date and time',
                      value: visit.scheduledAt != null
                          ? _formatDate(visit.scheduledAt!)
                          : 'Not set',
                    ),
                    if (visit.durationMinutes != null)
                      _DetailRow(
                        icon: Icons.timer_rounded,
                        label: 'Duration',
                        value: '${visit.durationMinutes} minutes',
                      ),
                    if (visit.visitorPhone != null)
                      _DetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Contact phone',
                        value: visit.visitorPhone!,
                      ),
                    if (visit.visitorEmail != null)
                      _DetailRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: visit.visitorEmail!,
                      ),
                    if (visit.visitorNotes != null)
                      _DetailRow(
                        icon: Icons.note_rounded,
                        label: l10n.siteVisitVisitorNotes,
                        value: visit.visitorNotes!,
                      ),
                    if (visit.hostNotes != null)
                      _DetailRow(
                        icon: Icons.note_add_rounded,
                        label: l10n.siteVisitHostNotes,
                        value: visit.hostNotes!,
                      ),
                    if (visit.outcome != null)
                      _DetailRow(
                        icon: Icons.flag_rounded,
                        label: l10n.siteVisitOutcome,
                        value: visit.outcome!,
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (visit.canConfirm)
                          _ActionButton(
                            label: 'Confirm',
                            icon: Icons.check_circle_rounded,
                            onPressed: () => _confirmVisit(notifier, visit),
                          ),
                        if (visit.canDecline)
                          _ActionButton(
                            label: 'Decline',
                            icon: Icons.cancel_rounded,
                            onPressed: () => _declineVisit(notifier, visit),
                          ),
                        if (visit.canReschedule)
                          _ActionButton(
                            label: 'Reschedule',
                            icon: Icons.schedule_rounded,
                            onPressed: () => context.push(
                              '/landlord/site-visits/${visit.id}/reschedule',
                            ),
                          ),
                        if (visit.canCancel)
                          _ActionButton(
                            label: 'Cancel',
                            icon: Icons.delete_outline_rounded,
                            onPressed: () => _cancelVisit(notifier, visit),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVisit(PropertyNotifier notifier, SiteVisit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm visit?'),
        content: const Text('Mark this site visit as confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.confirmSiteVisit(visitId: visit.id);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _declineVisit(PropertyNotifier notifier, SiteVisit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline visit?'),
        content: const Text('Decline this site visit request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.declineSiteVisit(visitId: visit.id);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _cancelVisit(PropertyNotifier notifier, SiteVisit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel visit?'),
        content: const Text('Cancel this site visit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel visit'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.cancelSiteVisit(visitId: visit.id);
      if (context.mounted) context.pop();
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color _color(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'declined':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

String _formatDate(String isoString) {
  try {
    final date = DateTime.parse(isoString);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return isoString;
  }
}
