// Splash screen with session restoration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../authentication/presentation/state/auth_state.dart';

String resolveUnauthenticatedStartupDestination(String? onboardingCompleted) =>
    onboardingCompleted == 'true' ? '/welcome' : '/onboarding';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    // Start session restoration
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    await authNotifier.restoreSession();

    // Wait for minimum splash duration
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // Navigate based on auth state
    final authState = ref.read(authNotifierProvider);
    _navigateBasedOnAuthState(authState);
  }

  void _navigateBasedOnAuthState(AuthState authState) {
    if (!mounted) return;

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
    } else {
      _routeUnauthenticatedUser();
    }
  }

  Future<void> _routeUnauthenticatedUser() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final onboardingCompleted = await storage.read(
        AppConstants.onboardingCompletedKey,
      );
      if (!mounted) return;
      context.go(resolveUnauthenticatedStartupDestination(onboardingCompleted));
    } on StorageException catch (error) {
      debugPrint('Unable to read onboarding preference: $error');
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: AppBorderRadius.xlargeRadius,
                      ),
                      child: Icon(
                        Icons.home_work_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 44,
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appTagline,
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    AppLoadingIndicator(
                      size: 28,
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
