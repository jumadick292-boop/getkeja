import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerComparePage extends ConsumerWidget {
  const HouseSeekerComparePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(houseSeekerComparisonProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppNotice(
              message: state.error!,
              type: NoticeType.error,
              actionLabel: l10n.retry,
              onAction: () =>
                  ref.read(houseSeekerComparisonProvider.notifier).load(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(l10n.compareTitle),
        actions: <Widget>[
          if (state.count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: l10n.compareClear,
              onPressed: () => _showClearConfirm(context, ref, l10n),
            ),
        ],
      ),
      body: state.isEmpty
          ? _ComparisonEmpty(l10n: l10n)
          : _ComparisonBody(state: state, l10n: l10n, ref: ref),
    );
  }

  Future<void> _showClearConfirm(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.compareClear),
        content: Text(l10n.compareClearConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.compareClear),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(houseSeekerComparisonProvider.notifier).clear();
    }
  }
}

class _ComparisonBody extends ConsumerWidget {
  const _ComparisonBody({
    required this.state,
    required this.l10n,
    required this.ref,
  });

  final ComparisonState state;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ComparisonHeader(
          count: state.count,
          max: kMaxComparisonItems,
          l10n: l10n,
          ref: ref,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(houseSeekerComparisonProvider.notifier).load();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ComparisonGrid(items: state.items, l10n: l10n, ref: ref),
                  const SizedBox(height: AppSpacing.xl),
                  _DifferenceToggle(l10n: l10n, ref: ref),
                ],
              ),
            ),
          ),
        ),
        _ComparisonBottomBar(items: state.items, l10n: l10n, ref: ref),
      ],
    );
  }
}

class _ComparisonEmpty extends StatelessWidget {
  const _ComparisonEmpty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.compare_arrows,
              size: 64,
              color: AppColors.inactive,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.compareEmptyTitle,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.compareEmptyDescription,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.discoverHomes,
              onPressed: () => context.goNamed('house-seeker-home'),
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonHeader extends ConsumerWidget {
  const _ComparisonHeader({
    required this.count,
    required this.max,
    required this.l10n,
    required this.ref,
  });

  final int count;
  final int max;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAtMax = count >= max;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.surfaceWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.compare_arrows,
                color: AppColors.brand,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.compareSelectedCount(count, max),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isAtMax)
            AppNotice(message: l10n.compareAtMax, type: NoticeType.warning),
        ],
      ),
    );
  }
}

class _ComparisonGrid extends ConsumerWidget {
  const _ComparisonGrid({
    required this.items,
    required this.l10n,
    required this.ref,
  });

  final List<ComparisonListingModel> items;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final differenceOnly = ref.watch(differenceOnlyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ComparisonSectionHeader(title: l10n.compareOverview, l10n: l10n),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ComparisonPropertyCard(
                listing: item,
                l10n: l10n,
                ref: ref,
                onRemove: () => ref
                    .read(houseSeekerComparisonProvider.notifier)
                    .remove(item.listingId),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._buildComparisonRows(items, differenceOnly, l10n),
      ],
    );
  }

  List<Widget> _buildComparisonRows(
    List<ComparisonListingModel> items,
    bool differenceOnly,
    AppLocalizations l10n,
  ) {
    final rows = <Widget>[];

    rows.add(_ComparisonSectionHeader(title: l10n.comparePricing, l10n: l10n));
    rows.add(const SizedBox(height: AppSpacing.sm));
    rows.add(
      _ComparisonRow(
        label: l10n.comparePrice,
        values: items.map((i) => _priceCell(i, l10n)).toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareDeposit,
        values: items
            .map(
              (i) => (i.depositAmount != null && i.depositAmount! > 0)
                  ? 'KES ${i.depositAmount!.toInt()}'
                  : l10n.compareNotDisclosed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );

    rows.add(
      _ComparisonSectionHeader(title: l10n.compareSpecifications, l10n: l10n),
    );
    rows.add(const SizedBox(height: AppSpacing.sm));
    rows.add(
      _ComparisonRow(
        label: l10n.compareBedrooms,
        values: items
            .map(
              (i) => (i.bedrooms != null)
                  ? '${i.bedrooms} ${l10n.compareBeds}'
                  : l10n.compareNotDisclosed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareBathrooms,
        values: items
            .map(
              (i) => (i.bathrooms != null)
                  ? '${i.bathrooms!.toStringAsFixed(i.bathrooms! % 1 == 0 ? 0 : 1)} ${l10n.compareBaths}'
                  : l10n.compareNotDisclosed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareFurnishing,
        values: items
            .map(
              (i) => i.furnished == true
                  ? l10n.compareFurnished
                  : l10n.compareUnfurnished,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.comparePetPolicy,
        values: items
            .map(
              (i) => i.petPolicy != null && i.petPolicy!.isNotEmpty
                  ? i.petPolicy!
                  : l10n.compareNotDisclosed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareSmoking,
        values: items
            .map(
              (i) => i.smokingAllowed == true
                  ? l10n.compareAllowed
                  : l10n.compareNotAllowed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareAvailableFrom,
        values: items
            .map(
              (i) => i.availableFrom != null && i.availableFrom!.isNotEmpty
                  ? i.availableFrom!
                  : l10n.compareNotDisclosed,
            )
            .toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );

    rows.add(
      _ComparisonSectionHeader(title: l10n.compareAmenities, l10n: l10n),
    );
    rows.add(const SizedBox(height: AppSpacing.sm));
    final allAmenities = <String>{};
    for (final item in items) {
      allAmenities.addAll(item.amenities);
    }
    for (final amenity in allAmenities.toList()..sort()) {
      rows.add(
        _ComparisonRow(
          label: humanizeEnum(amenity),
          values: items
              .map(
                (i) => i.amenities.contains(amenity)
                    ? l10n.compareYes
                    : l10n.compareNo,
              )
              .toList(),
          differenceOnly: differenceOnly,
          l10n: l10n,
        ),
      );
    }

    rows.add(_ComparisonSectionHeader(title: l10n.compareLocation, l10n: l10n));
    rows.add(const SizedBox(height: AppSpacing.sm));
    rows.add(
      _ComparisonRow(
        label: l10n.compareCounty,
        values: items.map((i) => i.county ?? l10n.compareNotDisclosed).toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );
    rows.add(
      _ComparisonRow(
        label: l10n.compareTown,
        values: items.map((i) => i.city ?? l10n.compareNotDisclosed).toList(),
        differenceOnly: differenceOnly,
        l10n: l10n,
      ),
    );

    return rows;
  }

  String _priceCell(ComparisonListingModel item, AppLocalizations l10n) {
    if (item.rentAmount == null) return l10n.comparePriceOnRequest;
    return 'KES ${item.rentAmount!.toInt()}${item.pricingLabel}';
  }
}

class _ComparisonPropertyCard extends ConsumerWidget {
  const _ComparisonPropertyCard({
    required this.listing,
    required this.l10n,
    required this.ref,
    required this.onRemove,
  });

  final ComparisonListingModel listing;
  final AppLocalizations l10n;
  final WidgetRef ref;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unavailable = !listing.isAvailable;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: AppBorderRadius.mediumRadius,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: listing.primaryImage != null
                        ? Image.network(
                            listing.primaryImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.brandTint,
                              child: const Icon(
                                Icons.home_outlined,
                                color: AppColors.inactive,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.brandTint,
                            child: const Icon(
                              Icons.home_outlined,
                              color: AppColors.inactive,
                            ),
                          ),
                  ),
                ),
                if (unavailable)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: AppBorderRadius.mediumRadius,
                    ),
                    child: const Center(
                      child: Text(
                        'Unavailable',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                Positioned(
                  right: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              listing.title?.isNotEmpty == true
                  ? listing.title!
                  : l10n.rentalListing,
              style: AppTypography.titleSmall.copyWith(
                color: unavailable ? AppColors.inactive : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (listing.fullLocation != null &&
                listing.fullLocation!.isNotEmpty)
              Text(
                listing.fullLocation!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mutedText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.xs),
            if (listing.rentAmount != null)
              Text(
                'KES ${listing.rentAmount!.toInt()}${listing.pricingLabel}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (unavailable) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.propertyUnavailable,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.compareViewDetails,
              onPressed: () => context.pushNamed(
                'house-seeker-listing-detail',
                pathParameters: <String, String>{
                  'listingId': listing.listingId,
                },
              ),
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSectionHeader extends StatelessWidget {
  const _ComparisonSectionHeader({required this.title, required this.l10n});

  final String title;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.values,
    required this.differenceOnly,
    required this.l10n,
  });

  final String label;
  final List<String> values;
  final bool differenceOnly;
  final AppLocalizations l10n;

  bool get _hasDifferences {
    if (values.length < 2) return false;
    final first = values.first;
    return values.any((v) => v != first);
  }

  @override
  Widget build(BuildContext context) {
    if (differenceOnly && !_hasDifferences) return const SizedBox.shrink();

    final isDifferent = _hasDifferences;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isDifferent ? AppColors.text : AppColors.mutedText,
                fontWeight: isDifferent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: values.map((value) {
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      value,
                      style: AppTypography.bodySmall.copyWith(
                        color: isDifferent
                            ? AppColors.brand
                            : AppColors.mutedText,
                        fontWeight: isDifferent
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifferenceToggle extends ConsumerWidget {
  const _DifferenceToggle({required this.l10n, required this.ref});

  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final differenceOnly = ref.watch(differenceOnlyProvider);
    return Row(
      children: <Widget>[
        Checkbox(
          value: differenceOnly,
          onChanged: (value) =>
              ref.read(differenceOnlyProvider.notifier).state = value ?? false,
          activeColor: AppColors.brand,
        ),
        Text(
          l10n.compareDifferencesOnly,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.text),
        ),
      ],
    );
  }
}

class DifferenceOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final differenceOnlyProvider = NotifierProvider<DifferenceOnlyNotifier, bool>(
  DifferenceOnlyNotifier.new,
);

class _ComparisonBottomBar extends ConsumerWidget {
  const _ComparisonBottomBar({
    required this.items,
    required this.l10n,
    required this.ref,
  });

  final List<ComparisonListingModel> items;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(houseSeekerComparisonProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.surfaceWhite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.clear(),
                  child: Text(l10n.compareClear),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: l10n.compareSavedAll(items.length),
                  onPressed: () async {
                    for (final item in items) {
                      await ref
                          .read(houseSeekerRepositoryProvider)
                          .saveListing(item.listingId);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.compareSavedAll(items.length)),
                        ),
                      );
                    }
                  },
                  isFullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
