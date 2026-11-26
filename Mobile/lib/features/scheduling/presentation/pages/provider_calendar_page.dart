// Provider unified operational calendar (Task 13.9).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/scheduling/presentation/state/scheduling_state.dart';

enum _ViewMode { day, week, month }

class ProviderCalendarPage extends ConsumerStatefulWidget {
  const ProviderCalendarPage({super.key});

  @override
  ConsumerState<ProviderCalendarPage> createState() => _ProviderCalendarPageState();
}

class _ProviderCalendarPageState extends ConsumerState<ProviderCalendarPage> {
  _ViewMode _mode = _ViewMode.week;
  Set<String> _domains = <String>{'moving', 'garbage', 'laundry'};

  (String, String) _window() {
    final now = DateTime.now();
    DateTime from;
    DateTime to;
    switch (_mode) {
      case _ViewMode.day:
        from = DateTime(now.year, now.month, now.day);
        to = from.add(const Duration(days: 1));
        break;
      case _ViewMode.week:
        from = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        to = from.add(const Duration(days: 7));
        break;
      case _ViewMode.month:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1);
        break;
    }
    return (from.toUtc().toIso8601String(), to.toUtc().toIso8601String());
  }

  void _navigate(BuildContext context, Map<String, dynamic> entry) {
    final domain = entry['domain'] as String? ?? '';
    final resourceId = entry['resourceId'] as String? ?? '';
    switch (domain) {
      case 'moving':
        context.push('/moving/provider/jobs/$resourceId');
        break;
      case 'garbage':
      case 'garbage_occurrence':
        context.push('/garbage/provider/jobs/$resourceId');
        break;
      case 'laundry':
        context.push('/laundry/provider/orders/$resourceId');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No detail view for this activity')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (from, to) = _window();
    final args = (from: from, to: to, domainsKey: _domains.join(','), staffUserId: null);
    final calendar = ref.watch(providerCalendarProvider(args));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schedulingCalendar)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<_ViewMode>(
              segments: [
                ButtonSegment(value: _ViewMode.day, label: Text(l10n.schedulingDay)),
                ButtonSegment(value: _ViewMode.week, label: Text(l10n.schedulingWeek)),
                ButtonSegment(value: _ViewMode.month, label: Text(l10n.schedulingMonth)),
              ],
              selected: <_ViewMode>{_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final domain in const <String>['moving', 'garbage', 'laundry'])
                FilterChip(
                  label: Text(domain == 'garbage' ? l10n.domainGarbage : domain == 'moving' ? l10n.domainMoving : l10n.domainLaundry),
                  selected: _domains.contains(domain),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _domains.add(domain);
                    } else {
                      _domains.remove(domain);
                    }
                  }),
                ),
            ],
          ),
          Expanded(
            child: calendar.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$error'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.read(providerCalendarProvider(args).notifier).load(),
                      child: Text(l10n.schedulingRetry),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) return Center(child: Text(l10n.schedulingNoActivities));
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
                      leading: const Icon(Icons.event),
                      title: Text('$domain • ${status.toUpperCase()}'),
                      subtitle: Text(start),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _navigate(context, entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}