import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

class HouseSeekerConversationPage extends ConsumerStatefulWidget {
  const HouseSeekerConversationPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<HouseSeekerConversationPage> createState() => _HouseSeekerConversationPageState();
}

class _HouseSeekerConversationPageState extends ConsumerState<HouseSeekerConversationPage> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = ref.read(authNotifierProvider).user?.id;
    // Mark as read on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(houseSeekerRepositoryProvider).markConversationRead(widget.conversationId).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(houseSeekerRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            content: text,
          );
      _controller.clear();
      ref.invalidate(houseSeekerMessagesProvider(widget.conversationId));
      ref.invalidate(houseSeekerConversationsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your message. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(houseSeekerMessagesProvider(widget.conversationId));
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messagesAsync.when(
              data: (messages) => messages.isEmpty
                  ? const _EmptyThread()
                  : ListView.builder(
                      reverse: false,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: _myUserId != null && message.senderId == _myUserId,
                        );
                      },
                    ),
              loading: () => const AppListSkeleton(rows: 5),
              error: (error, _) => AppNotice(
                message: 'Could not load messages.',
                type: NoticeType.error,
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(houseSeekerMessagesProvider(widget.conversationId)),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.inactive, width: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      label: 'Message',
                      hintText: 'Type a message...',
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: _sending || _controller.text.trim().isEmpty ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final color = isMine ? AppColors.brand : Colors.white;
    final textColor = isMine ? Colors.white : AppColors.text;
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: const Radius.circular(12),
            bottomRight: Radius.circular(isMine ? 4 : 12),
          ),
          border: isMine ? null : Border.all(color: AppColors.inactive.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message.content, style: AppTypography.bodyMedium.copyWith(color: textColor)),
            if (message.createdAt != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                _formatTime(message.createdAt!),
                style: AppTypography.labelSmall.copyWith(
                  color: isMine ? Colors.white70 : AppColors.mutedText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.inactive),
            const SizedBox(height: AppSpacing.md),
            Text('No messages yet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Send the first message to start the conversation.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}