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
import '../../features/property_search/presentation/pages/nearby_properties_page.dart';
import '../../features/property_search/presentation/pages/location_sharing_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/notification_preferences_page.dart';
import '../../features/messaging/presentation/pages/conversation_page.dart';
import '../../features/home_maintenance/presentation/pages/customer_home_maintenance_jobs_page.dart';
import '../../features/home_maintenance/presentation/pages/customer_home_maintenance_job_detail_page.dart';
import '../../features/home_maintenance/presentation/pages/provider_home_maintenance_jobs_page.dart';
import '../../features/cleaning_operations/presentation/pages/customer_cleaning_jobs_page.dart';
import '../../features/cleaning_operations/presentation/pages/customer_cleaning_job_detail_page.dart';
import '../../features/cleaning_operations/presentation/pages/provider_cleaning_jobs_page.dart';
import '../../features/installation_operations/presentation/pages/customer_installation_jobs_page.dart';
import '../../features/installation_operations/presentation/pages/customer_installation_job_detail_page.dart';
import '../../features/installation_operations/presentation/pages/provider_installation_jobs_page.dart';
import '../../features/finishing_operations/presentation/pages/customer_finishing_jobs_page.dart';
import '../../features/finishing_operations/presentation/pages/customer_finishing_job_detail_page.dart';
import '../../features/finishing_operations/presentation/pages/provider_finishing_jobs_page.dart';
import '../../features/tenancies/presentation/pages/tenancies_page.dart';
import '../../features/tenancies/presentation/pages/tenancy_detail_page.dart';
import '../../features/garbage/presentation/pages/garbage_page.dart';
import '../../features/maintenance/presentation/pages/maintenance_page.dart';
import '../../features/payments/presentation/pages/deposits_page.dart';
import '../../features/payments/presentation/pages/invoice_detail_page.dart';
import '../../features/payments/presentation/pages/invoice_list_page.dart';
import '../../features/payments/presentation/pages/payment_method_selection_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/payments/presentation/pages/receipts_page.dart';
import '../../features/payments/presentation/pages/statement_page.dart';
import '../../features/movers/presentation/pages/moving_page.dart';
import '../../features/provider_platform/presentation/pages/provider_dashboard_page.dart' as unified;
import '../../features/provider_platform/presentation/pages/provider_reports_page.dart';
import '../../features/provider_platform/presentation/pages/provider_reviews_page.dart';
import '../../features/provider_platform/presentation/pages/customer_reviews_page.dart';
import '../../features/provider_platform/presentation/pages/customer_complaints_page.dart';
import '../../features/provider_platform/presentation/pages/provider_complaints_page.dart';
import '../../features/provider_platform/presentation/pages/admin_complaints_page.dart';
import '../../features/provider_platform/presentation/pages/complaint_detail_page.dart';
import '../../features/provider_platform/presentation/pages/staff_workload_page.dart';
import '../../features/provider/presentation/pages/provider_onboarding_page.dart';
import '../../features/provider/presentation/pages/provider_organizations_page.dart';
import '../../features/provider/presentation/pages/provider_services_page.dart';
import '../../features/provider/presentation/pages/provider_locations_page.dart';
import '../../features/provider/presentation/pages/provider_service_areas_page.dart';
import '../../features/provider/presentation/pages/provider_availability_page.dart';
import '../../features/laundries/presentation/pages/laundry_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_browse_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_request_form_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_requests_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_request_detail_page.dart';
import '../../features/marketplace/presentation/pages/provider_marketplace_inbox_page.dart';
import '../../features/marketplace/presentation/pages/provider_marketplace_detail_page.dart';
import '../../features/moving/presentation/pages/moving_jobs_page.dart';
import '../../features/moving/presentation/pages/moving_job_detail_page.dart';
import '../../features/moving/presentation/pages/provider_moving_jobs_page.dart';
import '../../features/moving/presentation/pages/provider_moving_job_detail_page.dart';
import '../../features/garbage/presentation/pages/garbage_jobs_page.dart';
import '../../features/garbage/presentation/pages/garbage_job_detail_page.dart';
import '../../features/garbage/presentation/pages/provider_garbage_jobs_page.dart';
import '../../features/garbage/presentation/pages/provider_garbage_job_detail_page.dart';
import '../../features/laundry/presentation/pages/laundry_orders_page.dart';
import '../../features/laundry/presentation/pages/laundry_order_detail_page.dart';
import '../../features/laundry/presentation/pages/provider_laundry_orders_page.dart';
import '../../features/laundry/presentation/pages/provider_laundry_order_detail_page.dart';
import '../../features/scheduling/presentation/pages/provider_calendar_page.dart';
import '../../features/scheduling/presentation/pages/customer_appointments_page.dart';
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
import '../../features/property_management/presentation/pages/create_enquiry_page.dart';
import '../../features/property_management/presentation/pages/create_listing_page.dart';
import '../../features/property_management/presentation/pages/create_property_page.dart';
import '../../features/property_management/presentation/pages/enquiries_page.dart';
import '../../features/property_management/presentation/pages/landlord_dashboard_page.dart';
import '../../features/property_management/presentation/pages/landlord_proposals_page.dart';
import '../../features/property_management/presentation/pages/landlord_site_visit_detail_page.dart';
import '../../features/property_management/presentation/pages/landlord_site_visits_page.dart';
import '../../features/billing/presentation/pages/landlord_billing_dashboard_page.dart';
import '../../features/billing/presentation/pages/billing_schedules_page.dart';
import '../../features/billing/presentation/pages/create_billing_schedule_page.dart';
import '../../features/billing/presentation/pages/billing_schedule_detail_page.dart';
import '../../features/billing/presentation/pages/landlord_invoices_page.dart';
import '../../features/property_management/presentation/pages/listings_page.dart';
import '../../features/property_management/presentation/pages/properties_page.dart';
import '../../features/property_management/presentation/pages/property_detail_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_home_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_search_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_listing_detail_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_saved_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_enquiries_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_visits_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_conversations_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_conversation_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_applications_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_proposals_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_journey_page.dart';
import '../../features/rental_applications/presentation/application_detail_page.dart';
import '../../features/rental_applications/presentation/applications_inbox_page.dart';
import '../../features/rental_applications/presentation/application_review_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_saved_searches_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_preferences_page.dart';
import '../../features/house_seeker/presentation/pages/house_seeker_compare_page.dart';

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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SignInPage(
            initialEmail: extra?['email'] as String?,
            initialPhone: extra?['phone'] as String?,
          );
        },
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
        path: '/register/google',
        name: 'register-google',
        builder: (context, state) =>
            const RegisterPage(registrationMethod: RegistrationMethod.google),
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
        path: '/properties/nearby',
        name: 'nearby-properties',
        builder: (context, state) =>
            NearbyPropertiesPage(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '/location-sharing',
        name: 'location-sharing',
        builder: (context, state) => const LocationSharingPage(),
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
        path: '/messaging/conversations/:conversationId',
        name: 'messaging-conversation',
        builder: (context, state) => ConversationPage(
          conversationId: state.pathParameters['conversationId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/notifications/preferences',
        name: 'notification-preferences',
        builder: (context, state) => const NotificationPreferencesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/home-maintenance/jobs',
        name: 'home-maintenance-jobs',
        builder: (context, state) => const CustomerHomeMaintenanceJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/home-maintenance/jobs/:jobId',
        name: 'home-maintenance-job-detail',
        builder: (context, state) => CustomerHomeMaintenanceJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/home-maintenance/provider/jobs',
        name: 'provider-home-maintenance-jobs',
        builder: (context, state) => const ProviderHomeMaintenanceJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/home-maintenance/provider/jobs/:jobId',
        name: 'provider-home-maintenance-job-detail',
        builder: (context, state) => ProviderHomeMaintenanceJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/cleaning-operations/jobs',
        name: 'cleaning-operations-jobs',
        builder: (context, state) => const CustomerCleaningJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/cleaning-operations/jobs/:jobId',
        name: 'cleaning-operations-job-detail',
        builder: (context, state) => CustomerCleaningJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/cleaning-operations/provider/jobs',
        name: 'provider-cleaning-operations-jobs',
        builder: (context, state) => const ProviderCleaningJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/cleaning-operations/provider/jobs/:jobId',
        name: 'provider-cleaning-operations-job-detail',
        builder: (context, state) => ProviderCleaningJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/installation-operations/jobs',
        name: 'installation-operations-jobs',
        builder: (context, state) => const CustomerInstallationJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/installation-operations/jobs/:jobId',
        name: 'installation-operations-job-detail',
        builder: (context, state) => CustomerInstallationJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/installation-operations/provider/jobs',
        name: 'provider-installation-operations-jobs',
        builder: (context, state) => const ProviderInstallationJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/installation-operations/provider/jobs/:jobId',
        name: 'provider-installation-operations-job-detail',
        builder: (context, state) => ProviderInstallationJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/finishing-operations/jobs',
        name: 'finishing-operations-jobs',
        builder: (context, state) => const CustomerFinishingJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/finishing-operations/jobs/:jobId',
        name: 'finishing-operations-job-detail',
        builder: (context, state) => CustomerFinishingJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/finishing-operations/provider/jobs',
        name: 'provider-finishing-operations-jobs',
        builder: (context, state) => const ProviderFinishingJobsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/finishing-operations/provider/jobs/:jobId',
        name: 'provider-finishing-operations-job-detail',
        builder: (context, state) => ProviderFinishingJobDetailPage(
          jobId: state.pathParameters['jobId']!,
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
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
      // Landlord / property management routes
      GoRoute(
        path: '/landlord',
        name: 'landlord-dashboard',
        builder: (context, state) => const LandlordDashboardPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/properties',
        name: 'landlord-properties',
        builder: (context, state) => const PropertiesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/properties/new',
        name: 'landlord-property-create',
        builder: (context, state) => const CreatePropertyPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/properties/:propertyId',
        name: 'landlord-property-detail',
        builder: (context, state) =>
            PropertyDetailPage(propertyId: state.pathParameters['propertyId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/listings',
        name: 'landlord-listings',
        builder: (context, state) => const ListingsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/listings/new',
        name: 'landlord-listing-create',
        builder: (context, state) => const CreateListingPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/enquiries',
        name: 'landlord-enquiries',
        builder: (context, state) => const EnquiriesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/enquiries/new',
        name: 'landlord-enquiry-create',
        builder: (context, state) => const CreateEnquiryPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/proposals',
        name: 'landlord-proposals',
        builder: (context, state) => const LandlordProposalsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/site-visits',
        name: 'landlord-site-visits',
        builder: (context, state) => const LandlordSiteVisitsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/site-visits/:visitId',
        name: 'landlord-site-visit-detail',
        builder: (context, state) => LandlordSiteVisitDetailPage(
          visitId: state.pathParameters['visitId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/site-visits/:visitId/reschedule',
        name: 'landlord-site-visit-reschedule',
        builder: (context, state) => const LandlordSiteVisitDetailPage(
          visitId:
              '', // Placeholder; reschedule form handled via detail page actions
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // Recurring billing routes (Task 14.1)
      GoRoute(
        path: '/landlord/billing',
        name: 'landlord-billing',
        builder: (context, state) => const LandlordBillingDashboardPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/billing/schedules',
        name: 'landlord-billing-schedules',
        builder: (context, state) => const BillingSchedulesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/billing/schedules/new',
        name: 'landlord-billing-schedule-create',
        builder: (context, state) => const CreateBillingSchedulePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/billing/schedules/:scheduleId',
        name: 'landlord-billing-schedule-detail',
        builder: (context, state) => BillingScheduleDetailPage(
          scheduleId: state.pathParameters['scheduleId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/billing/invoices',
        name: 'landlord-billing-invoices',
        builder: (context, state) => const LandlordInvoicesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // House seeker routes
      GoRoute(
        path: '/house-seeker',
        name: 'house-seeker-home',
        builder: (context, state) => const HouseSeekerHomePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/search',
        name: 'house-seeker-search',
        builder: (context, state) => const HouseSeekerSearchPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/listings/:listingId',
        name: 'house-seeker-listing-detail',
        builder: (context, state) => HouseSeekerListingDetailPage(
          listingId: state.pathParameters['listingId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/saved',
        name: 'house-seeker-saved',
        builder: (context, state) => const HouseSeekerSavedPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/enquiries',
        name: 'house-seeker-enquiries',
        builder: (context, state) => const HouseSeekerEnquiriesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/visits',
        name: 'house-seeker-visits',
        builder: (context, state) => const HouseSeekerVisitsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/conversations',
        name: 'house-seeker-conversations',
        builder: (context, state) => const HouseSeekerConversationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/conversations/:conversationId',
        name: 'house-seeker-conversation',
        builder: (context, state) => HouseSeekerConversationPage(
          conversationId: state.pathParameters['conversationId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/applications',
        name: 'house-seeker-applications',
        builder: (context, state) => const HouseSeekerApplicationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/proposals',
        name: 'house-seeker-proposals',
        builder: (context, state) => const HouseSeekerProposalsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/applications/:applicationId',
        name: 'rental-application-detail',
        builder: (context, state) => RentalApplicationDetailPage(
          applicationId: state.pathParameters['applicationId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/applications',
        name: 'rental-applications-inbox',
        builder: (context, state) => const RentalApplicationsInboxPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/landlord/applications/:applicationId',
        name: 'rental-application-review',
        builder: (context, state) => RentalApplicationReviewPage(
          applicationId: state.pathParameters['applicationId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/journey',
        name: 'house-seeker-journey',
        builder: (context, state) => const HouseSeekerJourneyPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/saved-searches',
        name: 'house-seeker-saved-searches',
        builder: (context, state) => const HouseSeekerSavedSearchesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/preferences',
        name: 'house-seeker-preferences',
        builder: (context, state) => const HouseSeekerPreferencesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/house-seeker/compare',
        name: 'house-seeker-compare',
        builder: (context, state) => const HouseSeekerComparePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // Tenant routes
      GoRoute(
        path: '/tenant/dashboard',
        name: 'tenant-dashboard',
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
        path: '/tenant/tenancies',
        name: 'tenant-tenancies',
        builder: (context, state) => const TenanciesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/tenancies/:tenancyId',
        name: 'tenant-tenancy-detail',
        builder: (context, state) => TenancyDetailPage(
          tenancyId: state.pathParameters['tenancyId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/garbage',
        name: 'tenant-garbage',
        builder: (context, state) => const GarbagePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/movers',
        name: 'tenant-movers',
        builder: (context, state) => const MovingPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/laundries',
        name: 'tenant-laundries',
        builder: (context, state) => const LaundryPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/dashboard',
        name: 'provider-dashboard',
        builder: (context, state) => const unified.ProviderDashboardPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/reports',
        name: 'provider-reports',
        builder: (context, state) => const ProviderReportsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/reviews',
        name: 'provider-reviews',
        builder: (context, state) => const ProviderReviewsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/complaints',
        name: 'provider-complaints',
        builder: (context, state) => const ProviderComplaintsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/staff-workload',
        name: 'provider-staff-workload',
        builder: (context, state) => const StaffWorkloadPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/reviews/mine',
        name: 'my-reviews',
        builder: (context, state) => CustomerReviewsPage(
          domain: state.uri.queryParameters['domain'],
          resourceId: state.uri.queryParameters['resourceId'],
        ),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/complaints/mine',
        name: 'my-complaints',
        builder: (context, state) => const CustomerComplaintsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/complaints/admin',
        name: 'admin-complaints',
        builder: (context, state) => const AdminComplaintsPage(),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/complaints/:complaintId',
        name: 'complaint-detail',
        builder: (context, state) => ComplaintDetailPage(complaintId: state.pathParameters['complaintId']!),
        redirect: (context, state) {
          if (!ref.read(authNotifierProvider).isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/onboarding',
        name: 'provider-onboarding',
        builder: (context, state) => const ProviderOnboardingPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/organizations',
        name: 'provider-organizations',
        builder: (context, state) => const ProviderOrganizationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/services',
        name: 'provider-services',
        builder: (context, state) => const ProviderServicesPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/locations',
        name: 'provider-locations',
        builder: (context, state) => const ProviderLocationsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/service-areas',
        name: 'provider-service-areas',
        builder: (context, state) => ProviderServiceAreasPage(
          profileId: state.uri.queryParameters['profileId'],
          offeringId: state.uri.queryParameters['offeringId'],
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/provider/availability',
        name: 'provider-availability',
        builder: (context, state) => ProviderAvailabilityPage(
          profileId: state.uri.queryParameters['profileId'],
          offeringId: state.uri.queryParameters['offeringId'],
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/maintenance',
        name: 'tenant-maintenance',
        builder: (context, state) => const MaintenancePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      // Marketplace (Task 13.5) — customer requests + provider quotations.
      GoRoute(
        path: '/marketplace',
        name: 'marketplace-browse',
        builder: (context, state) => const MarketplaceBrowsePage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/marketplace/request/new',
        name: 'marketplace-request-new',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return MarketplaceRequestFormPage(
            categoryId: extra['categoryId'] as String? ?? '',
            categoryName: extra['categoryName'] as String? ?? 'New request',
            domain: extra['domain'] as String?,
          );
        },
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/marketplace/requests',
        name: 'marketplace-requests',
        builder: (context, state) => const MarketplaceRequestsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/marketplace/requests/:requestId',
        name: 'marketplace-request-detail',
        builder: (context, state) => MarketplaceRequestDetailPage(
          requestId: state.pathParameters['requestId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/marketplace',
        name: 'provider-marketplace-inbox',
        builder: (context, state) => const ProviderMarketplaceInboxPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/marketplace/requests/:requestId',
        name: 'provider-marketplace-detail',
        builder: (context, state) => ProviderMarketplaceDetailPage(
          requestId: state.pathParameters['requestId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      // Moving operations (Task 13.6).
      GoRoute(
        path: '/moving/jobs',
        name: 'moving-jobs',
        builder: (context, state) => const MovingJobsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/moving/jobs/:jobId',
        name: 'moving-job-detail',
        builder: (context, state) => MovingJobDetailPage(jobId: state.pathParameters['jobId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/moving/jobs',
        name: 'provider-moving-jobs',
        builder: (context, state) => const ProviderMovingJobsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/provider/moving/jobs/:jobId',
        name: 'provider-moving-job-detail',
        builder: (context, state) => ProviderMovingJobDetailPage(jobId: state.pathParameters['jobId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      // Garbage collection operations (Task 13.7).
      GoRoute(
        path: '/garbage/jobs',
        name: 'garbage-jobs',
        builder: (context, state) => const GarbageJobsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/garbage/jobs/:jobId',
        name: 'garbage-job-detail',
        builder: (context, state) => GarbageJobDetailPage(jobId: state.pathParameters['jobId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/garbage/provider/jobs',
        name: 'provider-garbage-jobs',
        builder: (context, state) => const ProviderGarbageJobsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/garbage/provider/jobs/:jobId',
        name: 'provider-garbage-job-detail',
        builder: (context, state) => ProviderGarbageJobDetailPage(jobId: state.pathParameters['jobId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      // Laundry operations (Task 13.8).
      GoRoute(
        path: '/laundry/orders',
        name: 'laundry-orders',
        builder: (context, state) => const LaundryOrdersPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/laundry/orders/:orderId',
        name: 'laundry-order-detail',
        builder: (context, state) => LaundryOrderDetailPage(orderId: state.pathParameters['orderId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/laundry/provider/orders',
        name: 'provider-laundry-orders',
        builder: (context, state) => const ProviderLaundryOrdersPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/laundry/provider/orders/:orderId',
        name: 'provider-laundry-order-detail',
        builder: (context, state) => ProviderLaundryOrderDetailPage(orderId: state.pathParameters['orderId']!),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      // Unified scheduling (Task 13.9).
      GoRoute(
        path: '/scheduling/calendar',
        name: 'scheduling-calendar',
        builder: (context, state) => const ProviderCalendarPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      GoRoute(
        path: '/scheduling/appointments',
        name: 'scheduling-appointments',
        builder: (context, state) => const CustomerAppointmentsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) return '/sign-in';
          return null;
        },
      ),
      // Payment routes
      GoRoute(
        path: '/tenant/payments',
        name: 'tenant-payments',
        builder: (context, state) => const PaymentsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/invoices',
        name: 'tenant-invoices',
        builder: (context, state) => const InvoiceListPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/invoices/:invoiceId',
        name: 'tenant-invoice-detail',
        builder: (context, state) => InvoiceDetailPage(
          invoiceId: state.pathParameters['invoiceId']!,
        ),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/methods',
        name: 'tenant-payment-methods',
        builder: (context, state) => const PaymentMethodSelectionPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/receipts',
        name: 'tenant-receipts',
        builder: (context, state) => const ReceiptsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/statement',
        name: 'tenant-statement',
        builder: (context, state) => const StatementPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/payments/deposits',
        name: 'tenant-deposits',
        builder: (context, state) => const DepositsPage(),
        redirect: (context, state) {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            return '/sign-in';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/tenant/notifications',
        name: 'tenant-notifications',
        builder: (context, state) => const NotificationsPage(),
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
        '/register/google',
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
        '/properties/nearby',
        '/location-sharing',
        '/profile',
        '/devices',
        '/sessions',
        '/mfa/manage',
        '/mfa/enroll/add',
        '/notifications',
        '/account',
        '/organisations',
        '/landlord',
        '/house-seeker',
        '/tenant',
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
