// Core constants for the application.

abstract final class AppConstants {
  static const String appName = 'GetKeja';
  static const String appTagline =
      'Find and rent homes, laundries, movers and garbage services across Kenya.';

  // Secure storage keys
  static const String accessTokenKey = 'getkeja_access_token';
  static const String refreshTokenKey = 'getkeja_refresh_token';
  static const String enrollmentTokenKey = 'getkeja_mfa_enrollment_token';
  static const String deviceIdKey = 'getkeja_device_id';
  static const String userIdKey = 'getkeja_user_id';
  static const String biometricEnabledKey = 'getkeja_biometric_enabled';
  static const String onboardingCompletedKey = 'getkeja_onboarding_completed';

  // API
  static const String apiVersion = 'v1';
  static const String authBasePath = '/api/v1/auth';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Retry
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 1);

  // MFA
  static const int totpCodeLength = 6;
  static const Duration mfaChallengeExpiry = Duration(minutes: 10);

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;

  // UI
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration snackbarDuration = Duration(seconds: 4);
  static const double defaultPadding = 24.0;
  static const double defaultBorderRadius = 16.0;
  static const double buttonHeight = 52.0;
}
