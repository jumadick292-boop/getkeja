library features.account.sections.organization_access.organization_access_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/organizations/presentation/state/organisation_state.dart';
import 'package:get_keja_mobile/features/organizations/presentation/widgets/organisation_card.dart';

class OrganizationAccessPage extends ConsumerWidget {
  const OrganizationAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisations = ref.watch(organisationsProvider);
    final isLoading = ref.watch(organisationLoadingProvider);
    final error = ref.watch(organisationErrorProvider);
    final notifier = ref.read(organisationNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization & access'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.loadOrganisations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => notifier.loadOrganisations(),
          child: isLoading && organisations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        AppNotice(
                          message: error,
                          type: NoticeType.error,
                          onDismiss: () => notifier.clearError(),
                        ),

                      _buildSectionHeader(
                        context,
                        'Your organizations',
                        Icons.groups_outlined,
                      ),
                      const SizedBox(height: 16),
                      if (organisations.isEmpty)
                        _buildEmptyState(context)
                      else
                        ...organisations.map(
                          (organisation) => OrganisationCard(
                            organisation: organisation,
                            onTap: () => context
                                .push('/organisations/${organisation.id}'),
                          ),
                        ),

                      const SizedBox(height: 32),

                      AppCard(
                        padding: AppSpacing.cardPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About organization access',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Organizations allow you to collaborate with team members, manage properties together, and share access to resources. Your role determines what actions you can perform within each organization.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/organisations/create'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No organizations yet',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re not a member of any organization.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Create organization',
            isFullWidth: false,
            onPressed: () => context.push('/organisations/create'),
          ),
        ],
      ),
    );
  }
}
