// Create billing schedule (Task 14.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';
import 'package:get_keja_mobile/features/billing/presentation/state/billing_provider.dart';

class CreateBillingSchedulePage extends ConsumerStatefulWidget {
  const CreateBillingSchedulePage({super.key});

  @override
  ConsumerState<CreateBillingSchedulePage> createState() =>
      _CreateBillingSchedulePageState();
}

class _CreateBillingSchedulePageState
    extends ConsumerState<CreateBillingSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _propertyId = TextEditingController();
  final _unitId = TextEditingController();
  final _tenancyId = TextEditingController();
  final _tenantId = TextEditingController();
  final _rentAmount = TextEditingController();
  final _billingDay = TextEditingController(text: '1');
  final _dueDay = TextEditingController();
  final _grace = TextEditingController(text: '0');

  String _frequency = 'monthly';
  DateTime _firstBillingDate = DateTime.now();
  bool _activate = false;
  bool _submitting = false;

  @override
  void dispose() {
    _propertyId.dispose();
    _unitId.dispose();
    _tenancyId.dispose();
    _tenantId.dispose();
    _rentAmount.dispose();
    _billingDay.dispose();
    _dueDay.dispose();
    _grace.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstBillingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _firstBillingDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final repo = ref.read(billingRemoteDataSourceProvider);
      await repo.createSchedule(<String, dynamic>{
        'propertyId': _propertyId.text.trim(),
        'unitId': _unitId.text.trim(),
        'tenancyId': _tenancyId.text.trim(),
        'tenantId': _tenantId.text.trim(),
        'rentAmount': double.parse(_rentAmount.text.trim()),
        'currency': 'KES',
        'billingFrequency': _frequency,
        'billingDay': int.parse(_billingDay.text.trim()),
        'firstBillingDate': _fmt(_firstBillingDate),
        'dueDayOfMonth':
            _dueDay.text.trim().isEmpty ? null : int.parse(_dueDay.text.trim()),
        'gracePeriodDays': int.parse(_grace.text.trim()),
        'activate': _activate,
      });
      ref.invalidate(billingSchedulesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleActivated)),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.retry)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createBillingSchedule)),
      body: AppPageFrame(
        title: l10n.createBillingSchedule,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _propertyId,
                  label: l10n.property,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.retry : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _unitId,
                  label: l10n.unit,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.retry : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _tenancyId,
                  label: l10n.tenancy,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.retry : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _tenantId,
                  label: l10n.tenant,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.retry : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _rentAmount,
                  label: l10n.rentAmount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return (n == null || n <= 0) ? l10n.retry : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: InputDecoration(labelText: l10n.billingFrequency),
                  items: [
                    DropdownMenuItem(value: 'monthly', child: Text(l10n.monthly)),
                    DropdownMenuItem(
                        value: 'quarterly', child: Text(l10n.quarterly)),
                    DropdownMenuItem(value: 'annual', child: Text(l10n.annually)),
                  ],
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _billingDay,
                  label: l10n.billingDay,
                  keyboardType: TextInputType.number,                ),
                const SizedBox(height: 12),
                AppTile(
                  title: l10n.firstBillingDate,
                  subtitle: _fmt(_firstBillingDate),
                  leading: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _dueDay,
                  label: l10n.dueDayOfMonth,
                  keyboardType: TextInputType.number,                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _grace,
                  label: l10n.gracePeriodDays,
                  keyboardType: TextInputType.number,                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _activate,
                  onChanged: (v) => setState(() => _activate = v),
                  title: Text(l10n.activateSchedule),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: l10n.save,
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}