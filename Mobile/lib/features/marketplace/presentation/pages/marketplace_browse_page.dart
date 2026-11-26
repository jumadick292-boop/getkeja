// Marketplace browse (Task 13.5) — customer service-category catalogue.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';

class MarketplaceBrowsePage extends ConsumerStatefulWidget {
  const MarketplaceBrowsePage({super.key});

  @override
  ConsumerState<MarketplaceBrowsePage> createState() => _MarketplaceBrowsePageState();
}

class _MarketplaceBrowsePageState extends ConsumerState<MarketplaceBrowsePage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(marketplaceCategoriesProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(marketplaceCategoriesProvider);
    final l10n = AppLocalizations.of(context)!;
    String localizedName(String id, String fallback) {
      switch (id) {
        case 'wifi_installation':
          return l10n.categoryWifiInstallation;
        case 'internet_installation':
          return l10n.categoryInternetInstallation;
        case 'solar_installation':
          return l10n.categorySolarInstallation;
        case 'painting_decoration':
          return l10n.categoryPaintingDecoration;
        default:
          return fallback;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Home services')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load services: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No services available yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = items[index];
              final id = category['id'] as String? ?? '';
              final fallback = category['name'] as String? ?? id;
              final name = localizedName(id, fallback);
              final domain = category['domain'] as String? ?? '';
              final description = category['description'] as String? ?? '';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.home_repair_service_outlined),
                  title: Text(name),
                  subtitle: Text('$domain${description.isEmpty ? '' : ' — $description'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/marketplace/request/new', extra: <String, dynamic>{
                    'categoryId': id,
                    'categoryName': name,
                    'domain': domain,
                  }),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/requests'),
        icon: const Icon(Icons.list_alt),
        label: const Text('My requests'),
      ),
    );
  }
}