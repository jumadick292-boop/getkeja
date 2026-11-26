library features.property_management.presentation.pages.create_listing_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';

class CreateListingPage extends ConsumerStatefulWidget {
  const CreateListingPage({super.key});

  @override
  ConsumerState<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends ConsumerState<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _propertyId;
  String? _unitId;
  bool _furnished = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadProperties(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final properties = ref.watch(propertiesProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New listing'),
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
                DropdownButtonFormField<String>(
                  initialValue: _propertyId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: properties
                      .map(
                        (property) => DropdownMenuItem(
                          value: property.id,
                          child: Text(
                            property.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _propertyId = value;
                      _unitId = null;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a property';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleController,
                  label: 'Listing title',
                  hintText: 'e.g. Spacious 2-bedroom in Kilimani',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _rentController,
                  label: 'Monthly rent (KES)',
                  hintText: 'e.g. 35000',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Rent is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _depositController,
                  label: 'Deposit (KES)',
                  hintText: 'e.g. 70000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Describe the unit (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Furnished'),
                  value: _furnished,
                  onChanged: (value) => setState(() => _furnished = value),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create listing',
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
    final rent = double.tryParse(_rentController.text.trim());
    final deposit = double.tryParse(_depositController.text.trim());
    final success = await ref
        .read(propertyNotifierProvider.notifier)
        .createListing(
          propertyId: _propertyId!,
          title: _titleController.text.trim(),
          rentAmount: rent,
          depositAmount: deposit,
          unitId: _unitId,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
    if (success && mounted) {
      context.pop();
    }
  }
}
