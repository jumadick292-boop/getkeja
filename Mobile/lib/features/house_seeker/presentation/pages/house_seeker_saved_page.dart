import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerSavedPage extends ConsumerWidget {
  const HouseSeekerSavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final savedAsync = ref.watch(houseSeekerSavedListingsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: Text(l10n.savedHomes)),
      body: savedAsync.when(
        data: (saved) => saved.isEmpty
            ? const _EmptySaved()
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(houseSeekerSavedListingsProvider);
                  await ref.read(houseSeekerSavedListingsProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = saved[index];
                    return _SavedTile(
                      saved: item,
                      onOpen: () => context.pushNamed(
                        'house-seeker-listing-detail',
                        pathParameters: <String, String>{
                          'listingId': item.listingId,
                        },
                      ),
                      onRemove: () async {
                        await ref
                            .read(houseSeekerRepositoryProvider)
                            .removeSavedListing(item.listingId);
                        ref.invalidate(houseSeekerSavedListingsProvider);
                        ref.invalidate(houseSeekerSavedIdsProvider);
                      },
                      onEnquire: () async {
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
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom +
                                  AppSpacing.lg,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Send enquiry',
                                  style: AppTypography.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  item.locationLabel ?? 'Property',
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
                                    hintText:
                                        'Tell the landlord about yourself...',
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
                                            propertyId: item.propertyId,
                                            listingId: item.listingId,
                                            message: messageController.text
                                                .trim(),
                                            phone: phoneController.text.trim(),
                                          );
                                      if (context.mounted) {
                                        Navigator.of(context).pop(true);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Enquiry sent.'),
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not send enquiry: $error',
                                            ),
                                          ),
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
                      },
                    );
                  },
                ),
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: l10n.couldNotLoadSavedHomes,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(houseSeekerSavedListingsProvider),
        ),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.saved,
    required this.onOpen,
    required this.onRemove,
    required this.onEnquire,
  });

  final SavedListingModel saved;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;
  final Future<void> Function() onEnquire;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: saved.primaryImage != null
                ? ClipRRect(
                    borderRadius: AppBorderRadius.mediumRadius,
                    child: Image.network(
                      saved.primaryImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.home_outlined,
                        color: AppColors.brand,
                      ),
                    ),
                  )
                : const Icon(Icons.home_outlined, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  saved.title.isNotEmpty ? saved.title : l10n.rentalListing,
                  style: AppTypography.titleSmall.copyWith(
                    color: saved.isAvailable
                        ? AppColors.text
                        : AppColors.inactive,
                  ),
                ),
                if (saved.locationLabel != null &&
                    saved.locationLabel!.isNotEmpty)
                  Text(
                    saved.locationLabel!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                if (saved.rentAmount > 0)
                  Text(
                    'KES ${saved.rentAmount}${_pricingLabel(saved)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (!saved.isAvailable)
                  Text(
                    l10n.propertyUnavailable,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: l10n.remove,
            onPressed: () async {
              await onRemove();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.removedFromSaved)));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined, color: AppColors.brand),
            tooltip: l10n.enquire,
            onPressed: () async {
              await onEnquire();
            },
          ),
        ],
      ),
    );
  }
}

String _pricingLabel(SavedListingModel saved) {
  return '/mo';
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.favorite_border,
              size: 56,
              color: AppColors.inactive,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.noSavedHomesYet, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.tapHeartSaveHome,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.discoverHomes,
              onPressed: () => context.goNamed('house-seeker-home'),
            ),
          ],
        ),
      ),
    );
  }
}
