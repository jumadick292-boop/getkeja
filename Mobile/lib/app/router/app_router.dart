// Application router using GoRouter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/services_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/registration/presentation/pages/register_page.dart';
import '../../features/authentication/presentation/pages/sign_in_page.dart';
import '../../features/password_recovery/presentation/pages/forgot_password_page.dart';
import '../../features/password_recovery/presentation/pages/reset_password_page.dart';
import '../../features/password_recovery/presentation/pages/restore_account_page.dart';
import '../../features/verification/presentation/pages/email_verification_page.dart';
import '../../features/verification/presentation/pages/phone_verification_page.dart';
import '../../features/mfa/presentation/pages/mfa_enrollment_page.dart';
import '../../features/mfa/presentation/pages/mfa_challenge_page.dart';
import '../../features/mfa/presentation/pages/mfa_management_page.dart';
import '../../features/account_recovery/presentation/pages/account_recovery_page.dart';
import '../../features/authentication/presentation/state/auth_state.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_management_page.dart';
import '../../features/profile/presentation/pages/location_picker_page.dart';
import '../../features/organizations/presentation/pages/organization_profile_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/devices/presentation/pages/sessions_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/account/presentation/pages/account_overview_page.dart';
import '../../features/account/sections/personal_information/personal_information_page.dart';
import '../../features/account/sections/login_methods/login_methods_page.dart';
import '../../features/account/sections/connected_accounts/connected_accounts_page.dart';
import '../../features/account/sections/security_activity/security_activity_page.dart';
import '../../features/account/sections/privacy/privacy_page.dart';
import '../../features/account/sections/preferences/preferences_page.dart';
import '../../features/account/sections/account_status/account_status_page.dart';
import '../../features/account/sections/organization_access/organization_access_page.dart';
import '../../features/organizations/presentation/pages/create_organisation_page.dart';
import '../../features/organizations/presentation/pages/organisation_detail_page.dart';
import '../../features/organizations/presentation/pages/organisations_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'services-onboarding',
        builder: (context, state) => const ServicesOnboardingPage(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/register/email',
        name: 'register-email',
        builder: (context, state) =>
            const RegisterPage(registrationMethod: RegistrationMethod.email),
      ),
      GoRoute(
        path: '/register/phone',
        name: 'register-phone',
        builder: (context, state) =>
            const RegisterPage(registrationMethod: RegistrationMethod.phone),
      ),
      GoRoute(
        path: '/register/phone-otp',
        name: 'register-phone-otp',
        builder: (context, state) =>
            const RegisterPage(registrationMethod: RegistrationMethod.phoneOtp),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordPage(initialToken: token);
        },
      ),
      GoRoute(
        path: '/restore-account',
        name: 'restore-account',
        builder: (context, state) => RestoreAccountPage(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return EmailVerificationPage(
            email:
                extra?['email'] as String? ??
                state.uri.queryParameters['email'],
            otpLogin: extra?['otpLogin'] == true,
            deliveryFailed: extra?['deliveryFailed'] == true,
            initialToken: state.uri.queryParameters['token'],
          );
        },
      ),
      GoRoute(
        path: '/verify-phone',
        name: 'verify-phone',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PhoneVerificationPage(
            phone: extra?['phone'] as String?,
            otpLogin: extra?['otpLogin'] == true,
          );
        },
      ),
      GoRoute(
        path: '/mfa/enroll',
        name: 'mfa-enrollment',
        builder: (context, state) => const MfaEnrollmentPage(),
      ),
      GoRoute(
        path: '/mfa/enroll/add',
        name: 'mfa-additional-enrollment',
        builder: (context, state) => MfaEnrollmentPage(
          additionalMethod: true,
          methodType: state.uri.queryParameters['method'] ?? 'totp',
        ),
      ),
      GoRoute(
        path: '/mfa/challenge',
        name: 'mfa-challenge',
        builder: (context, state) {
          final challengeId = state.uri.queryParameters['challengeId'];
          final methods =
              state.uri.queryParameters['methods']?.split(',') ?? [];
          return MfaChallengePage(
            challengeId: challengeId ?? '',
            availableMethods: methods,
          );
        },
      ),
      GoRoute(
        path: '/mfa/manage',
        name: 'mfa-management',
        builder: (context, state) => const MfaManagementPage(),
      ),
      GoRoute(
        path: '/account-recovery',
        name: 'account-recovery',
        builder: (context, state) => AccountRecoveryPage(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      // Authenticated routes
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/profile/manage',
        name: 'profile-manage',
        builder: (context, state) => const ProfileManagementPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/profile/personal/edit',
        name: 'profile-personal-edit',
        builder: (context, state) => const PersonalProfileEditorPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/profile/manage/edit',
        name: 'profile-edit',
        builder: (context, state) {
          final extra = state.extra as Map<String, Object?>? ?? const {};
          final profile = extra['profile'];
          return ProfileEditorPage(
            category: extra['category'] as String?,
            profile: profile is Map<String, Object?> ? profile : null,
          );
        },
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/profile/location',
        name: 'profile-location',
        builder: (context, state) {
          final extra = state.extra as Map<String, Object?>? ?? const {};
          final location = extra['location'];
          return LocationPickerPage(
            locationType:
                extra['locationType'] as String? ?? 'personal_residential',
            profileId: extra['profileId'] as String?,
            organizationId: extra['organizationId'] as String?,
            location: location is Map<String, Object?> ? location : null,
          );
        },
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/devices',
        name: 'devices',
        builder: (context, state) => const DevicesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        builder: (context, state) => const SessionsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // Account routes
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (context, state) => const AccountOverviewPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/personal-information',
        name: 'account-personal-information',
        builder: (context, state) => const PersonalInformationPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/login-methods',
        name: 'account-login-methods',
        builder: (context, state) => const LoginMethodsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/connected-accounts',
        name: 'account-connected-accounts',
        builder: (context, state) => const ConnectedAccountsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/security-activity',
        name: 'account-security-activity',
        builder: (context, state) => const SecurityActivityPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/privacy',
        name: 'account-privacy',
        builder: (context, state) => const PrivacyDataPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/preferences',
        name: 'account-preferences',
        builder: (context, state) => const AccountPreferencesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/status',
        name: 'account-status',
        builder: (context, state) => const AccountStatusPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/account/organization-access',
        name: 'account-organization-access',
        builder: (context, state) => const OrganizationAccessPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // Organisations routes
      GoRoute(
        path: '/organisations',
        name: 'organisations',
        builder: (context, state) => const OrganisationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/organisations/:organisationId',
        name: 'organisation-detail',
        builder: (context, state) {
          final organisationId = state.pathParameters['organisationId']!;
          return OrganisationDetailPage(organisationId: organisationId);
        },
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/organisations/:organisationId/profile',
        name: 'organisation-profile',
        builder: (context, state) => OrganizationProfilePage(
          organizationId: state.pathParameters['organisationId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/organisations/create',
        name: 'organisation-create',
        builder: (context, state) => const CreateOrganisationPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthRoute = [
        '/sign-in',
        '/register',
        '/register/email',
        '/register/phone',
        '/register/phone-otp',
        '/forgot-password',
        '/reset-password',
        '/verify-email',
        '/verify-phone',
        '/mfa/enroll',
        '/mfa/challenge',
        '/account-recovery',
      ].contains(state.matchedLocation);

      final isSplashOrWelcome =
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/welcome';

      // Allow splash and welcome always
      if (isSplashOrWelcome) return null;

      // If authenticated and trying to access auth routes, redirect to dashboard
      if (authState.isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      // If not authenticated and trying to access protected routes, redirect to sign-in
      final isProtectedRoute = [
        '/dashboard',
        '/profile',
        '/devices',
        '/sessions',
        '/mfa/manage',
        '/mfa/enroll/add',
        '/notifications',
        '/account',
        '/organisations',
      ].any((route) => state.matchedLocation.startsWith(route));

      if (!authState.isAuthenticated && isProtectedRoute) {
        return '/sign-in';
      }

      // Handle MFA flow redirects
      if (authState.isMfaRequired) {
        if (state.matchedLocation != '/mfa/challenge') {
          final challengeId = (authState as dynamic).challengeId as String?;
          final methods =
              (authState as dynamic).availableMethods as List<String>?;
          return '/mfa/challenge?challengeId=$challengeId&methods=${methods?.join(',')}';
        }
      }

      if (authState.isMfaEnrollmentRequired) {
        if (state.matchedLocation != '/mfa/enroll') {
          return '/mfa/enroll';
        }
      }

      if (authState.isVerificationRequired) {
        final verificationType =
            (authState as dynamic).verificationType as String?;
        if (verificationType == 'phone' &&
            state.matchedLocation != '/verify-phone') {
          return '/verify-phone';
        }
        if (verificationType == 'email' &&
            state.matchedLocation != '/verify-email') {
          return '/verify-email';
        }
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/welcome'),
              child: const Text('Go to Welcome'),
            ),
          ],
        ),
      ),
    ),
  );
});
