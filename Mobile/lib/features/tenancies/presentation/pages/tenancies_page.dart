// Tenancies page.
// Lists the authenticated tenant's tenancies with active/historical filtering.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';
import 'package:get_keja_mobile/features/tenancies/presentation/state/tenancy_state.dart';
import 'package:get_keja_mobile/features/tenancies/presentation/widgets/tenancy_card.dart';

class TenanciesPage extends ConsumerWidget {
  const TenanciesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenanciesAsync = ref.watch(tenancyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tenancies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(tenancyProvider.notifier).refresh(),
          ),
        ],
      ),
      body: tenanciesAsync.when(
        data: (tenancies) {
          if (tenancies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tenancies found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Your tenancy records will appear here once you have an active tenancy.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final active = tenancies.where((t) => t.isActive).toList();
          final historical = tenancies.where((t) => !t.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                const Text(
                  'Active Tenancy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                ...active.map(
                  (t) => TenancyCard(
                    tenancy: t,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/tenant/tenancies/${t.id}',
                    ),
                  ),
                ),
              ],
              if (historical.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Historical Tenancies',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ...historical.map(
                  (t) => TenancyCard(
                    tenancy: t,
                    onTap: () => Navigator.of(context).pushNamed(
                      '/tenant/tenancies/${t.id}',
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load tenancies',
                style: TextStyle(fontSize: 18, color: Colors.red[700]),
              ),
              const SizedBox(height: 8),
              Text(
                (error as AppException).message,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => ref.read(tenancyProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
