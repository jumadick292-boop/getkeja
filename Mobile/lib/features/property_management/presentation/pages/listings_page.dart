library features.property_management.presentation.pages.listings_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/widgets/listing_card.dart';

class ListingsPage extends ConsumerStatefulWidget {
  const ListingsPage({super.key});

  @override
  ConsumerState<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends ConsumerState<ListingsPage> {
  String? _statusFilter;

  static const _statusOptions = <String?>[
    null,
    'draft',
    'published',
    'paused',
    'withdrawn',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadListings(),
    );
  }

  Future<void> _reload() {
    return ref
        .read(propertyNotifierProvider.notifier)
        .loadListings(status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(listingsProvider);
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listings'),
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
                if (isLoading && listings.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (listings.isEmpty)
                  _EmptyState()
                else
                  ...listings.map(
                    (listing) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListingCard(listing: listing),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/landlord/listings/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New listing'),
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No listings yet',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Publish a listing to advertise a unit to prospective renters.',
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
