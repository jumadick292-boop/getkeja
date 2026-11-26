// Laundry service request submission form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/laundries/presentation/state/laundry_state.dart';

class LaundryRequestFormPage extends ConsumerStatefulWidget {
  const LaundryRequestFormPage({super.key});

  @override
  ConsumerState<LaundryRequestFormPage> createState() => _LaundryRequestFormPageState();
}

class _LaundryRequestFormPageState extends ConsumerState<LaundryRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _providerIdController = TextEditingController();
  final _preferredDateTimeController = TextEditingController();
  final _garmentCountController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _serviceCategories = const [
    'wash_fold',
    'dry_clean',
    'iron_only',
    'bedding_cleaning',
    'household_textile_cleaning',
    'other',
  ];
  final _collectionPreferences = const ['doorstep', 'lobby', 'designated_area'];
  String? _selectedServiceCategory;
  String? _selectedCollectionPreference;

  @override
  void dispose() {
    _providerIdController.dispose();
    _preferredDateTimeController.dispose();
    _garmentCountController.dispose();
    _specialInstructionsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(laundryProvider.notifier);
    try {
      await notifier.submitLaundryRequest(
        providerId: _providerIdController.text.trim(),
        serviceCategory: _selectedServiceCategory!,
        collectionPreference: _selectedCollectionPreference!,
        preferredDateTime: _preferredDateTimeController.text.trim(),
        garmentCount: int.tryParse(_garmentCountController.text.trim()) ?? 0,
        specialInstructions:
            _specialInstructionsController.text.trim().isEmpty
                ? null
                : _specialInstructionsController.text.trim(),
        contactName:
            _contactNameController.text.trim().isEmpty
                ? null
                : _contactNameController.text.trim(),
        contactPhone:
            _contactPhoneController.text.trim().isEmpty
                ? null
                : _contactPhoneController.text.trim(),
        contactEmail:
            _contactEmailController.text.trim().isEmpty
                ? null
                : _contactEmailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laundry request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Laundry Request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _providerIdController,
              decoration: const InputDecoration(
                labelText: 'Provider ID',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Provider ID is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Service Category',
                border: OutlineInputBorder(),
              ),
              items: _serviceCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceAll('_', ' ').toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedServiceCategory = v),
              validator: (v) => v == null ? 'Please select a service category' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Collection Preference',
                border: OutlineInputBorder(),
              ),
              items: _collectionPreferences
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceAll('_', ' ').toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCollectionPreference = v),
              validator: (v) => v == null ? 'Please select a collection preference' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _preferredDateTimeController,
              decoration: const InputDecoration(
                labelText: 'Preferred Date & Time',
                hintText: 'YYYY-MM-DDTHH:mm:ss',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Preferred date and time is required'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _garmentCountController,
              decoration: const InputDecoration(
                labelText: 'Garment Count',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || int.tryParse(v.trim()) == null
                      ? 'Please enter a valid garment count'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _specialInstructionsController,
              decoration: const InputDecoration(
                labelText: 'Special Instructions (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactEmailController,
              decoration: const InputDecoration(
                labelText: 'Contact Email (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
