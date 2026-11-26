// Provider marketplace detail (Task 13.5) — view request, submit quotation, advance job.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';

class ProviderMarketplaceDetailPage extends ConsumerStatefulWidget {
  const ProviderMarketplaceDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ProviderMarketplaceDetailPage> createState() =>
      _ProviderMarketplaceDetailPageState();
}

class _ProviderMarketplaceDetailPageState extends ConsumerState<ProviderMarketplaceDetailPage> {
  final _amountController = TextEditingController();
  final _itemController = TextEditingController();
  final _termsController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(providerMarketplaceDetailProvider(widget.requestId).notifier)
          .load(widget.requestId),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _itemController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  String? _resolveProfileId() {
    final data = ref.read(providerMarketplaceDetailProvider(widget.requestId)).asData?.value;
    if (data == null) return null;
    final assigned = data['assignedProviderId'] as String?;
    if (assigned != null) return assigned;
    final eligible = data['eligibleProfileIds'];
    if (eligible is List && eligible.isNotEmpty) return eligible.first as String?;
    return null;
  }

  Future<void> _submitQuotation() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid total amount')),
      );
      return;
    }
    final profileId = _resolveProfileId();
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No provider profile available to quote with')),
      );
      return;
    }
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'profileId': profileId,
      'currency': 'KES',
      'items': [
        <String, dynamic>{
          'description': _itemController.text.trim().isEmpty ? 'Service' : _itemController.text.trim(),
          'quantity': 1,
          'unitPrice': amount,
          'amount': amount,
        },
      ],
      'subtotalAmount': amount,
      'totalAmount': amount,
      'validUntil': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      if (_termsController.text.isNotEmpty) 'terms': _termsController.text.trim(),
    };
    try {
      await ref
          .read(providerMarketplaceDetailProvider(widget.requestId).notifier)
          .submitQuotation(widget.requestId, body);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit quotation: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _advance(String action) async {
    try {
      await ref
          .read(providerMarketplaceDetailProvider(widget.requestId).notifier)
          .advance(widget.requestId, action);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update job: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(providerMarketplaceDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(title: const Text('Request')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load request: $error')),
        data: (data) {
          final status = data['status'] as String? ?? 'open';
          final description = data['description'] as String? ?? '';
          final assigned = data['assignedProviderId'] as String?;
          final quotable = status == 'open' || status == 'quoted';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Status: ${status.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 24),
              if (quotable) ...[
                Text('Submit a quotation', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _itemController,
                  decoration: const InputDecoration(labelText: 'Item / description'),
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Total amount (KES)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _termsController,
                  decoration: const InputDecoration(labelText: 'Terms (optional)'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : _submitQuotation,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send quotation'),
                ),
              ],
              if (assigned != null && (status == 'accepted' || status == 'in_progress')) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (status == 'accepted')
                      FilledButton(
                        onPressed: () => _advance('start'),
                        child: const Text('Start job'),
                      ),
                    if (status == 'in_progress') ...[
                      FilledButton(
                        onPressed: () => _advance('complete'),
                        child: const Text('Mark complete'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}