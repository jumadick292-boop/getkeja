// Landlord billing dashboard (Task 14.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/billing/presentation/state/billing_provider.dart';

class LandlordBillingDashboardPage extends ConsumerWidget {
  const LandlordBillingDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final schedulesAsync = ref.watch(billingSchedulesProvider);
    final invoicesAsync = ref.watch(landlordInvoicesProvider(null));

    return AppPageFrame(
      title: l10n.billingDashboard,
      description: l10n.billing,
      actions: [
        SecondaryButton(
          label: l10n.billingSchedules,
          onPressed: () => context.push('/landlord/billing/schedules'),
        ),
      ],
      children: [
        schedulesAsync.when(
          data: (schedules) {
            final active = schedules.where((s) => s.isActive).length;
            return AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: l10n.billingSchedules, value: schedules.length.toString()),
                  _Stat(label: l10n.scheduleStatusActive, value: active.toString()),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: AppLoadingIndicator()),
          ),
          error: (e, _) => AppNotice(message: l10n.retry, type: NoticeType.error),
        ),
        const SizedBox(height: 12),
        invoicesAsync.when(
          data: (invoices) {
            final outstanding = invoices
                .where((i) => !i.isPaid && !i.isVoid)
                .fold<num>(0, (sum, i) => sum + i.amountOutstanding);
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.outstandingAmount,
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text('${outstanding.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        AppSectionHeader(title: l10n.billing),
        AppListSection(
          children: [
            AppTile(
              title: l10n.billingSchedules,
              subtitle: l10n.createBillingSchedule,
              leading: const Icon(Icons.event_repeat_outlined),
              onTap: () => context.push('/landlord/billing/schedules'),
            ),
            AppTile(
              title: l10n.invoices,
              subtitle: l10n.invoiceHistory,
              leading: const Icon(Icons.receipt_long_outlined),
              onTap: () => context.push('/landlord/billing/invoices'),
            ),
            AppTile(
              title: l10n.createBillingSchedule,
              leading: const Icon(Icons.add_circle_outline),
              onTap: () => context.push('/landlord/billing/schedules/new'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}