// Contextual conversation page.
// Reuses the existing /api/v1/messaging backend. Opened from a service detail
// page via startContextualConversation; the backend enforces participant
// authorization and conversation reuse/dedup.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/messaging_state.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId, this.subject});

  final String conversationId;
  final String? subject;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagingRemoteDataSourceProvider).markRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingRemoteDataSourceProvider)
          .sendMessage(widget.conversationId, text);
      _controller.clear();
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotLoadNotifications)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject ?? l10n.messages)),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noMessages,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final content = m['content'] as String? ?? '';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Text(content, style: AppTypography.bodyMedium),
                      ),
                    );
                  },
                );
              },
              loading: () => const AppListSkeleton(rows: 4),
              error: (_, __) => AppNotice(
                message: l10n.couldNotLoadNotifications,
                type: NoticeType.error,
                actionLabel: l10n.retry,
                onAction: () =>
                    ref.invalidate(conversationMessagesProvider(widget.conversationId)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      label: l10n.typeMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const AppLoadingIndicator()
                      : IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
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