// House Seeker search page — production-ready property search and results.
// Connected to real backend data via [HouseSeekerSearchNotifier]. All
// user-facing strings are localized (en/sw). Search input is debounced.
// Filter state is preserved across navigation (opening a listing detail and
// returning keeps the current search).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/listing_card.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerSearchPage extends ConsumerStatefulWidget {
  const HouseSeekerSearchPage({super.key});

  @override
  ConsumerState<HouseSeekerSearchPage> createState() =>
      _HouseSeekerSearchPageState();
}

class _HouseSeekerSearchPageState extends ConsumerState<HouseSeekerSearchPage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(houseSeekerSearchProvider.notifier).search();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(houseSeekerSearchProvider.notifier);
      final state = ref.read(houseSeekerSearchProvider);
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        notifier.search(append: true);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    ref
        .read(houseSeekerSearchProvider.notifier)
        .applyFilter(
          ref
              .read(houseSeekerSearchProvider)
              .filter
              .copyWith(q: trimmed.isEmpty ? null : trimmed),
        );
  }

  Future<void> _onRefresh() async {
    ref.read(houseSeekerSearchProvider.notifier).search();
  }

  void _showFilterSheet(BuildContext context) async {
    final current = ref.read(houseSeekerSearchProvider).filter;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xlarge),
        ),
      ),
      builder: (context) => _FilterSheet(initial: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(houseSeekerSearchProvider);
    final activeCount = state.filter.activeCount;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(l10n.searchHomes),
        actions: <Widget>[
          if (activeCount > 0)
            Tooltip(
              message: '${l10n.activeFilters}: $activeCount',
              child: IconButton(
                tooltip: l10n.filters,
                icon: const Icon(Icons.tune),
                onPressed: () => _showFilterSheet(context),
              ),
            )
          else
            IconButton(
              tooltip: l10n.filters,
              icon: const Icon(Icons.tune),
              onPressed: () => _showFilterSheet(context),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _SearchField(initialValue: state.filter.q, onSubmit: _submitSearch),
          if (state.filter.isActive || state.filter.sort != 'relevance')
            _ActiveFilterBar(filter: state.filter),
          _SortBar(
            current: state.filter.sort,
            onSelect: (sort) {
              ref
                  .read(houseSeekerSearchProvider.notifier)
                  .applyFilter(state.filter.copyWith(sort: sort));
            },
          ),
          Expanded(child: _buildBody(state, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(HouseSeekerSearchState state, AppLocalizations l10n) {
    if (state.isLoading) {
      return const AppListSkeleton(rows: 5);
    }
    if (state.error != null && state.items.isEmpty) {
      return AppNotice(
        message: state.error!,
        type: NoticeType.error,
        actionLabel: l10n.retry,
        onAction: () => ref.read(houseSeekerSearchProvider.notifier).search(),
      );
    }
    if (state.isEmpty) {
      return _EmptyResults(
        onClear: () =>
            ref.read(houseSeekerSearchProvider.notifier).clearFilter(),
        l10n: l10n,
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.homesFoundCount(state.total),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            );
          }
          final listing = state.items[index - 1];
          return Consumer(
            builder: (_, ref, __) {
              final savedAsync = ref.watch(houseSeekerSavedIdsProvider);
              final comparedIds = ref.watch(houseSeekerComparisonIdsProvider);
              final isSaved =
                  savedAsync.asData?.value.contains(listing.listingId) ?? false;
              final isCompared = comparedIds.contains(listing.listingId);
              return HouseSeekerListingCard(
                listing: listing,
                onTap: () => context.pushNamed(
                  'house-seeker-listing-detail',
                  pathParameters: <String, String>{
                    'listingId': listing.listingId,
                  },
                ),
                onToggleSave: () => ref
                    .read(houseSeekerToggleSaveProvider.notifier)
                    .toggle(listing.listingId),
                isSaved: isSaved,
                onToggleCompare: () => ref
                    .read(houseSeekerComparisonProvider.notifier)
                    .add(listing.listingId),
                isCompared: isCompared,
                onEnquire: () => _openEnquire(context, ref, listing),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEnquire(
    BuildContext context,
    WidgetRef ref,
    ListingCardModel listing,
  ) async {
    final messageController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xlarge),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Send enquiry', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              listing.locationLabel ?? 'Property',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your message',
                hintText: 'Tell the landlord about yourself...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. +254712345678',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Send enquiry',
              onPressed: () async {
                if (messageController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty)
                  return;
                try {
                  await ref
                      .read(houseSeekerRepositoryProvider)
                      .submitEnquiry(
                        propertyId: listing.propertyId,
                        listingId: listing.listingId,
                        unitId: listing.unitId,
                        message: messageController.text.trim(),
                        phone: phoneController.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enquiry sent.')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not send enquiry: $error')),
                    );
                  }
                }
              },
              isFullWidth: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      ref.invalidate(houseSeekerEnquiriesProvider);
    }
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.initialValue, required this.onSubmit});

  final String? initialValue;
  final ValueChanged<String> onSubmit;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmit,
        decoration: InputDecoration(
          hintText: l10n.searchSuburbEstatePrice,
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    widget.onSubmit('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: AppBorderRadius.largeRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.filter});

  final HouseSeekerFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[
      if (filter.rentMin != null || filter.rentMax != null)
        _FilterChip(
          label: filter.rentMin != null && filter.rentMax != null
              ? 'KES ${filter.rentMin!.toInt()}–${filter.rentMax!.toInt()}'
              : filter.rentMax != null
              ? 'Under ${filter.rentMax!.toInt()}'
              : 'From ${filter.rentMin!.toInt()}',
        ),
      if (filter.bedrooms != null) _FilterChip(label: '${filter.bedrooms} bed'),
      if (filter.propertyType != null) _FilterChip(label: filter.propertyType!),
      if (filter.furnished != null)
        _FilterChip(
          label: filter.furnished == 'true' ? l10n.furnished : l10n.unfurnished,
        ),
      if (filter.city != null) _FilterChip(label: filter.city!),
      if (filter.county != null) _FilterChip(label: filter.county!),
      if (filter.neighbourhood != null)
        _FilterChip(label: filter.neighbourhood!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: chips,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Chip(
        label: Text(label),
        backgroundColor: AppColors.brandTint,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.current, required this.onSelect});

  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(Icons.swap_vert, size: 18, color: AppColors.mutedText),
          ),
          ...<(String, String)>[
            ('relevance', l10n.relevance),
            ('newest', l10n.newest),
            ('price_asc', l10n.priceLowToHigh),
            ('price_desc', l10n.priceHighToLow),
          ].map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: SizedBox(
                  width: 120,
                  child: Text(
                    option.$2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
                selected: current == option.$1,
                onSelected: (_) => onSelect(option.$1),
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color: current == option.$1 ? Colors.white : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear, required this.l10n});

  final VoidCallback onClear;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search_off, size: 56, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.noHomesMatch, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.tryWideningFilters,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onClear, child: Text(l10n.clearFilters)),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final HouseSeekerFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late String? _propertyType;
  late int? _bedrooms;
  late String? _furnished;
  late String? _city;
  late String? _county;
  late String? _neighbourhood;
  late String? _amenities;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initial.rentMin?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.rentMax?.toString() ?? '',
    );
    _propertyType = widget.initial.propertyType;
    _bedrooms = widget.initial.bedrooms;
    _furnished = widget.initial.furnished;
    _city = widget.initial.city;
    _county = widget.initial.county;
    _neighbourhood = widget.initial.neighbourhood;
    _amenities = widget.initial.amenities;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    final filter = widget.initial.copyWith(
      rentMin: _minController.text.isEmpty
          ? null
          : num.tryParse(_minController.text),
      rentMax: _maxController.text.isEmpty
          ? null
          : num.tryParse(_maxController.text),
      propertyType: _propertyType,
      bedrooms: _bedrooms,
      bathrooms: null,
      furnished: _furnished,
      city: _city,
      county: _county,
      neighbourhood: _neighbourhood,
      amenities: _amenities,
    );
    ref.read(houseSeekerSearchProvider.notifier).applyFilter(filter);
    Navigator.of(context).pop();
  }

  void _reset() {
    _minController.clear();
    _maxController.clear();
    setState(() {
      _propertyType = null;
      _bedrooms = null;
      _furnished = null;
      _city = null;
      _county = null;
      _neighbourhood = null;
      _amenities = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final facets = ref.watch(houseSeekerFacetsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.filters, style: AppTypography.titleLarge),
                ),
                TextButton(onPressed: _reset, child: Text(l10n.reset)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.priceRangeKes, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.minPrice,
                      prefixText: 'KES ',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.maxPrice,
                      prefixText: 'KES ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.bedrooms, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <int?>[null, 1, 2, 3, 4].map((value) {
                final selected = _bedrooms == value;
                return ChoiceChip(
                  label: Text(value == null ? l10n.any : '$value'),
                  selected: selected,
                  onSelected: (_) => setState(() => _bedrooms = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.furnishing, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <String?>[null, 'true', 'false'].map((value) {
                final label = value == null
                    ? l10n.any
                    : (value == 'true' ? l10n.furnished : l10n.unfurnished);
                return ChoiceChip(
                  label: Text(label),
                  selected: _furnished == value,
                  onSelected: (_) => setState(() => _furnished = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.propertyType, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            facets.when(
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (data.propertyTypes.isNotEmpty) ...<Widget>[
                    Text(l10n.propertyType, style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: data.propertyTypes.map((type) {
                        return ChoiceChip(
                          label: Text(type),
                          selected: _propertyType == type,
                          onSelected: (_) =>
                              setState(() => _propertyType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (data.counties.isNotEmpty) ...<Widget>[
                    Text(l10n.county, style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _county != null && data.counties.contains(_county)
                          ? _county
                          : null,
                      decoration: InputDecoration(hintText: l10n.any),
                      items: data.counties
                          .map(
                            (county) => DropdownMenuItem<String>(
                              value: county,
                              child: Text(county),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _county = value),
                    ),
                  ],
                ],
              ),
              loading: () => const SizedBox(height: AppSpacing.xl),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.neighbourhood, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: TextEditingController(text: _neighbourhood ?? ''),
              decoration: InputDecoration(hintText: l10n.neighbourhood),
              onChanged: (value) =>
                  setState(() => _neighbourhood = value.isEmpty ? null : value),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.amenities, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: TextEditingController(text: _amenities ?? ''),
              decoration: InputDecoration(hintText: 'wifi, parking, pool'),
              onChanged: (value) =>
                  setState(() => _amenities = value.isEmpty ? null : value),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: l10n.showHomes, onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
