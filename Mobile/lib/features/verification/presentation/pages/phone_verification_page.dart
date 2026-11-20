// Phone verification page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart'
    show AppNotice, AppTextField, PrimaryButton, NoticeType;
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class PhoneVerificationPage extends ConsumerStatefulWidget {
  const PhoneVerificationPage({this.phone, this.otpLogin = false, super.key});

  final String? phone;
  final bool otpLogin;

  @override
  ConsumerState<PhoneVerificationPage> createState() =>
      _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends ConsumerState<PhoneVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  int _resendCountdown = 0;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phone ?? '';
    if (widget.phone != null) _startCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _countdown();
  }

  void _countdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _countdown();
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      final phone = _phoneController.text.trim();
      await notifier.handleAction(
        widget.otpLogin
            ? AuthAction.verifyPhoneOtp(
                phone: phone,
                otp: _codeController.text.trim(),
              )
            : AuthAction.confirmPhoneVerification(
                phone: phone,
                code: _codeController.text.trim(),
              ),
      );
      if (!mounted) return;

      final authState = ref.read(authNotifierProvider);
      _handleAuthNavigation(authState);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() => _isResending = true);

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      final phone = _phoneController.text.trim();
      if (Validators.phone(phone) != null) {
        throw const ValidationException('Enter a valid phone number.');
      }
      await notifier.handleAction(
        widget.otpLogin
            ? AuthAction.requestPhoneOtp(phone: phone)
            : AuthAction.requestPhoneVerification(phone: phone),
      );
      if (!mounted) return;
      _startCountdown();
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

  void _handleAuthNavigation(AuthState authState) {
    if (authState.isAuthenticated) {
      context.go('/dashboard');
    } else if (authState.isMfaEnrollmentRequired) {
      context.go('/mfa/enroll');
    } else if (authState.isMfaRequired) {
      final challengeId = (authState as dynamic).challengeId as String?;
      final methods = (authState as dynamic).availableMethods as List<String>?;
      context.go(
        '/mfa/challenge?challengeId=${challengeId ?? ''}&methods=${methods?.join(',') ?? ''}',
      );
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
                  'Verify your phone',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.otpLogin
                      ? 'Enter the sign-in code sent via SMS to ${_phoneController.text}.'
                      : 'Enter the SMS verification code sent to your phone number.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  keyboardType: TextInputType.phone,
                  hintText: '+254 7XX XXX XXX',
                  validator: (value) => value?.phone,
                ),
                const SizedBox(height: 16),

                // Code input
                AppTextField(
                  controller: _codeController,
                  label: 'Verification code',
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
                  label: widget.otpLogin ? 'Sign in' : 'Verify phone',
                  isLoading: authState.isLoading,
                  onPressed: _verify,
                ),

                const SizedBox(height: 16),

                // Resend code with countdown
                Center(
                  child: TextButton(
                    onPressed: (_isResending || _resendCountdown > 0)
                        ? null
                        : _resendCode,
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
                        : _resendCountdown > 0
                        ? Text(
                            'Resend code in ${_resendCountdown}s',
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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

                // Change phone option
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: Text(
                      'Wrong number? Sign in with a different account',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Help text
                Text(
                  'Didn\'t receive the code? Make sure you have signal and try again.',
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
