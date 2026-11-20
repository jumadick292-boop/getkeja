// Account preferences page for language, theme, currency, timezone, etc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../l10n/generated/app_localizations.dart';

class AccountPreferencesPage extends ConsumerStatefulWidget {
  const AccountPreferencesPage({super.key});

  @override
  ConsumerState<AccountPreferencesPage> createState() =>
      _AccountPreferencesPageState();
}

class _AccountPreferencesPageState
    extends ConsumerState<AccountPreferencesPage> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  String _language = 'en';
  String _theme = 'system';
  String _currency = 'KES';
  String _timezone = 'Africa/Nairobi';
  String _dateFormat = 'dd/MM/yyyy';
  String _numberFormat = 'en-KE';
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  static const List<_LocaleOption> _languages = [
    _LocaleOption('en', 'English'),
    _LocaleOption('sw', 'Kiswahili'),
  ];

  static const List<_ThemeOption> _themes = [
    _ThemeOption('system', 'System default', Icons.settings_outlined),
    _ThemeOption('light', 'Light', Icons.light_mode_rounded),
    _ThemeOption('dark', 'Dark', Icons.dark_mode_rounded),
  ];

  static const List<_CurrencyOption> _currencies = [
    _CurrencyOption('KES', 'KES - Kenyan Shilling', 'KSh'),
    _CurrencyOption('USD', 'USD - US Dollar', '\$'),
    _CurrencyOption('EUR', 'EUR - Euro', '€'),
    _CurrencyOption('GBP', 'GBP - British Pound', '£'),
  ];

  static const List<_TimezoneOption> _timezones = [
    _TimezoneOption('Africa/Nairobi', 'Nairobi (EAT) UTC+3'),
    _TimezoneOption('Africa/Kampala', 'Kampala (EAT) UTC+3'),
    _TimezoneOption('Africa/Dar_es_Salaam', 'Dar es Salaam (EAT) UTC+3'),
    _TimezoneOption('UTC', 'UTC (Coordinated Universal Time)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/account/preferences');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        final preferences = AppPreferences.fromJson(payload);
        AppFormatters.update(preferences);
        ref.read(appPreferencesProvider.notifier).state = preferences;
        setState(() {
          _language = payload['language'] as String? ?? 'en';
          _theme = payload['theme'] as String? ?? 'system';
          _currency = payload['currency'] as String? ?? 'KES';
          _timezone = payload['timezone'] as String? ?? 'Africa/Nairobi';
          _dateFormat = payload['dateFormat'] as String? ?? 'dd/MM/yyyy';
          _numberFormat = payload['numberFormat'] as String? ?? 'en-KE';
          _pushNotifications = payload['pushNotifications'] as bool? ?? true;
          _emailNotifications = payload['emailNotifications'] as bool? ?? true;
          _smsNotifications = payload['smsNotifications'] as bool? ?? true;
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _errorMessageFrom(error));
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/account/preferences',
            data: {
              'language': _language,
              'theme': _theme,
              'currency': _currency,
              'timezone': _timezone,
              'dateFormat': _dateFormat,
              'numberFormat': _numberFormat,
              'pushNotifications': _pushNotifications,
              'emailNotifications': _emailNotifications,
              'smsNotifications': _smsNotifications,
            },
          );

      if (mounted) {
        final preferences = AppPreferences(
          language: _language,
          theme: _theme,
          currency: _currency,
          timezone: _timezone,
          dateFormat: _dateFormat,
          numberFormat: _numberFormat,
          pushNotifications: _pushNotifications,
          emailNotifications: _emailNotifications,
          smsNotifications: _smsNotifications,
        );
        AppFormatters.update(preferences);
        ref.read(appPreferencesProvider.notifier).state = preferences;
        setState(
          () =>
              _successMessage = AppLocalizations.of(context)!.preferencesSaved,
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _errorMessageFrom(error));
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to save preferences. Please try again.';
  }

  String _timezoneName(AppLocalizations l10n, String code) => switch (code) {
    'Africa/Kampala' => l10n.kampalaTimezone,
    'Africa/Dar_es_Salaam' => l10n.darEsSalaamTimezone,
    'UTC' => l10n.utcTimezone,
    _ => l10n.nairobiTimezone,
  };

  String _themeName(AppLocalizations l10n, String code) => switch (code) {
    'light' => l10n.light,
    'dark' => l10n.dark,
    _ => l10n.systemDefault,
  };

  String _currencyName(AppLocalizations l10n, String code) => switch (code) {
    'USD' => l10n.currencyUsd,
    'EUR' => l10n.currencyEur,
    'GBP' => l10n.currencyGbp,
    _ => l10n.currencyKes,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.preferencesAndNotifications)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    AppNotice(
                      message: _errorMessage!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                  if (_successMessage != null)
                    AppNotice(
                      message: _successMessage!,
                      type: NoticeType.success,
                      onDismiss: () => setState(() => _successMessage = null),
                    ),

                  // Language section
                  _buildSectionHeader(
                    context,
                    l10n.languageAndRegion,
                    Icons.language_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        _buildDropdownField<String>(
                          context,
                          label: l10n.language,
                          value: _language,
                          items: _languages
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l.code,
                                  child: Text(
                                    l.code == 'sw'
                                        ? l10n.kiswahili
                                        : l10n.english,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _language = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField<String>(
                          context,
                          label: l10n.timezone,
                          value: _timezone,
                          items: _timezones
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.code,
                                  child: Text(_timezoneName(l10n, t.code)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _timezone = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField<String>(
                          context,
                          label: l10n.dateFormat,
                          value: _dateFormat,
                          items: [
                            DropdownMenuItem(
                              value: 'dd/MM/yyyy',
                              child: Text(l10n.dateDayFirst),
                            ),
                            DropdownMenuItem(
                              value: 'MM/dd/yyyy',
                              child: Text(l10n.dateMonthFirst),
                            ),
                            DropdownMenuItem(
                              value: 'yyyy-MM-dd',
                              child: Text(l10n.dateIso),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _dateFormat = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField<String>(
                          context,
                          label: l10n.numberFormat,
                          value: _numberFormat,
                          items: [
                            DropdownMenuItem(
                              value: 'en-KE',
                              child: Text(l10n.kenyaEnglish),
                            ),
                            DropdownMenuItem(
                              value: 'en-US',
                              child: Text(l10n.systemEmail),
                            ),
                            DropdownMenuItem(
                              value: 'en-GB',
                              child: Text(l10n.ukEnglish),
                            ),
                            DropdownMenuItem(
                              value: 'sw-KE',
                              child: Text(l10n.kenyaSwahili),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _numberFormat = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Theme section
                  _buildSectionHeader(
                    context,
                    l10n.appearance,
                    Icons.palette_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.theme,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _themes.map((option) {
                            final isSelected = _theme == option.code;
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    option.icon,
                                    size: 18,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_themeName(l10n, option.code)),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected)
                                  setState(() => _theme = option.code);
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                              labelStyle: AppTypography.bodyMedium.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppBorderRadius.mediumRadius,
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Currency section
                  _buildSectionHeader(
                    context,
                    l10n.currency,
                    Icons.currency_exchange_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: _buildDropdownField<String>(
                      context,
                      label: l10n.defaultCurrency,
                      value: _currency,
                      items: _currencies
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.code,
                              child: Text(_currencyName(l10n, c.code)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _currency = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Notification channels section
                  _buildSectionHeader(
                    context,
                    l10n.notificationChannels,
                    Icons.notifications_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        _buildNotificationSwitch(
                          context,
                          icon: Icons.push_pin_outlined,
                          title: l10n.pushNotifications,
                          subtitle: l10n.pushNotificationsDescription,
                          value: _pushNotifications,
                          onChanged: (value) =>
                              setState(() => _pushNotifications = value),
                        ),
                        const Divider(height: 24),
                        _buildNotificationSwitch(
                          context,
                          icon: Icons.email_outlined,
                          title: l10n.emailNotifications,
                          subtitle: l10n.emailNotificationsDescription,
                          value: _emailNotifications,
                          onChanged: (value) =>
                              setState(() => _emailNotifications = value),
                        ),
                        const Divider(height: 24),
                        _buildNotificationSwitch(
                          context,
                          icon: Icons.sms_outlined,
                          title: l10n.smsNotifications,
                          subtitle: l10n.smsNotificationsDescription,
                          value: _smsNotifications,
                          onChanged: (value) =>
                              setState(() => _smsNotifications = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  PrimaryButton(
                    label: l10n.savePreferences,
                    isLoading: _isSaving,
                    onPressed: _savePreferences,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumRadius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumRadius,
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _LocaleOption {
  final String code;
  final String name;
  const _LocaleOption(this.code, this.name);
}

class _ThemeOption {
  final String code;
  final String name;
  final IconData icon;
  const _ThemeOption(this.code, this.name, this.icon);
}

class _CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  const _CurrencyOption(this.code, this.name, this.symbol);
}

class _TimezoneOption {
  final String code;
  final String name;
  const _TimezoneOption(this.code, this.name);
}
