import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';

class HouseSeekerConversationsPage extends ConsumerWidget {
  const HouseSeekerConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(houseSeekerConversationsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Messages')),
      body: conversationsAsync.when(
        data: (conversations) => conversations.isEmpty
            ? const _EmptyConversations()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _ConversationTile(conversation: conversation);
                },
              ),
        loading: () => const AppListSkeleton(rows: 5),
        error: (error, _) => AppNotice(
          message: 'Could not load your conversations.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerConversationsProvider),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    final location = <String>[
      if (conversation.city != null && conversation.city!.trim().isNotEmpty) conversation.city!.trim(),
    ].join(', ');

    return AppCard(
      onTap: () => context.pushNamed(
        'house-seeker-conversation',
        pathParameters: <String, String>{'conversationId': conversation.id},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: AppColors.brandTint,
            child: const Icon(Icons.forum_outlined, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.displayTitle,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: conversation.hasUnread ? AppColors.text : AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.lastMessageAt != null)
                      Text(
                        formatDateLabel(conversation.lastMessageAt),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.mutedText),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (location.isNotEmpty)
                  Text(
                    location,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        humanizeEnum(conversation.status),
                        style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
                      ),
                    ),
                    if (conversation.hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: AppBorderRadius.roundRadius,
                        ),
                        child: Text(
                          '${conversation.unreadCount}',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text('No messages yet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Conversations with landlords appear here once you start chatting.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}