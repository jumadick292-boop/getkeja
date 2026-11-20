// Registration page with email, phone, and phone-OTP options.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';

enum RegistrationMethod { email, phone, phoneOtp }

const Map<String, Map<String, String>> _accountTypeGroups = {
  'Homes and rentals': {
    'house_seeker': 'House seeker',
    'tenant': 'Tenant',
    'landlord': 'Landlord',
  },
  'Property teams': {
    'caretaker': 'Caretaker',
    'property_manager': 'Property manager',
    'letting_agent': 'Letting agent',
  },
  'Service providers': {
    'moving_company': 'Moving company',
    'individual_mover': 'Individual mover',
    'garbage_provider': 'Garbage collection provider',
    'laundry_provider': 'Laundry provider',
    'service_provider': 'Other service provider',
  },
};

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({
    this.registrationMethod = RegistrationMethod.email,
    super.key,
  });

  final RegistrationMethod registrationMethod;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late RegistrationMethod _registrationMethod;
  String? _selectedAccountType;

  @override
  void initState() {
    super.initState();
    _registrationMethod = widget.registrationMethod;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithGoogle(WidgetRef ref, String role) async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and privacy policy'),
        ),
      );
      return;
    }
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .handleAction(AuthAction.registerWithGoogle(role: role));
      if (!mounted) return;
      _handleAuthNavigation(ref.read(authNotifierProvider));
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _signUpWithGoogleForSelectedRole(WidgetRef ref) async {
    final role = _selectedAccountType;
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose how you will use GetKeja first')),
      );
      return;
    }
    await _signUpWithGoogle(ref, role);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and privacy policy'),
        ),
      );
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      switch (_registrationMethod) {
        case RegistrationMethod.email:
          await notifier.handleAction(
            AuthAction.registerEmail(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              role: _selectedAccountType!,
              termsAccepted: true,
            ),
          );
        case RegistrationMethod.phone:
          await notifier.handleAction(
            AuthAction.registerPhone(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
              role: _selectedAccountType!,
              termsAccepted: true,
            ),
          );
        case RegistrationMethod.phoneOtp:
          await notifier.handleAction(
            AuthAction.registerPhoneOtp(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phone: _phoneController.text.trim(),
              role: _selectedAccountType!,
              termsAccepted: true,
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

  void _handleAuthNavigation(AuthState authState) {
    if (authState.isVerificationRequired) {
      final verificationType =
          (authState as dynamic).verificationType as String?;
      if (verificationType == 'phone') {
        context.go(
          '/verify-phone',
          extra: {'phone': _phoneController.text.trim()},
        );
      } else {
        context.go(
          '/verify-email',
          extra: {
            'email': _emailController.text.trim(),
            'deliveryFailed': ref
                .read(authNotifierProvider.notifier)
                .emailVerificationDeliveryFailed,
          },
        );
      }
    } else if (authState.isMfaEnrollmentRequired) {
      context.go('/mfa/enroll');
    } else if (authState.isMfaRequired) {
      final challengeId = (authState as dynamic).challengeId as String?;
      final methods = (authState as dynamic).availableMethods as List<String>?;
      context.go(
        '/mfa/challenge?challengeId=${challengeId ?? ''}&methods=${methods?.join(',') ?? ''}',
      );
    } else if (authState.isAuthenticated) {
      context.go('/dashboard');
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _openLegalPage(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Show an in-app message if the device cannot open the legal page.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the requested page.')),
    );
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
                  'Create account',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to save homes and manage your bookings.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                SegmentedButton<RegistrationMethod>(
                  segments: const [
                    ButtonSegment(
                      value: RegistrationMethod.email,
                      label: Text('Email'),
                      icon: Icon(Icons.email_outlined),
                    ),
                    ButtonSegment(
                      value: RegistrationMethod.phone,
                      label: Text('Phone'),
                      icon: Icon(Icons.phone_outlined),
                    ),
                  ],
                  selected: {
                    _registrationMethod == RegistrationMethod.phoneOtp
                        ? RegistrationMethod.phone
                        : _registrationMethod,
                  },
                  onSelectionChanged: authState.isLoading
                      ? null
                      : (selection) {
                          if (selection.isNotEmpty) {
                            setState(
                              () => _registrationMethod = selection.first,
                            );
                          }
                        },
                  expandedInsets: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Name fields
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _firstNameController,
                        label: 'First name',
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter first name'
                            : null,
                        autofillHints: const [AutofillHints.givenName],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        controller: _lastNameController,
                        label: 'Last name',
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter last name'
                            : null,
                        autofillHints: const [AutofillHints.familyName],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email or Phone field based on registration method
                if (_registrationMethod == RegistrationMethod.email) ...[
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 254,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value?.email,
                    autofillHints: const [AutofillHints.email],
                  ),
                ] else if (_registrationMethod == RegistrationMethod.phone ||
                    _registrationMethod == RegistrationMethod.phoneOtp) ...[
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value?.phone,
                    hintText: '+254 7XX XXX XXX',
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  if (_registrationMethod == RegistrationMethod.phone) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(
                          () =>
                              _registrationMethod = RegistrationMethod.phoneOtp,
                        ),
                        child: const Text('Use SMS verification code instead'),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedAccountType,
                  decoration: const InputDecoration(
                    labelText: 'How will you use GetKeja?',
                    helperText:
                        'Your choice sets your starting tools and access. You can complete your profile after signup.',
                  ),
                  items: [
                    for (final group in _accountTypeGroups.entries) ...[
                      DropdownMenuItem<String>(
                        value: '__group_${group.key}',
                        enabled: false,
                        child: Text(
                          group.key,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      for (final entry in group.value.entries)
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                  ],
                  validator: (value) =>
                      value == null ? 'Choose how you will use GetKeja' : null,
                  onChanged: authState.isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedAccountType = value);
                          }
                        },
                ),
                const SizedBox(height: 16),

                if (_registrationMethod != RegistrationMethod.phoneOtp) ...[
                  AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value?.password,
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
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _submit(),
                  ),
                ] else ...[
                  Text(
                    'We will text a one-time verification code to this number.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],

                // Terms checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _termsAccepted,
                      onChanged: (value) =>
                          setState(() => _termsAccepted = value ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'I agree to the',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _openLegalPage('https://getkeja.com/terms'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Terms of Service'),
                            ),
                            Text(
                              'and',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _openLegalPage('https://getkeja.com/privacy'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Privacy Policy'),
                            ),
                            Text(
                              '.',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Error message
                if (authState.errorMessage case final error?) ...[
                  AppNotice(message: error, type: NoticeType.error),
                  const SizedBox(height: 16),
                ],

                PrimaryButton(
                  label:
                      'Create account with ${_registrationMethod == RegistrationMethod.email ? 'email' : 'phone'}',
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
                _GoogleSignUpButton(
                  isLoading: authState.isLoading,
                  onPressed: () => _signUpWithGoogleForSelectedRole(ref),
                ),

                const SizedBox(height: 24),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/sign-in'),
                      child: Text(
                        'Sign in',
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

class _GoogleSignUpButton extends StatelessWidget {
  const _GoogleSignUpButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
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
}
