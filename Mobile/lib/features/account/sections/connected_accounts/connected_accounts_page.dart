// Connected accounts page for managing OAuth connections.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class ConnectedAccountsPage extends ConsumerStatefulWidget {
  const ConnectedAccountsPage({super.key});

  @override
  ConsumerState<ConnectedAccountsPage> createState() =>
      _ConnectedAccountsPageState();
}

class _ConnectedAccountsPageState extends ConsumerState<ConnectedAccountsPage> {
  bool _isLoading = false;
  bool _googleLinked = false;
  String? _googleEmail;
  String? _googleName;
  String? _googlePicture;
  String? _errorMessage;
  String? _successMessage;
  bool _isLinking = false;
  bool _isUnlinking = false;

  @override
  void initState() {
    super.initState();
    _loadConnectedAccounts();
  }

  Future<void> _loadConnectedAccounts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/account/connected-accounts');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        final google = payload['google'];
        if (google is Map<String, dynamic>) {
          _googleLinked = google['linked'] as bool? ?? false;
          _googleEmail = google['email'] as String?;
          _googleName = google['name'] as String?;
          _googlePicture = google['picture'] as String?;
        } else {
          _googleLinked = payload['googleLinked'] as bool? ?? false;
          _googleEmail = payload['googleEmail'] as String?;
          _googleName = payload['googleName'] as String?;
          _googlePicture = payload['googlePicture'] as String?;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkGoogle() async {
    final password = await _requestPassword();
    if (password == null) return;
    setState(() {
      _isLinking = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn.instance;
      await initializeGoogleSignIn();

      if (!googleSignIn.supportsAuthenticate()) {
        throw const ServerException(
          message: 'Google sign-in is not available on this platform.',
        );
      }

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const ServerException(
          message: 'Google did not provide an identity token.',
        );
      }

      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/google/link',
            data: {
              'idToken': idToken,
              if (password.isNotEmpty) 'password': password,
            },
          );

      if (mounted) {
        setState(() {
          _googleLinked = true;
          _googleEmail = account.email;
          _googleName = account.displayName;
          _googlePicture = account.photoUrl;
          _successMessage = 'Google account linked successfully';
        });
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
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _unlinkGoogle() async {
    final password = await _requestPassword();
    if (password == null) return;

    setState(() {
      _isUnlinking = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .delete<Map<String, dynamic>>(
            '/google/unlink',
            data: {if (password.isNotEmpty) 'password': password},
          );

      if (mounted) {
        setState(() {
          _googleLinked = false;
          _googleEmail = null;
          _googleName = null;
          _googlePicture = null;
          _successMessage = 'Google account unlinked successfully';
        });
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
      if (mounted) setState(() => _isUnlinking = false);
    }
  }

  Future<String?> _requestPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm it’s you'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password, or leave it blank if you signed in or verified with MFA recently. Google linking still requires you to choose the account explicitly. If you do not have a password and MFA is not set up, set a password under Account > Password & login first.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              autofillHints: const [AutofillHints.password],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to update connected accounts. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Connected accounts')),
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

                  Text(
                    'Third-party accounts',
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link accounts for easier sign-in and data sync.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Google account
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _googleLinked
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: AppBorderRadius.mediumRadius,
                          ),
                          child: _googleLinked && _googlePicture != null
                              ? ClipRRect(
                                  borderRadius: AppBorderRadius.mediumRadius,
                                  child: Image.network(
                                    _googlePicture!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.g_mobiledata,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.g_mobiledata,
                                  color: _googleLinked
                                      ? theme.colorScheme.onSecondaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Google',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_googleLinked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        borderRadius:
                                            AppBorderRadius.roundRadius,
                                      ),
                                      child: Text(
                                        'Linked',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius:
                                            AppBorderRadius.roundRadius,
                                      ),
                                      child: Text(
                                        'Not linked',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_googleLinked && _googleName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _googleName!,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (_googleLinked && _googleEmail != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _googleEmail!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_googleLinked)
                          OutlinedButton(
                            onPressed: _isUnlinking ? null : _unlinkGoogle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                            ),
                            child: _isUnlinking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Unlink'),
                          )
                        else
                          FilledButton.tonal(
                            onPressed: _isLinking ? null : _linkGoogle,
                            child: _isLinking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Link'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info card
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About connected accounts',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Linking your Google account allows you to sign in with Google. Your Google profile information (name, email, picture) will be used to personalize your GetKeja experience. You can unlink at any time.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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
}
