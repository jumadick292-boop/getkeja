// Messaging & Communication Centre widget tests.
//
// Exercises the House Seeker conversations list and conversation thread:
//   - loading, empty and data states for the inbox
//   - conversation tile rendering (subject, location, unread badge)
//   - thread rendering with message bubbles
//   - empty thread state
//   - send-message flow (repository interaction, field cleared on success)
//   - error notice rendering (AppNotice in isolation, matching the pattern
//     used by house_seeker_saved_page_test.dart)
//
// Uses the shared [houseSeekerApp] helper and a focused fake repository that
// implements only the messaging surface required by these pages.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/repositories/house_seeker_repository.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_conversation_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/pages/house_seeker_conversations_page.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

import 'house_seeker_test_utils.dart';

void main() {
  group('HouseSeekerConversationsPage', () {
    testWidgets('shows a loading skeleton while conversations load', (tester) async {
      final completer = Completer<List<ConversationModel>>();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(
                  conversationsCompleter: completer,
                ),
              ),
            ],
            child: const HouseSeekerConversationsPage(),
          ),
        ),
      );
      expect(find.byType(AppListSkeleton), findsOneWidget);
      completer.complete(<ConversationModel>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows an empty state when there are no conversations', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(),
              ),
            ],
            child: const HouseSeekerConversationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppListSkeleton), findsNothing);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.text('Conversations with landlords appear here once you start chatting.'),
        findsOneWidget,
      );
    });

    testWidgets('renders a conversation tile with subject, location and unread badge',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(conversations: _sampleConversations()),
              ),
            ],
            child: const HouseSeekerConversationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('About the apartment'), findsOneWidget);
      expect(find.text('Kilimani'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('AppNotice renders the conversations error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: Scaffold(
            body: AppNotice(
              message: 'Could not load your conversations.',
              type: NoticeType.error,
              actionLabel: 'Retry',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load your conversations.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('HouseSeekerConversationPage', () {
    testWidgets('shows a loading skeleton while messages load', (tester) async {
      final completer = Completer<List<MessageModel>>();
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(messagesCompleter: completer),
              ),
            ],
            child: const HouseSeekerConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      expect(find.byType(AppListSkeleton), findsOneWidget);
      completer.complete(<MessageModel>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows an empty thread state when there are no messages', (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(),
              ),
            ],
            child: const HouseSeekerConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Send the first message to start the conversation.'),
          findsOneWidget);
    });

    testWidgets('renders messages with the send button disabled until text is entered',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(
                _MessagingFakeRepository(messages: _sampleMessages()),
              ),
            ],
            child: const HouseSeekerConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello, is this still available?'), findsOneWidget);
      expect(find.text('Yes, it is available'), findsOneWidget);

      final sendButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('sends a message and clears the input field on success', (tester) async {
      final repo = _MessagingFakeRepository(messages: _sampleMessages());
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const HouseSeekerConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Can I schedule a visit?');
      await tester.pump();
      // Trigger send via the keyboard action (AppTextField.onSubmitted -> _send).
      // The IconButton may be disabled until a rebuild after enterText.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(repo.sentMessages, contains('Can I schedule a visit?'));
      expect(repo.markedReadConversationId, equals('conv-1'));
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
    });

    testWidgets('shows a snackbar when sending fails', (tester) async {
      final repo = _MessagingFakeRepository(
        messages: _sampleMessages(),
        sendError: true,
      );
      await tester.pumpWidget(
        houseSeekerApp(
          child: ProviderScope(
            overrides: [
              houseSeekerRepositoryProvider.overrideWithValue(repo),
            ],
            child: const HouseSeekerConversationPage(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Failing message');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Could not send your message. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('AppNotice renders the messages error message and retry action',
        (tester) async {
      await tester.pumpWidget(
        houseSeekerApp(
          child: Scaffold(
            body: AppNotice(
              message: 'Could not load messages.',
              type: NoticeType.error,
              actionLabel: 'Retry',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Could not load messages.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

List<ConversationModel> _sampleConversations() => <ConversationModel>[
      ConversationModel(
        id: 'conv-1',
        status: 'active',
        subject: 'About the apartment',
        propertyId: 'prop-1',
        propertyTitle: 'Cozy 2-bedroom',
        city: 'Kilimani',
        county: 'Nairobi',
        unreadCount: 2,
      ),
    ];

List<MessageModel> _sampleMessages() => <MessageModel>[
      MessageModel(
        id: 'msg-1',
        conversationId: 'conv-1',
        content: 'Hello, is this still available?',
        senderId: 'landlord-1',
        createdAt: '2026-01-01T10:00:00Z',
      ),
      MessageModel(
        id: 'msg-2',
        conversationId: 'conv-1',
        content: 'Yes, it is available',
        senderId: 'me',
        createdAt: '2026-01-01T10:05:00Z',
      ),
    ];

/// Fake repository implementing only the messaging surface used by the
/// conversation pages. Non-messaging methods throw [UnimplementedError].
class _MessagingFakeRepository implements HouseSeekerRepository {
  _MessagingFakeRepository({
    this.conversations = const <ConversationModel>[],
    this.messages = const <MessageModel>[],
    this.sendError = false,
    Completer<List<ConversationModel>>? conversationsCompleter,
    Completer<List<MessageModel>>? messagesCompleter,
  })  : _conversationsCompleter = conversationsCompleter,
        _messagesCompleter = messagesCompleter;

  final List<ConversationModel> conversations;
  final List<MessageModel> messages;
  final bool sendError;
  final Completer<List<ConversationModel>>? _conversationsCompleter;
  final Completer<List<MessageModel>>? _messagesCompleter;

  final List<String> sentMessages = <String>[];
  String? markedReadConversationId;

  @override
  Future<List<ConversationModel>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    if (_conversationsCompleter != null) {
      return _conversationsCompleter.future;
    }
    return conversations;
  }

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (_messagesCompleter != null) {
      return _messagesCompleter.future;
    }
    return messages;
  }

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    if (sendError) {
      throw Exception('send failed');
    }
    sentMessages.add(content);
    return MessageModel(
      id: 'msg-${sentMessages.length}',
      conversationId: conversationId,
      content: content,
      senderId: 'me',
      createdAt: '2026-01-01T10:10:00Z',
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    markedReadConversationId = conversationId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used in this test');
}