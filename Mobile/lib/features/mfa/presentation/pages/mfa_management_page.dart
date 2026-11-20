// MFA management page for viewing and managing MFA methods.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class MfaManagementPage extends ConsumerStatefulWidget {
  const MfaManagementPage({super.key});

  @override
  ConsumerState<MfaManagementPage> createState() => _MfaManagementPageState();
}

class _MfaManagementPageState extends ConsumerState<MfaManagementPage> {
  List<MfaMethod> _methods = [];
  bool _isLoading = false;
  int _recoveryCodesRemaining = 0;
  bool _mfaEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/mfa/status');
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic> || payload['methods'] is! List) {
        throw const ServerException(
          message: 'The server returned invalid MFA settings.',
        );
      }
      final methods = (payload['methods'] as List)
          .whereType<Map<String, dynamic>>()
          .map(MfaMethod.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _recoveryCodesRemaining =
            payload['recoveryCodesRemaining'] as int? ?? 0;
        _mfaEnabled = payload['mfaEnabled'] as bool? ?? false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorMessageFrom(error));
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMethod(String methodType) async {
    if (methodType == 'totp' || methodType == 'sms' || methodType == 'email') {
      context.push('/mfa/enroll/add?method=$methodType');
      return;
    }
    if (methodType != 'recovery_codes') return;

    try {
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/mfa/methods/add',
            data: {'methodType': methodType, 'makePrimary': false},
          );
      final payload = response.data?['data'];
      final codes = payload is Map<String, dynamic>
          ? payload['recoveryCodes']
          : null;
      if (codes is! List || codes.isEmpty) {
        throw const ServerException(
          message: 'The server did not return recovery codes.',
        );
      }
      await _showRecoveryCodes(codes.cast<String>());
      await _loadMethods();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _removeMethod(String methodId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove MFA method?'),
        content: const Text(
          'This will remove this authentication method. You\'ll need to verify your identity to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    MfaMethod? method;
    for (final item in _methods) {
      if (item.id == methodId) {
        method = item;
        break;
      }
    }
    final code = await _requestVerificationCode(
      'Remove MFA method',
      method: method,
    );
    if (code == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(
            '/mfa/methods/disable',
            data: {'mfaMethodId': methodId, 'verificationCode': code},
          );
      _showMessage('MFA method removed.');
      await _loadMethods();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _regenerateRecoveryCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate recovery codes?'),
        content: const Text(
          'This will invalidate all existing recovery codes and generate new ones. Make sure to save the new codes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final code = await _requestVerificationCode(
      'Enter an unused recovery code',
      fieldLabel: 'Recovery code',
    );
    if (code == null) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/mfa/recovery-codes/regenerate',
            data: {'verificationCode': code},
          );
      final codes = response.data?['data']?['codes'];
      if (codes is! List || codes.isEmpty) {
        throw const ServerException(
          message: 'The server did not return recovery codes.',
        );
      }
      await _showRecoveryCodes(codes.cast<String>());
      await _loadMethods();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<String?> _requestVerificationCode(
    String title, {
    String fieldLabel = 'Verification code',
    MfaMethod? method,
  }) async {
    if (method?.methodType == 'sms' || method?.methodType == 'email') {
      try {
        await ref
            .read(authNotifierProvider.notifier)
            .requestMfaMethodCode(method!.id);
      } on DioException catch (error) {
        _showError(_errorMessageFrom(error));
        return null;
      } on AppException catch (error) {
        _showError(error.message);
        return null;
      }
    }
    if (!mounted) return null;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (method?.methodType == 'sms' || method?.methodType == 'email')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  method?.methodType == 'sms'
                      ? 'A verification code was sent to this phone.'
                      : 'A verification code was sent to your email.',
                ),
              ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(labelText: fieldLabel),
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to update MFA settings. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('MFA methods')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                if (_errorMessage != null)
                  AppNotice(message: _errorMessage!, type: NoticeType.error),
                if (_errorMessage != null)
                  TextButton(
                    onPressed: _loadMethods,
                    child: const Text('Try again'),
                  ),
                // MFA status
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
                          Icons.shield_rounded,
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
                              _mfaEnabled
                                  ? 'Multi-factor authentication enabled'
                                  : 'Multi-factor authentication not enabled',
                              style: AppTypography.titleMedium.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_methods.where((m) => m.isActive && m.isVerified).length} active method(s)',
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

                // Methods list
                Text(
                  'Authentication methods',
                  style: AppTypography.titleMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                if (_methods.isEmpty)
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No authentication methods configured',
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ..._methods.map((method) => _buildMethodCard(method)),

                const SizedBox(height: 24),

                // Add method button
                SecondaryButton(
                  label: 'Add authentication method',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _showAddMethodDialog,
                ),

                const SizedBox(height: 16),

                // Recovery codes section
                if (_methods.any((m) => m.methodType == 'recovery_codes')) ...[
                  Text(
                    'Recovery codes',
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
                                    'Backup codes available',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_recoveryCodesRemaining unused codes remaining',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _regenerateRecoveryCodes,
                              child: const Text('Regenerate'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Save these codes in a secure place. Each code can only be used once.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildMethodCard(MfaMethod method) {
    final theme = Theme.of(context);
    final (icon, label) = _getMethodIconAndLabel(method.methodType);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: method.isPrimary
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(
              icon,
              color: method.isPrimary
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (method.methodName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        method.methodName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (method.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: AppBorderRadius.roundRadius,
                        ),
                        child: Text(
                          'Primary',
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: method.isActive && method.isVerified
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      method.isActive && method.isVerified
                          ? 'Active'
                          : 'Inactive',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (method.verifiedAt != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        'Added ${_formatDate(method.verifiedAt!)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'set_primary':
                  _setPrimaryMethod(method);
                  break;
                case 'remove':
                  _removeMethod(method.id);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!method.isPrimary && method.methodType != 'recovery_codes')
                const PopupMenuItem(
                  value: 'set_primary',
                  child: Text('Set as primary'),
                ),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, String) _getMethodIconAndLabel(String methodType) {
    switch (methodType) {
      case 'totp':
        return (Icons.shield_outlined, 'Authenticator app');
      case 'sms':
        return (Icons.sms_outlined, 'SMS codes');
      case 'email':
        return (Icons.email_outlined, 'Email codes');
      case 'recovery_codes':
        return (Icons.backup_outlined, 'Recovery codes');
      default:
        return (Icons.help_outline, methodType);
    }
  }

  String _formatDate(DateTime date) {
    return AppFormatters.relativeTime(date);
  }

  Future<void> _setPrimaryMethod(MfaMethod method) async {
    final code = await _requestVerificationCode(
      'Confirm primary method',
      method: method,
    );
    if (code == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(
            '/mfa/methods/set-primary',
            data: {'mfaMethodId': method.id, 'verificationCode': code},
          );
      _showMessage('Primary MFA method updated.');
      await _loadMethods();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    }
  }

  void _showAddMethodDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMethodBottomSheet(onSelect: _addMethod),
    );
  }
}

class _AddMethodBottomSheet extends StatelessWidget {
  const _AddMethodBottomSheet({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add authentication method',
                style: AppTypography.titleLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a method to add to your account.',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _MethodOption(
                icon: Icons.shield_outlined,
                title: 'Authenticator app',
                subtitle: 'TOTP codes from Google Authenticator, Authy, etc.',
                onTap: () {
                  Navigator.pop(context);
                  onSelect('totp');
                },
              ),
              const SizedBox(height: 12),
              _MethodOption(
                icon: Icons.sms_outlined,
                title: 'Text message',
                subtitle:
                    'Verify a phone number and receive sign-in codes by text.',
                onTap: () {
                  Navigator.pop(context);
                  onSelect('sms');
                },
              ),
              const SizedBox(height: 12),
              _MethodOption(
                icon: Icons.email_outlined,
                title: 'Email code',
                subtitle:
                    'Receive sign-in codes at your verified account email.',
                onTap: () {
                  Navigator.pop(context);
                  onSelect('email');
                },
              ),
              const SizedBox(height: 12),
              _MethodOption(
                icon: Icons.backup_outlined,
                title: 'Recovery codes',
                subtitle: 'One-time backup codes for emergency access',
                onTap: () {
                  Navigator.pop(context);
                  onSelect('recovery_codes');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.largeRadius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppBorderRadius.largeRadius,
            border: Border.all(color: theme.colorScheme.outline),
          ),
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
                  icon,
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
                      title,
                      style: AppTypography.bodyLarge.copyWith(
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
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
