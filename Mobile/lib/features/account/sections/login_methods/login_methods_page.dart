// Login methods page for managing password and login methods.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class LoginMethodsPage extends ConsumerStatefulWidget {
  const LoginMethodsPage({super.key});

  @override
  ConsumerState<LoginMethodsPage> createState() => _LoginMethodsPageState();
}

class _LoginMethodsPageState extends ConsumerState<LoginMethodsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isChangingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _successMessage;

  bool _hasEmailLogin = false;
  bool _hasEmailAddress = false;
  bool _emailVerified = false;
  bool _hasPhoneLogin = false;
  bool _hasPhoneNumber = false;
  bool _phoneVerified = false;
  bool _hasPassword = false;
  bool _googleLinked = false;

  @override
  void initState() {
    super.initState();
    _loadLoginMethods();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadLoginMethods() async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.user;
      if (user != null) {
        _hasEmailAddress = user.email != null && user.email!.isNotEmpty;
        _emailVerified = user.emailVerified;
        _hasEmailLogin = _hasEmailAddress && _emailVerified;
        _hasPhoneNumber = user.phone != null && user.phone!.isNotEmpty;
        _phoneVerified = user.phoneVerified;
        _hasPhoneLogin = _hasPhoneNumber && _phoneVerified;
        final response = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>('/account/connected-accounts');
        final payload = response.data?['data'];
        if (payload is Map<String, dynamic>) {
          _hasPassword = payload['hasPassword'] as bool? ?? false;
          final loginMethods = payload['loginMethods'];
          if (loginMethods is List) {
            final methods = loginMethods.whereType<Map<String, dynamic>>();
            final emailMethods = methods
                .where((method) => method['provider'] == 'email')
                .toList();
            _hasEmailAddress = emailMethods.isNotEmpty || _hasEmailAddress;
            _emailVerified = emailMethods.any(
              (method) => method['verified'] == true,
            );
            _hasEmailLogin = emailMethods.any(
              (method) =>
                  method['verified'] == true && method['hasPassword'] == true,
            );
            final phoneMethods = methods
                .where((method) => method['provider'] == 'phone')
                .toList();
            _hasPhoneNumber = phoneMethods.isNotEmpty || _hasPhoneNumber;
            _phoneVerified = phoneMethods.any(
              (method) => method['verified'] == true,
            );
            _hasPhoneLogin = phoneMethods.any(
              (method) =>
                  method['verified'] == true && method['hasPassword'] == true,
            );
          }
          final google = payload['google'];
          _googleLinked =
              google is Map<String, dynamic> && google['linked'] == true;
        }
      }
    } on DioException catch (error) {
      if (mounted) setState(() => _errorMessage = _errorMessageFrom(error));
    } on AppException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load login methods.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final isSettingPassword = !_hasPassword;

    setState(() {
      _isChangingPassword = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            isSettingPassword ? '/set-password' : '/account/password/change',
            data: isSettingPassword
                ? {'password': _newPasswordController.text}
                : {
                    'currentPassword': _currentPasswordController.text,
                    'newPassword': _newPasswordController.text,
                  },
          );

      if (mounted) {
        setState(() {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          if (isSettingPassword) {
            _hasPassword = true;
            _successMessage = 'Password set for your available login methods.';
          }
        });
        if (isSettingPassword) {
          await _loadLoginMethods();
        } else {
          await ref
              .read(authNotifierProvider.notifier)
              .handleAction(const AuthAction.logoutAll());
          if (mounted) context.go('/sign-in');
        }
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
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to change password. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Password & login')),
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

                  // Current login methods
                  Text(
                    'Login methods',
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
                        _buildLoginMethodRow(
                          context,
                          icon: Icons.email_outlined,
                          title: 'Email & password',
                          subtitle: _hasEmailLogin
                              ? 'Email address with password'
                              : _hasEmailAddress
                              ? _emailVerified
                                    ? 'Set a password to enable email sign-in'
                                    : 'Verify your email to enable sign-in'
                              : 'Add an email to enable sign-in',
                          status: _hasEmailLogin ? 'Active' : 'Inactive',
                          isActive: _hasEmailLogin,
                          onTap: _manageContactDetails,
                        ),
                        const Divider(height: 24),
                        _buildLoginMethodRow(
                          context,
                          icon: Icons.phone_outlined,
                          title: 'Phone & password',
                          subtitle: _hasPhoneLogin
                              ? 'Phone number with password'
                              : _hasPhoneNumber
                              ? _phoneVerified
                                    ? 'Set a password to enable phone sign-in'
                                    : 'Verify your number to enable sign-in'
                              : 'Add and verify a number to enable sign-in',
                          status: _hasPhoneLogin ? 'Active' : 'Inactive',
                          isActive: _hasPhoneLogin,
                          onTap: _manageContactDetails,
                        ),
                        const Divider(height: 24),
                        _buildLoginMethodRow(
                          context,
                          icon: Icons.g_mobiledata,
                          title: 'Google account',
                          subtitle: _googleLinked
                              ? 'Linked - sign in with Google'
                              : 'Not linked',
                          status: _googleLinked ? 'Linked' : 'Not linked',
                          isActive: _googleLinked,
                          onTap: _manageGoogleAccount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password change section
                  Text(
                    _hasPassword ? 'Change password' : 'Set a password',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasPassword
                        ? 'Your password must be at least 8 characters long.'
                        : 'Set a password to enable email and phone password sign-in. For security, setting one requires a recent sign-in or MFA verification; if prompted, sign in again and retry.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_hasPassword) ...[
                            AppTextField(
                              controller: _currentPasswordController,
                              label: 'Current password',
                              obscureText: _obscureCurrent,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrent
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                ),
                                tooltip: _obscureCurrent
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Current password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          AppTextField(
                            controller: _newPasswordController,
                            label: _hasPassword ? 'New password' : 'Password',
                            obscureText: _obscureNew,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                              tooltip: _obscureNew
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'New password is required';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (value.length > 72) {
                                return 'Password is too long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm new password',
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _changePassword(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              tooltip: _obscureConfirm
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: _hasPassword
                                ? 'Change password'
                                : 'Set password',
                            isLoading: _isChangingPassword,
                            onPressed: _changePassword,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // MFA section
                  Text(
                    'Two-factor authentication',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an extra layer of security to your account.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            Icons.shield_outlined,
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
                                'Two-factor authentication',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage authenticator apps, SMS codes, and backup codes',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => context.push('/mfa/manage'),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildLoginMethodRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.mediumRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppBorderRadius.mediumRadius,
              ),
              child: Icon(
                icon,
                color: isActive
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppBorderRadius.roundRadius,
              ),
              child: Text(
                status,
                style: AppTypography.labelSmall.copyWith(
                  color: isActive
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _manageContactDetails() async {
    await context.push('/account/personal-information');
    if (mounted) await _loadLoginMethods();
  }

  Future<void> _manageGoogleAccount() async {
    await context.push('/account/connected-accounts');
    if (mounted) await _loadLoginMethods();
  }
}
