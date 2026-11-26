library features.property_management.presentation.pages.landlord_dashboard_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/widgets/stat_card.dart';

class LandlordDashboardPage extends ConsumerStatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  ConsumerState<LandlordDashboardPage> createState() =>
      _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends ConsumerState<LandlordDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadDashboardStats(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => notifier.loadDashboardStats(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => notifier.loadDashboardStats(),
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
                _WelcomeHeader(),
                const SizedBox(height: 20),
                if (isLoading && stats == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _SectionHeader(
                    title: 'Overview',
                    icon: Icons.dashboard_outlined,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.25,
                    children: [
                      StatCard(
                        label: 'Properties',
                        value: '${stats?.totalProperties ?? 0}',
                        icon: Icons.apartment_rounded,
                        onTap: () => context.push('/landlord/properties'),
                      ),
                      StatCard(
                        label: 'Listings live',
                        value: '${stats?.publishedListings ?? 0}',
                        icon: Icons.campaign_outlined,
                        color: AppColors.navy,
                        onTap: () => context.push('/landlord/listings'),
                      ),
                      StatCard(
                        label: 'Units',
                        value: '${stats?.totalUnits ?? 0}',
                        icon: Icons.meeting_room_outlined,
                        onTap: () => context.push('/landlord/properties'),
                      ),
                      StatCard(
                        label: 'Enquiries',
                        value: '${stats?.totalTenants ?? 0}',
                        icon: Icons.contacts_outlined,
                        color: AppColors.terracotta,
                        onTap: () => context.push('/landlord/enquiries'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Occupancy',
                    icon: Icons.pie_chart_outline,
                  ),
                  const SizedBox(height: 12),
                  _OccupancyCard(
                    vacant: stats?.vacantUnits ?? 0,
                    occupied: stats?.occupiedUnits ?? 0,
                    total: stats?.totalUnits ?? 0,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Manage', icon: Icons.tune_rounded),
                  const SizedBox(height: 12),
                  _ManageTile(
                    icon: Icons.apartment_rounded,
                    title: 'Properties',
                    subtitle: 'Create and manage your properties',
                    onTap: () => context.push('/landlord/properties'),
                  ),
                  _ManageTile(
                    icon: Icons.meeting_room_outlined,
                    title: 'Units',
                    subtitle: 'Add units and set rent',
                    onTap: () => context.push('/landlord/properties'),
                  ),
                  _ManageTile(
                    icon: Icons.campaign_outlined,
                    title: 'Listings',
                    subtitle: 'Publish and pause listings',
                    onTap: () => context.push('/landlord/listings'),
                  ),
                  _ManageTile(
                    icon: Icons.contacts_outlined,
                    title: 'Enquiries',
                    subtitle: 'Follow up with prospects',
                    onTap: () => context.push('/landlord/enquiries'),
                  ),
                  _ManageTile(
                    icon: Icons.request_quote_outlined,
                    title: 'Rental proposals',
                    subtitle: 'Review terms and message renters',
                    onTap: () => context.push('/landlord/proposals'),
                  ),
                  _ManageTile(
                    icon: Icons.event_repeat_outlined,
                    title: 'Billing',
                    subtitle: 'Recurring rent & invoices',
                    onTap: () => context.push('/landlord/billing'),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: AppTypography.headlineSmall.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is how your portfolio is performing.',
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({
    required this.vacant,
    required this.occupied,
    required this.total,
  });

  final int vacant;
  final int occupied;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denom = total == 0 ? 1 : total;
    final occupiedRatio = (occupied / denom).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.round),
            child: LinearProgressIndicator(
              value: occupiedRatio,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(
                color: AppColors.brand,
                label: 'Occupied',
                value: occupied,
              ),
              _LegendItem(
                color: AppColors.inactive,
                label: 'Vacant',
                value: vacant,
              ),
              _LegendItem(
                color: theme.colorScheme.outline,
                label: 'Total',
                value: total,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: AppTypography.bodyLarge.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: AppSpacing.compactCardPadding,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: AppBorderRadius.mediumRadius,
              ),
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
