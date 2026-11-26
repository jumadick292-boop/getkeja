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
import '../../../authentication/presentation/state/auth_navigation.dart';

enum RegistrationMethod { choose, email, phone, phoneOtp, google }

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
    this.registrationMethod = RegistrationMethod.choose,
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
  bool _isSubmitting = false;

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
    if (_isSubmitting || ref.read(authNotifierProvider).isLoading) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and privacy policy'),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .handleAction(AuthAction.registerWithGoogle(role: role));
      if (!mounted) return;
      _navigate(ref.read(authNotifierProvider));
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    if (_isSubmitting || ref.read(authNotifierProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and privacy policy'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      switch (_registrationMethod) {
        case RegistrationMethod.choose:
        case RegistrationMethod.google:
          return;
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
      _navigate(authState);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _navigate(AuthState authState) {
    navigateForAuthState(
      context,
      authState,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      verificationDeliveryFailed: ref
          .read(authNotifierProvider.notifier)
          .emailVerificationDeliveryFailed,
    );
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

    if (_registrationMethod == RegistrationMethod.choose) {
      return _buildMethodChooser(context, theme, authState.isLoading);
    }

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
                  _registrationMethod == RegistrationMethod.google
                      ? 'Set up Google sign up'
                      : 'Create account with ${_registrationMethod == RegistrationMethod.email ? 'email' : 'phone'}',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _registrationMethod == RegistrationMethod.google
                      ? 'Choose how you will use GetKeja, then continue with Google.'
                      : 'Sign up to save homes and manage your bookings.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 24),

                // Name fields
                if (_registrationMethod != RegistrationMethod.google)
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
                if (_registrationMethod != RegistrationMethod.google)
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

                if (_registrationMethod != RegistrationMethod.phoneOtp &&
                    _registrationMethod != RegistrationMethod.google) ...[
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
                ] else if (_registrationMethod ==
                    RegistrationMethod.phoneOtp) ...[
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

                if (_registrationMethod == RegistrationMethod.google)
                  PrimaryButton(
                    label: 'Continue with Google',
                    isLoading: authState.isLoading || _isSubmitting,
                    onPressed: () => _signUpWithGoogleForSelectedRole(ref),
                  )
                else
                  PrimaryButton(
                    label:
                        'Create account with ${_registrationMethod == RegistrationMethod.email ? 'email' : 'phone'}',
                    isLoading: authState.isLoading || _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
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

  Widget _buildMethodChooser(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
  ) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create account',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you would like to sign up.',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Continue with email',
                isLoading: false,
                onPressed: isLoading
                    ? null
                    : () => context.push('/register/email'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => context.push('/register/phone'),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Continue with phone'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => context.push('/register/google'),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTypography.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.push('/sign-in'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
