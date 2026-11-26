import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider operating hours + temporary closures (Task 13.4). API-backed.
class ProviderAvailabilityPage extends ConsumerStatefulWidget {
  const ProviderAvailabilityPage({super.key, this.profileId, this.offeringId});

  final String? profileId;
  final String? offeringId;

  @override
  ConsumerState<ProviderAvailabilityPage> createState() =>
      _ProviderAvailabilityPageState();
}

class _DayHours {
  _DayHours(this.day, {this.closed = false, this.open = '08:00', this.close = '17:00'});
  final int day;
  bool closed;
  String open;
  String close;
}

class _ProviderAvailabilityPageState
    extends ConsumerState<ProviderAvailabilityPage> {
  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String? _profileId;
  List<_DayHours> _days = List.generate(7, (d) => _DayHours(d));
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    _profileId = widget.profileId;
    if (_profileId == null) {
      final profiles = await ref.read(providerRepositoryProvider).listProfiles();
      if (profiles.isNotEmpty) _profileId = profiles.first['id'] as String;
    }
    if (_profileId != null) {
      try {
        final hours = await ref.read(providerRepositoryProvider).getAvailability(
              profileId: _profileId,
              offeringId: widget.offeringId,
            );
        final byDay = <int, List<Map<String, dynamic>>>{};
        for (final h in hours) {
          final d = h['dayOfWeek'] as int;
          byDay.putIfAbsent(d, () => []).add(h);
        }
        _days = List.generate(7, (d) {
          final entries = byDay[d] ?? [];
          if (entries.isEmpty) return _DayHours(d, closed: true);
          final first = entries.first;
          return _DayHours(
            d,
            closed: first['isClosed'] as bool? ?? false,
            open: _hhmm(first['openTime'] as String?),
            close: _hhmm(first['closeTime'] as String?),
          );
        });
      } catch (_) {
        // keep defaults
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _hhmm(String? value) {
    if (value == null) return '08:00';
    final parts = value.split(':');
    if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    return value;
  }

  Future<void> _pickTime(_DayHours d, {required bool isOpen}) async {
    final parts = (isOpen ? d.open : d.close).split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpen) {
        d.open = text;
      } else {
        d.close = text;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_profileId == null) return;
    try {
      await ref.read(providerRepositoryProvider).putAvailability(<String, dynamic>{
        if (widget.offeringId != null) 'offeringId': widget.offeringId,
        'specializedProfileId': _profileId,
        'timeZone': 'Africa/Nairobi',
        'hours': _days
            .map((d) => <String, dynamic>{
                  'dayOfWeek': d.day,
                  'openTime': d.open,
                  'closeTime': d.close,
                  'isClosed': d.closed,
                })
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.providerSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addClosure() async {
    final l10n = AppLocalizations.of(context)!;
    if (_profileId == null) return;
    DateTime? date;
    final reasonController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.providerTemporaryClosure),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(date == null
                  ? l10n.providerTemporaryClosure
                  : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) date = picked;
              },
            ),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(labelText: l10n.providerTemporaryClosure),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.providerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.providerSave),
          ),
        ],
      ),
    );
    if (saved != true || date == null) return;
    final dateStr =
        '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(providerRepositoryProvider).createException(<String, dynamic>{
        'specializedProfileId': _profileId,
        if (widget.offeringId != null) 'offeringId': widget.offeringId,
        'exceptionDate': dateStr,
        'isUnavailable': true,
        'reason': reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
        'timeZone': 'Africa/Nairobi',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.providerSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerAvailability)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                ..._days.map((d) => AppCard(
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text(_dayNames[d.day])),
                          if (d.closed)
                            Text(l10n.providerClosed)
                          else ...[
                            TextButton(
                              onPressed: () => _pickTime(d, isOpen: true),
                              child: Text(d.open),
                            ),
                            const Text('-'),
                            TextButton(
                              onPressed: () => _pickTime(d, isOpen: false),
                              child: Text(d.close),
                            ),
                          ],
                          const Spacer(),
                          Switch(
                            value: !d.closed,
                            onChanged: (v) => setState(() => d.closed = !v),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.providerSave),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _addClosure,
                  icon: const Icon(Icons.event_busy),
                  label: Text(l10n.providerTemporaryClosure),
                ),
                ],
              ),
            ),
    );
  }
}