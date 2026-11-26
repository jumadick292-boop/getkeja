library features.property_management.presentation.widgets.unit_card;

import 'package:flutter/material.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';

class UnitCard extends StatelessWidget {
  const UnitCard({required this.unit, this.onTap, super.key});

  final PropertyUnit unit;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (unit.status.toLowerCase()) {
      case 'available':
      case 'vacant':
        return AppColors.success;
      case 'occupied':
        return AppColors.navy;
      case 'maintenance':
        return AppColors.warning;
      default:
        return AppColors.inactive;
    }
  }

  String get _rentLabel {
    final rent = unit.rentAmount;
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
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              color: theme.colorScheme.onPrimaryContainer,
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
                        'Unit ${unit.unitNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _Badge(label: unit.status, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _rentLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[unit.unitType];
    if (unit.bedrooms != null) parts.add('${unit.bedrooms} bed');
    if (unit.bathrooms != null) parts.add('${unit.bathrooms} bath');
    if (unit.areaSqm != null)
      parts.add('${unit.areaSqm!.toStringAsFixed(0)} m²');
    return parts.join(' · ');
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
