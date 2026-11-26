// Customer scheduling / appointments (Task 13.9).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/scheduling/presentation/state/scheduling_state.dart';

class CustomerAppointmentsPage extends ConsumerStatefulWidget {
  const CustomerAppointmentsPage({super.key});

  @override
  ConsumerState<CustomerAppointmentsPage> createState() => _CustomerAppointmentsPageState();
}

class _CustomerAppointmentsPageState extends ConsumerState<CustomerAppointmentsPage> {
  late final ({String from, String to}) _range = (() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - 30);
    final to = from.add(const Duration(days: 60));
    return (from: from.toUtc().toIso8601String(), to: to.toUtc().toIso8601String());
  })();

  void _navigate(BuildContext context, Map<String, dynamic> entry) {
    final domain = entry['domain'] as String? ?? '';
    final resourceId = entry['resourceId'] as String? ?? '';
    switch (domain) {
      case 'moving':
        context.push('/moving/jobs/$resourceId');
        break;
      case 'garbage':
      case 'garbage_occurrence':
        context.push('/garbage/jobs/$resourceId');
        break;
      case 'laundry':
        context.push('/laundry/orders/$resourceId');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No detail view for this appointment')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appointments = ref.watch(customerAppointmentsProvider(_range));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schedulingAppointments)),
      body: appointments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(customerAppointmentsProvider(_range).notifier).load(),
                child: Text(l10n.schedulingRetry),
              ),
            ],
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) return Center(child: Text(l10n.schedulingNoAppointments));
          final sorted = [...entries]
            ..sort((a, b) => (a['startAt'] as String? ?? '').compareTo(b['startAt'] as String? ?? ''));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = sorted[index];
              final status = (entry['status'] as String? ?? '').replaceAll('_', ' ');
              final start = entry['startAt'] as String? ?? '';
              final domain = (entry['domain'] as String? ?? '').replaceAll('_', ' ');
              return ListTile(
                leading: const Icon(Icons.event_available),
                title: Text('$domain • ${status.toUpperCase()}'),
                subtitle: Text(start),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigate(context, entry),
              );
            },
          );
        },
      ),
    );
  }
}