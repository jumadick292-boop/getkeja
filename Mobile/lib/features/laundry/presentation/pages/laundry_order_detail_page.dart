// Customer laundry order detail (Task 13.8).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/laundry/presentation/state/laundry_state.dart';
import 'package:get_keja_mobile/features/messaging/presentation/conversation_launcher.dart';

class LaundryOrderDetailPage extends ConsumerStatefulWidget {
  const LaundryOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<LaundryOrderDetailPage> createState() => _LaundryOrderDetailPageState();
}

class _LaundryOrderDetailPageState extends ConsumerState<LaundryOrderDetailPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(customerLaundryOrderDetailProvider(widget.orderId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(customerLaundryOrderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.laundryOrderDetails),
        actions: [
          IconButton(
            tooltip: l10n.contactProvider,
            icon: const Icon(Icons.message_outlined),
            onPressed: () => startContextualConversation(
              context,
              ref,
              type: 'laundry_order',
              laundryOrderId: widget.orderId,
              subject: l10n.laundryOrderDetails,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (order) {
          final status = (order['status'] as String? ?? '').replaceAll('_', ' ');
          final items = (order['items'] as List?) ?? const <dynamic>[];
          final awaiting = order['status'] == 'awaiting_customer_confirmation';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.laundryStatus}: ${status.toUpperCase()}'),
              const SizedBox(height: 8),
              if ((order['returnDate'] as String?) != null)
                Text('${l10n.laundrySchedule}: ${order['returnDate']}'),
              const SizedBox(height: 16),
              Text(l10n.laundryItems),
              for (final item in items)
                if (item is Map<String, dynamic>)
                  ListTile(
                    dense: true,
                    title: Text('${item['itemCategory'] ?? ''} x${item['quantity'] ?? 0}'),
                    subtitle: Text((item['description'] as String?) ?? ''),
                  ),
              const SizedBox(height: 16),
              if (awaiting)
                FilledButton(
                  onPressed: () => ref
                      .read(customerLaundryOrderDetailProvider(widget.orderId).notifier)
                      .confirmCompletion(confirm: true),
                  child: Text(l10n.laundryConfirmDelivery),
                ),
            ],
          );
        },
      ),
    );
  }
}