// Messaging state (contextual conversations) — Riverpod providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/messaging/data/datasources/messaging_remote_datasource.dart';

final messagingRemoteDataSourceProvider = Provider<MessagingRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MessagingRemoteDataSource(apiClient.dio);
});

final conversationMessagesProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, conversationId) async {
  return ref.watch(messagingRemoteDataSourceProvider).getMessages(conversationId);
});