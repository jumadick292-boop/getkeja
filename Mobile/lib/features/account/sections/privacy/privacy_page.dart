// Privacy & data page for data export and account deletion.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class PrivacyDataPage extends ConsumerStatefulWidget {
  const PrivacyDataPage({super.key});

  @override
  ConsumerState<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends ConsumerState<PrivacyDataPage> {
  bool _isLoading = false;
  bool _exportingData = false;
  bool _deletingAccount = false;
  String? _errorMessage;
  String? _successMessage;

  bool _marketingEmails = false;
  bool _analyticsTracking = true;
  bool _personalizedAds = false;
  bool _dataSharing = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/account/privacy');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        setState(() {
          _marketingEmails = payload['marketingEmails'] as bool? ?? false;
          _analyticsTracking = payload['analyticsTracking'] as bool? ?? true;
          _personalizedAds = payload['personalizedAds'] as bool? ?? false;
          _dataSharing = payload['dataSharing'] as bool? ?? false;
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

  Future<void> _updatePrivacySetting(String key, bool value) async {
    try {
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>('/account/privacy', data: {key: value});
      if (mounted) {
        setState(() {
          switch (key) {
            case 'marketingEmails':
              _marketingEmails = value;
            case 'analyticsTracking':
              _analyticsTracking = value;
            case 'personalizedAds':
              _personalizedAds = value;
            case 'dataSharing':
              _dataSharing = value;
          }
          _errorMessage = null;
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
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Unable to save privacy preference: $error',
        );
      }
    }
  }

  Future<void> _requestDataExport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export your account data?'),
        content: const Text(
          'Your account data will be prepared now. You can save or share the JSON file from the system share sheet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _exportingData = true;
      _errorMessage = null;
    });

    try {
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('/account/data-export');
      final exportData = response.data?['data'];
      if (exportData == null) {
        throw const FormatException(
          'The server returned an empty data export.',
        );
      }
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final file = File(
        '${directory.path}/getkeja-account-export-$timestamp.json',
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
        flush: true,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'GetKeja account data export',
        ),
      );

      if (mounted) {
        setState(() {
          _successMessage = result.status == ShareResultStatus.dismissed
              ? 'Your export file was prepared but not shared.'
              : 'Your account data export is ready.';
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
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Unable to prepare or share your data export: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _exportingData = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await _requestPassword();
    if (password == null) return;

    final confirmText = await _requestConfirmationText();
    if (confirmText != 'DELETE') return;

    setState(() {
      _deletingAccount = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .delete<Map<String, dynamic>>(
            '/account',
            data: {'currentPassword': password, 'confirmation': 'DELETE'},
          );

      if (mounted) {
        // Clear auth state and redirect
        await ref
            .read(authNotifierProvider.notifier)
            .handleAction(const AuthAction.logoutAll());
        if (mounted) {
          context.go('/welcome');
        }
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
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<String?> _requestPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Recent MFA verification is required. Enter your password too if your account has one; leave it blank for passwordless sign-in.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              autofillHints: const [AutofillHints.password],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  Future<String?> _requestConfirmationText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Type "DELETE" to confirm',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This signs you out and starts a 30-day recovery window. After that, personal account data is permanently purged. Some business records may remain where required for legal, financial, or tenancy obligations.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Type DELETE',
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.toUpperCase()),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    controller.dispose();
    return text;
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to complete the action. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: _isLoading
          ? const AppListSkeleton(rows: 4)
          : SingleChildScrollView(
              padding: AppSpacing.compactScreenPadding,
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

                  // Data export section
                  Text(
                    'Your data',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download a copy of your data or request account deletion.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.compactCardPadding,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: AppBorderRadius.mediumRadius,
                          ),
                          child: Icon(
                            Icons.download_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download your data',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get a copy of your profile, settings, activity, and more.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _exportingData ? null : _requestDataExport,
                          child: _exportingData
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Request export'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: AppSpacing.compactCardPadding,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: AppBorderRadius.mediumRadius,
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.onErrorContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete your account',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Restore it within 30 days using a verified email or phone. Personal data is purged after that window; some required business records may remain.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _deletingAccount ? null : _deleteAccount,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                          ),
                          child: _deletingAccount
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Delete account'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Privacy settings section
                  Text(
                    'Privacy preferences',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Control how your data is used for marketing and analytics.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.compactCardPadding,
                    child: Column(
                      children: [
                        _buildPrivacySwitch(
                          context,
                          title: 'Marketing emails',
                          subtitle:
                              'Receive promotional emails about GetKeja services',
                          value: _marketingEmails,
                          onChanged: (value) =>
                              _updatePrivacySetting('marketingEmails', value),
                        ),
                        const Divider(height: 24),
                        _buildPrivacySwitch(
                          context,
                          title: 'Analytics tracking',
                          subtitle:
                              'Help us improve by sharing anonymous usage data',
                          value: _analyticsTracking,
                          onChanged: (value) =>
                              _updatePrivacySetting('analyticsTracking', value),
                        ),
                        const Divider(height: 24),
                        _buildPrivacySwitch(
                          context,
                          title: 'Personalized ads',
                          subtitle:
                              'Allow data to be used for personalized advertising',
                          value: _personalizedAds,
                          onChanged: (value) =>
                              _updatePrivacySetting('personalizedAds', value),
                        ),
                        const Divider(height: 24),
                        _buildPrivacySwitch(
                          context,
                          title: 'Data sharing with partners',
                          subtitle:
                              'Share anonymized data with trusted partners for service improvement',
                          value: _dataSharing,
                          onChanged: (value) =>
                              _updatePrivacySetting('dataSharing', value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legal links
                  Text(
                    'Legal & policies',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.compactCardPadding,
                    child: Column(
                      children: [
                        _buildLegalLink(
                          context,
                          title: 'Privacy Policy',
                          subtitle:
                              'How we collect, use, and protect your data',
                          onTap: () => _openUrl('https://getkeja.com/privacy'),
                        ),
                        const Divider(height: 1),
                        _buildLegalLink(
                          context,
                          title: 'Terms of Service',
                          subtitle: 'Rules and guidelines for using GetKeja',
                          onTap: () => _openUrl('https://getkeja.com/terms'),
                        ),
                        const Divider(height: 1),
                        _buildLegalLink(
                          context,
                          title: 'Cookie Policy',
                          subtitle:
                              'How we use cookies and similar technologies',
                          onTap: () => _openUrl('https://getkeja.com/cookies'),
                        ),
                        const Divider(height: 1),
                        _buildLegalLink(
                          context,
                          title: 'Data Processing Agreement',
                          subtitle: 'Legal framework for data processing',
                          onTap: () => _openUrl('https://getkeja.com/dpa'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacySwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
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

  Widget _buildLegalLink(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.mediumRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
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
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This legal page URL is invalid.')),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this legal page.')),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open this legal page: ${error.message}'),
          ),
        );
      }
    }
  }
}
