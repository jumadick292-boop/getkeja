library features.property_management.presentation.pages.property_detail_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/domain/entities/property.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/widgets/unit_card.dart';

class PropertyDetailPage extends ConsumerStatefulWidget {
  const PropertyDetailPage({required this.propertyId, super.key});

  final String propertyId;

  @override
  ConsumerState<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends ConsumerState<PropertyDetailPage> {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(propertyNotifierProvider.notifier);
    Future.microtask(() {
      notifier.loadProperty(widget.propertyId);
      notifier.loadUnits(propertyId: widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(propertyNotifierProvider);
    final property = state.selectedProperty;
    final units = ref.watch(unitsProvider);
    final isLoading = state.isLoading;
    final error = state.error;
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Property')),
      body: SafeArea(
        child: isLoading && property == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await notifier.loadProperty(widget.propertyId);
                  await notifier.loadUnits(propertyId: widget.propertyId);
                },
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: property == null
                      ? Column(
                          children: [
                            const SizedBox(height: 80),
                            if (error != null)
                              AppNotice(
                                message: error,
                                type: NoticeType.error,
                                onDismiss: notifier.clearError,
                              )
                            else
                              Text(
                                'Property not found',
                                style: AppTypography.titleMedium,
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PropertyHeader(property: property),
                            const SizedBox(height: 20),
                            if (property.description != null &&
                                property.description!.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'About',
                                icon: Icons.info_outline_rounded,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                property.description!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _SectionHeader(
                                    title: 'Units',
                                    icon: Icons.meeting_room_outlined,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAddUnit(context, property.id),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (units.isEmpty)
                              AppCard(
                                padding: AppSpacing.compactCardPadding,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'No units added yet.',
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...units.map(
                                (unit) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: UnitCard(unit: unit),
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  void _showAddUnit(BuildContext context, String propertyId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddUnitSheet(propertyId: propertyId),
    );
  }
}

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                property.title,
                style: AppTypography.headlineSmall.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StatusBadge(status: property.status),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                property.locationLabel,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.home_work_outlined,
              label: '${property.totalUnits} units',
            ),
            _InfoChip(
              icon: Icons.category_outlined,
              label: property.propertyType,
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'published' => AppColors.success,
      'archived' => AppColors.inactive,
      'paused' => AppColors.warning,
      _ => AppColors.pending,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
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

class _AddUnitSheet extends ConsumerStatefulWidget {
  const _AddUnitSheet({required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<_AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<_AddUnitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitNumberController = TextEditingController();
  final _rentController = TextEditingController();
  String _unitType = 'one_bedroom';

  static const _unitTypes = <String>[
    'bedsitter',
    'one_bedroom',
    'two_bedroom',
    'three_bedroom',
    'commercial',
  ];

  @override
  void dispose() {
    _unitNumberController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(propertyLoadingProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add unit',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _unitNumberController,
              label: 'Unit number',
              hintText: 'e.g. A1',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Unit number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _unitType,
              decoration: const InputDecoration(labelText: 'Unit type'),
              items: _unitTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('_', ' ')),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _unitType = value);
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _rentController,
              label: 'Monthly rent (KES)',
              hintText: 'e.g. 30000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Add unit',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final rent = double.tryParse(_rentController.text.trim());
    final success = await ref
        .read(propertyNotifierProvider.notifier)
        .createUnit(
          propertyId: widget.propertyId,
          unitNumber: _unitNumberController.text.trim(),
          unitType: _unitType,
          rentAmount: rent,
        );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }
}
