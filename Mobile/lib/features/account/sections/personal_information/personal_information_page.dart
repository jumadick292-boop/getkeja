// Personal information page for managing name, email, and phone.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class PersonalInformationPage extends ConsumerStatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  ConsumerState<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState
    extends ConsumerState<PersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _emailChangePending = false;
  bool _phoneChangePending = false;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.user;
      if (user != null) {
        _firstNameController.text = user.firstName;
        _lastNameController.text = user.lastName;
        _emailController.text = user.email ?? '';
        _phoneController.text = user.phone ?? '';
        _emailVerified = user.emailVerified;
        _phoneVerified = user.phoneVerified;
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Failed to load your information. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/account/profile',
            data: {
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
            },
          );

      if (mounted) {
        setState(() {
          _successMessage = 'Profile updated successfully';
        });
        // Update auth state
        ref
            .read(authNotifierProvider.notifier)
            .handleAction(AuthAction.restoreSession());
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestEmailChange() async {
    final email = _emailController.text.trim();
    if (!email.isValidEmail) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/email/change-request',
            data: {'newEmail': email},
          );

      if (mounted) {
        setState(() {
          _emailChangePending = true;
          _pendingEmail = email;
          _successMessage =
              'Verification code sent to $email. Enter the code from your inbox.';
        });
        _showOtpDialog('email');
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmEmailChange(String token) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/email/change-confirm',
            data: {'token': token},
          );

      if (mounted) {
        setState(() {
          _emailChangePending = false;
          _pendingEmail = null;
          _emailVerified = true;
          _successMessage = 'Email updated successfully';
        });
        ref
            .read(authNotifierProvider.notifier)
            .handleAction(AuthAction.restoreSession());
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestPhoneChange() async {
    final phone = _phoneController.text.trim();
    if (!phone.isValidKenyanPhone) {
      setState(
        () => _errorMessage = 'Please enter a valid Kenyan phone number',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/phone/change-request',
            data: {'newPhone': phone},
          );

      if (mounted) {
        setState(() {
          _phoneChangePending = true;
          _successMessage =
              'Verification code sent via SMS. Please enter it to confirm.';
        });
        _showOtpDialog('phone');
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmPhoneChange(String otp) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/phone/change-confirm',
            data: {'otp': otp},
          );

      if (mounted) {
        setState(() {
          _phoneChangePending = false;
          _phoneVerified = true;
          _successMessage = 'Phone number updated successfully';
        });
        ref
            .read(authNotifierProvider.notifier)
            .handleAction(AuthAction.restoreSession());
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showOtpDialog(String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(type == 'email' ? 'Verify email' : 'Verify phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type == 'email'
                  ? 'Enter the verification code sent to your email'
                  : 'Enter the 6-digit code sent via SMS',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: type == 'email'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: InputDecoration(
                labelText: type == 'email'
                    ? 'Verification code'
                    : '6-digit code',
                hintText: '000000',
              ),
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (type == 'email') _emailChangePending = false;
                if (type == 'phone') _phoneChangePending = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              Navigator.pop(context);
              if (type == 'email') {
                _confirmEmailChange(code);
              } else {
                _confirmPhoneChange(code);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to update your information. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal information')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: _formKey,
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

                    // Name section
                    Text(
                      'Name',
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
                          AppTextField(
                            controller: _firstNameController,
                            label: 'First name',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              if (value.trim().length > 100) {
                                return 'First name is too long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _lastNameController,
                            label: 'Last name',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Last name is required';
                              }
                              if (value.trim().length > 100) {
                                return 'Last name is too long';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email section
                    Text(
                      'Email address',
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  maxLength: 254,
                                  textInputAction: TextInputAction.next,
                                  enabled: !_emailChangePending,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!value.trim().isValidEmail) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_emailChangePending)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (_emailVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: AppBorderRadius.roundRadius,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: _requestEmailChange,
                                  child: const Text('Verify'),
                                ),
                            ],
                          ),
                          if (_emailChangePending) ...[
                            const SizedBox(height: 12),
                            Text(
                              'A verification email has been sent to $_pendingEmail. Enter the code to confirm.',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _requestEmailChange,
                              child: const Text('Resend code'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Phone section
                    Text(
                      'Phone number',
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _phoneController,
                                  label: 'Phone number',
                                  hintText: '07XXXXXXXX',
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  enabled: !_phoneChangePending,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return null; // Phone is optional
                                    }
                                    if (!value.trim().isValidKenyanPhone) {
                                      return 'Enter a valid Kenyan phone number (e.g., 07XXXXXXXX)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_phoneChangePending)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (_phoneVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: AppBorderRadius.roundRadius,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: _requestPhoneChange,
                                  child: const Text('Verify'),
                                ),
                            ],
                          ),
                          if (_phoneChangePending) ...[
                            const SizedBox(height: 12),
                            Text(
                              'A verification code has been sent via SMS. Enter the code to confirm.',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _requestPhoneChange,
                              child: const Text('Resend code'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    PrimaryButton(
                      label: 'Save changes',
                      isLoading: _isSaving,
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

extension StringExtensions on String {
  bool get isValidEmail => Validators.email(this) == null;

  bool get isValidKenyanPhone {
    final cleaned = replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+254'))
      return RegExp(r'^\+254[17]\d{8}$').hasMatch(cleaned);
    if (cleaned.startsWith('254'))
      return RegExp(r'^254[17]\d{8}$').hasMatch(cleaned);
    if (cleaned.startsWith('0'))
      return RegExp(r'^0[17]\d{8}$').hasMatch(cleaned);
    return RegExp(r'^[17]\d{8}$').hasMatch(cleaned);
  }
}
