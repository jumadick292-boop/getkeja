library features.property_management.presentation.pages.create_enquiry_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';

class CreateEnquiryPage extends ConsumerStatefulWidget {
  const CreateEnquiryPage({super.key});

  @override
  ConsumerState<CreateEnquiryPage> createState() => _CreateEnquiryPageState();
}

class _CreateEnquiryPageState extends ConsumerState<CreateEnquiryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  String? _propertyId;
  String _enquirySource = 'walk_in';

  static const _sourceOptions = <String>[
    'walk_in',
    'public_listing',
    'property_detail',
    'site_visit_request',
    'agency_representative',
    'referral',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadProperties(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
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
        title: const Text('New enquiry'),
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
                  onChanged: (value) => setState(() => _propertyId = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a property';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nameController,
                  label: 'Prospective renter name',
                  hintText: 'e.g. John Doe',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  hintText: 'e.g. +254712345678',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  label: 'Email (optional)',
                  hintText: 'e.g. john@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _enquirySource,
                  decoration: const InputDecoration(labelText: 'Source'),
                  items: _sourceOptions
                      .map(
                        (source) => DropdownMenuItem(
                          value: source,
                          child: Text(source.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _enquirySource = value);
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _messageController,
                  label: 'Message (optional)',
                  hintText: 'What is the renter looking for?',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create enquiry',
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
    final success = await ref
        .read(propertyNotifierProvider.notifier)
        .createEnquiry(
          propertyId: _propertyId!,
          prospectiveRenterName: _nameController.text.trim(),
          prospectiveRenterPhone: _phoneController.text.trim(),
          message: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
          enquirySource: _enquirySource,
        );
    if (success && mounted) {
      context.pop();
    }
  }
}
