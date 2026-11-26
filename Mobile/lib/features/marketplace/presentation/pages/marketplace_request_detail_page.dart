// Marketplace request detail (Task 13.5) — customer views quotations + accepts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';
import 'package:get_keja_mobile/features/messaging/presentation/conversation_launcher.dart';

class MarketplaceRequestDetailPage extends ConsumerStatefulWidget {
  const MarketplaceRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<MarketplaceRequestDetailPage> createState() =>
      _MarketplaceRequestDetailPageState();
}

class _MarketplaceRequestDetailPageState extends ConsumerState<MarketplaceRequestDetailPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(marketplaceRequestDetailProvider(widget.requestId).notifier).load(widget.requestId),
    );
  }

  Future<void> _accept(String quotationId, int version) async {
    try {
      await ref
          .read(marketplaceRequestDetailProvider(widget.requestId).notifier)
          .acceptQuotation(widget.requestId, quotationId, expectedVersion: version);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept quotation: $error')),
      );
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(marketplaceRequestDetailProvider(widget.requestId).notifier).cancel(widget.requestId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel request: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(marketplaceRequestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request detail'),
        actions: [
          IconButton(
            tooltip: 'Contact provider',
            icon: const Icon(Icons.message_outlined),
            onPressed: () => startContextualConversation(
              context,
              ref,
              type: 'marketplace_request',
              marketplaceRequestId: widget.requestId,
              subject: 'Request detail',
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load request: $error')),
        data: (data) {
          final status = data['status'] as String? ?? 'open';
          final description = data['description'] as String? ?? '';
          final quotations = (data['quotations'] as List? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
          final liveQuotations = quotations
              .where((q) => q['status'] == 'submitted' || q['status'] == 'revised')
              .toList();
          final canCancel = status == 'open' || status == 'quoted' || status == 'accepted';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Status: ${status.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 20),
              Text('Quotations (${liveQuotations.length} live)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (liveQuotations.isEmpty)
                const Text('No quotations yet. Providers will respond soon.')
              else
                ...liveQuotations.map((q) {
                  final id = q['id'] as String? ?? '';
                  final version = (q['versionNumber'] as num?)?.toInt() ?? 1;
                  final total = q['totalAmount'] as String? ?? '';
                  final provider = (q['providerName'] as String?) ?? 'Provider';
                  final currency = q['currency'] as String? ?? 'KES';
                  return Card(
                    child: ListTile(
                      title: Text('$provider — $currency $total'),
                      subtitle: Text('Version $version'),
                      trailing: status == 'open' || status == 'quoted'
                          ? FilledButton(
                              onPressed: () => _accept(id, version),
                              child: const Text('Accept'),
                            )
                          : null,
                    ),
                  );
                }),
              const SizedBox(height: 24),
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel request'),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/marketplace/requests'),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}