import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';

class HouseSeekerPreferencesPage extends ConsumerStatefulWidget {
  const HouseSeekerPreferencesPage({super.key});

  @override
  ConsumerState<HouseSeekerPreferencesPage> createState() => _HouseSeekerPreferencesPageState();
}

class _HouseSeekerPreferencesPageState extends ConsumerState<HouseSeekerPreferencesPage> {
  final TextEditingController _minBudget = TextEditingController();
  final TextEditingController _maxBudget = TextEditingController();
  final TextEditingController _moveInDate = TextEditingController();

  String? _propertyType;
  String? _bedrooms;
  String? _bathrooms;
  bool _alerts = true;
  bool _loading = false;
  bool _seeded = false;

  static const List<String> _propertyTypes = <String>[
    'apartment',
    'house',
    'studio',
    'bedsitter',
    'townhouse',
    'mansionette',
  ];
  static const List<String> _bedroomOptions = <String>['any', '1', '2', '3', '4'];
  static const List<String> _bathroomOptions = <String>['any', '1', '2', '3'];

  @override
  void dispose() {
    _minBudget.dispose();
    _maxBudget.dispose();
    _moveInDate.dispose();
    super.dispose();
  }

  void _seed(HouseSeekerPreferencesModel? prefs) {
    if (_seeded) return;
    _seeded = true;
    _minBudget.text = prefs?.minBudget?.toString() ?? '';
    _maxBudget.text = prefs?.maxBudget?.toString() ?? '';
    _moveInDate.text = prefs?.moveInDate ?? '';
    _propertyType = (prefs?.preferredPropertyTypes != null && prefs!.preferredPropertyTypes!.isNotEmpty)
        ? prefs.preferredPropertyTypes!.first
        : null;
    _bedrooms = prefs?.preferredBedrooms?.toString();
    _bathrooms = prefs?.preferredBathrooms?.toString();
    _alerts = prefs?.alertsEnabled ?? true;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final min = num.tryParse(_minBudget.text.trim());
    final max = num.tryParse(_maxBudget.text.trim());
    final body = <String, dynamic>{
      if (min != null) 'minBudget': min,
      if (max != null) 'maxBudget': max,
      if (_propertyType != null) 'preferredPropertyTypes': <String>[_propertyType!],
      if (_bedrooms != null && _bedrooms != 'any') 'preferredBedrooms': int.parse(_bedrooms!),
      if (_bathrooms != null && _bathrooms != 'any') 'preferredBathrooms': int.parse(_bathrooms!),
      if (_moveInDate.text.trim().isNotEmpty) 'moveInDate': _moveInDate.text.trim(),
      'alertsEnabled': _alerts,
    };
    try {
      await ref.read(houseSeekerRepositoryProvider).updatePreferences(body);
      ref.invalidate(houseSeekerPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(houseSeekerPreferencesProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: const Text('Rental preferences')),
      body: prefsAsync.when(
        data: (prefs) {
          _seed(prefs);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text('Budget', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _minBudget,
                      label: 'Min rent (KES)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _maxBudget,
                      label: 'Max rent (KES)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Home type', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _propertyType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Preferred type',
                  border: OutlineInputBorder(),
                ),
                items: _propertyTypes
                    .map((t) => DropdownMenuItem<String>(value: t, child: Text(_label(t))))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _propertyType = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Size', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bedrooms ?? 'any',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bedrooms',
                        border: OutlineInputBorder(),
                      ),
                      items: _bedroomOptions
                          .map((b) => DropdownMenuItem<String>(
                                value: b,
                                child: Text(b == 'any' ? 'Any' : b),
                              ))
                          .toList(growable: false),
                      onChanged: (v) => setState(() => _bedrooms = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bathrooms ?? 'any',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bathrooms',
                        border: OutlineInputBorder(),
                      ),
                      items: _bathroomOptions
                          .map((b) => DropdownMenuItem<String>(
                                value: b,
                                child: Text(b == 'any' ? 'Any' : b),
                              ))
                          .toList(growable: false),
                      onChanged: (v) => setState(() => _bathrooms = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Timing', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _moveInDate,
                label: 'Preferred move-in date (YYYY-MM-DD)',
                hintText: 'e.g. 2026-12-01',
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                value: _alerts,
                onChanged: (v) => setState(() => _alerts = v),
                title: const Text('Email me about matching rentals'),
                subtitle: const Text('Get notified when new homes match your preferences'),
                secondary: const Icon(Icons.notifications_active, color: AppColors.brand),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Save preferences',
                isLoading: _loading,
                onPressed: _save,
              ),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, _) => AppNotice(
          message: 'Could not load your preferences.',
          type: NoticeType.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(houseSeekerPreferencesProvider),
        ),
      ),
    );
  }

  String _label(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}