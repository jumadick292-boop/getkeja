// Sign in page with email/password, phone/password, and OTP options.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../state/auth_state.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  LoginMode _loginMode = LoginMode.emailPassword;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      switch (_loginMode) {
        case LoginMode.emailPassword:
          await notifier.handleAction(
            AuthAction.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
        case LoginMode.phonePassword:
          await notifier.handleAction(
            AuthAction.loginWithPhone(
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
            ),
          );
      }

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

  Future<void> _requestEmailOtp() async {
    final email = _emailController.text.trim();
    if (Validators.email(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(AuthAction.requestEmailOtp(email: email));
      if (!mounted) return;
      context.push('/verify-email', extra: {'email': email, 'otpLogin': true});
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _requestEmailVerification() async {
    final email = _emailController.text.trim();
    if (Validators.email(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .handleAction(AuthAction.requestEmailVerification(email: email));
      if (!mounted) return;
      context.push('/verify-email', extra: {'email': email});
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _requestPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (Validators.phone(phone) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(AuthAction.requestPhoneOtp(phone: phone));
      if (!mounted) return;
      context.push('/verify-phone', extra: {'phone': phone, 'otpLogin': true});
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _handleAuthNavigation(AuthState authState) {
    if (authState.isAuthenticated) {
      context.go('/dashboard');
    } else if (authState.isMfaRequired) {
      final challengeId = (authState as dynamic).challengeId as String?;
      final methods = (authState as dynamic).availableMethods as List<String>?;
      context.go(
        '/mfa/challenge?challengeId=${challengeId ?? ''}&methods=${methods?.join(',') ?? ''}',
      );
    } else if (authState.isMfaEnrollmentRequired) {
      context.go('/mfa/enroll');
    } else if (authState.isVerificationRequired) {
      final verificationType =
          (authState as dynamic).verificationType as String?;
      if (verificationType == 'phone') {
        context.go('/verify-phone');
      } else {
        context.go('/verify-email');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                  'Welcome back',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your GetKeja account.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Login mode selector
                _LoginModeSelector(
                  selectedMode: _loginMode,
                  onModeChanged: (mode) => setState(() => _loginMode = mode),
                ),
                const SizedBox(height: 24),

                // Sign-in method fields
                if (_loginMode == LoginMode.emailPassword) ...[
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 254,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value?.email,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        Validators.password(value, minLength: 1),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                ] else if (_loginMode == LoginMode.phonePassword) ...[
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value?.phone,
                    hintText: '+254 7XX XXX XXX',
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        Validators.password(value, minLength: 1),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                ],

                const SizedBox(height: 16),

                if (_loginMode == LoginMode.emailPassword) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        'Forgot password?',
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // OTP options
                if (_loginMode == LoginMode.emailPassword) ...[
                  TextButton.icon(
                    onPressed: _requestEmailOtp,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Sign in with email OTP instead'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _requestEmailVerification,
                    icon: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 18,
                    ),
                    label: const Text('Resend email verification'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ] else if (_loginMode == LoginMode.phonePassword) ...[
                  TextButton.icon(
                    onPressed: _requestPhoneOtp,
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Sign in with SMS OTP instead'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Error message
                if (authState.errorMessage case final error?) ...[
                  AppNotice(message: error, type: NoticeType.error),
                  const SizedBox(height: 16),
                ],

                // Submit button
                PrimaryButton(
                  label:
                      'Sign in with ${_loginMode == LoginMode.emailPassword ? 'email' : 'phone'}',
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'or',
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _GoogleSignInButton(isLoading: authState.isLoading),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Created your account with Google? Continue with Google here. To use email and password, sign in with Google first, then set a password under Account > Password & login.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: () => context.push('/restore-account'),
                    child: const Text(
                      'Restore a deactivated or recently deleted account',
                    ),
                  ),
                ),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(
                        'Create account',
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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

enum LoginMode { emailPassword, phonePassword }

class _LoginModeSelector extends StatelessWidget {
  const _LoginModeSelector({
    required this.selectedMode,
    required this.onModeChanged,
  });

  final LoginMode selectedMode;
  final ValueChanged<LoginMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.mediumRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Email',
              icon: Icons.email_outlined,
              isSelected: selectedMode == LoginMode.emailPassword,
              onTap: () => onModeChanged(LoginMode.emailPassword),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Phone',
              icon: Icons.phone_outlined,
              isSelected: selectedMode == LoginMode.phonePassword,
              onTap: () => onModeChanged(LoginMode.phonePassword),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumRadius,
        child: AnimatedContainer(
          duration: AppAnimation.fast,
          curve: AppAnimation.standard,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends ConsumerWidget {
  const _GoogleSignInButton({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: isLoading ? null : () => _signInWithGoogle(context, ref),
      icon: Image.asset(
        'assets/images/brand/google_logo.png',
        width: 20,
        height: 20,
        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 20),
      ),
      label: Text(
        isLoading ? 'Connecting to Google...' : 'Continue with Google',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        padding: AppSpacing.buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
    );
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      await notifier.handleAction(const AuthAction.loginWithGoogle());
      if (context.mounted) {
        final authState = ref.read(authNotifierProvider);
        if (authState.isMfaRequired) {
          final challengeId = (authState as dynamic).challengeId as String?;
          final methods =
              (authState as dynamic).availableMethods as List<String>?;
          context.go(
            '/mfa/challenge?challengeId=${challengeId ?? ''}&methods=${methods?.join(',') ?? ''}',
          );
        } else if (authState.isMfaEnrollmentRequired) {
          context.go('/mfa/enroll');
        } else if (authState.isAuthenticated) {
          context.go('/dashboard');
        }
      }
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'INVALID_CREDENTIALS'
                ? 'No linked Google sign-in was found. If you already use email and password for GetKeja, sign in that way first, then link Google under Account > Password & login. Otherwise, create an account with Google.'
                : error.message,
          ),
        ),
      );
    }
  }
}
