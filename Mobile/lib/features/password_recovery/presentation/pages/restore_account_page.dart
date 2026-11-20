import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/design_widgets.dart';

class RestoreAccountPage extends ConsumerStatefulWidget {
  const RestoreAccountPage({this.initialToken, super.key});

  final String? initialToken;

  @override
  ConsumerState<RestoreAccountPage> createState() => _RestoreAccountPageState();
}

class _RestoreAccountPageState extends ConsumerState<RestoreAccountPage> {
  final _contactController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _usePhone = false;
  bool _hasRequestedCode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      _tokenController.text = token;
      _hasRequestedCode = true;
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final contact = _contactController.text.trim();
    final validation = _usePhone
        ? Validators.phone(contact)
        : Validators.email(contact);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/restore/${_usePhone ? 'phone' : 'email'}/request',
            data: {_usePhone ? 'phone' : 'email': contact},
          );
      if (!mounted) return;
      setState(() => _hasRequestedCode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usePhone
                ? 'If this is a verified contact for an eligible account, a code has been sent.'
                : 'If this is a verified contact for an eligible account, instructions have been sent.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _messageFrom(error));
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmRestore() async {
    final token = _tokenController.text.trim();
    if (token.length < 32 || token.length > 256) {
      setState(
        () => _error = 'Enter the complete code from your email or SMS.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/restore/confirm',
            data: {'token': token},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account restored. Sign in to continue.')),
      );
      context.go('/sign-in');
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _messageFrom(error));
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to restore this account right now. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              const SizedBox(height: 16),
              Text(
                'Restore your account',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Verify an email address or phone number already linked to your account. You can reactivate an account you paused, or restore a deleted account within 30 days.',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Suspended or admin-deactivated accounts need support review at support@getkeja.com. After 30 days, personal account data is permanently purged.',
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (!_hasRequestedCode) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Email')),
                    ButtonSegment(value: true, label: Text('Phone')),
                  ],
                  selected: {_usePhone},
                  onSelectionChanged: _isLoading
                      ? null
                      : (selection) => setState(() {
                          _usePhone = selection.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _contactController,
                  label: _usePhone ? 'Phone number' : 'Email address',
                  hintText: _usePhone ? '+254 7XX XXX XXX' : null,
                  keyboardType: _usePhone
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  maxLength: _usePhone ? 16 : 254,
                  validator: (_) => null,
                  autofillHints: [
                    _usePhone
                        ? AutofillHints.telephoneNumber
                        : AutofillHints.email,
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _usePhone ? 'Send SMS code' : 'Send email link',
                  isLoading: _isLoading,
                  onPressed: _requestCode,
                ),
              ] else ...[
                Text(
                  'Enter the restoration code we sent. Codes expire after one hour.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _tokenController,
                  label: 'Restoration code',
                  keyboardType: TextInputType.text,
                  maxLength: 256,
                  validator: (_) => null,
                  autofillHints: const [AutofillHints.oneTimeCode],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Restore account',
                  isLoading: _isLoading,
                  onPressed: _confirmRestore,
                ),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _hasRequestedCode = false;
                            _tokenController.clear();
                            _error = null;
                          }),
                    child: const Text('Use a different contact'),
                  ),
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                AppNotice(message: error, type: NoticeType.error),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Back to sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
