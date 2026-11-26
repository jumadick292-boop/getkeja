// Provider laundry order detail + operational controls (Task 13.8).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/laundry/presentation/state/laundry_state.dart';

class ProviderLaundryOrderDetailPage extends ConsumerStatefulWidget {
  const ProviderLaundryOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ProviderLaundryOrderDetailPage> createState() => _ProviderLaundryOrderDetailPageState();
}

class _ProviderLaundryOrderDetailPageState extends ConsumerState<ProviderLaundryOrderDetailPage> {
  static const List<String> _processing = <String>[
    'processing', 'washing', 'drying', 'ironing', 'folding', 'quality_check',
  ];

  // Allowed provider-driven next statuses (mirrors the backend matrix, with
  // forward skipping across processing stages).
  List<String> _next(String status) {
    switch (status) {
      case 'confirmed':
        return <String>['collection_scheduled', 'received_at_facility'];
      case 'collection_scheduled':
        return <String>['collected'];
      case 'collected':
        return <String>['received_at_facility'];
      case 'received_at_facility':
        return <String>['inspection', 'ready_for_return'];
      case 'inspection':
        return <String>['processing', 'ready_for_return'];
      case 'awaiting_customer_approval':
        return <String>[..._processing, 'ready_for_return'];
      case 'ready_for_return':
        return <String>['out_for_delivery', 'awaiting_customer_confirmation'];
      case 'out_for_delivery':
        return <String>['delivered'];
      case 'delivered':
        return <String>['awaiting_customer_confirmation'];
      default:
        if (_processing.contains(status)) {
          final i = _processing.indexOf(status);
          return <String>[..._processing.sublist(i + 1), 'ready_for_return'];
        }
        return <String>[];
    }
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerLaundryOrderDetailProvider(widget.orderId).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(providerLaundryOrderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.laundryOrderDetails)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (order) {
          final status = order['status'] as String? ?? '';
          final canView = order['canViewLocations'] == true;
          final items = (order['items'] as List?) ?? const <dynamic>[];
          final next = _next(status);
          final notifier = ref.read(providerLaundryOrderDetailProvider(widget.orderId).notifier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${l10n.laundryStatus}: ${status.replaceAll('_', ' ').toUpperCase()}'),
              const SizedBox(height: 8),
              if (canView && (order['collectionAddress'] as String?) != null)
                Text('${order['collectionAddress']}'),
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
              if (status == 'ready_for_return' || status == 'out_for_delivery')
                FilledButton(
                  onPressed: () => notifier.submitCompletion(outstandingIssue: false),
                  child: Text(l10n.laundryConfirmDelivery),
                ),
              for (final to in next)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => notifier.updateProgress(to),
                    child: Text(to.replaceAll('_', ' ').toUpperCase()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}