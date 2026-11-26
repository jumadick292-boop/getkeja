// Billing schedule detail (Task 14.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/billing/presentation/state/billing_provider.dart';
import 'package:get_keja_mobile/features/billing/data/models/billing_models.dart';

class BillingScheduleDetailPage extends ConsumerWidget {
  const BillingScheduleDetailPage({super.key, required this.scheduleId});

  final String scheduleId;

  Future<void> _run(BuildContext context, WidgetRef ref, String action,
      String successKey, {String? reason}) async {
    final repo = ref.read(billingRemoteDataSourceProvider);
    await repo.setStatus(scheduleId, action, reason: reason);
    ref.invalidate(billingScheduleProvider(scheduleId));
    ref.invalidate(billingSchedulesProvider);
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      final msg = switch (successKey) {
        'activated' => l10n.scheduleActivated,
        'suspended' => l10n.scheduleSuspended,
        _ => l10n.scheduleCancelled,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref,
      {required String action, required String title, required String body,
      required String successKey}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(ctx)!.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(ctx)!.confirm)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, ref, action, successKey);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheduleAsync = ref.watch(billingScheduleProvider(scheduleId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingScheduleDetail)),
      body: scheduleAsync.when(
        data: (s) => _Content(schedule: s, ref: ref, confirm: _confirm),
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: SecondaryButton(
            label: l10n.retry,
            onPressed: () => ref.invalidate(billingScheduleProvider(scheduleId)),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content(
      {required this.schedule, required this.ref, required this.confirm});
  final BillingScheduleModel schedule;
  final WidgetRef ref;
  final Future<void> Function(BuildContext, WidgetRef,
      {required String action, required String title, required String body,
      required String successKey}) confirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final termsAsync = ref.watch(rentTermsProvider(schedule.id));
    final previewAsync = ref.watch(invoicePreviewProvider(schedule.id));
    final invoicesAsync = ref.watch(scheduleInvoicesProvider(schedule.id));

    return AppPageFrame(
      title: '${schedule.rentAmount.toStringAsFixed(0)} ${schedule.currency}',
      description: '${schedule.billingFrequency} • ${schedule.status}',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.billingDay}: ${schedule.billingDay}'),
              Text('${l10n.firstBillingDate}: ${schedule.firstBillingDate}'),
              Text('${l10n.dueDate}: ${schedule.nextBillingDate}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        previewAsync.when(
          data: (p) => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.previewInvoice,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('${l10n.billingPeriod}: ${p.billingPeriodStart} → ${p.billingPeriodEnd}'),
                Text('${l10n.proratedAmount}: ${p.proratedAmount.toStringAsFixed(2)} ${p.currency}'),
                Text(p.fullPeriod ? l10n.fullPeriod : l10n.partialPeriod),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        AppSectionHeader(title: l10n.rentTerms),
        termsAsync.when(
          data: (terms) => AppListSection(
            children: terms
                .map((t) => AppTile(
                      title: '${t.rentAmount.toStringAsFixed(0)} ${t.currency}',
                      subtitle: '${l10n.firstBillingDate}: ${t.effectiveDate}',
                    ))
                .toList(),
          ),
          loading: () => const AppLoadingIndicator(),
          error: (e, _) => AppNotice(message: l10n.retry, type: NoticeType.error),
        ),
        const SizedBox(height: 12),
        AppSectionHeader(title: l10n.invoices),
        invoicesAsync.when(
          data: (invoices) => invoices.isEmpty
              ? Text(l10n.noInvoices)
              : AppListSection(
                  children: invoices
                      .map((i) => AppTile(
                            title: i.invoiceNumber,
                            subtitle:
                                '${i.totalAmount.toStringAsFixed(0)} ${i.currency} • ${i.dueDate}',
                            trailing: Text(i.status),
                          ))
                      .toList(),
                ),
          loading: () => const AppLoadingIndicator(),
          error: (e, _) => AppNotice(message: l10n.retry, type: NoticeType.error),
        ),
        const SizedBox(height: 16),
        if (schedule.status == 'pending' || schedule.status == 'suspended')
          PrimaryButton(
            label: schedule.status == 'pending'
                ? l10n.activateSchedule
                : l10n.resumeSchedule,
            onPressed: () =>
                confirm(context, ref, action: 'activate', title: l10n.activateSchedule,
                    body: l10n.confirmCancelSchedule, successKey: 'activated'),
          ),
        if (schedule.status == 'active') ...[
          SecondaryButton(
            label: l10n.suspendSchedule,
            onPressed: () =>
                confirm(context, ref, action: 'suspend', title: l10n.suspendSchedule,
                    body: l10n.confirmCancelSchedule, successKey: 'suspended'),
          ),
          const SizedBox(height: 8),
          DestructiveButton(
            label: l10n.cancelSchedule,
            onPressed: () => confirm(context, ref, action: 'cancel',
                title: l10n.cancelSchedule, body: l10n.confirmCancelSchedule,
                successKey: 'cancelled'),
          ),
        ],
      ],
    );
  }
}