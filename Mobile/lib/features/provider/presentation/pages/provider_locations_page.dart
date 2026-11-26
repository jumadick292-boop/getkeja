import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider locations (Task 13.4). API-backed business/operating locations with
/// public/private visibility and primary selection.
class ProviderLocationsPage extends ConsumerStatefulWidget {
  const ProviderLocationsPage({super.key});

  @override
  ConsumerState<ProviderLocationsPage> createState() => _ProviderLocationsPageState();
}

class _ProviderLocationsPageState extends ConsumerState<ProviderLocationsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerLocationsProvider.notifier).load(),
    );
  }

  Future<void> _addLocation() async {
    final l10n = AppLocalizations.of(context)!;
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final cityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPublic = false;
    String type = 'business_office';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.providerAddLocation),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration:
                        InputDecoration(labelText: l10n.providerServiceCategory),
                    items: const [
                      DropdownMenuItem(value: 'business_office', child: Text('Business office')),
                      DropdownMenuItem(value: 'provider_operating', child: Text('Operating location')),
                    ],
                    onChanged: (v) => type = v ?? type,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: latController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.providerLatitude),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.providerRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lngController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.providerLongitude),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.providerRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityController,
                    decoration: InputDecoration(labelText: l10n.providerCity),
                  ),
                  SwitchListTile(
                    value: isPublic,
                    onChanged: (v) => setDialogState(() => isPublic = v),
                    title: Text(l10n.providerPublicLocation),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.providerCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(l10n.providerSave),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await ref.read(providerRepositoryProvider).createLocation(<String, dynamic>{
        'locationType': type,
        'latitude': double.parse(latController.text.trim()),
        'longitude': double.parse(lngController.text.trim()),
        'city': cityController.text.trim().isEmpty ? null : cityController.text.trim(),
        'locationSource': 'manual_map_pin',
        'isPublic': isPublic,
        'visibility': isPublic ? 'public' : 'private',
      });
      await ref.read(providerLocationsProvider.notifier).load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _setPrimary(String id) async {
    try {
      await ref.read(providerRepositoryProvider).setPrimaryLocation(id);
      await ref.read(providerLocationsProvider.notifier).load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(providerRepositoryProvider).deleteLocation(id);
      await ref.read(providerLocationsProvider.notifier).load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(providerLocationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerLocations)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.providerAddLocation),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (locations) => locations.isEmpty
            ? Center(child: Text(l10n.providerNoLocations))
            : ListView.builder(
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  final id = loc['id'] as String?;
                  final isPrimary = loc['isPrimary'] as bool? ?? false;
                  final isPublic = loc['isPublic'] as bool? ?? false;
                  return AppCard(
                    child: ListTile(
                      title: Text(loc['label'] as String? ?? loc['city'] as String? ?? ''),
                      subtitle: Text(
                        '${loc['locationType'] ?? ''} · ${isPublic ? 'Public' : 'Private'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPrimary && id != null)
                            IconButton(
                              icon: const Icon(Icons.star_outline),
                              tooltip: l10n.providerSetPrimary,
                              onPressed: () => _setPrimary(id),
                            ),
                          if (id != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.providerDelete,
                              onPressed: () => _delete(id),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}