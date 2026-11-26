// Provider reviews (Task 13.16) — list reviews about own jobs + respond.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class ProviderReviewsPage extends ConsumerWidget {
  const ProviderReviewsPage({super.key});

  Future<void> _respond(BuildContext context, WidgetRef ref, String reviewId) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.respondToReview),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Write a response')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: Text(AppLocalizations.of(context)!.save)),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await ref.read(providerPlatformRemoteDataSourceProvider).respondReview(reviewId, text);
      ref.invalidate(providerReviewsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(providerReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviews)),
      body: async.when(
        data: (reviews) => reviews.isEmpty
            ? Center(child: Text(l10n.noReviews, style: AppTypography.bodyMedium))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(providerReviewsProvider),
                child: ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: reviews.length,
                  itemBuilder: (context, i) {
                    final r = reviews[i];
                    final hasResponse = (r['response']?.toString() ?? '').isNotEmpty;
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('${r['overallRating']}★', style: AppTypography.titleMedium),
                            Text('${r['status']}', style: AppTypography.bodySmall),
                          ]),
                          if ((r['comment']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r['comment'].toString(), style: AppTypography.bodyMedium),
                          ],
                          if (hasResponse) ...[
                            const SizedBox(height: 6),
                            Text('${l10n.providerResponse}: ${r['response']}', style: AppTypography.bodySmall),
                          ] else ...[
                            const SizedBox(height: 8),
                            PrimaryButton(label: l10n.respondToReview, onPressed: () => _respond(context, ref, r['id'] as String)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
        loading: () => const AppListSkeleton(rows: 5),
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(providerReviewsProvider)),
      ),
    );
  }
}