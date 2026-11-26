// Landlord invoices list (Task 14.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/billing/presentation/state/billing_provider.dart';

class LandlordInvoicesPage extends ConsumerWidget {
  const LandlordInvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invoicesAsync = ref.watch(landlordInvoicesProvider(null));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoices)),
      body: invoicesAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) return Center(child: Text(l10n.noInvoices));
          return AppPageFrame(
            title: l10n.invoices,
            children: [
              AppListSection(
                children: invoices.map((i) {
                  return AppTile(
                    title: i.invoiceNumber,
                    subtitle:
                        '${i.totalAmount.toStringAsFixed(0)} ${i.currency} • ${l10n.dueDate}: ${i.dueDate}',
                    trailing: Text(i.status),
                  );
                }).toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: SecondaryButton(
            label: l10n.retry,
            onPressed: () => ref.invalidate(landlordInvoicesProvider(null)),
          ),
        ),
      ),
    );
  }
}