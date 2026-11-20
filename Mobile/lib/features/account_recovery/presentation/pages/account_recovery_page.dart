// Account recovery page for lost MFA/device access.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class AccountRecoveryPage extends ConsumerStatefulWidget {
  const AccountRecoveryPage({this.initialToken, super.key});

  final String? initialToken;

  @override
  ConsumerState<AccountRecoveryPage> createState() =>
      _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends ConsumerState<AccountRecoveryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AccountRecoveryStep _step = AccountRecoveryStep.selectMethod;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      _tokenController.text = token;
      _step = AccountRecoveryStep.verifyToken;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestEmailRecovery() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        AuthAction.requestAccountRecoveryEmail(
          email: _emailController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If the email exists, an account recovery link will be sent',
          ),
        ),
      );
      setState(() => _step = AccountRecoveryStep.waitForEmail);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _requestPhoneRecovery() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        AuthAction.requestAccountRecoveryPhone(
          phone: _phoneController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If the phone number exists, a recovery code will be sent via SMS',
          ),
        ),
      );
      setState(() => _step = AccountRecoveryStep.waitForPhone);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _verifyRecovery() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        AuthAction.verifyAccountRecovery(
          token: _tokenController.text.trim(),
          password: _passwordController.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account recovered. You can now sign in.'),
        ),
      );
      context.go('/sign-in');
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
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
                'Account recovery',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lost your authenticator? This recovery is for active accounts only. Contact support about deactivation; deleted accounts cannot be restored.',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Step content
              Expanded(child: _buildStepContent(theme)),

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

              const SizedBox(height: 24),

              // Back to sign in
              Center(
                child: TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: Text(
                    'Back to sign in',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_step) {
      case AccountRecoveryStep.selectMethod:
        return _buildMethodSelection(theme);
      case AccountRecoveryStep.emailForm:
        return _buildEmailForm(theme);
      case AccountRecoveryStep.phoneForm:
        return _buildPhoneForm(theme);
      case AccountRecoveryStep.waitForEmail:
        return _buildWaitForEmail(theme);
      case AccountRecoveryStep.waitForPhone:
        return _buildWaitForPhone(theme);
      case AccountRecoveryStep.verifyToken:
        return _buildVerifyToken(theme);
    }
  }

  Widget _buildMethodSelection(ThemeData theme) {
    return Column(
      children: [
        _RecoveryMethodOption(
          icon: Icons.email_outlined,
          title: 'Email recovery',
          subtitle: 'Receive a recovery link via email',
          onTap: () {
            // Show email form
            setState(() => _step = AccountRecoveryStep.emailForm);
          },
        ),
        const SizedBox(height: 12),
        _RecoveryMethodOption(
          icon: Icons.sms_outlined,
          title: 'SMS recovery',
          subtitle: 'Receive a recovery code via SMS',
          onTap: () {
            setState(() => _step = AccountRecoveryStep.phoneForm);
          },
        ),
      ],
    );
  }

  Widget _buildEmailForm(ThemeData theme) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email recovery',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address. If it exists, we\'ll send a recovery link.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _emailController,
            label: 'Email address',
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            textInputAction: TextInputAction.done,
            validator: (value) => value?.email,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _requestEmailRecovery(),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _step = AccountRecoveryStep.selectMethod),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm(ThemeData theme) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SMS recovery',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your phone number. If it exists, we\'ll send a recovery code via SMS.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _phoneController,
            label: 'Phone number',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: (value) => value?.phone,
            hintText: '+254 7XX XXX XXX',
            autofillHints: const [AutofillHints.telephoneNumber],
            onSubmitted: (_) => _requestPhoneRecovery(),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _step = AccountRecoveryStep.selectMethod),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitForEmail(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.email_outlined,
              color: theme.colorScheme.onPrimaryContainer,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your email',
            style: AppTypography.headlineSmall.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'We\'ve sent a recovery link to your email. Click the link to continue.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => _requestEmailRecovery(),
            child: const Text('Resend email'),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _step = AccountRecoveryStep.selectMethod),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitForPhone(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sms_outlined,
              color: theme.colorScheme.onPrimaryContainer,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your messages',
            style: AppTypography.headlineSmall.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'We\'ve sent a recovery code via SMS. Enter it below to continue.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => _requestPhoneRecovery(),
            child: const Text('Resend code'),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _step = AccountRecoveryStep.selectMethod),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyToken(ThemeData theme) {
    return Form(
      key: _verifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify recovery token',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the recovery token from your email or SMS, then choose a new password.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _tokenController,
            label: 'Recovery token',
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().length < 10
                ? 'Enter a valid recovery token'
                : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _passwordController,
            label: 'New password',
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
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _verifyRecovery(),
          ),
        ],
      ),
    );
  }

  String _getButtonLabel() {
    switch (_step) {
      case AccountRecoveryStep.selectMethod:
        return 'Continue';
      case AccountRecoveryStep.emailForm:
        return 'Send recovery link';
      case AccountRecoveryStep.phoneForm:
        return 'Send recovery code';
      case AccountRecoveryStep.waitForEmail:
        return 'Continue';
      case AccountRecoveryStep.waitForPhone:
        return 'Continue';
      case AccountRecoveryStep.verifyToken:
        return 'Recover account';
    }
  }

  VoidCallback? _getButtonAction() {
    switch (_step) {
      case AccountRecoveryStep.selectMethod:
        return null;
      case AccountRecoveryStep.emailForm:
        return _requestEmailRecovery;
      case AccountRecoveryStep.phoneForm:
        return _requestPhoneRecovery;
      case AccountRecoveryStep.waitForEmail:
        return () => setState(() => _step = AccountRecoveryStep.verifyToken);
      case AccountRecoveryStep.waitForPhone:
        return () => setState(() => _step = AccountRecoveryStep.verifyToken);
      case AccountRecoveryStep.verifyToken:
        return _verifyRecovery;
    }
  }
}

enum AccountRecoveryStep {
  selectMethod,
  emailForm,
  phoneForm,
  waitForEmail,
  waitForPhone,
  verifyToken,
}

class _RecoveryMethodOption extends StatelessWidget {
  const _RecoveryMethodOption({
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
