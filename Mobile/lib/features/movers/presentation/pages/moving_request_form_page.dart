// Moving service request submission form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/movers/presentation/state/moving_state.dart';

class MovingRequestFormPage extends ConsumerStatefulWidget {
  const MovingRequestFormPage({super.key});

  @override
  ConsumerState<MovingRequestFormPage> createState() => _MovingRequestFormPageState();
}

class _MovingRequestFormPageState extends ConsumerState<MovingRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _preferredDateTimeController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _preferredDateTimeController.dispose();
    _itemDescriptionController.dispose();
    _specialInstructionsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(movingProvider.notifier);
    try {
      await notifier.submitMovingRequest(
        pickupUnitId: '', // Resolved from tenant's active tenancy by backend
        destinationAddress: _destinationController.text.trim(),
        preferredDateTime: _preferredDateTimeController.text.trim(),
        itemDescription: _itemDescriptionController.text.trim(),
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
            content: Text('Moving request submitted successfully'),
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
        title: const Text('New Moving Request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination Address',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().length < 5
                      ? 'Please enter a destination address'
                      : null,
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
              controller: _itemDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Item Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().length < 5
                      ? 'Please describe the items to move'
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
