library features.organizations.presentation.pages.organisation_detail_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/get_invitations.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/get_members.dart';
import 'package:get_keja_mobile/features/organizations/domain/usecases/get_organisation.dart';
import 'package:get_keja_mobile/features/organizations/presentation/state/organisation_state.dart';
import 'package:get_keja_mobile/features/organizations/presentation/widgets/invitation_card.dart';
import 'package:get_keja_mobile/features/organizations/presentation/widgets/membership_card.dart';

class OrganisationDetailPage extends ConsumerStatefulWidget {
  const OrganisationDetailPage({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<OrganisationDetailPage> createState() =>
      _OrganisationDetailPageState();
}

class _OrganisationDetailPageState
    extends ConsumerState<OrganisationDetailPage> {
  Organisation? _organisation;
  List<OrganisationMember> _members = [];
  List<OrganisationInvitation> _invitations = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final organisation = await ref
          .read(getOrganisationProvider)
          .call(widget.organisationId);
      if (!mounted) return;
      setState(() => _organisation = organisation);

      if (organisation != null) {
        final organisationId = widget.organisationId;
        final members = await ref.read(getMembersProvider).call(organisationId);
        final invitations = await ref
            .read(getInvitationsProvider)
            .call(organisationId);
        if (!mounted) return;
        setState(() {
          _members = members;
          _invitations = invitations;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_organisation?.name ?? 'Organization')),
      body: _isLoading && _organisation == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      AppNotice(
                        message: _error!,
                        type: NoticeType.error,
                        onDismiss: () => setState(() => _error = null),
                      ),

                    if (_organisation != null) ...[
                      _buildOrgHeader(context, _organisation!),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/organisations/${_organisation!.id}/profile',
                        ),
                        icon: const Icon(Icons.business_outlined),
                        label: const Text('Organization profile'),
                      ),
                      const SizedBox(height: 24),

                      // Members
                      _buildSectionHeader(
                        context,
                        'Members (${_members.length})',
                        Icons.people_outline,
                      ),
                      const SizedBox(height: 16),
                      if (_members.isEmpty)
                        _buildEmptyState(
                          context: context,
                          icon: Icons.people_outline,
                          title: 'No members',
                          subtitle:
                              'You are the only member of this organization.',
                        )
                      else
                        ..._members.map(
                          (member) => MembershipCard(
                            member: member,
                            organisation: _organisation!,
                            onTap: () {},
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Invitations
                      _buildSectionHeader(
                        context,
                        'Invitations (${_invitations.length})',
                        Icons.mail_outline,
                      ),
                      const SizedBox(height: 16),
                      if (_invitations.isEmpty)
                        _buildEmptyState(
                          context: context,
                          icon: Icons.mail_outline,
                          title: 'No invitations',
                          subtitle:
                              'Invite team members to join this organization.',
                        )
                      else
                        ..._invitations.map(
                          (invitation) => InvitationCard(
                            invitation: invitation,
                            onAccept: () {},
                            onDecline: () {},
                          ),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrgHeader(BuildContext context, Organisation organisation) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: organisation.logoUrl != null
                    ? ClipRRect(
                        borderRadius: AppBorderRadius.mediumRadius,
                        child: Image.network(
                          organisation.logoUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.business_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organisation.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (organisation.slug.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        organisation.slug,
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (organisation.description != null &&
                        organisation.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        organisation.description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildEmptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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

final getOrganisationProvider = Provider<GetOrganisation>((ref) {
  final repository = ref.watch(organisationRepositoryProvider);
  return GetOrganisation(repository);
});

final getMembersProvider = Provider<GetMembers>((ref) {
  final repository = ref.watch(organisationRepositoryProvider);
  return GetMembers(repository);
});

final getInvitationsProvider = Provider<GetInvitations>((ref) {
  final repository = ref.watch(organisationRepositoryProvider);
  return GetInvitations(repository);
});
