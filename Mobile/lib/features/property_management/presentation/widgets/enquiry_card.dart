library features.property_management.presentation.widgets.enquiry_card;

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';

class EnquiryCard extends StatelessWidget {
  const EnquiryCard({required this.enquiry, this.onTap, super.key});

  final PropertyEnquiry enquiry;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (enquiry.status.toLowerCase()) {
      case 'new':
        return AppColors.brand;
      case 'contacted':
        return AppColors.navy;
      case 'viewing_scheduled':
      case 'site_visit_scheduled':
        return AppColors.warning;
      case 'converted':
        return AppColors.success;
      case 'closed':
      case 'lost':
        return AppColors.inactive;
      default:
        return AppColors.pending;
    }
  }

  String _statusLabel() {
    return enquiry.status.replaceAll('_', ' ');
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
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppBorderRadius.mediumRadius,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                enquiry.prospectiveRenterName.isNotEmpty
                    ? enquiry.prospectiveRenterName[0].toUpperCase()
                    : '?',
                style: AppTypography.titleMedium.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                        enquiry.prospectiveRenterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _Badge(label: _statusLabel(), color: _statusColor),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      enquiry.prospectiveRenterPhone,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· ${enquiry.enquirySource.replaceAll('_', ' ')}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (enquiry.message != null && enquiry.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    enquiry.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
