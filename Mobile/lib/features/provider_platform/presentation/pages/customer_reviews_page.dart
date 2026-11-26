// Customer reviews (Task 13.16) — list own reviews + submit a verified review
// for an eligible completed job (domain + resourceId supplied by the caller).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/provider_platform_state.dart';

class CustomerReviewsPage extends ConsumerStatefulWidget {
  const CustomerReviewsPage({super.key, this.domain, this.resourceId});
  final String? domain;
  final String? resourceId;

  @override
  ConsumerState<CustomerReviewsPage> createState() => _CustomerReviewsPageState();
}

class _CustomerReviewsPageState extends ConsumerState<CustomerReviewsPage> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (widget.domain == null || widget.resourceId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(providerPlatformRemoteDataSourceProvider).submitReview(
            widget.domain!,
            widget.resourceId!,
            <String, dynamic>{'overallRating': _rating, if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim()},
          );
      ref.invalidate(myReviewsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadNotifications)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(myReviewsProvider);
    final canSubmit = widget.domain != null && widget.resourceId != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myReviews)),
      body: async.when(
        data: (reviews) => ListView(
          padding: AppSpacing.screenPadding,
          children: [
            if (canSubmit) ...[
              AppSectionHeader(title: l10n.submitReview),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          ChoiceChip(
                            label: Text('$i★'),
                            selected: _rating == i,
                            onSelected: (_) => setState(() => _rating = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _comment, maxLines: 2, decoration: InputDecoration(labelText: l10n.feedback)),
                    const SizedBox(height: 8),
                    PrimaryButton(label: l10n.submitReview, onPressed: _busy ? null : _submit),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (reviews.isEmpty)
              Center(child: Text(l10n.noReviews, style: AppTypography.bodyMedium))
            else
              for (final r in reviews)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['overallRating']}★', style: AppTypography.titleMedium),
                      if ((r['comment']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r['comment'].toString(), style: AppTypography.bodyMedium),
                      ],
                    ],
                  ),
                ),
          ],
        ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(message: l10n.couldNotLoadNotifications, type: NoticeType.error, actionLabel: l10n.retry, onAction: () => ref.invalidate(myReviewsProvider)),
      ),
    );
  }
}