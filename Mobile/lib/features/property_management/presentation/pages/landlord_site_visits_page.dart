library features.property_management.presentation.pages.landlord_site_visits_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class LandlordSiteVisitsPage extends ConsumerStatefulWidget {
  const LandlordSiteVisitsPage({super.key});

  @override
  ConsumerState<LandlordSiteVisitsPage> createState() =>
      _LandlordSiteVisitsPageState();
}

class _LandlordSiteVisitsPageState
    extends ConsumerState<LandlordSiteVisitsPage> {
  String? _statusFilter;

  static const _statusOptions = <String?>[
    null,
    'scheduled',
    'confirmed',
    'completed',
    'cancelled',
    'declined',
    'no_show',
    'rescheduled',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadSiteVisits(),
    );
  }

  Future<void> _reload() {
    return ref
        .read(propertyNotifierProvider.notifier)
        .loadSiteVisits(status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visits = ref.watch(siteVisitsProvider);
    final isLoading = ref.watch(siteVisitLoadingProvider);
    final error = ref.watch(siteVisitErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.siteVisitMyVisits),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  AppNotice(
                    message: error,
                    type: NoticeType.error,
                    onDismiss: notifier.clearError,
                  ),
                _StatusFilter(
                  value: _statusFilter,
                  options: _statusOptions,
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _reload();
                  },
                ),
                const SizedBox(height: 16),
                if (isLoading && visits.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (visits.isEmpty)
                  _EmptyState()
                else
                  ...visits.map(
                    (visit) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SiteVisitCard(visit: visit),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String?> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option == value;
          return ChoiceChip(
            label: Text(option == null ? 'All' : option.toUpperCase()),
            selected: selected,
            onSelected: (_) => onChanged(option),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No site visits yet',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Site visit requests from renters will appear here.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SiteVisitCard extends ConsumerWidget {
  const SiteVisitCard({super.key, required this.visit});

  final SiteVisit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(propertyNotifierProvider.notifier);
    return AppCard(
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
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (visit.scheduledAt != null) ...[
                      Text(
                        'Visit on ${_formatDate(visit.scheduledAt!)}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusBadge(status: visit.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoChip(label: 'Status', value: visit.status),
              ),
              if (visit.durationMinutes != null)
                Expanded(
                  child: _InfoChip(
                    label: 'Duration',
                    value: '${visit.durationMinutes} min',
                  ),
                ),
            ],
          ),
          if (visit.visitorPhone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(visit.visitorPhone!)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (visit.canConfirm)
                _ActionButton(
                  label: 'Confirm',
                  icon: Icons.check_circle_rounded,
                  onPressed: () => _confirmDialog(context, notifier, visit),
                ),
              if (visit.canDecline)
                _ActionButton(
                  label: 'Decline',
                  icon: Icons.cancel_rounded,
                  onPressed: () => _declineDialog(context, notifier, visit),
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
                  onPressed: () => _cancelDialog(context, notifier, visit),
                ),
              TextButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Details'),
                onPressed: () =>
                    context.push('/landlord/site-visits/${visit.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDialog(
    BuildContext context,
    PropertyNotifier notifier,
    SiteVisit visit,
  ) async {
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
    }
  }

  Future<void> _declineDialog(
    BuildContext context,
    PropertyNotifier notifier,
    SiteVisit visit,
  ) async {
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
    }
  }

  Future<void> _cancelDialog(
    BuildContext context,
    PropertyNotifier notifier,
    SiteVisit visit,
  ) async {
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
