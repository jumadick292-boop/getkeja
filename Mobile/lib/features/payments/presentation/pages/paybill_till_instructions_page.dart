// M-Pesa Paybill / Buy Goods Till instructions page.
// Displays backend-provided Paybill/Till number, account reference,
// amount, and payment instructions. Allows copying payment details.
// Does NOT mark the invoice paid when the tenant reports payment.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/payments/domain/entities/payment_models.dart';

class PaybillTillInstructionsPage extends StatelessWidget {
  final PaymentProviderModel provider;
  final String invoiceId;
  final num amount;

  const PaybillTillInstructionsPage({
    super.key,
    required this.provider,
    required this.invoiceId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shortCode = provider.businessShortCode ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Paybill / Till Instructions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  _instructionRow(l10n.businessNumber, shortCode, copyable: true),
                  _instructionRow(
                    l10n.accountReference,
                    provider.accountReferencePlaceholder ?? 'Invoice number',
                    copyable: false,
                  ),
                  _instructionRow(
                    l10n.amountLabel,
                    'KES ${amount.toStringAsFixed(2)}',
                    copyable: false,
                  ),
                  _instructionRow(
                    l10n.invoiceReference,
                    invoiceId,
                    copyable: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppNotice(
              message: 'Manual payments may take time to reconcile. Your invoice will be updated once the payment is confirmed by M-Pesa. Do not consider the invoice paid until you receive a receipt.',
              type: NoticeType.warning,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                onPressed: () => Navigator.of(context).pop(),
                label: l10n.iHavePaid,
                icon: const Icon(Icons.check, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.chooseDifferentMethod),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instructionRow(String label, String value, {required bool copyable}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                tooltip: 'Copy',
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
