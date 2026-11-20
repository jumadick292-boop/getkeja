// Recovery page for managing MFA recovery codes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  bool _isLoading = false;
  bool _regenerating = false;
  String? _errorMessage;
  String? _successMessage;

  int _recoveryCodesRemaining = 0;
  bool _hasRecoveryCodes = false;
  List<String> _currentRecoveryCodes = [];

  @override
  void initState() {
    super.initState();
    _loadRecoveryCodes();
  }

  Future<void> _loadRecoveryCodes() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/mfa/status');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        setState(() {
          _recoveryCodesRemaining =
              payload['recoveryCodesRemaining'] as int? ?? 0;
          _hasRecoveryCodes = _recoveryCodesRemaining > 0;
          final methods = payload['methods'] as List?;
          if (methods != null) {
            final recoveryMethod = methods
                .whereType<Map<String, dynamic>>()
                .where((m) => m['methodType'] == 'recovery_codes')
                .firstOrNull;
            if (recoveryMethod != null) {
              _hasRecoveryCodes =
                  recoveryMethod['isActive'] == true &&
                  recoveryMethod['isVerified'] == true;
            }
          }
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

  Future<void> _regenerateRecoveryCodes() async {
    final code = await _requestVerificationCode();
    if (code == null) return;

    setState(() {
      _regenerating = true;
      _errorMessage = null;
    });

    try {
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/mfa/recovery-codes/regenerate',
            data: {'verificationCode': code},
          );

      final payload = response.data?['data'];
      final codes = payload is Map<String, dynamic>
          ? payload['codes'] as List?
          : null;

      if (codes != null && codes.isNotEmpty) {
        if (mounted) {
          _currentRecoveryCodes = codes.cast<String>();
          await _showRecoveryCodes(_currentRecoveryCodes);
          await _loadRecoveryCodes();
        }
      } else {
        throw const ServerException(
          message: 'The server did not return recovery codes.',
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
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<String?> _requestVerificationCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify your identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter an unused recovery code to regenerate new ones.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(labelText: 'Recovery code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return code?.isNotEmpty == true ? code : null;
  }

  Future<void> _showRecoveryCodes(List<String> codes) async {
    var saved = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save your recovery codes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Each code can be used once. Store them somewhere private and secure.',
                ),
                const SizedBox(height: 16),
                ...codes.map((code) => SelectableText(code)),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: saved,
                  title: const Text('I saved these codes'),
                  onChanged: (value) =>
                      setDialogState(() => saved = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: saved ? () => Navigator.pop(context) : null,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to load recovery codes. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery codes')),
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

                  // Header
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: AppBorderRadius.mediumRadius,
                          ),
                          child: Icon(
                            Icons.backup_outlined,
                            color: theme.colorScheme.onSecondaryContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recovery codes',
                                style: AppTypography.titleMedium.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hasRecoveryCodes
                                    ? '$_recoveryCodesRemaining unused codes remaining'
                                    : 'No recovery codes configured',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About recovery codes',
                          style: AppTypography.bodyLarge.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          context,
                          Icons.info_outline_rounded,
                          'Recovery codes are one-time use backup codes that let you sign in if you lose access to your authenticator app or phone.',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          context,
                          Icons.warning_amber_rounded,
                          'Each code can only be used once. After using a code, it becomes invalid.',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          context,
                          Icons.security_outlined,
                          'Store your codes in a secure place like a password manager or printed in a safe.',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          context,
                          Icons.refresh_outlined,
                          'Regenerating codes invalidates all existing codes immediately.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  if (_hasRecoveryCodes) ...[
                    Text(
                      'Actions',
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Regenerate recovery codes',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Create new codes and invalidate all existing ones',
                                      style: AppTypography.bodySmall.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _regenerating
                                    ? null
                                    : _regenerateRecoveryCodes,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.tertiary,
                                  side: BorderSide(
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                                child: _regenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Regenerate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Set up recovery codes',
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        children: [
                          Icon(
                            Icons.backup_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recovery codes configured',
                            style: AppTypography.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add recovery codes as a backup authentication method.',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Add recovery codes',
                            icon: const Icon(Icons.add_rounded),
                            onPressed: () => context.push(
                              '/mfa/enroll/add?method=recovery_codes',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
