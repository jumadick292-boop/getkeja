import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';

class HouseSeekerJourneyPage extends ConsumerWidget {
  const HouseSeekerJourneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeyAsync = ref.watch(houseSeekerJourneyProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('My rental journey')),
      body: journeyAsync.when(
        data: (journey) => _JourneyContent(journey: journey),
        loading: () => const AppListSkeleton(rows: 6),
        error: (error, _) => AppNotice(
          message: 'Could not load your rental journey.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerJourneyProvider),
        ),
      ),
    );
  }
}

class _JourneyContent extends StatelessWidget {
  const _JourneyContent({required this.journey});

  final RentalJourneyModel journey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Overview', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: <Widget>[
            _StatCard(label: 'Saved homes', value: journey.counts.savedHomes, icon: Icons.favorite_border),
            _StatCard(label: 'Enquiries', value: journey.counts.activeEnquiries, icon: Icons.forum_outlined),
            _StatCard(label: 'Upcoming visits', value: journey.counts.upcomingVisits, icon: Icons.event_outlined),
            _StatCard(label: 'Proposals', value: journey.counts.pendingProposals, icon: Icons.request_quote_outlined),
            _StatCard(label: 'Applications', value: journey.counts.activeApplications, icon: Icons.assignment_outlined),
          ],
        ),
        if (journey.upcomingVisits.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'Upcoming visits'),
          const SizedBox(height: AppSpacing.sm),
          ...journey.upcomingVisits.map((visit) => _UpcomingVisitRow(visit: visit)),
        ],
        if (journey.recentProposals.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'Recent proposals'),
          const SizedBox(height: AppSpacing.sm),
          ...journey.recentProposals.map((proposal) => _RecentProposalRow(proposal: proposal)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: AppColors.brand, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text('$value', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

class _UpcomingVisitRow extends StatelessWidget {
  const _UpcomingVisitRow({required this.visit});

  final JourneyVisitModel visit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          const Icon(Icons.event_outlined, color: AppColors.brand, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              visit.scheduledAt != null ? _formatDateTime(visit.scheduledAt!) : 'Site visit',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (visit.status != null)
            Text(
              humanizeEnum(visit.status),
              style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
            ),
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
    return '${date.day} ${months[date.month - 1]} at $hour:$minute';
  }
}

class _RecentProposalRow extends StatelessWidget {
  const _RecentProposalRow({required this.proposal});

  final JourneyProposalModel proposal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          const Icon(Icons.request_quote_outlined, color: AppColors.brand, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  proposal.propertyTitle ?? 'Rental proposal',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                ),
                if (proposal.proposedRentAmount != null)
                  Text(
                    formatPrice(proposal.proposedRentAmount),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
                  ),
              ],
            ),
          ),
          if (proposal.status != null)
            Text(
              humanizeEnum(proposal.status),
              style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
            ),
        ],
      ),
    );
  }
}