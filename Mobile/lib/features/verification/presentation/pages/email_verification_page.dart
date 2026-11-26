// Email verification page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../authentication/presentation/state/auth_navigation.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    this.email,
    this.otpLogin = false,
    this.deliveryFailed = false,
    this.initialToken,
    super.key,
  });

  final String? email;
  final bool otpLogin;
  final bool deliveryFailed;
  final String? initialToken;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isResending = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.initialToken ?? '';
    _emailController.text = widget.email ?? '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_isSubmitting || ref.read(authNotifierProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() => _isSubmitting = true);
    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        widget.otpLogin
            ? AuthAction.verifyEmailOtp(
                email: email,
                otp: _codeController.text.trim(),
              )
            : AuthAction.confirmEmailVerification(
                email: email,
                code: _codeController.text.trim(),
              ),
      );
      if (!mounted) return;

      final authState = ref.read(authNotifierProvider);
      navigateForAuthState(
        context,
        authState,
        email: widget.email,
        verificationDeliveryFailed: widget.deliveryFailed,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    final email = _emailController.text.trim();
    if (Validators.email(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    setState(() => _isResending = true);

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        widget.otpLogin
            ? AuthAction.requestEmailOtp(email: email)
            : AuthAction.requestEmailVerification(email: email),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification code sent')));
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.deliveryFailed && !widget.otpLogin) ...[
                  const AppNotice(
                    message:
                        'We could not send the verification email. Check the address and use Resend code below.',
                    type: NoticeType.warning,
                  ),
                  const SizedBox(height: 12),
                ],
                // Back button
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
                  'Verify your email',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.otpLogin
                      ? 'Enter the sign-in code sent to ${_emailController.text.isEmpty ? 'your email address' : _emailController.text}.'
                      : 'Enter the 6-digit verification code sent to ${_emailController.text.isEmpty ? 'your email address' : _emailController.text}.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                if (_emailController.text.isEmpty) ...[
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 254,
                    validator: (value) => value?.email,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                ],

                // Code input
                AppTextField(
                  controller: _codeController,
                  label: widget.otpLogin ? 'Sign-in code' : 'Verification code',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  validator: (value) => value?.otp(length: 6),
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 24),

                // Error message
                if (authState.errorMessage case final error?) ...[
                  AppNotice(message: error, type: NoticeType.error),
                  const SizedBox(height: 16),
                ],

                // Verify button
                PrimaryButton(
                  label: widget.otpLogin ? 'Sign in' : 'Verify email',
                  isLoading: authState.isLoading || _isSubmitting,
                  onPressed: _verify,
                ),

                const SizedBox(height: 16),

                // Resend code
                Center(
                  child: TextButton(
                    onPressed: _isResending ? null : _resendCode,
                    child: _isResending
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sending...',
                                style: AppTypography.labelMedium.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Resend code',
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Change email option
                Center(
                  child: TextButton(
                    onPressed: () => context.go(
                      '/sign-in',
                      extra: {'email': _emailController.text.trim()},
                    ),
                    child: Text(
                      'Wrong email? Sign in with a different account',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Help text
                Text(
                  'Didn\'t receive the code? Check your spam folder or request a new one.',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
