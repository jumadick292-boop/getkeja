// Unified provider dashboard (Task 13.16) — context-scoped operational metrics,
// domain performance and navigation into reports, reviews and complaints.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

class ProviderDashboardPage extends ConsumerWidget {
  const ProviderDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(providerDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerDashboard)),
      body: async.when(
        data: (data) {
          final metrics = (data['metrics'] as Map<String, dynamic>? ?? <String, dynamic>{});
          final byDomain = (data['byDomain'] as List<dynamic>? ?? <dynamic>[]);
          final isOrg = (data['scope'] as Map<String, dynamic>?)?['isOrganization'] == true;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(providerDashboardProvider),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                if (isOrg) ...[
                  AppNotice(message: l10n.organizationView, type: NoticeType.info),
                  const SizedBox(height: 8),
                ],
                AppSectionHeader(title: l10n.overview),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: l10n.activeJobs, value: metrics['activeJobs']),
                    _MetricCard(label: l10n.scheduledToday, value: metrics['scheduledToday']),
                    _MetricCard(label: l10n.awaitingConfirmation, value: metrics['awaitingConfirmation']),
                    _MetricCard(label: l10n.completedJobs, value: metrics['completedJobs']),
                    _MetricCard(label: l10n.newEligibleRequests, value: metrics['newEligibleRequests']),
                    _MetricCard(label: l10n.pendingQuotations, value: metrics['pendingQuotations']),
                    _MetricCard(label: l10n.overdueOrInterrupted, value: metrics['overdueOrInterrupted']),
                    _MetricCard(label: l10n.unresolvedComplaints, value: metrics['unresolvedComplaints']),
                    _MetricCard(label: l10n.averageRating, value: metrics['averageRating']?.toStringAsFixed(2) ?? '-'),
                  ],
                ),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.quickLinks),
                PrimaryButton(label: l10n.reports, onPressed: () => context.push('/provider/reports')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.reviews, onPressed: () => context.push('/provider/reviews')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.complaints, onPressed: () => context.push('/provider/complaints')),
                if (isOrg) ...[
                  const SizedBox(height: 8),
                  PrimaryButton(label: l10n.staffWorkload, onPressed: () => context.push('/provider/staff-workload')),
                ],
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.providerSetup),
                PrimaryButton(label: l10n.onboarding, onPressed: () => context.push('/provider/onboarding')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.organizations, onPressed: () => context.push('/provider/organizations')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.services, onPressed: () => context.push('/provider/services')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.locations, onPressed: () => context.push('/provider/locations')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.serviceAreas, onPressed: () => context.push('/provider/service-areas')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.availability, onPressed: () => context.push('/provider/availability')),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.marketplace),
                PrimaryButton(label: l10n.providerRequests, onPressed: () => context.push('/provider/marketplace')),
                const SizedBox(height: 16),
                AppSectionHeader(title: l10n.operations),
                PrimaryButton(label: l10n.moving, onPressed: () => context.push('/provider/moving/jobs')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.garbage, onPressed: () => context.push('/garbage/provider/jobs')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.laundry, onPressed: () => context.push('/laundry/provider/orders')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.homeMaintenance, onPressed: () => context.push('/home-maintenance/provider/jobs')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.cleaning, onPressed: () => context.push('/cleaning-operations/provider/jobs')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.installation, onPressed: () => context.push('/installation-operations/provider/jobs')),
                const SizedBox(height: 8),
                PrimaryButton(label: l10n.finishing, onPressed: () => context.push('/finishing-operations/provider/jobs')),
                if (byDomain.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppSectionHeader(title: l10n.byDomain),
                  for (final d in byDomain) ...[
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${d['domain']}', style: AppTypography.titleMedium),
                          Text('${l10n.active}: ${_int(d['active'])}  ${l10n.completed}: ${_int(d['completed'])}',
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const AppListSkeleton(rows: 6),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerDashboardProvider),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - AppSpacing.screenPadding.horizontal * 2 - 12) / 2;
    return SizedBox(
      width: width.clamp(140.0, 400.0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: AppTypography.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}