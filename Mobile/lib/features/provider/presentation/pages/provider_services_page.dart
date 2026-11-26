import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider services overview + create (Task 13.4). API-backed.
class ProviderServicesPage extends ConsumerStatefulWidget {
  const ProviderServicesPage({super.key});

  @override
  ConsumerState<ProviderServicesPage> createState() => _ProviderServicesPageState();
}

class _ProviderServicesPageState extends ConsumerState<ProviderServicesPage> {
  Map<String, dynamic> _catalogue = <String, dynamic>{};
  List<Map<String, dynamic>> _profiles = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    ref.read(providerServicesProvider.notifier).load();
    final repo = ref.read(providerRepositoryProvider);
    try {
      final catalogue = await repo.getCatalogue();
      final profiles = await repo.listProfiles();
      if (mounted) {
        setState(() {
          _catalogue = catalogue;
          _profiles = profiles;
        });
      }
    } catch (_) {
      // Catalogue is optional for the overview; ignore.
    }
  }

  Future<void> _addService() async {
    final l10n = AppLocalizations.of(context)!;
    if (_profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.providerError)),
      );
      return;
    }
    final profileId = _profiles.first['id'] as String;
    final categories = (_catalogue['categories'] as List? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedCategory;
    String status = 'draft';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.providerAddService),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(labelText: l10n.providerServiceCategory),
                  items: categories
                      .map((c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String? ?? c['id'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => selectedCategory = v,
                  validator: (v) => v == null ? l10n.providerRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: l10n.providerServiceTitle),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.providerRequired : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: l10n.providerStatus),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                  ],
                  onChanged: (v) => status = v ?? 'draft',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: l10n.providerBaseAmount),
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
    );

    if (saved != true) return;
    final selected = categories.firstWhere((c) => c['id'] == selectedCategory);
    final amount = double.tryParse(amountController.text.trim());
    try {
      await ref.read(providerRepositoryProvider).createOffering(<String, dynamic>{
        'profileId': profileId,
        'domain': selected['domain'],
        'categoryId': selectedCategory,
        'title': titleController.text.trim(),
        'status': status,
        if (amount != null)
          'pricing': <String, dynamic>{
            'pricingModel': 'starting',
            'currency': 'KES',
            'baseAmount': amount,
            'isIndicative': true,
          },
      });
      await ref.read(providerServicesProvider.notifier).load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(providerServicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providerServices)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addService,
        icon: const Icon(Icons.add),
        label: Text(l10n.providerAddService),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (services) => services.isEmpty
            ? Center(child: Text(l10n.providerNoServices))
            : ListView.builder(
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final s = services[index];
                  return AppCard(
                    child: ListTile(
                      title: Text(s['title'] as String? ?? ''),
                      subtitle: Text(
                        '${s['categoryName'] ?? s['domain'] ?? ''} · ${s['status'] ?? ''}',
                      ),
                      trailing: Chip(label: Text(s['status'] as String? ?? '')),
                    ),
                  );
                },
              ),
      ),
    );
  }
}