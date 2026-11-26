import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/presentation/rental_application_providers.dart';

/// Landlord / property-manager applications inbox with a status filter.
class RentalApplicationsInboxPage extends ConsumerStatefulWidget {
  const RentalApplicationsInboxPage({super.key});

  @override
  ConsumerState<RentalApplicationsInboxPage> createState() =>
      _RentalApplicationsInboxPageState();
}

class _RentalApplicationsInboxPageState
    extends ConsumerState<RentalApplicationsInboxPage> {
  String? _status;

  static const Map<String, String> _filters = <String, String>{
    'All': '',
    'Submitted': 'submitted',
    'Under review': 'under_review',
    'Information requested': 'information_requested',
    'Shortlisted': 'shortlisted',
    'Approved': 'approved',
    'Rejected': 'rejected',
  };

  @override
  Widget build(BuildContext context) {
    final asyncInbox = ref.watch(managedInboxProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: _filters.entries.map((entry) {
                final selected = (_status == null && entry.key == 'All') ||
                    _status == entry.value && entry.key != 'All';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(entry.key),
                    selected: selected,
                    onSelected: (_) => setState(() => _status = entry.value.isEmpty ? null : entry.value),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: asyncInbox.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load applications.'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(managedInboxProvider(_status)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const Center(child: Text('No applications yet.'));
                }
                return ListView.separated(
                  itemCount: data.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final app = data.items[index];
                    return _InboxTile(application: app);
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

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.application});
  final ManagedApplicationModel application;

  @override
  Widget build(BuildContext context) {
    final title = application.propertyTitle ?? 'Property';
    final subtitle = <String>[
      if (application.applicantName != null) application.applicantName!,
      if (application.city != null) application.city!,
    ].join(' · ');
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? application.status : '$subtitle · ${application.status.replaceAll('_', ' ')}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pushNamed(
          'rental-application-review',
          arguments: application.id,
        );
      },
    );
  }
}