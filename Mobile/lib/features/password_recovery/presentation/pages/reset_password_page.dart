// Reset password page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({this.initialToken, super.key});

  final String? initialToken;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenController.text = widget.initialToken!;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || ref.read(authNotifierProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.handleAction(
        AuthAction.resetPassword(
          token: _tokenController.text.trim(),
          password: _passwordController.text,
        ),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can now sign in.')),
      );
      context.go('/sign-in');
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  'Choose a new password',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the reset token from your email and choose a new password.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Token field
                AppTextField(
                  controller: _tokenController,
                  label: 'Reset token',
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  maxLength: 256,
                  validator: (value) {
                    final token = value?.trim() ?? '';
                    if (token.length < 32 || token.length > 256) {
                      return 'Enter the complete reset token from your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New password
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

                // Confirm password
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
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),

                // Error message
                if (authState.errorMessage case final error?) ...[
                  AppNotice(message: error, type: NoticeType.error),
                  const SizedBox(height: 16),
                ],

                // Submit button
                PrimaryButton(
                  label: 'Update password',
                  isLoading: authState.isLoading || _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
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

                // Help text
                Text(
                  'Your password must be at least 8 characters long.',
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
