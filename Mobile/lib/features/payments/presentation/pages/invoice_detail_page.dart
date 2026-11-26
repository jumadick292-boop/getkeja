// Invoice detail page.
// Shows invoice line items, amounts paid/outstanding, and payment history.
// Provides a clear action to pay outstanding invoices.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/payment_method_selection_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';

class InvoiceDetailPage extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
      ),
      body: invoiceAsync.when(
        data: (result) => _buildContent(context, ref, result.invoice, l10n),
        loading: () => const Center(child: AppListSkeleton(rows: 4)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadInvoice,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                onPressed: () => ref.refresh(invoiceDetailProvider(invoiceId)),
                label: l10n.tryAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel inv,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice header
          AppCard(
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            inv.description ?? l10n.invoiceDescription,
                            style: const TextStyle(
                              fontSize: 14,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const Divider(height: 24),
                  _detailRow(l10n.dueDate, inv.dueDate),
                  _detailRow(l10n.issuedDate, inv.issuedAt),
                  _detailRow(l10n.amountPaid, '${inv.currency} ${inv.paid.toStringAsFixed(2)}'),
                  _detailRow(
                    l10n.amountOutstanding,
                    '${inv.currency} ${inv.outstanding.toStringAsFixed(2)}',
                    isOutstanding: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Line items
          AppSectionHeader(
            title: l10n.invoiceItems,
            subtitle: l10n.invoiceItemsSubtitle,
          ),
          const SizedBox(height: 12),
          if ((inv.lineItems ?? []).isEmpty)
            const Center(
              child: Text('No line items available.'),
            )
          else
            ...ListTile.divideTiles(
              color: Colors.grey.withValues(alpha: 0.2),
              tiles: (inv.lineItems ?? []).map((item) {
                return ListTile(
                  leading: const Icon(Icons.receipt, size: 20),
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.chargeType}  •  ${item.billingPeriodStart ?? '-'} to ${item.billingPeriodEnd ?? '-'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.currency} ${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }),
            ),

          const SizedBox(height: 20),

          // Pay action
          if (inv.isPayable)
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentMethodSelectionPage(
                        invoiceId: inv.id,
                        amount: inv.outstanding,
                      ),
                    ),
                  );
                },
                label: l10n.payNow,
                icon: const Icon(Icons.payment, size: 20),
              ),
            )
          else if (!inv.isCancelled)
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: null,
                label: l10n.invoiceAlreadyPaid,
                isLoading: false,
              ),
            ),

          const SizedBox(height: 20),

          // Payment history section header
          AppSectionHeader(
            title: l10n.paymentHistory,
            subtitle: l10n.paymentHistorySubtitle,
          ),
          const SizedBox(height: 12),
          // Note: Payment history for this specific invoice would come from
          // the backend /api/v1/tenant/payments endpoint filtered by invoiceId.
          // For now, show a link to the full payment history.
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.history, size: 20),
              title: Text(l10n.viewAllPayments),
              subtitle: Text(l10n.viewAllPaymentsSubtitle),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentHistoryPageFromDashboard(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isOutstanding = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isOutstanding ? Colors.orange : Colors.black87,
            ),
          ),
        ],
      ),
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

// Payment history page navigated from invoice detail
class PaymentHistoryPageFromDashboard extends ConsumerWidget {
  const PaymentHistoryPageFromDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: paymentsAsync.when(
        data: (payments) => _buildList(context, payments, l10n),
        loading: () => const Center(child: AppListSkeleton(rows: 5)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadPaymentHistory,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<PaymentHistoryModel> payments,
    AppLocalizations l10n,
  ) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noPaymentHistory,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        return AppTile(
          title: p.paymentMethod,
          subtitle: '${p.paymentReference}  •  ${p.paidAt}',
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.currency} ${p.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _statusLabel(p.status),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}
