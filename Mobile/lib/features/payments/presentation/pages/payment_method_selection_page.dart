// Payment method selection page.
// Supports M-Pesa STK Push, Paybill, Till, and Pesapal.
// Available methods and configuration come from the backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';
import 'package:get_keja_mobile/features/payments/presentation/state/payment_provider.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/mpesa_stk_push_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/paybill_till_instructions_page.dart';
import 'package:get_keja_mobile/features/payments/presentation/pages/pesapal_checkout_page.dart';

class PaymentMethodSelectionPage extends ConsumerWidget {
  final String? invoiceId;
  final num? amount;

  const PaymentMethodSelectionPage({
    super.key,
    this.invoiceId,
    this.amount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final providersAsync = ref.watch(paymentProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Payment Method'),
      ),
      body: providersAsync.when(
        data: (providers) => _buildList(context, providers, l10n, ref),
        loading: () => const Center(child: AppListSkeleton(rows: 4)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadProviders,
                style: const TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                onPressed: () => ref.refresh(paymentProvidersProvider),
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
    List<PaymentProviderModel> providers,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noPaymentMethods,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final p = providers[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _onProviderSelected(context, ref, p),
            borderRadius: AppBorderRadius.mediumRadius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.15),
                      borderRadius: AppBorderRadius.mediumRadius,
                    ),
                    child: Icon(
                      _providerIcon(p.type),
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (p.businessShortCode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${l10n.configured}: ${p.businessShortCode}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        if (p.businessShortCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.businessNumber}: ${p.businessShortCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onProviderSelected(
    BuildContext context,
    WidgetRef ref,
    PaymentProviderModel p,
  ) {
    if (invoiceId == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoice selected for payment')),
      );
      return;
    }

    switch (p.type) {
      case 'stk_push':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MpesaStkPushPage(
              invoiceId: invoiceId!,
              amount: amount!,
            ),
          ),
        );
      case 'manual':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaybillTillInstructionsPage(
              provider: p,
              invoiceId: invoiceId!,
              amount: amount!,
            ),
          ),
        );
      case 'hosted_checkout':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PesapalCheckoutPage(
              invoiceId: invoiceId!,
              amount: amount!,
            ),
          ),
        );
    }
  }

  IconData _providerIcon(String type) {
    switch (type) {
      case 'stk_push':
        return Icons.phone_android;
      case 'manual':
        return Icons.account_balance_wallet;
      case 'hosted_checkout':
        return Icons.open_in_new;
      default:
        return Icons.payment;
    }
  }
}
