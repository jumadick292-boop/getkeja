import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerListingDetailPage extends ConsumerWidget {
  const HouseSeekerListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(houseSeekerListingDetailProvider(listingId));
    final relatedAsync = ref.watch(
      houseSeekerRelatedListingsProvider(listingId),
    );

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: detailAsync.when(
        data: (listing) =>
            _DetailContent(listing: listing, relatedAsync: relatedAsync),
        loading: () => const _LoadingBody(),
        error: (error, _) => _ErrorBody(
          message: _errorMessage(error, l10n),
          onRetry: () =>
              ref.invalidate(houseSeekerListingDetailProvider(listingId)),
        ),
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        data: (listing) => _ContactBar(listing: listing),
        orElse: () => null,
      ),
    );
  }

  String _errorMessage(Object error, AppLocalizations l10n) {
    final message = error.toString();
    if (message.contains('not found') || message.contains('404')) {
      return l10n.propertyNotFound;
    }
    return l10n.couldNotLoadProperty;
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppLoadingIndicator());
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppNotice(
          message: message,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: onRetry,
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({required this.listing, required this.relatedAsync});

  final ListingDetailModel listing;
  final AsyncValue<List<ListingCardModel>> relatedAsync;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  bool _descriptionExpanded = false;
  bool _amenitiesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: AppColors.navy,
          flexibleSpace: FlexibleSpaceBar(
            background: _ImageGallery(images: widget.listing.images),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.shareProperty,
              onPressed: () => _share(context, widget.listing),
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: l10n.reportListing,
              onPressed: () =>
                  _showReportSheet(context, ref: ref, listing: widget.listing),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.listing.title ??
                            widget.listing.propertyTitle ??
                            l10n.propertyDetails,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        widget.listing.rentAmount == null
                            ? l10n.priceOnRequest
                            : '${formatPrice(widget.listing.rentAmount)}${widget.listing.pricingLabel}',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.listing.locationLabel != null)
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.listing.locationLabel!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.mutedText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                _AttributesRow(listing: widget.listing),
                const SizedBox(height: AppSpacing.lg),
                // Description section
                if (_hasDescription(widget.listing)) ...<Widget>[
                  AppSectionHeader(
                    title: l10n.aboutThisHome,
                    action: _descriptionExpanded
                        ? l10n.readLess
                        : l10n.readMore,
                    onAction: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _descriptionText(widget.listing),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.text,
                      height: 1.5,
                    ),
                    maxLines: _descriptionExpanded ? null : 3,
                    overflow: _descriptionExpanded
                        ? null
                        : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Amenities section
                if ((widget.listing.amenities.isNotEmpty ||
                    widget.listing.features.isNotEmpty)) ...<Widget>[
                  AppSectionHeader(
                    title: l10n.amenitiesAndFeatures,
                    action: _amenitiesExpanded
                        ? l10n.showLessAmenities
                        : l10n.showAllAmenities,
                    onAction: () => setState(
                      () => _amenitiesExpanded = !_amenitiesExpanded,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _amenityItems(widget.listing)
                        .take(
                          _amenitiesExpanded
                              ? _amenityItems(widget.listing).length
                              : 6,
                        )
                        .map((a) => _AmenityChip(label: a))
                        .toList(),
                  ),
                  if (_amenityItems(widget.listing).length > 6 &&
                      !_amenitiesExpanded) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          setState(() => _amenitiesExpanded = true),
                      child: Text(l10n.showAllAmenities),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Details card
                if (_hasDetails(widget.listing)) ...<Widget>[
                  AppSectionHeader(title: l10n.listingDetails),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(children: _detailRows(widget.listing, l10n)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Listed by
                if (widget.listing.landlordFirstName != null) ...<Widget>[
                  AppSectionHeader(title: l10n.listedBy),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor: AppColors.brandTint,
                              child: Text(
                                widget
                                    .listing
                                    .landlordFirstName!
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    widget.listing.landlordFirstName!,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    l10n.propertyOwner,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openEnquiry(context, ref, widget.listing),
                                icon: const Icon(Icons.forum_outlined),
                                label: Text(l10n.enquire),
                              ),
                            ),
                            if (widget.listing.landlordUserId !=
                                null) ...<Widget>[
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openMessage(
                                    context,
                                    ref,
                                    widget.listing,
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: Text(l10n.message),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Location + map
                if (_hasLocation(widget.listing)) ...<Widget>[
                  AppSectionHeader(title: l10n.location),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.listing.address ??
                              widget.listing.locationLabel!,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_hasCoordinates(widget.listing)) ...<Widget>[
                          SizedBox(
                            height: 200,
                            child: _MapPreview(
                              latitude: widget.listing.latitude!,
                              longitude: widget.listing.longitude!,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: () =>
                                _viewOnMap(context, widget.listing),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Text(l10n.viewOnMap),
                          ),
                        ] else ...<Widget>[
                          AppNotice(
                            message: l10n.mapPreviewUnavailable,
                            type: NoticeType.info,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Related properties
                widget.relatedAsync.when(
                  data: (related) {
                    if (related.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppSectionHeader(
                          title: l10n.relatedProperties,
                          action: null,
                          onAction: null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: related.length,
                            itemBuilder: (context, index) {
                              final relatedListing = related[index];
                              return _RelatedPropertyCard(
                                listing: relatedListing,
                                onTap: () => context.pushNamed(
                                  'house-seeker-listing-detail',
                                  pathParameters: <String, String>{
                                    'listingId': relatedListing.listingId,
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _hasDescription(ListingDetailModel listing) {
    return (listing.description ?? '').isNotEmpty ||
        (listing.propertyDescription ?? '').isNotEmpty ||
        (listing.unitDescription ?? '').isNotEmpty;
  }

  String _descriptionText(ListingDetailModel listing) {
    return listing.description ??
        listing.unitDescription ??
        listing.propertyDescription ??
        '';
  }

  bool _hasDetails(ListingDetailModel listing) {
    return listing.depositAmount != null ||
        listing.furnished != null ||
        listing.petPolicy != null ||
        listing.smokingAllowed != null ||
        listing.availableFrom != null ||
        listing.unitNumber != null;
  }

  List<Widget> _detailRows(ListingDetailModel listing, AppLocalizations l10n) {
    final rows = <Widget>[];
    if (listing.depositAmount != null) {
      rows.add(
        _DetailRow(
          label: l10n.deposit,
          value: formatPrice(listing.depositAmount),
        ),
      );
    }
    if (listing.furnished != null) {
      rows.add(
        _DetailRow(
          label: 'Furnishing',
          value: listing.furnished! ? l10n.furnished : l10n.unfurnished,
        ),
      );
    }
    if (listing.petPolicy != null && listing.petPolicy!.isNotEmpty) {
      rows.add(
        _DetailRow(
          label: l10n.petPolicy,
          value: humanizeEnum(listing.petPolicy),
        ),
      );
    }
    if (listing.smokingAllowed != null) {
      rows.add(
        _DetailRow(
          label: l10n.smoking,
          value: listing.smokingAllowed! ? 'Allowed' : 'Not allowed',
        ),
      );
    }
    if (listing.availableFrom != null) {
      rows.add(
        _DetailRow(
          label: l10n.availableFrom,
          value: formatDateLabel(listing.availableFrom),
        ),
      );
    }
    if (listing.unitNumber != null && listing.unitNumber!.isNotEmpty) {
      rows.add(_DetailRow(label: 'Unit', value: listing.unitNumber!));
    }
    return rows;
  }

  bool _hasLocation(ListingDetailModel listing) {
    return (listing.address != null && listing.address!.isNotEmpty) ||
        listing.locationLabel != null ||
        _hasCoordinates(listing);
  }

  bool _hasCoordinates(ListingDetailModel listing) {
    return listing.latitude != null && listing.longitude != null;
  }

  List<String> _amenityItems(ListingDetailModel listing) {
    final items = <String>[];
    items.addAll(listing.amenities);
    items.addAll(listing.features);
    return items.toSet().toList();
  }

  void _share(BuildContext context, ListingDetailModel listing) {
    final l10n = AppLocalizations.of(context)!;
    final url =
        'https://getkeja.com/house-seeker/listings/${listing.listingId}';
    try {
      Share.share(
        '${listing.title ?? listing.propertyTitle ?? l10n.propertyDetails}\n$url',
        subject: l10n.shareProperty,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareNotAvailable)));
      }
    }
  }

  Future<void> _showReportSheet(
    BuildContext context, {
    required WidgetRef ref,
    required ListingDetailModel listing,
  }) async {
    String? reason;
    final detailsController = TextEditingController();
    const reasons = <(String, String)>[
      ('suspicious', 'Suspicious activity'),
      ('incorrect_info', 'Incorrect information'),
      ('misleading_photos', 'Misleading photos'),
      ('unavailable', 'Unavailable but advertised'),
      ('fraud', 'Suspected fraud'),
      ('inappropriate', 'Inappropriate content'),
      ('other', 'Other'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xlarge),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              Text('Report this listing', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.md),
              ...reasons.map(
                (r) => RadioListTile<String>(
                  value: r.$1,
                  groupValue: reason,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.$2),
                  onChanged: (value) => setSheetState(() => reason = value),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Submit report',
                onPressed: reason == null
                    ? null
                    : () async {
                        await ref
                            .read(houseSeekerRepositoryProvider)
                            .reportListing(
                              listingId: listing.listingId,
                              reason: reason!,
                              details: detailsController.text,
                            );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thanks — your report has been submitted.',
                              ),
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEnquiry(
    BuildContext context,
    WidgetRef ref,
    ListingDetailModel listing,
  ) {
    final messageController = TextEditingController();
    final phoneController = TextEditingController();
    showModalBottomSheet<void>(
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
            Text('Enquire about this home', style: AppTypography.titleLarge),
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
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your message',
                hintText: 'Hi, is this property still available?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone (optional)',
                hintText: 'So the landlord can reach you',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Send enquiry',
              onPressed: () async {
                if (messageController.text.trim().isEmpty) return;
                try {
                  await ref
                      .read(houseSeekerRepositoryProvider)
                      .submitEnquiry(
                        propertyId: listing.propertyId,
                        listingId: listing.listingId,
                        unitId: listing.unitId,
                        message: messageController.text.trim(),
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enquiry sent to the landlord.')),
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessage(
    BuildContext context,
    WidgetRef ref,
    ListingDetailModel listing,
  ) async {
    if (listing.landlordUserId == null) return;
    final messageController = TextEditingController();
    final subjectController = TextEditingController();
    await showModalBottomSheet<void>(
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
            Text('Message the landlord', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              listing.locationLabel ?? 'Property',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your message',
                hintText: 'Hi, I am interested in this property...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Send message',
              onPressed: () async {
                if (messageController.text.trim().isEmpty) return;
                try {
                  final result = await ref
                      .read(houseSeekerRepositoryProvider)
                      .startConversation(
                        propertyId: listing.propertyId,
                        landlordUserId: listing.landlordUserId!,
                        listingId: listing.listingId,
                        unitId: listing.unitId,
                        subject: subjectController.text.trim().isEmpty
                            ? null
                            : subjectController.text.trim(),
                        message: messageController.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    context.pushNamed(
                      'house-seeker-conversation',
                      pathParameters: <String, String>{
                        'conversationId': result.conversation.id,
                      },
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not send message: $error')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewOnMap(BuildContext context, ListingDetailModel listing) {
    // Open map preview - handled by _MapPreview expansion or external maps
    // Could use url_launcher to open Google Maps web URL
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.mapPreviewUnavailable)));
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        color: AppColors.brandTint,
        child: const Center(
          child: Icon(
            Icons.home_work_outlined,
            size: 64,
            color: AppColors.inactive,
          ),
        ),
      );
    }
    return Stack(
      children: <Widget>[
        PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openFullScreen(context, index),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.brandTint,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: AppColors.inactive,
                  ),
                ),
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
              ),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: AppBorderRadius.roundRadius,
              ),
              child: Text(
                '${images.length}',
                style: AppTypography.labelSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _FullScreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.closeGallery,
              ),
              TextButton.icon(
                icon: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white70,
                ),
                label: Text(
                  l10n.gallery,
                  style: const TextStyle(color: Colors.white70),
                ),
                onPressed: () => _controller.jumpToPage(0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttributesRow extends StatelessWidget {
  const _AttributesRow({required this.listing});

  final ListingDetailModel listing;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if (listing.bedrooms != null)
        (
          Icons.bed_outlined,
          '${listing.bedrooms} ${listing.bedrooms == 1 ? 'bed' : 'beds'}',
        ),
      if (listing.bathrooms != null)
        (
          Icons.bathtub_outlined,
          '${listing.bathrooms!.toStringAsFixed(listing.bathrooms! % 1 == 0 ? 0 : 1)} baths',
        ),
      if (listing.propertyType != null)
        (Icons.apartment_outlined, humanizeEnum(listing.propertyType)),
      if (listing.furnished != null)
        (
          Icons.chair_outlined,
          listing.furnished! ? 'Furnished' : 'Unfurnished',
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(item.$1, size: 18, color: AppColors.brand),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        humanizeEnum(label),
        style: AppTypography.bodySmall.copyWith(color: AppColors.navy),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppBorderRadius.mediumRadius,
      child: Stack(
        children: <Widget>[
          // Placeholder map container; actual Google Map widget would require
          // an API key and platform setup. Render a geographic preview card.
          Container(
            color: AppColors.brandTint,
            child: const Center(
              child: Icon(
                Icons.map_outlined,
                size: 48,
                color: AppColors.inactive,
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: AppBorderRadius.roundRadius,
              ),
              child: Text(
                '$latitude, $longitude',
                style: AppTypography.labelSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedPropertyCard extends StatelessWidget {
  const _RelatedPropertyCard({required this.listing, required this.onTap});

  final ListingCardModel listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppBorderRadius.largeRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppBorderRadius.large),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _ListingImage(url: listing.primaryImage),
                  ),
                ),
                if (listing.images.length > 1)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
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
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${listing.images.length}',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    listing.title ?? listing.propertyTitle ?? 'Rental listing',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${formatPrice(listing.rentAmount)}${listing.rentAmount != null
                        ? listing is ListingDetailModel
                              ? (listing as ListingDetailModel).pricingLabel
                              : '/month'
                        : ''}',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (listing.locationLabel != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      listing.locationLabel!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
  const _ListingImage({required this.url});

  final String? url;

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

class _ContactBar extends ConsumerWidget {
  const _ContactBar({required this.listing});

  final ListingDetailModel listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final savedIds =
        ref.watch(houseSeekerSavedIdsProvider).asData?.value ?? <String>{};
    final comparedIds = ref.watch(houseSeekerComparisonIdsProvider);
    final isSaved = savedIds.contains(listing.listingId);
    final isCompared = comparedIds.contains(listing.listingId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton(
              onPressed: () async {
                await ref
                    .read(houseSeekerRepositoryProvider)
                    .saveListing(listing.listingId);
                ref.invalidate(houseSeekerSavedIdsProvider);
                ref.invalidate(houseSeekerSavedListingsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSaved ? l10n.propertyUnsaved : l10n.propertySaved,
                      ),
                    ),
                  );
                }
              },
              child: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final added = await ref
                    .read(houseSeekerComparisonProvider.notifier)
                    .add(listing.listingId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added ? l10n.compareAdded : l10n.compareAlreadyAdded,
                      ),
                    ),
                  );
                }
              },
              child: Icon(
                isCompared
                    ? Icons.compare_arrows
                    : Icons.compare_arrows_outlined,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _openEnquire(context, ref, listing),
              child: Icon(Icons.message_outlined, color: AppColors.brand),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openVisit(context, ref, listing),
              icon: const Icon(Icons.event_outlined),
              label: Text(l10n.requestVisit),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _openApply(context, ref, listing),
              child: Text(l10n.applyNow),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVisit(
    BuildContext context,
    WidgetRef ref,
    ListingDetailModel listing,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final notesController = TextEditingController();
    final phoneController = TextEditingController();
    await showModalBottomSheet<bool>(
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
            Text(l10n.siteVisitTitle, style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${listing.locationLabel ?? l10n.siteVisitProperty} · ${_formatDateTime(scheduled)}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note to the landlord (optional)',
                hintText: 'Let them know what you would like to see',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: l10n.siteVisitRequestVisit,
              onPressed: () async {
                try {
                  await ref
                      .read(houseSeekerRepositoryProvider)
                      .requestSiteVisit(
                        propertyId: listing.propertyId,
                        listingId: listing.listingId,
                        unitId: listing.unitId,
                        scheduledAt: scheduled.toUtc().toIso8601String(),
                        visitorNotes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.siteVisitSubmitted,
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.siteVisitRequestError}: $error'),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApply(
    BuildContext context,
    WidgetRef ref,
    ListingDetailModel listing,
  ) async {
    final rentController = TextEditingController(
      text: listing.rentAmount?.toString() ?? '',
    );
    final employerController = TextEditingController();
    final incomeController = TextEditingController();
    final startDateController = TextEditingController();
    await showModalBottomSheet<void>(
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
            Text('Apply for this home', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              listing.locationLabel ?? 'Property',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Proposed monthly rent (KES)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: startDateController,
              decoration: const InputDecoration(
                labelText: 'Preferred start date (YYYY-MM-DD)',
                hintText: 'e.g. 2026-12-01',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: employerController,
              decoration: const InputDecoration(
                labelText: 'Employer (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: incomeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly income (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Submit application',
              onPressed: () async {
                final rent = num.tryParse(rentController.text.trim());
                final income = num.tryParse(incomeController.text.trim());
                final start = startDateController.text.trim();
                try {
                  await ref
                      .read(houseSeekerRepositoryProvider)
                      .submitApplication(
                        propertyId: listing.propertyId,
                        listingId: listing.listingId,
                        unitId: listing.unitId,
                        proposedRentAmount: rent,
                        preferredStartDate: start.isEmpty ? null : start,
                        employerName: employerController.text.trim().isEmpty
                            ? null
                            : employerController.text.trim(),
                        monthlyIncome: income,
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application submitted.')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not submit application: $error'),
                      ),
                    );
                  }
                }
              },
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
  }

  Future<void> _openEnquire(
    BuildContext context,
    WidgetRef ref,
    ListingDetailModel listing,
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

  String _formatDateTime(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} at $hour:$minute';
  }
}
