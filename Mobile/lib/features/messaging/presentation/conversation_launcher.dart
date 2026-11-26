// Helper to start (or reuse) an authorized contextual conversation and open it.
// The backend enforces participant authorization and conversation dedup; the
// caller only supplies the business context id.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/messaging_remote_datasource.dart';
import 'pages/conversation_page.dart';
import 'state/messaging_state.dart';

Future<void> startContextualConversation(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  String? movingJobId,
  String? marketplaceRequestId,
  String? garbageJobId,
  String? laundryOrderId,
  String? schedulingActivityId,
  String? subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final conversation = await ref.read(messagingRemoteDataSourceProvider).startConversation(
          type: type,
          movingJobId: movingJobId,
          marketplaceRequestId: marketplaceRequestId,
          garbageJobId: garbageJobId,
          laundryOrderId: laundryOrderId,
          schedulingActivityId: schedulingActivityId,
        );
    final id = conversation['id'] as String?;
    if (id == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage(conversationId: id, subject: subject),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open conversation')),
    );
  }
}