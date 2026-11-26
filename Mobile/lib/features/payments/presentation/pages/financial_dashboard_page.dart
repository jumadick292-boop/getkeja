// Tenant financial dashboard.
// Shows outstanding balance, rent due, upcoming due dates,
// recent payments, unpaid invoices, deposit info, and payment history.
// All data comes from authenticated backend endpoints.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/invoice_list_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/payment_method_selection_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/receipts_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/statement_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/deposits_page.dart';

class FinancialDashboardPage extends ConsumerWidget {
  const FinancialDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardAsync = ref.watch(tenantDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(tenantDashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (result) => _buildContent(context, ref, result.dashboard, l10n),
        loading: () => const Center(child: AppListSkeleton(rows: 4)),
        error: (error, _) => _buildError(context, l10n),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    TenantDashboardModel d,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance summary card
          AppCardSection(
            title: l10n.outstandingBalance,
            subtitle: l10n.payableFromYourTenancy,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _balanceTile(
                      l10n.outstandingBalance,
                      '${d.currency} ${d.outstandingBalance.toStringAsFixed(2)}',
                      d.hasOutstandingBalance ? Colors.orange : Colors.green,
                      Icons.account_balance_wallet,
                    ),
                  ),
                  Expanded(
                    child: _balanceTile(
                      l10n.unpaidInvoices,
                      '${d.invoiceCount}',
                      d.hasUnpaidInvoices ? Colors.red : Colors.green,
                      Icons.receipt_long,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InvoiceListPage(),
                      ),
                    );
                  },
                  label: l10n.viewInvoices,
                  icon: const Icon(Icons.list_alt, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaymentMethodSelectionPage(),
                      ),
                    );
                  },
                  label: l10n.makePayment,
                  icon: const Icon(Icons.payment, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick actions
          AppSectionHeader(
            title: l10n.quickActions,
            subtitle: l10n.quickActionsSubtitle,
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _actionCard(
                context,
                l10n.invoices,
                l10n.viewAndPayInvoices,
                Icons.receipt_long,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InvoiceListPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                l10n.paymentHistory,
                l10n.viewPaymentHistory,
                Icons.history,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentHistoryPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                l10n.receipts,
                l10n.downloadReceipts,
                Icons.document_scanner,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReceiptsPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                l10n.statement,
                l10n.financialStatement,
                Icons.article,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StatementPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                l10n.deposits,
                l10n.depositBalance,
                Icons.attach_money,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DepositsPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                l10n.payNow,
                l10n.payOutstandingBalance,
                Icons.payment,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PaymentMethodSelectionPage(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tenancy info
          if (d.activeTenancyId.isNotEmpty) ...[
            AppSectionHeader(
              title: l10n.yourTenancy,
              subtitle: '${d.propertyName} - ${d.unitNumber}',
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  AppTile(
                    title: l10n.property,
                    subtitle: d.propertyName,
                    leading: const Icon(Icons.home, size: 20),
                  ),
                  const Divider(height: 1),
                  AppTile(
                    title: l10n.unit,
                    subtitle: d.unitNumber,
                    leading: const Icon(Icons.door_front_door, size: 20),
                  ),
                  const Divider(height: 1),
                  AppTile(
                    title: l10n.status,
                    subtitle: d.tenancyStatus ?? l10n.active,
                    leading: Icon(
                      d.tenancyStatus == 'active'
                          ? Icons.check_circle
                          : Icons.error_outline,
                      size: 20,
                      color: d.tenancyStatus == 'active'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorderRadius.mediumRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            l10n.failedToLoadDashboard,
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            onPressed: () {},
            label: l10n.tryAgain,
          ),
        ],
      ),
    );
  }
}

// Placeholder for payment history page (navigated from dashboard)
class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(paymentHistoryProvider),
          ),
        ],
      ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: p.isCompleted ? Colors.green : Colors.grey,
                ),
              ),
              Text(
                p.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: p.isCompleted ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on PaymentHistoryModel {
  String get statusLabel {
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
