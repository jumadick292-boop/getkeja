// Provider assigned laundry orders list (Task 13.8).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/laundry/presentation/state/laundry_state.dart';

class ProviderLaundryOrdersPage extends ConsumerStatefulWidget {
  const ProviderLaundryOrdersPage({super.key});

  @override
  ConsumerState<ProviderLaundryOrdersPage> createState() => _ProviderLaundryOrdersPageState();
}

class _ProviderLaundryOrdersPageState extends ConsumerState<ProviderLaundryOrdersPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(providerLaundryOrdersProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orders = ref.watch(providerLaundryOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerLaundryOrders)),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(providerLaundryOrdersProvider.notifier).load(),
                child: Text(l10n.laundryRetry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return Center(child: Text(l10n.laundryNoOrders));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = items[index];
              final id = order['id'] as String? ?? '';
              final status = (order['status'] as String? ?? '').replaceAll('_', ' ');
              final date = order['returnDate'] as String? ?? order['collectionDate'] as String? ?? '';
              return ListTile(
                title: Text(status.isEmpty ? id : status.toUpperCase()),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/laundry/provider/orders/$id'),
              );
            },
          );
        },
      ),
    );
  }
}