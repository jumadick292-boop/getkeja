library features.property_management.presentation.widgets.listing_card;

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({required this.listing, this.onTap, super.key});

  final PropertyListing listing;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (listing.status.toLowerCase()) {
      case 'published':
        return AppColors.success;
      case 'paused':
        return AppColors.warning;
      case 'withdrawn':
      case 'archived':
        return AppColors.inactive;
      default:
        return AppColors.pending;
    }
  }

  String get _rentLabel {
    final rent = listing.rentAmount;
    if (rent == null) return 'Rent not set';
    return 'KES ${rent.toStringAsFixed(0)}/mo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: theme.colorScheme.onTertiaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _Badge(label: listing.status, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _rentLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (listing.furnished) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· Furnished',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
