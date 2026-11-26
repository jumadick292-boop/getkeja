// MFA enrollment page for authenticator, SMS, email, and recovery codes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class MfaEnrollmentPage extends ConsumerStatefulWidget {
  const MfaEnrollmentPage({
    super.key,
    this.additionalMethod = false,
    this.methodType = 'totp',
  });

  final bool additionalMethod;
  final String methodType;

  @override
  ConsumerState<MfaEnrollmentPage> createState() => _MfaEnrollmentPageState();
}

class _MfaEnrollmentPageState extends ConsumerState<MfaEnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _provisioningUri;
  String? _secret;
  String? _methodId;
  late String _activeMethodType;
  MfaEnrollmentStep _step = MfaEnrollmentStep.selectMethod;

  @override
  void initState() {
    super.initState();
    _activeMethodType = widget.methodType;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment(String methodType) async {
    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        widget.additionalMethod
            ? AuthAction.addMfaMethod(
                methodType: methodType,
                phoneNumber: methodType == 'sms'
                    ? _phoneController.text.trim()
                    : null,
                makePrimary: false,
              )
            : AuthAction.startMfaEnrollment(
                methodType: methodType,
                phoneNumber: methodType == 'sms'
                    ? _phoneController.text.trim()
                    : null,
              ),
      );
      final result = notifier.lastMfaEnrollment;
      if (result == null || result['methodId'] is! String) {
        throw const ServerException(
          message: 'The server did not return MFA setup details.',
        );
      }
      final provisioningUri = result['provisioningUri'] as String?;
      final secret = result['secret'] as String?;
      if (methodType == 'totp' &&
          (provisioningUri == null || secret == null || secret.isEmpty)) {
        throw const ServerException(
          message:
              'The server returned incomplete authenticator setup details.',
        );
      }
      if (!mounted) return;
      setState(() {
        _activeMethodType = methodType;
        _methodId = result['methodId'] as String;
        _provisioningUri = provisioningUri;
        _secret = secret;
        _step = MfaEnrollmentStep.verifyCode;
      });
      if (methodType == 'sms' || methodType == 'email') {
        try {
          await notifier.requestMfaEnrollmentCode(_methodId!);
        } on AppException catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not send the code: ${error.message}'),
            ),
          );
        }
      }
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start enrollment: ${error.message}')),
      );
    }
  }

  Future<void> _resendCode() async {
    if (_methodId == null) return;
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .requestMfaEnrollmentCode(_methodId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code was sent.')),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _verifyEnrollment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_methodId == null) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      if (widget.additionalMethod) {
        await notifier.handleAction(
          AuthAction.verifyMfaMethod(
            methodId: _methodId!,
            code: _codeController.text.trim(),
          ),
        );
      } else {
        await notifier.handleAction(
          AuthAction.verifyMfaEnrollment(
            methodId: _methodId!,
            code: _codeController.text.trim(),
          ),
        );
      }
      if (!mounted) return;

      if (widget.additionalMethod) {
        context.go('/mfa/manage');
        return;
      }

      final authState = ref.read(authNotifierProvider);
      if (authState.isUnauthenticated) {
        // After enrollment, user needs to sign in again
        context.go('/sign-in');
      }
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _skipEnrollment() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(const AuthAction.skipMfaEnrollment());
      if (!mounted) return;
      if (ref.read(authNotifierProvider).isAuthenticated) {
        context.go('/dashboard');
      }
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button (only on first step)
                if (_step == MfaEnrollmentStep.selectMethod)
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                const SizedBox(height: 8),

                // Logo
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: AppBorderRadius.mediumRadius,
                  ),
                  child: Icon(
                    Icons.home_work_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Secure your account',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.additionalMethod
                      ? 'Verify this method to add it to your account.'
                      : 'Choose an authenticator app, phone, or verified email to add a second sign-in check.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Step content
                Expanded(child: _buildStepContent(context, theme)),

                // Error message
                if (authState.errorMessage case final error?) ...[
                  AppNotice(message: error, type: NoticeType.error),
                  const SizedBox(height: 16),
                ],

                // Action button
                PrimaryButton(
                  label: _getButtonLabel(),
                  isLoading: authState.isLoading,
                  onPressed: _getButtonAction(),
                ),
                if (!widget.additionalMethod &&
                    _step == MfaEnrollmentStep.selectMethod) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: authState.isLoading ? null : _skipEnrollment,
                      child: const Text('Skip for now'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, ThemeData theme) {
    switch (_step) {
      case MfaEnrollmentStep.selectMethod:
        return _buildMethodSelection(theme);
      case MfaEnrollmentStep.verifyCode:
        return _buildCodeVerification(theme);
    }
  }

  Widget _buildMethodSelection(ThemeData theme) {
    final showSms = !widget.additionalMethod || widget.methodType == 'sms';
    final showEmail = !widget.additionalMethod || widget.methodType == 'email';
    final showTotp = !widget.additionalMethod || widget.methodType == 'totp';
    return SingleChildScrollView(
      child: Column(
        children: [
          if (showTotp)
            _MfaMethodOption(
              icon: Icons.shield_outlined,
              title: 'Authenticator app (TOTP)',
              subtitle:
                  'Use Google Authenticator, Authy, or another TOTP app to add an extra layer of account security.',
              isRecommended: true,
              onTap: () => _startEnrollment('totp'),
            ),
          if (showSms) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+254 7XX XXX XXX',
              ),
              validator: (value) {
                final normalized = (value ?? '').replaceAll(
                  RegExp(r'[\s()-]'),
                  '',
                );
                if (!RegExp(r'^(?:\+?254|0)?[17]\d{8}$').hasMatch(normalized)) {
                  return 'Enter a valid Kenyan phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _MfaMethodOption(
              icon: Icons.sms_outlined,
              title: 'Text message',
              subtitle: 'Receive a one-time code on your phone.',
              onTap: () {
                if (_formKey.currentState!.validate()) _startEnrollment('sms');
              },
            ),
          ],
          if (showEmail) ...[
            const SizedBox(height: 12),
            _MfaMethodOption(
              icon: Icons.email_outlined,
              title: 'Email code',
              subtitle:
                  'Receive a one-time code at your verified account email.',
              onTap: () => _startEnrollment('email'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeVerification(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeMethodType == 'sms' || _activeMethodType == 'email') ...[
            Text(
              _activeMethodType == 'sms'
                  ? 'Enter the code sent to your phone.'
                  : 'Enter the code sent to your verified email.',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_provisioningUri != null && _secret != null) ...[
            // TOTP QR Code
            Text(
              'Scan with your authenticator app',
              style: AppTypography.titleMedium.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: _provisioningUri!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Or enter manually',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _secret!,
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Code input
          AppTextField(
            controller: _codeController,
            label: 'Enter the verification code',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: (value) {
              final code = value?.trim() ?? '';
              final lengthIsValid = _activeMethodType == 'totp'
                  ? code.length == 6
                  : code.length >= 4 && code.length <= 8;
              if (!lengthIsValid || !RegExp(r'^\d+$').hasMatch(code)) {
                return 'Enter the numeric code you received';
              }
              return null;
            },
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verifyEnrollment(),
          ),
          if (_activeMethodType == 'sms' || _activeMethodType == 'email')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resendCode,
                child: const Text('Resend code'),
              ),
            ),
        ],
      ),
    );
  }

  String _getButtonLabel() {
    switch (_step) {
      case MfaEnrollmentStep.selectMethod:
        return 'Continue';
      case MfaEnrollmentStep.verifyCode:
        return 'Verify & continue';
    }
  }

  VoidCallback? _getButtonAction() {
    switch (_step) {
      case MfaEnrollmentStep.selectMethod:
        return null; // Handled by method options
      case MfaEnrollmentStep.verifyCode:
        return _verifyEnrollment;
    }
  }
}

enum MfaEnrollmentStep { selectMethod, verifyCode }

class _MfaMethodOption extends StatelessWidget {
  const _MfaMethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isRecommended = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isRecommended;

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
            border: Border.all(
              color: isRecommended
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: isRecommended ? 2 : 1,
            ),
            color: isRecommended
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRecommended
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Icon(
                  icon,
                  color: isRecommended
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: AppBorderRadius.roundRadius,
                            ),
                            child: Text(
                              'Recommended',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
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
