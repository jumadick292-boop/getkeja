// Marketplace request form (Task 13.5) — create a category-scoped request.
// Renders strict, category-specific detail fields for the mandatory categories
// (Wi-Fi, Internet, Solar, Painting & Decoration) plus a generic fallback.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/marketplace/presentation/state/marketplace_state.dart';

class MarketplaceRequestFormPage extends ConsumerStatefulWidget {
  const MarketplaceRequestFormPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.domain,
  });

  final String categoryId;
  final String categoryName;
  final String? domain;

  @override
  ConsumerState<MarketplaceRequestFormPage> createState() =>
      _MarketplaceRequestFormPageState();
}

class _MarketplaceRequestFormPageState extends ConsumerState<MarketplaceRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _roomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _propertyTypeController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _preferredDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _existingSystemController = TextEditingController();
  final _powerController = TextEditingController();
  final _inverterController = TextEditingController();
  final _surfacePrepController = TextEditingController();

  String? _propertyUse;
  String? _jobType;
  String? _surface;
  String? _finishType;
  bool _submitting = false;

  bool get _isWifi => widget.categoryId == 'wifi_installation';
  bool get _isInternet => widget.categoryId == 'internet_installation';
  bool get _isSolar => widget.categoryId == 'solar_installation';
  bool get _isPainting => widget.categoryId == 'painting_decoration';
  bool get _isNetwork => _isWifi || _isInternet;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _roomsController.dispose();
    _areaController.dispose();
    _propertyTypeController.dispose();
    _equipmentController.dispose();
    _preferredDateController.dispose();
    _notesController.dispose();
    _existingSystemController.dispose();
    _powerController.dispose();
    _inverterController.dispose();
    _surfacePrepController.dispose();
    super.dispose();
  }

  String _localizedName(AppLocalizations l10n) {
    switch (widget.categoryId) {
      case 'wifi_installation':
        return l10n.categoryWifiInstallation;
      case 'internet_installation':
        return l10n.categoryInternetInstallation;
      case 'solar_installation':
        return l10n.categorySolarInstallation;
      case 'painting_decoration':
        return l10n.categoryPaintingDecoration;
      default:
        return widget.categoryName;
    }
  }

  Map<String, dynamic> _buildDetails() {
    final details = <String, dynamic>{};
    final notes = _notesController.text.trim();
    if (_isNetwork) {
      if (_propertyUse != null) details['propertyUse'] = _propertyUse;
      if (_propertyTypeController.text.isNotEmpty) details['propertyType'] = _propertyTypeController.text.trim();
      if (_roomsController.text.isNotEmpty) details['rooms'] = int.tryParse(_roomsController.text);
      if (_areaController.text.isNotEmpty) details['coverageAreaSqM'] = double.tryParse(_areaController.text);
      if (_equipmentController.text.isNotEmpty) details['existingEquipment'] = _equipmentController.text.trim();
      if (_jobType != null) details['jobType'] = _jobType;
      if (_preferredDateController.text.isNotEmpty) details['preferredDate'] = _preferredDateController.text.trim();
      if (notes.isNotEmpty) details['notes'] = notes;
    } else if (_isSolar) {
      if (_propertyUse != null) details['propertyUse'] = _propertyUse;
      if (_propertyTypeController.text.isNotEmpty) details['propertyType'] = _propertyTypeController.text.trim();
      if (_jobType != null) details['jobType'] = _jobType;
      if (_existingSystemController.text.isNotEmpty) details['existingSystem'] = _existingSystemController.text.trim();
      if (_powerController.text.isNotEmpty) details['powerRequirementsKw'] = double.tryParse(_powerController.text);
      if (_inverterController.text.isNotEmpty) details['existingInverterBatteryPanel'] = _inverterController.text.trim();
      if (_preferredDateController.text.isNotEmpty) details['preferredDate'] = _preferredDateController.text.trim();
      if (notes.isNotEmpty) details['notes'] = notes;
    } else if (_isPainting) {
      if (_surface != null) details['surface'] = _surface;
      if (_propertyTypeController.text.isNotEmpty) details['propertyType'] = _propertyTypeController.text.trim();
      if (_roomsController.text.isNotEmpty) details['rooms'] = int.tryParse(_roomsController.text);
      if (_areaController.text.isNotEmpty) details['areaSqM'] = double.tryParse(_areaController.text);
      if (_surfacePrepController.text.isNotEmpty) details['surfacePreparation'] = _surfacePrepController.text.trim();
      if (_finishType != null) details['finishType'] = _finishType;
      if (_preferredDateController.text.isNotEmpty) details['preferredDate'] = _preferredDateController.text.trim();
      if (notes.isNotEmpty) details['notes'] = notes;
    } else {
      if (_roomsController.text.isNotEmpty) details['rooms'] = int.tryParse(_roomsController.text);
      if (notes.isNotEmpty) details['notes'] = notes;
    }
    return details;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'categoryId': widget.categoryId,
      'description': _descriptionController.text.trim(),
      'details': _buildDetails(),
      if (_titleController.text.isNotEmpty) 'title': _titleController.text.trim(),
    };
    try {
      final created = await ref.read(marketplaceRepositoryProvider).createRequest(body);
      if (!mounted) return;
      final id = created['id'] as String?;
      if (id != null) {
        context.go('/marketplace/requests/$id');
      } else {
        context.go('/marketplace/requests');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create request: $error')),
      );
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_localizedName(l10n))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
              maxLength: 200,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Describe the job'),
              maxLines: 4,
              validator: (value) =>
                  (value == null || value.trim().length < 10) ? 'Add at least 10 characters' : null,
            ),
            const SizedBox(height: 8),
            if (_isNetwork || _isSolar) ...[
              DropdownButtonFormField<String>(
                initialValue: _propertyUse,
                decoration: const InputDecoration(labelText: 'Property use'),
                items: const [
                  DropdownMenuItem(value: 'residential', child: Text('Residential')),
                  DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
                ],
                onChanged: (value) => setState(() => _propertyUse = value),
              ),
              const SizedBox(height: 12),
              _field('Property type', _propertyTypeController),
            ],
            if (_isNetwork) ...[
              _field('Number of rooms', _roomsController, keyboard: TextInputType.number),
              _field('Approx. coverage area (sq m)', _areaController, keyboard: TextInputType.number),
              _field('Existing router / network equipment', _equipmentController, maxLines: 2),
              DropdownButtonFormField<String>(
                initialValue: _jobType,
                decoration: const InputDecoration(labelText: 'Job type'),
                items: const [
                  DropdownMenuItem(value: 'new_installation', child: Text('New installation')),
                  DropdownMenuItem(value: 'troubleshooting', child: Text('Troubleshooting')),
                ],
                onChanged: (value) => setState(() => _jobType = value),
              ),
              const SizedBox(height: 12),
              _field('Preferred installation date', _preferredDateController),
            ],
            if (_isSolar) ...[
              DropdownButtonFormField<String>(
                initialValue: _jobType,
                decoration: const InputDecoration(labelText: 'Job type'),
                items: const [
                  DropdownMenuItem(value: 'new_installation', child: Text('New installation')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                ],
                onChanged: (value) => setState(() => _jobType = value),
              ),
              const SizedBox(height: 12),
              _field('Existing solar system (if any)', _existingSystemController, maxLines: 2),
              _field('Approx. power requirement (kW)', _powerController, keyboard: TextInputType.number),
              _field('Existing inverter / battery / panels', _inverterController, maxLines: 2),
              _field('Preferred site assessment date', _preferredDateController),
            ],
            if (_isPainting) ...[
              DropdownButtonFormField<String>(
                initialValue: _surface,
                decoration: const InputDecoration(labelText: 'Surface'),
                items: const [
                  DropdownMenuItem(value: 'interior', child: Text('Interior')),
                  DropdownMenuItem(value: 'exterior', child: Text('Exterior')),
                ],
                onChanged: (value) => setState(() => _surface = value),
              ),
              const SizedBox(height: 12),
              _field('Property type', _propertyTypeController),
              _field('Number of rooms', _roomsController, keyboard: TextInputType.number),
              _field('Approx. area (sq m)', _areaController, keyboard: TextInputType.number),
              _field('Surface preparation requirements', _surfacePrepController, maxLines: 2),
              DropdownButtonFormField<String>(
                initialValue: _finishType,
                decoration: const InputDecoration(labelText: 'Finish'),
                items: const [
                  DropdownMenuItem(value: 'painting', child: Text('Painting')),
                  DropdownMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
                  DropdownMenuItem(value: 'decorative', child: Text('Decorative finish')),
                ],
                onChanged: (value) => setState(() => _finishType = value),
              ),
              const SizedBox(height: 12),
              _field('Preferred date', _preferredDateController),
            ],
            if (!_isNetwork && !_isSolar && !_isPainting) ...[
              _field('Rooms (optional)', _roomsController, keyboard: TextInputType.number),
            ],
            _field('Additional notes (optional)', _notesController, maxLines: 3),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post request'),
            ),
          ],
        ),
      ),
    );
  }
}