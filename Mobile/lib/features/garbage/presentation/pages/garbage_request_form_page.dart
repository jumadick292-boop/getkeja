// Garbage request submission form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/garbage/presentation/state/garbage_state.dart';

class GarbageRequestFormPage extends ConsumerStatefulWidget {
  const GarbageRequestFormPage({super.key});

  @override
  ConsumerState<GarbageRequestFormPage> createState() => _GarbageRequestFormPageState();
}

class _GarbageRequestFormPageState extends ConsumerState<GarbageRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _preferredDateController = TextEditingController();
  final _categories = const [
    'regular_collection',
    'special_pickup',
    'bulky_waste',
    'recycling',
  ];
  String? _selectedCategory;

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _preferredDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(garbageProvider.notifier);
    try {
      await notifier.submitGarbageRequest(
        unitId: '', // Will be resolved from tenant's active tenancy by backend
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        preferredDate:
            _preferredDateController.text.trim().isEmpty
                ? null
                : _preferredDateController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Garbage request submitted successfully'),
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
        title: const Text('New Garbage Request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Request Category',
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
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().length < 5
                      ? 'Description must be at least 5 characters'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _preferredDateController,
              decoration: const InputDecoration(
                labelText: 'Preferred Date (optional)',
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
