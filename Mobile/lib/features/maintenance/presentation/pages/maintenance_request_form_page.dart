// Maintenance request submission form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/maintenance/presentation/state/maintenance_state.dart';

class MaintenanceRequestFormPage extends ConsumerStatefulWidget {
  const MaintenanceRequestFormPage({super.key});

  @override
  ConsumerState<MaintenanceRequestFormPage> createState() => _MaintenanceRequestFormPageState();
}

class _MaintenanceRequestFormPageState extends ConsumerState<MaintenanceRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessInstructionsController = TextEditingController();
  final _preferredAvailabilityController = TextEditingController();
  final _categories = const [
    'plumbing',
    'electrical',
    'water_supply',
    'security',
    'structural',
    'cleaning',
    'fixtures',
    'pest_control',
    'hvac',
    'appliances',
    'other',
  ];
  final _priorities = const ['low', 'medium', 'high', 'urgent', 'emergency'];
  String? _selectedCategory;
  String? _selectedPriority;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _accessInstructionsController.dispose();
    _preferredAvailabilityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(maintenanceProvider.notifier);
    try {
      await notifier.submitMaintenanceRequest(
        unitId: '', // Resolved from tenant's active tenancy by backend
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        priority: _selectedPriority!,
        description: _descriptionController.text.trim(),
        accessInstructions:
            _accessInstructionsController.text.trim().isEmpty
                ? null
                : _accessInstructionsController.text.trim(),
        preferredAvailability:
            _preferredAvailabilityController.text.trim().isEmpty
                ? null
                : _preferredAvailabilityController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance request submitted successfully'),
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
        title: const Text('New Maintenance Request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceAll('_', ' ').toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) => v == null ? 'Please select a category' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: _priorities
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedPriority = v),
              validator: (v) => v == null ? 'Please select a priority' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().length < 10
                      ? 'Description must be at least 10 characters'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accessInstructionsController,
              decoration: const InputDecoration(
                labelText: 'Access Instructions (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _preferredAvailabilityController,
              decoration: const InputDecoration(
                labelText: 'Preferred Availability (optional)',
                hintText: 'YYYY-MM-DDTHH:mm:ss',
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
