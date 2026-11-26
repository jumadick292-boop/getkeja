// Garbage services page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/garbage/presentation/pages/garbage_request_form_page.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_state.dart';class GarbagePage extends ConsumerWidget {
  const GarbagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(garbageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garbage Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(garbageProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const GarbageRequestFormPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No garbage service requests',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.green),
                  title: Text(r.providerName.isNotEmpty ? r.providerName : 'Garbage Service'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category: ${r.category}'),
                      Text('Status: ${r.status}'),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load garbage services',
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                (error as AppException).message,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
