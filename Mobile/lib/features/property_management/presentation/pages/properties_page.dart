library features.property_management.presentation.pages.properties_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/widgets/property_card.dart';

class PropertiesPage extends ConsumerStatefulWidget {
  const PropertiesPage({super.key});

  @override
  ConsumerState<PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends ConsumerState<PropertiesPage> {
  String? _statusFilter;

  static const _statusOptions = <String?>[
    null,
    'draft',
    'published',
    'paused',
    'archived',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadProperties(),
    );
  }

  Future<void> _reload() {
    return ref
        .read(propertyNotifierProvider.notifier)
        .loadProperties(status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider);
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
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
                _StatusFilter(
                  value: _statusFilter,
                  options: _statusOptions,
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _reload();
                  },
                ),
                const SizedBox(height: 16),
                if (isLoading && properties.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (properties.isEmpty)
                  _EmptyState(
                    onCreate: () => context.push('/landlord/properties/new'),
                  )
                else
                  ...properties.map(
                    (property) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PropertyCard(
                        property: property,
                        onTap: () =>
                            context.push('/landlord/properties/${property.id}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/landlord/properties/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New property'),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String?> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option == value;
          final label = option == null
              ? 'All'
              : option[0].toUpperCase() + option.substring(1);
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onChanged(option),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(
            Icons.apartment_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No properties yet',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first property to start managing units and listings.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Add property',
            isFullWidth: false,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
