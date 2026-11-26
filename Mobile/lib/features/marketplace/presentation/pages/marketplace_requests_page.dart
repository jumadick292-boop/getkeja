// Marketplace requests list (Task 13.5) — customer's own requests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';

class MarketplaceRequestsPage extends ConsumerStatefulWidget {
  const MarketplaceRequestsPage({super.key});

  @override
  ConsumerState<MarketplaceRequestsPage> createState() => _MarketplaceRequestsPageState();
}

class _MarketplaceRequestsPageState extends ConsumerState<MarketplaceRequestsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(marketplaceRequestsProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(marketplaceRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My service requests')),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load requests: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('You have not posted any requests yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item['id'] as String? ?? '';
              final title = (item['title'] as String?)?.isNotEmpty == true
                  ? item['title'] as String
                  : (item['categoryName'] as String? ?? 'Request');
              final status = item['status'] as String? ?? 'open';
              return ListTile(
                title: Text(title),
                subtitle: Text(status.toUpperCase()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/marketplace/requests/$id'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/marketplace'),
        child: const Icon(Icons.add),
      ),
    );
  }
}