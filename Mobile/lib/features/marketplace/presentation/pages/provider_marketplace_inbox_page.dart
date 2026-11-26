// Provider marketplace inbox (Task 13.5) — open requests the provider can quote.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';

class ProviderMarketplaceInboxPage extends ConsumerStatefulWidget {
  const ProviderMarketplaceInboxPage({super.key});

  @override
  ConsumerState<ProviderMarketplaceInboxPage> createState() =>
      _ProviderMarketplaceInboxPageState();
}

class _ProviderMarketplaceInboxPageState extends ConsumerState<ProviderMarketplaceInboxPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerMarketplaceInboxProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(providerMarketplaceInboxProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Service requests')),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load inbox: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No open requests match your services.'));
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
              final county = item['serviceCounty'] as String? ?? '';
              return ListTile(
                title: Text(title),
                subtitle: Text(county.isEmpty ? 'Open for quotations' : county),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/provider/marketplace/requests/$id'),
              );
            },
          );
        },
      ),
    );
  }
}