library features.property_management.presentation.pages.create_property_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';

class CreatePropertyPage extends ConsumerStatefulWidget {
  const CreatePropertyPage({super.key});

  @override
  ConsumerState<CreatePropertyPage> createState() => _CreatePropertyPageState();
}

class _CreatePropertyPageState extends ConsumerState<CreatePropertyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _totalUnitsController = TextEditingController();

  String _propertyType = 'apartment';

  static const _propertyTypes = <String>[
    'apartment',
    'house',
    'studio',
    'hostel',
    'commercial',
    'land',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New property'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  AppNotice(
                    message: error,
                    type: NoticeType.error,
                    onDismiss: notifier.clearError,
                  ),
                AppTextField(
                  controller: _titleController,
                  label: 'Property title',
                  hintText: 'e.g. Kilimani Heights',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _propertyType,
                  decoration: const InputDecoration(labelText: 'Property type'),
                  items: _propertyTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _propertyType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _addressController,
                  label: 'Street address',
                  hintText: 'e.g. Ngong Road',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _cityController,
                  label: 'City',
                  hintText: 'e.g. Nairobi',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _countyController,
                  label: 'County',
                  hintText: 'e.g. Nairobi',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'County is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _totalUnitsController,
                  label: 'Total units',
                  hintText: 'e.g. 10',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Describe the property (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Create property',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final totalUnits = int.tryParse(_totalUnitsController.text.trim());
    final success = await ref
        .read(propertyNotifierProvider.notifier)
        .createProperty(
          title: _titleController.text.trim(),
          propertyType: _propertyType,
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          county: _countyController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          totalUnits: totalUnits,
        );
    if (success && mounted) {
      context.pop();
    }
  }
}
