// Receipts page.
// Lists receipts generated after verified payment success.
// Supports secure receipt download via signed download URL.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceiptsPage extends ConsumerStatefulWidget {
  const ReceiptsPage({super.key});

  @override
  ConsumerState<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends ConsumerState<ReceiptsPage> {
  String? _downloadingReceiptId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final receiptsAsync = ref.watch(receiptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(receiptsProvider),
          ),
        ],
      ),
      body: receiptsAsync.when(
        data: (receipts) => _buildList(context, receipts, l10n),
        loading: () => const Center(child: AppListSkeleton(rows: 5)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadReceipts,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                onPressed: () => ref.refresh(receiptsProvider),
                label: l10n.tryAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ReceiptModel> receipts,
    AppLocalizations l10n,
  ) {
    if (receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noReceipts,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: receipts.length,
      itemBuilder: (context, index) {
        final r = receipts[index];
        final isDownloading = _downloadingReceiptId == r.id;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.receipt, size: 24),
            title: Text(r.receiptNumber),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.paymentMethod}  •  ${r.paymentDate}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Outstanding after payment: ${r.currency} ${r.outstandingBalanceAfter.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${r.currency} ${r.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isDownloading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: () => _downloadReceipt(r.id),
                    tooltip: l10n.downloadReceipt,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadReceipt(String receiptId) async {
    setState(() {
      _downloadingReceiptId = receiptId;
    });

    try {
      final result = await ref.read(paymentRepositoryProvider).downloadReceipt(receiptId);
      final url = result.url;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open download URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReceiptId = null;
        });
      }
    }
  }
}
