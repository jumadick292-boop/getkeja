import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider service areas (Task 13.4). API-backed coverage per profile/offering.
class ProviderServiceAreasPage extends ConsumerStatefulWidget {
  const ProviderServiceAreasPage({super.key, this.profileId, this.offeringId});

  final String? profileId;
  final String? offeringId;

  @override
  ConsumerState<ProviderServiceAreasPage> createState() =>
      _ProviderServiceAreasPageState();
}

class _ProviderServiceAreasPageState
    extends ConsumerState<ProviderServiceAreasPage> {
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _profileId = widget.profileId;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (_profileId == null) {
      final profiles = await ref.read(providerRepositoryProvider).listProfiles();
      if (profiles.isNotEmpty) {
        _profileId = profiles.first['id'] as String;
      }
    }
    ref.read(providerServiceAreasProvider.notifier).load(
          profileId: _profileId,
          offeringId: widget.offeringId,
        );
  }

  Future<void> _addArea() async {
    final l10n = AppLocalizations.of(context)!;
    if (_profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.providerError)));
      return;
    }
    final countyController = TextEditingController();
    final cityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.providerServiceAreas),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: countyController,
                decoration: InputDecoration(labelText: l10n.providerCounty),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.providerRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cityController,
                decoration: InputDecoration(labelText: l10n.providerCity),
              ),
            ],
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
    );
    if (saved != true) return;
    try {
      await ref.read(providerRepositoryProvider).createServiceArea(<String, dynamic>{
        'specializedProfileId': _profileId,
        if (widget.offeringId != null) 'offeringId': widget.offeringId,
        'county': countyController.text.trim(),
        'city': cityController.text.trim().isEmpty ? null : cityController.text.trim(),
        'isActive': true,
      });
      ref.read(providerServiceAreasProvider.notifier).load(
            profileId: _profileId,
            offeringId: widget.offeringId,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(providerRepositoryProvider).deleteServiceArea(id);
      ref.read(providerServiceAreasProvider.notifier).load(
            profileId: _profileId,
            offeringId: widget.offeringId,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(providerServiceAreasProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerServiceAreas)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addArea,
        icon: const Icon(Icons.add),
        label: Text(l10n.providerAdd),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (areas) => areas.isEmpty
            ? Center(child: Text(l10n.providerNoAreas))
            : ListView.builder(
                itemCount: areas.length,
                itemBuilder: (context, index) {
                  final area = areas[index];
                  final id = area['id'] as String?;
                  return AppCard(
                    child: ListTile(
                      title: Text(area['county'] as String? ?? area['city'] as String? ?? ''),
                      subtitle: Text(area['areaDescription'] as String? ?? ''),
                      trailing: id == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.providerDelete,
                              onPressed: () => _delete(id),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}