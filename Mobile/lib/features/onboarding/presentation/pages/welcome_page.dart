// Welcome page - authentication entry point.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: AppBorderRadius.xlargeRadius,
                    ),
                    child: ClipRRect(
                      borderRadius: AppBorderRadius.largeRadius,
                      child: Image.asset(
                        'assets/images/brand/brand_mark.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    style: AppTypography.headlineLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appTagline,
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  PrimaryButton(
                    label: 'Sign in',
                    onPressed: () => context.push('/sign-in'),
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'Create account',
                    onPressed: () => context.push('/register'),
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose email or phone on the next screen, or continue with Google.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _GoogleSignInButton(),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New accounts must accept our ',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _launchUrl(context, 'https://getkeja.com/terms'),
                        child: Text(
                          'Terms of Service',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _launchUrl(context, 'https://getkeja.com/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // The URL could not be handed off to an external application.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the requested page.')),
    );
  }
}

class _GoogleSignInButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return OutlinedButton.icon(
      onPressed: isLoading ? null : () => _signInWithGoogle(context, ref),
      icon: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset(
              'assets/images/brand/google_logo.png',
              width: 20,
              height: 20,
            ),
      label: Text(isLoading ? 'Signing in…' : 'Continue with Google'),
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
      await ref
          .read(authNotifierProvider.notifier)
          .handleAction(const AuthAction.loginWithGoogle());
      if (!context.mounted) return;

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
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
