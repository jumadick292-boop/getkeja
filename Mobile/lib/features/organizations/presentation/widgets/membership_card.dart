library features.organizations.presentation.widgets.membership_card;

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/app/preferences/app_preferences.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';

class MembershipCard extends StatelessWidget {
  const MembershipCard({
    required this.member,
    required this.organisation,
    required this.onTap,
    super.key,
  });

  final OrganisationMember member;
  final Organisation organisation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _getRoleColor(theme, member.role);
    final statusColor = _getStatusColor(theme, member.status);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: organisation.logoUrl != null
                ? ClipRRect(
                    borderRadius: AppBorderRadius.mediumRadius,
                    child: Image.network(
                      organisation.logoUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.business_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    Icons.business_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        organisation.name,
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (member.isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: AppBorderRadius.roundRadius,
                        ),
                        child: Text(
                          'Owner',
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        _formatRole(member.role),
                        style: AppTypography.labelSmall.copyWith(
                          color: roleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        member.status.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (member.joinedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Joined ${_formatDate(member.joinedAt!)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(ThemeData theme, String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return theme.colorScheme.secondary;
      case 'admin':
        return theme.colorScheme.primary;
      case 'manager':
        return theme.colorScheme.tertiary;
      case 'member':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return theme.colorScheme.secondary;
      case 'invited':
        return theme.colorScheme.tertiary;
      case 'suspended':
        return theme.colorScheme.error;
      case 'removed':
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String _formatRole(String role) {
    return role.isEmpty ? '' : role[0].toUpperCase() + role.substring(1);
  }

  String _formatDate(DateTime date) {
    return AppFormatters.date(date);
  }
}
