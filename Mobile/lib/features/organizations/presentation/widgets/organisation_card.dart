library features.organizations.presentation.widgets.organisation_card;

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/organizations/domain/entities/organisation.dart';

class OrganisationCard extends StatelessWidget {
  const OrganisationCard({
    required this.organisation,
    required this.onTap,
    super.key,
  });

  final Organisation organisation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
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
                Text(
                  organisation.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (organisation.slug.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    organisation.slug,
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
}
