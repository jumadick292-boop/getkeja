import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider onboarding (foundation).
///
/// A real, API-backed entry point that creates an individual provider profile
/// or a provider organization using the existing GetKeja identity. Full
/// multi-step wizardry and document upload arrive in later tasks.
class ProviderOnboardingPage extends ConsumerStatefulWidget {
  const ProviderOnboardingPage({super.key});

  @override
  ConsumerState<ProviderOnboardingPage> createState() =>
      _ProviderOnboardingPageState();
}

class _ProviderOnboardingPageState
    extends ConsumerState<ProviderOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  String _mode = 'individual'; // individual | organization
  String _category = 'moving_service_provider';
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _success;

  static const _categories = <String, String>{
    'moving_service_provider': 'Moving services',
    'garbage_collection_provider': 'Garbage collection',
    'laundry_service_provider': 'Laundry services',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    final repo = ref.read(providerRepositoryProvider);
    try {
      if (_mode == 'individual') {
        await repo.createProfile(<String, dynamic>{
          'profileCategory': _category,
          'fullName': _nameController.text.trim(),
          'businessName': _businessController.text.trim(),
          'contactPhone': _phoneController.text.trim(),
        });
      } else {
        final slug =
            'org-${DateTime.now().millisecondsSinceEpoch}-${_nameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}';
        await repo.createOrganization(<String, dynamic>{
          'name': _nameController.text.trim(),
          'slug': slug,
          'type': _category == 'moving_service_provider'
              ? 'moving_company'
              : _category == 'garbage_collection_provider'
                  ? 'garbage_collection'
                  : 'laundry',
        });
      }
      if (mounted) {
        setState(() => _success = 'Submitted for verification.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Onboarding')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'individual', label: Text('Individual')),
                  ButtonSegment(value: 'organization', label: Text('Organization')),
                ],
                selected: <String>{_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Service category'),
                items: _categories.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _mode == 'individual' ? 'Full name' : 'Business name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              if (_mode == 'individual') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessController,
                  decoration:
                      const InputDecoration(labelText: 'Trading name (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Contact phone'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _success!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}