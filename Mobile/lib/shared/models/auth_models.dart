// Authentication domain models matching backend API.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    String? email,
    required String firstName,
    required String lastName,
    String? phone,
    @JsonKey(name: 'emailVerified') @Default(false) bool emailVerified,
    @JsonKey(name: 'phoneVerified') @Default(false) bool phoneVerified,
    @JsonKey(name: 'mfaEnabled') @Default(false) bool mfaEnabled,
    @JsonKey(name: 'mfaEnrolledAt') DateTime? mfaEnrolledAt,
    @JsonKey(name: 'accountStatus') @Default('active') String accountStatus,
    @JsonKey(name: 'roles') @Default(<String>[]) List<String> roles,
    @JsonKey(name: 'lastMfaVerifiedAt') DateTime? lastMfaVerifiedAt,
    @JsonKey(name: 'createdAt') DateTime? createdAt,
    @JsonKey(name: 'updatedAt') DateTime? updatedAt,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}

@freezed
abstract class LoginResponse with _$LoginResponse {
  const factory LoginResponse({
    @JsonKey(name: 'authenticationStatus') required String authenticationStatus,
    @JsonKey(name: 'challengeId') String? challengeId,
    @JsonKey(name: 'availableMethods') List<String>? availableMethods,
    @JsonKey(name: 'enrollmentToken') String? enrollmentToken,
    AuthUser? user,
    @JsonKey(name: 'sessionId') String? sessionId,
    @JsonKey(name: 'expiresIn') int? expiresIn,
    @JsonKey(name: 'accessToken') String? accessToken,
    @JsonKey(name: 'refreshToken') String? refreshToken,
  }) = _LoginResponse;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);
}

@freezed
abstract class MfaEnrollmentStartResponse with _$MfaEnrollmentStartResponse {
  const factory MfaEnrollmentStartResponse({
    required String method,
    @JsonKey(name: 'methodId') required String methodId,
    @JsonKey(name: 'provisioningUri') String? provisioningUri,
    @JsonKey(name: 'qrCodeDataUrl') String? qrCodeDataUrl,
    String? secret,
    @JsonKey(name: 'recoveryCodes') List<String>? recoveryCodes,
  }) = _MfaEnrollmentStartResponse;

  factory MfaEnrollmentStartResponse.fromJson(Map<String, dynamic> json) =>
      _$MfaEnrollmentStartResponseFromJson(json);
}

@freezed
abstract class MfaEnrollmentVerifyResponse with _$MfaEnrollmentVerifyResponse {
  const factory MfaEnrollmentVerifyResponse({
    required bool success,
    required String message,
    @JsonKey(name: 'mfaStatus') String? mfaStatus,
  }) = _MfaEnrollmentVerifyResponse;

  factory MfaEnrollmentVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$MfaEnrollmentVerifyResponseFromJson(json);
}

@freezed
abstract class MfaMethod with _$MfaMethod {
  const factory MfaMethod({
    required String id,
    @JsonKey(name: 'userId') required String userId,
    @JsonKey(name: 'methodType') required String methodType,
    @JsonKey(name: 'methodName') String? methodName,
    @JsonKey(name: 'isPrimary') required bool isPrimary,
    @JsonKey(name: 'isVerified') required bool isVerified,
    @JsonKey(name: 'isActive') required bool isActive,
    @JsonKey(name: 'verifiedAt') DateTime? verifiedAt,
    @JsonKey(name: 'createdAt') required DateTime createdAt,
    @JsonKey(name: 'updatedAt') required DateTime updatedAt,
  }) = _MfaMethod;

  factory MfaMethod.fromJson(Map<String, dynamic> json) => _$MfaMethodFromJson(json);
}

@freezed
abstract class MfaStatusResponse with _$MfaStatusResponse {
  const factory MfaStatusResponse({
    @JsonKey(name: 'mfaEnabled') required bool mfaEnabled,
    @JsonKey(name: 'mfaEnrolled') required bool mfaEnrolled,
    @JsonKey(name: 'enrollmentRequired') required bool enrollmentRequired,
    required List<MfaMethod> methods,
    @JsonKey(name: 'recoveryCodesRemaining') required int recoveryCodesRemaining,
  }) = _MfaStatusResponse;

  factory MfaStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$MfaStatusResponseFromJson(json);
}

@freezed
abstract class MfaChallengeResponse with _$MfaChallengeResponse {
  const factory MfaChallengeResponse({
    @JsonKey(name: 'challengeId') required String challengeId,
    @JsonKey(name: 'availableMethods') required List<String> availableMethods,
    @JsonKey(name: 'expiresAt') required DateTime expiresAt,
  }) = _MfaChallengeResponse;

  factory MfaChallengeResponse.fromJson(Map<String, dynamic> json) =>
      _$MfaChallengeResponseFromJson(json);
}

@freezed
abstract class MfaVerifyResponse with _$MfaVerifyResponse {
  const factory MfaVerifyResponse({
    required bool success,
    required String message,
    @JsonKey(name: 'authenticationStatus') String? authenticationStatus,
    @JsonKey(name: 'sessionToken') String? sessionToken,
    AuthUser? user,
  }) = _MfaVerifyResponse;

  factory MfaVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$MfaVerifyResponseFromJson(json);
}

@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    @JsonKey(name: 'deviceId') String? deviceId,
    @JsonKey(name: 'userAgent') String? userAgent,
    @JsonKey(name: 'ipAddress') String? ipAddress,
    @JsonKey(name: 'countryCode') String? countryCode,
    @JsonKey(name: 'city') String? city,
    @JsonKey(name: 'isCurrent') required bool isCurrent,
    @JsonKey(name: 'idleExpiresAt') required DateTime idleExpiresAt,
    @JsonKey(name: 'absoluteExpiresAt') required DateTime absoluteExpiresAt,
    @JsonKey(name: 'revokedAt') DateTime? revokedAt,
    @JsonKey(name: 'revokedReason') String? revokedReason,
    @JsonKey(name: 'createdAt') required DateTime createdAt,
    @JsonKey(name: 'updatedAt') required DateTime updatedAt,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}

@freezed
abstract class Device with _$Device {
  const factory Device({
    required String id,
    @JsonKey(name: 'deviceIdentifier') required String deviceIdentifier,
    required String platform,
    @JsonKey(name: 'deviceName') String? deviceName,
    @JsonKey(name: 'deviceModel') String? deviceModel,
    @JsonKey(name: 'osVersion') String? osVersion,
    @JsonKey(name: 'appVersion') String? appVersion,
    @JsonKey(name: 'pushProvider') String? pushProvider,
    @JsonKey(name: 'lastIp') String? lastIp,
    @JsonKey(name: 'lastCountryCode') String? lastCountryCode,
    @JsonKey(name: 'lastCity') String? lastCity,
    required String status,
    @JsonKey(name: 'revokedAt') DateTime? revokedAt,
    @JsonKey(name: 'revokedReason') String? revokedReason,
    @JsonKey(name: 'lastActivityAt') DateTime? lastActivityAt,
    @JsonKey(name: 'createdAt') required DateTime createdAt,
    @JsonKey(name: 'updatedAt') required DateTime updatedAt,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

@freezed
abstract class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest.email({
    @JsonKey(name: 'firstName') required String firstName,
    @JsonKey(name: 'lastName') required String lastName,
    required String email,
    required String password,
    required String role,
    @JsonKey(name: 'termsAccepted') required bool termsAccepted,
  }) = RegisterEmailRequest;

  const factory RegisterRequest.phone({
    @JsonKey(name: 'firstName') required String firstName,
    @JsonKey(name: 'lastName') required String lastName,
    required String phone,
    required String password,
    required String role,
    @JsonKey(name: 'termsAccepted') required bool termsAccepted,
  }) = RegisterPhoneRequest;

  const factory RegisterRequest.phoneOtp({
    @JsonKey(name: 'firstName') required String firstName,
    @JsonKey(name: 'lastName') required String lastName,
    required String phone,
    required String role,
    @JsonKey(name: 'termsAccepted') required bool termsAccepted,
  }) = RegisterPhoneOtpRequest;

  const factory RegisterRequest.google({
    @JsonKey(name: 'idToken') required String idToken,
  }) = RegisterGoogleRequest;
}

@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest.email({
    required String email,
    required String password,
  }) = LoginEmailRequest;

  const factory LoginRequest.phone({
    required String phone,
    required String password,
  }) = LoginPhoneRequest;

  const factory LoginRequest.google({
    @JsonKey(name: 'idToken') required String idToken,
  }) = LoginGoogleRequest;
}

@freezed
abstract class OtpRequest with _$OtpRequest {
  const factory OtpRequest.email({required String email}) = EmailOtpRequest;
  const factory OtpRequest.phone({required String phone}) = PhoneOtpRequest;
}

@freezed
abstract class OtpVerifyRequest with _$OtpVerifyRequest {
  const factory OtpVerifyRequest.email({required String email, required String otp}) = EmailOtpVerifyRequest;
  const factory OtpVerifyRequest.phone({required String phone, required String otp}) = PhoneOtpVerifyRequest;
}

@freezed
abstract class MfaEnrollmentStartRequest with _$MfaEnrollmentStartRequest {
  const factory MfaEnrollmentStartRequest({
    @JsonKey(name: 'methodType') required String methodType,
    @JsonKey(name: 'methodName') String? methodName,
    @JsonKey(name: 'phoneNumber') String? phoneNumber,
    @JsonKey(name: 'makePrimary') bool? makePrimary,
  }) = _MfaEnrollmentStartRequest;

  factory MfaEnrollmentStartRequest.fromJson(Map<String, dynamic> json) =>
      _$MfaEnrollmentStartRequestFromJson(json);
}

@freezed
abstract class MfaEnrollmentVerifyRequest with _$MfaEnrollmentVerifyRequest {
  const factory MfaEnrollmentVerifyRequest({
    @JsonKey(name: 'mfaMethodId') required String mfaMethodId,
    required String code,
  }) = _MfaEnrollmentVerifyRequest;

  factory MfaEnrollmentVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$MfaEnrollmentVerifyRequestFromJson(json);
}

@freezed
abstract class MfaChallengeRequest with _$MfaChallengeRequest {
  const factory MfaChallengeRequest({
    @JsonKey(name: 'challengeId') required String challengeId,
    @JsonKey(name: 'totpCode') required String totpCode,
  }) = _MfaChallengeRequest;

  factory MfaChallengeRequest.fromJson(Map<String, dynamic> json) =>
      _$MfaChallengeRequestFromJson(json);
}

@freezed
abstract class RefreshTokenRequest with _$RefreshTokenRequest {
  const factory RefreshTokenRequest({
    @JsonKey(name: 'refreshToken') required String refreshToken,
  }) = _RefreshTokenRequest;

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);
}

@freezed
abstract class RefreshTokenResponse with _$RefreshTokenResponse {
  const factory RefreshTokenResponse({
    @JsonKey(name: 'accessToken') required String accessToken,
    @JsonKey(name: 'refreshToken') required String refreshToken,
    @JsonKey(name: 'expiresIn') required int expiresIn,
  }) = _RefreshTokenResponse;

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenResponseFromJson(json);
}

@freezed
abstract class ForgotPasswordRequest with _$ForgotPasswordRequest {
  const factory ForgotPasswordRequest({required String email}) = _ForgotPasswordRequest;

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestFromJson(json);
}

@freezed
abstract class ResetPasswordRequest with _$ResetPasswordRequest {
  const factory ResetPasswordRequest({
    required String token,
    required String password,
  }) = _ResetPasswordRequest;

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestFromJson(json);
}

@freezed
abstract class EmailVerificationRequest with _$EmailVerificationRequest {
  const factory EmailVerificationRequest.request({required String email}) = RequestEmailVerification;
  const factory EmailVerificationRequest.confirm({required String code}) = ConfirmEmailVerification;
}

@freezed
abstract class PhoneVerificationRequest with _$PhoneVerificationRequest {
  const factory PhoneVerificationRequest.request({required String phone}) = RequestPhoneVerification;
  const factory PhoneVerificationRequest.confirm({required String phone, required String code}) = ConfirmPhoneVerification;
}

@freezed
abstract class DeviceRegistrationRequest with _$DeviceRegistrationRequest {
  const factory DeviceRegistrationRequest({
    @JsonKey(name: 'deviceIdentifier') required String deviceIdentifier,
    required String platform,
    @JsonKey(name: 'deviceName') String? deviceName,
    @JsonKey(name: 'deviceModel') String? deviceModel,
    @JsonKey(name: 'osVersion') String? osVersion,
    @JsonKey(name: 'appVersion') String? appVersion,
    @JsonKey(name: 'pushProvider') String? pushProvider,
    @JsonKey(name: 'pushToken') String? pushToken,
  }) = _DeviceRegistrationRequest;

  factory DeviceRegistrationRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegistrationRequestFromJson(json);
}

@freezed
abstract class DeviceUpdateRequest with _$DeviceUpdateRequest {
  const factory DeviceUpdateRequest({
    @JsonKey(name: 'deviceName') String? deviceName,
    @JsonKey(name: 'pushToken') String? pushToken,
  }) = _DeviceUpdateRequest;

  factory DeviceUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceUpdateRequestFromJson(json);
}

@freezed
abstract class AccountRecoveryRequest with _$AccountRecoveryRequest {
  const factory AccountRecoveryRequest.email({required String email}) = RecoveryEmailRequest;
  const factory AccountRecoveryRequest.phone({required String phone}) = RecoveryPhoneRequest;
  const factory AccountRecoveryRequest.verify({
    required String token,
    required String password,
    String? mfaMethod,
    String? phoneNumber,
  }) = RecoveryVerifyRequest;
}

@freezed
abstract class SecurityEvent with _$SecurityEvent {
  const factory SecurityEvent({
    required String id,
    @JsonKey(name: 'userId') String? userId,
    @JsonKey(name: 'eventType') required String eventType,
    @JsonKey(name: 'eventCategory') required String eventCategory,
    required String severity,
    @JsonKey(name: 'ipAddress') String? ipAddress,
    @JsonKey(name: 'userAgent') String? userAgent,
    @JsonKey(name: 'metadata') Map<String, dynamic>? metadata,
    @JsonKey(name: 'createdAt') required DateTime createdAt,
  }) = _SecurityEvent;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => _$SecurityEventFromJson(json);
}

@freezed
abstract class GoogleAuthUrlResponse with _$GoogleAuthUrlResponse {
  const factory GoogleAuthUrlResponse({
    required String url,
    required String state,
  }) = _GoogleAuthUrlResponse;

  factory GoogleAuthUrlResponse.fromJson(Map<String, dynamic> json) =>
      _$GoogleAuthUrlResponseFromJson(json);
}