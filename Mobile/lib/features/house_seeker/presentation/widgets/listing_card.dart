import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';

class HouseSeekerListingCard extends ConsumerWidget {
  const HouseSeekerListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onToggleSave,
    this.isSaved = false,
    this.onToggleCompare,
    this.isCompared = false,
    this.onEnquire,
    this.showStatusBadge = false,
  });

  final ListingCardModel listing;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;
  final bool isSaved;
  final VoidCallback? onToggleCompare;
  final bool isCompared;
  final VoidCallback? onEnquire;
  final bool showStatusBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unavailable = showStatusBadge && listing.listingStatus != 'published';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.largeRadius),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _ListingImage(
                    url: listing.primaryImage,
                    dimmed: unavailable,
                  ),
                ),
                if (listing.images.length > 1)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _ImageCountBadge(count: listing.images.length),
                  ),
                if (onToggleSave != null)
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _SaveButton(isSaved: isSaved, onTap: onToggleSave!),
                  ),
                if (onToggleCompare != null)
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm + 34,
                    child: _CompareButton(
                      isCompared: isCompared,
                      onTap: onToggleCompare!,
                    ),
                  ),
                if (onEnquire != null)
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm + 68,
                    child: _EnquireButton(onTap: onEnquire!),
                  ),
                if (unavailable)
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _StatusBadge(
                      label: humanizeEnum(listing.listingStatus),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          listing.title ??
                              listing.propertyTitle ??
                              'Rental listing',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${formatPrice(listing.rentAmount)}${listing.rentAmount != null ? '/mo' : ''}',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (listing.locationLabel != null)
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing.locationLabel!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.mutedText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (listing.bedrooms != null)
                        _MetaChip(
                          icon: Icons.bed_outlined,
                          label: '${listing.bedrooms} bed',
                        ),
                      if (listing.bathrooms != null)
                        _MetaChip(
                          icon: Icons.bathtub_outlined,
                          label:
                              '${listing.bathrooms!.toStringAsFixed(listing.bathrooms! % 1 == 0 ? 0 : 1)} bath',
                        ),
                      if (listing.propertyType != null)
                        _MetaChip(
                          icon: Icons.apartment_outlined,
                          label: humanizeEnum(listing.propertyType),
                        ),
                      if (listing.furnished == true)
                        const _MetaChip(
                          icon: Icons.chair_outlined,
                          label: 'Furnished',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingImage extends StatelessWidget {
  const _ListingImage({required this.url, this.dimmed = false});

  final String? url;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: AppColors.brandTint),
        if (url != null && url!.isNotEmpty)
          Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _PlaceholderImage(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppColors.brandTint,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          )
        else
          const _PlaceholderImage(),
        if (dimmed) Container(color: Colors.black.withValues(alpha: 0.25)),
      ],
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandTint,
      child: const Icon(
        Icons.home_work_outlined,
        size: 48,
        color: AppColors.inactive,
      ),
    );
  }
}

class _ImageCountBadge extends StatelessWidget {
  const _ImageCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.photo_library_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTypography.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            isSaved ? Icons.favorite : Icons.favorite_border,
            color: isSaved ? AppColors.error : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.isCompared, required this.onTap});

  final bool isCompared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            isCompared ? Icons.compare_arrows : Icons.compare_arrows_outlined,
            color: isCompared ? AppColors.brand : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _EnquireButton extends StatelessWidget {
  const _EnquireButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Icon(Icons.message_outlined, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.inactive,
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}
