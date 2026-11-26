// House Seeker Discovery Home screen.
// A production-quality property discovery experience connected to real backend
// data: featured listings, saved location, user greeting, notifications, and
// favorites toggle with optimistic updates and rollback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/listing_card.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

/// Personal saved location for the House Seeker discovery home.
///
/// Reuses the existing API client and `/api/v1/profile/locations` endpoint.
final houseSeekerPersonalLocationProvider =
    FutureProvider<Map<String, Object?>?>((ref) async {
      final userId = ref.watch(
        authNotifierProvider.select((state) => state.user?.id),
      );
      if (userId == null) return null;
      final response = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/profile/locations');
      final data = response.data?['data'];
      if (data is! List) return null;
      for (final value in data) {
        if (value is! Map) continue;
        final location = value.map<String, Object?>(
          (key, item) => MapEntry(_camelCase(key.toString()), item),
        );
        if (location['locationType'] == 'personal_residential') return location;
      }
      return null;
    });

String _camelCase(String value) => value.replaceAllMapped(
  RegExp(r'_([a-z])'),
  (match) => match[1]!.toUpperCase(),
);

class HouseSeekerHomePage extends ConsumerStatefulWidget {
  const HouseSeekerHomePage({super.key});

  @override
  ConsumerState<HouseSeekerHomePage> createState() =>
      _HouseSeekerHomePageState();
}

class _HouseSeekerHomePageState extends ConsumerState<HouseSeekerHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    ref
        .read(houseSeekerSearchProvider.notifier)
        .applyFilter(
          ref
              .read(houseSeekerSearchProvider)
              .filter
              .copyWith(q: query.isEmpty ? null : query),
        );
    context.pushNamed('house-seeker-search');
  }

  void _applyFilter(HouseSeekerFilter filter) {
    ref.read(houseSeekerSearchProvider.notifier).applyFilter(filter);
    context.pushNamed('house-seeker-search');
  }

  Future<void> _onRefresh() async {
    try {
      ref.invalidate(houseSeekerFeaturedProvider);
      ref.read(houseSeekerSearchProvider.notifier).clearFilter();
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _toggleSave(String listingId) {
    ref.read(houseSeekerToggleSaveProvider.notifier).toggle(listingId);
  }

  void _toggleCompare(String listingId) {
    ref.read(houseSeekerComparisonProvider.notifier).add(listingId);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final personalLocation = ref
        .watch(houseSeekerPersonalLocationProvider)
        .asData
        ?.value;
    final featuredAsync = ref.watch(houseSeekerFeaturedProvider);
    final isSmall = MediaQuery.of(context).size.width < 600;

    final greeting = user != null
        ? l10n.welcomeBack(user.firstName)
        : l10n.welcomeGuest;
    final locationLabel = personalLocation != null
        ? (personalLocation['city'] ??
                  personalLocation['town'] ??
                  l10n.savedLocation)
              .toString()
        : null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screenPadding.copyWith(
                    top: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: AppHeroBanner(
                    greeting: greeting,
                    subtitle: l10n.homeHeroDescription,
                    locationLabel: locationLabel ?? l10n.savedLocation,
                    onLocationChange: () =>
                        context.pushNamed('profile-location'),
                    onNotificationsTap: () =>
                        context.pushNamed('notifications'),
                    hasLocation: personalLocation != null,
                  ),
                ),
              ),
              if (personalLocation == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppSpacing.screenPadding.copyWith(
                      bottom: AppSpacing.md,
                    ),
                    child: AppLocationPrompt(
                      onSetLocation: () =>
                          context.pushNamed('profile-location'),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screenPadding.copyWith(
                    bottom: AppSpacing.md,
                  ),
                  child: AppSearchField(
                    controller: _searchController,
                    onSubmit: _submitSearch,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _QuickFilters(onSelect: _applyFilter)),
              const SliverToBoxAdapter(child: _ShortcutRow()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: AppSectionHeader(
                    title: l10n.featuredHomes,
                    action: l10n.seeAll,
                    onAction: () => context.pushNamed('house-seeker-search'),
                  ),
                ),
              ),
              featuredAsync.when(
                data: (listings) => listings.isEmpty
                    ? const SliverToBoxAdapter(child: _EmptyFeatured())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: _FeaturedList(
                          listings: listings,
                          isSmall: isSmall,
                          onTap: (listing) => context.pushNamed(
                            'house-seeker-listing-detail',
                            pathParameters: <String, String>{
                              'listingId': listing.listingId,
                            },
                          ),
                          onToggleSave: (listing) =>
                              _toggleSave(listing.listingId),
                          onToggleCompare: (listing) =>
                              _toggleCompare(listing.listingId),
                          onEnquire: (listing) =>
                              _openEnquire(context, ref, listing),
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: _FeaturedSkeleton(),
                  ),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppNotice(
                      message: l10n.featuredLoadError,
                      type: NoticeType.error,
                      actionLabel: l10n.retry,
                      onAction: () =>
                          ref.invalidate(houseSeekerFeaturedProvider),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedList extends StatelessWidget {
  const _FeaturedList({
    required this.listings,
    required this.isSmall,
    required this.onTap,
    required this.onToggleSave,
    required this.onToggleCompare,
    required this.onEnquire,
  });

  final List<ListingCardModel> listings;
  final bool isSmall;
  final void Function(ListingCardModel) onTap;
  final void Function(ListingCardModel) onToggleSave;
  final void Function(ListingCardModel) onToggleCompare;
  final void Function(ListingCardModel) onEnquire;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmall ? 1 : 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final listing = listings[index];
        return Consumer(
          builder: (_, ref, __) {
            final savedAsync = ref.watch(houseSeekerSavedIdsProvider);
            final comparedIds = ref.watch(houseSeekerComparisonIdsProvider);
            final isSaved =
                savedAsync.asData?.value.contains(listing.listingId) ?? false;
            final isCompared = comparedIds.contains(listing.listingId);
            return HouseSeekerListingCard(
              listing: listing,
              onTap: () => onTap(listing),
              onToggleSave: () => onToggleSave(listing),
              isSaved: isSaved,
              onToggleCompare: () => onToggleCompare(listing),
              isCompared: isCompared,
              onEnquire: () => onEnquire(listing),
            );
          },
        );
      }, childCount: listings.length),
    );
  }
}

class _QuickFilters extends ConsumerWidget {
  _QuickFilters({required this.onSelect});

  final void Function(HouseSeekerFilter) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeFilter = ref.watch(houseSeekerSearchProvider).filter;
    final filters = <(String, IconData, HouseSeekerFilter)>[
      (
        l10n.categoryApartments,
        Icons.apartment_outlined,
        const HouseSeekerFilter(propertyType: 'apartment'),
      ),
      (
        l10n.categoryHouses,
        Icons.house_outlined,
        const HouseSeekerFilter(propertyType: 'house'),
      ),
      (
        l10n.categoryTownhouses,
        Icons.apartment_outlined,
        const HouseSeekerFilter(propertyType: 'townhouse'),
      ),
      (
        l10n.categoryStudios,
        Icons.meeting_room,
        const HouseSeekerFilter(propertyType: 'studio'),
      ),
      (
        l10n.categoryBedsitters,
        Icons.hotel_outlined,
        const HouseSeekerFilter(propertyType: 'bedsitter'),
      ),
      (
        l10n.categoryLand,
        Icons.terrain_outlined,
        const HouseSeekerFilter(propertyType: 'land'),
      ),
      (
        l10n.categoryCommercial,
        Icons.storefront_outlined,
        const HouseSeekerFilter(propertyType: 'commercial'),
      ),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (label, icon, filter) = filters[index];
          final isSelected = activeFilter.propertyType == filter.propertyType;
          return AppCategoryChip(
            label: label,
            icon: icon,
            isSelected: isSelected,
            onTap: () => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _EmptyFeatured extends StatelessWidget {
  const _EmptyFeatured();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search, size: 48, color: AppColors.inactive),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.featuredHomes,
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try adjusting your search to discover more rentals.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (
          var i = 0;
          i < (MediaQuery.of(context).size.width < 600 ? 2 : 4);
          i++
        ) ...<Widget>[
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppBorderRadius.largeRadius,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow();

  @override
  Widget build(BuildContext context) {
    final shortcuts = <(String, IconData, String)>[
      ('Journey', Icons.timeline_outlined, 'house-seeker-journey'),
      ('Visits', Icons.event_outlined, 'house-seeker-visits'),
      ('Messages', Icons.forum_outlined, 'house-seeker-conversations'),
      ('Applications', Icons.assignment_outlined, 'house-seeker-applications'),
      ('Proposals', Icons.request_quote_outlined, 'house-seeker-proposals'),
      ('Saved', Icons.favorite_border, 'house-seeker-saved'),
      ('Enquiries', Icons.forum_outlined, 'house-seeker-enquiries'),
      ('Searches', Icons.bookmark_border, 'house-seeker-saved-searches'),
      ('Preferences', Icons.tune, 'house-seeker-preferences'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: shortcuts.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final (label, icon, route) = shortcuts[index];
            return _ShortcutCard(
              label: label,
              icon: icon,
              onTap: () => context.pushNamed(route),
            );
          },
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppBorderRadius.mediumRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumRadius,
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppBorderRadius.mediumRadius,
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: AppColors.brand, size: 26),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
