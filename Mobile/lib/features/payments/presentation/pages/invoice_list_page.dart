// Invoice list page.
// Shows all tenant invoices with status, due dates, and balances.
// Provides a clear action to pay outstanding invoices.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/invoice_detail_page.dart';

class InvoiceListPage extends ConsumerWidget {
  const InvoiceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(invoicesProvider),
          ),
        ],
      ),
      body: invoicesAsync.when(
        data: (invoices) => _buildList(context, ref, invoices, l10n),
        loading: () => const Center(child: AppListSkeleton(rows: 5)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadInvoices,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                onPressed: () => ref.refresh(invoicesProvider),
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
    WidgetRef ref,
    List<InvoiceModel> invoices,
    AppLocalizations l10n,
  ) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noInvoices,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(invoiceId: inv.id),
                ),
              );
            },
            borderRadius: AppBorderRadius.mediumRadius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.invoiceNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              inv.description ?? l10n.invoiceDescription,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(inv.status)
                                  .withValues(alpha: 0.1),
                              borderRadius: AppBorderRadius.roundRadius,
                            ),
                            child: Text(
                              inv.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(inv.status),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${inv.currency} ${inv.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(Icons.event, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${inv.dueDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (inv.isPayable)
                        SecondaryButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailPage(
                                  invoiceId: inv.id,
                                ),
                              ),
                            );
                          },
                          label: l10n.pay,
                          isFullWidth: false,
                          icon: const Icon(Icons.payment, size: 18),
                        )
                      else
                        Text(
                          l10n.invoiceNotPayable,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'cancelled':
      case 'void':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
