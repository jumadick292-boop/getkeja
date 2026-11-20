library features.organizations.presentation.pages.create_organisation_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/organizations/presentation/state/organisation_state.dart';

class CreateOrganisationPage extends ConsumerStatefulWidget {
  const CreateOrganisationPage({super.key});

  @override
  ConsumerState<CreateOrganisationPage> createState() =>
      _CreateOrganisationPageState();
}

class _CreateOrganisationPageState extends ConsumerState<CreateOrganisationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactEmailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(organisationLoadingProvider);
    final error = ref.watch(organisationErrorProvider);
    final notifier = ref.read(organisationNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create organization'),
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
                    onDismiss: () => notifier.clearError(),
                  ),
                AppTextField(
                  controller: _nameController,
                  label: 'Organization name',
                  hintText: 'e.g. Acme Property Management',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Organization name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _slugController,
                  label: 'Slug',
                  hintText: 'e.g. acme-properties',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Slug is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'What does your organization do?',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _contactEmailController,
                  label: 'Contact email',
                  hintText: 'contact@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Create organization',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _create,
                  ),
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
    final success = await ref.read(organisationNotifierProvider.notifier).createOrganisation(
      name: _nameController.text.trim(),
      slug: _slugController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      contactEmail: _contactEmailController.text.trim().isEmpty
          ? null
          : _contactEmailController.text.trim(),
    );
    if (success && mounted) {
      context.pop();
    }
  }
}
