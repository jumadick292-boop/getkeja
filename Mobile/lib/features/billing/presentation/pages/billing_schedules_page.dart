// Billing schedules list (Task 14.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/billing/presentation/state/billing_provider.dart';

class BillingSchedulesPage extends ConsumerWidget {
  const BillingSchedulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final schedulesAsync = ref.watch(billingSchedulesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingSchedules)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/landlord/billing/schedules/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.createBillingSchedule),
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return Center(child: Text(l10n.noSchedules));
          }
          return AppPageFrame(
            title: l10n.billingSchedules,
            children: [
              AppListSection(
                children: schedules.map((s) {
                  return AppTile(
                    title: '${s.rentAmount.toStringAsFixed(0)} ${s.currency}',
                    subtitle:
                        '${s.billingFrequency} • ${l10n.dueDate}: ${s.nextBillingDate}',
                    leading: const Icon(Icons.event_repeat_outlined),
                    trailing: _StatusChip(status: s.status, isSchedule: true),
                    onTap: () => context.push('/landlord/billing/schedules/${s.id}'),
                  );
                }).toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNotice(message: l10n.retry, type: NoticeType.error),
              const SizedBox(height: 12),
              SecondaryButton(
                label: l10n.retry,
                onPressed: () => ref.invalidate(billingSchedulesProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isSchedule});
  final String status;
  final bool isSchedule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (status) {
      'active' => isSchedule ? l10n.scheduleStatusActive : l10n.invoiceStatusIssued,
      'pending' => l10n.scheduleStatusPending,
      'suspended' => l10n.scheduleStatusSuspended,
      'cancelled' || 'void' => l10n.scheduleStatusCancelled,
      'paid' => l10n.invoiceStatusPaid,
      'overdue' => l10n.invoiceStatusOverdue,
      'partially_paid' => l10n.invoiceStatusPartiallyPaid,
      _ => status,
    };
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}