// Authentication state management with Riverpod.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../shared/models/auth_models.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/errors/app_exceptions.dart';

export '../../../../shared/models/auth_models.dart';

part 'auth_state.freezed.dart';

Future<void>? _googleSignInInitialization;

Future<void> initializeGoogleSignIn() {
  const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );
}

@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated({
    required AuthUser user,
    required String accessToken,
    required String refreshToken,
  }) = _Authenticated;
  const factory AuthState.mfaRequired({
    required String challengeId,
    required List<String> availableMethods,
  }) = _MfaRequired;
  const factory AuthState.mfaEnrollmentRequired({
    required String enrollmentToken,
  }) = _MfaEnrollmentRequired;
  const factory AuthState.verificationRequired({
    required String verificationType,
    AuthUser? user,
  }) = _VerificationRequired;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.error({required String message}) = _Error;
}

@freezed
abstract class AuthAction with _$AuthAction {
  const factory AuthAction.login({
    required String email,
    required String password,
  }) = _Login;
  const factory AuthAction.loginWithPhone({
    required String phone,
    required String password,
  }) = _LoginWithPhone;
  const factory AuthAction.loginWithGoogle() = _LoginWithGoogle;
  const factory AuthAction.registerWithGoogle({required String role}) =
      _RegisterWithGoogle;
  const factory AuthAction.registerEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    required bool termsAccepted,
  }) = _RegisterEmail;
  const factory AuthAction.registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String role,
    required bool termsAccepted,
  }) = _RegisterPhone;
  const factory AuthAction.registerPhoneOtp({
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
    required bool termsAccepted,
  }) = _RegisterPhoneOtp;
  const factory AuthAction.requestEmailOtp({required String email}) =
      _RequestEmailOtp;
  const factory AuthAction.verifyEmailOtp({
    required String email,
    required String otp,
  }) = _VerifyEmailOtp;
  const factory AuthAction.requestPhoneOtp({required String phone}) =
      _RequestPhoneOtp;
  const factory AuthAction.verifyPhoneOtp({
    required String phone,
    required String otp,
  }) = _VerifyPhoneOtp;
  const factory AuthAction.verifyMfa({
    required String challengeId,
    required String totpCode,
  }) = _VerifyMfa;
  const factory AuthAction.verifyMfaRecoveryCode({
    required String challengeId,
    required String recoveryCode,
  }) = _VerifyMfaRecoveryCode;
  const factory AuthAction.startMfaEnrollment({
    required String methodType,
    String? methodName,
    String? phoneNumber,
    bool? makePrimary,
  }) = _StartMfaEnrollment;
  const factory AuthAction.verifyMfaEnrollment({
    required String methodId,
    required String code,
  }) = _VerifyMfaEnrollment;
  const factory AuthAction.skipMfaEnrollment() = _SkipMfaEnrollment;
  const factory AuthAction.refreshToken() = _RefreshToken;
  const factory AuthAction.logout() = _Logout;
  const factory AuthAction.logoutAll() = _LogoutAll;
  const factory AuthAction.restoreSession() = _RestoreSession;
  const factory AuthAction.requestPasswordReset({required String email}) =
      _RequestPasswordReset;
  const factory AuthAction.resetPassword({
    required String token,
    required String password,
  }) = _ResetPassword;
  const factory AuthAction.requestEmailVerification({required String email}) =
      _RequestEmailVerification;
  const factory AuthAction.confirmEmailVerification({
    required String email,
    required String code,
  }) = _ConfirmEmailVerification;
  const factory AuthAction.requestPhoneVerification({required String phone}) =
      _RequestPhoneVerification;
  const factory AuthAction.confirmPhoneVerification({
    required String phone,
    required String code,
  }) = _ConfirmPhoneVerification;
  const factory AuthAction.registerDevice({
    required Map<String, dynamic> deviceData,
  }) = _RegisterDevice;
  const factory AuthAction.getDevices() = _GetDevices;
  const factory AuthAction.revokeDevice({required String deviceId}) =
      _RevokeDevice;
  const factory AuthAction.getSessions() = _GetSessions;
  const factory AuthAction.revokeSession({required String sessionId}) =
      _RevokeSession;
  const factory AuthAction.getMfaStatus() = _GetMfaStatus;
  const factory AuthAction.getMfaMethods() = _GetMfaMethods;
  const factory AuthAction.addMfaMethod({
    required String methodType,
    String? methodName,
    String? phoneNumber,
    bool? makePrimary,
  }) = _AddMfaMethod;
  const factory AuthAction.verifyMfaMethod({
    required String methodId,
    required String code,
  }) = _VerifyMfaMethod;
  const factory AuthAction.disableMfaMethod({
    required String methodId,
    required String verificationCode,
  }) = _DisableMfaMethod;
  const factory AuthAction.setPrimaryMfaMethod({
    required String methodId,
    required String verificationCode,
  }) = _SetPrimaryMfaMethod;
  const factory AuthAction.regenerateRecoveryCodes({
    required String verificationCode,
  }) = _RegenerateRecoveryCodes;
  const factory AuthAction.requestAccountRecoveryEmail({
    required String email,
  }) = _RequestAccountRecoveryEmail;
  const factory AuthAction.requestAccountRecoveryPhone({
    required String phone,
  }) = _RequestAccountRecoveryPhone;
  const factory AuthAction.verifyAccountRecovery({
    required String token,
    required String password,
    String? mfaMethod,
    String? phoneNumber,
  }) = _VerifyAccountRecovery;
  const factory AuthAction.getSecurityEvents({int? limit, int? offset}) =
      _GetSecurityEvents;
  const factory AuthAction.linkGoogle({required String idToken}) = _LinkGoogle;
  const factory AuthAction.unlinkGoogle({required String password}) =
      _UnlinkGoogle;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._apiClient, this._tokenStorage)
    : super(const AuthState.unauthenticated()) {
    _init();
  }

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;
  Map<String, dynamic>? lastMfaEnrollment;
  bool emailVerificationDeliveryFailed = false;

  Future<void> _init() async {
    await restoreSession();
  }

  Future<void> _handleAction(AuthAction action) async {
    final previousState = state;
    try {
      state = const AuthState.loading();
      await _executeAction(action);
      if (state.isLoading) state = previousState;
    } on AppException {
      state = action is _Logout || action is _LogoutAll
          ? const AuthState.unauthenticated()
          : previousState;
      rethrow;
    } on DioException catch (error) {
      state = action is _Logout || action is _LogoutAll
          ? const AuthState.unauthenticated()
          : previousState;
      throw _mapDioException(error);
    } catch (error) {
      state = action is _Logout || action is _LogoutAll
          ? const AuthState.unauthenticated()
          : previousState;
      debugPrint(
        'Auth action failed before a valid API response: ${error.runtimeType}',
      );
      throw const ServerException();
    }
  }

  Future<void> handleAction(AuthAction action) => _handleAction(action);

  Future<void> _executeAction(AuthAction action) async {
    switch (action) {
      case _Login():
        await _login(action.email, action.password);
      case _LoginWithPhone():
        await _loginWithPhone(action.phone, action.password);
      case _LoginWithGoogle():
        await _authenticateWithGoogle(register: false);
      case _RegisterWithGoogle():
        await _authenticateWithGoogle(register: true, role: action.role);
      case _RegisterEmail():
        await _registerEmail(
          action.firstName,
          action.lastName,
          action.email,
          action.password,
          action.role,
          action.termsAccepted,
        );
      case _RegisterPhone():
        await _registerPhone(
          action.firstName,
          action.lastName,
          action.phone,
          action.password,
          action.role,
          action.termsAccepted,
        );
      case _RegisterPhoneOtp():
        await _registerPhoneOtp(
          action.firstName,
          action.lastName,
          action.phone,
          action.role,
          action.termsAccepted,
        );
      case _RequestEmailOtp():
        await _requestEmailOtp(action.email);
      case _VerifyEmailOtp():
        await _verifyEmailOtp(action.email, action.otp);
      case _RequestPhoneOtp():
        await _requestPhoneOtp(action.phone);
      case _VerifyPhoneOtp():
        await _verifyPhoneOtp(action.phone, action.otp);
      case _VerifyMfa():
        await _verifyMfa(
          action.challengeId,
          action.totpCode,
          methodType: 'totp',
        );
      case _VerifyMfaRecoveryCode():
        await _verifyMfa(
          action.challengeId,
          action.recoveryCode,
          methodType: 'recovery_codes',
        );
      case _StartMfaEnrollment():
        await _startMfaEnrollment(
          action.methodType,
          action.methodName,
          action.phoneNumber,
          action.makePrimary,
        );
      case _VerifyMfaEnrollment():
        await _verifyMfaEnrollment(action.methodId, action.code);
      case _SkipMfaEnrollment():
        await _skipMfaEnrollment();
      case _RefreshToken():
        await _refreshToken();
      case _Logout():
        await _logout();
      case _LogoutAll():
        await _logoutAll();
      case _RestoreSession():
        await restoreSession();
      case _RequestPasswordReset():
        await _requestPasswordReset(action.email);
      case _ResetPassword():
        await _resetPassword(action.token, action.password);
      case _RequestEmailVerification():
        await _requestEmailVerification(action.email);
      case _ConfirmEmailVerification():
        await _confirmEmailVerification(action.email, action.code);
      case _RequestPhoneVerification():
        await _requestPhoneVerification(action.phone);
      case _ConfirmPhoneVerification():
        await _confirmPhoneVerification(action.phone, action.code);
      case _RegisterDevice():
        await _registerDevice(action.deviceData);
      case _GetDevices():
        await _getDevices();
      case _RevokeDevice():
        await _revokeDevice(action.deviceId);
      case _GetSessions():
        await _getSessions();
      case _RevokeSession():
        await _revokeSession(action.sessionId);
      case _GetMfaStatus():
        await _getMfaStatus();
      case _GetMfaMethods():
        await _getMfaMethods();
      case _AddMfaMethod():
        await _addMfaMethod(
          action.methodType,
          action.methodName,
          action.phoneNumber,
          action.makePrimary,
        );
      case _VerifyMfaMethod():
        await _verifyMfaMethod(action.methodId, action.code);
      case _DisableMfaMethod():
        await _disableMfaMethod(action.methodId, action.verificationCode);
      case _SetPrimaryMfaMethod():
        await _setPrimaryMfaMethod(action.methodId, action.verificationCode);
      case _RegenerateRecoveryCodes():
        await _regenerateRecoveryCodes(action.verificationCode);
      case _RequestAccountRecoveryEmail():
        await _requestAccountRecoveryEmail(action.email);
      case _RequestAccountRecoveryPhone():
        await _requestAccountRecoveryPhone(action.phone);
      case _VerifyAccountRecovery():
        await _verifyAccountRecovery(
          action.token,
          action.password,
          action.mfaMethod,
          action.phoneNumber,
        );
      case _GetSecurityEvents():
        await _getSecurityEvents(limit: action.limit, offset: action.offset);
      case _LinkGoogle():
        await _linkGoogle(action.idToken);
      case _UnlinkGoogle():
        await _unlinkGoogle(action.password);
    }
  }

  Future<void> _login(String email, String password) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/login/email',
      data: {'email': email, 'password': password},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _loginWithPhone(String phone, String password) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/login/phone',
      data: {'phone': phone, 'password': password},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _authenticateWithGoogle({
    required bool register,
    String? role,
  }) async {
    final googleSignIn = GoogleSignIn.instance;
    await initializeGoogleSignIn();

    if (!googleSignIn.supportsAuthenticate()) {
      throw const ServerException(
        message: 'Google sign-in is not available on this platform.',
        code: 'GOOGLE_SIGN_IN_UNAVAILABLE',
      );
    }

    late final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        state = const AuthState.unauthenticated();
        return;
      }
      final description = error.description?.trim();
      debugPrint(
        'Google sign-in failed before API request: ${error.code.name}'
        '${description == null || description.isEmpty ? '' : ' ($description)'}',
      );
      final message = switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is misconfigured. Check the Android OAuth client and app signing fingerprint.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google Play services could not complete sign-in. Update Google Play services and try again.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in could not open on this device. Close other sign-in prompts and retry.',
        GoogleSignInExceptionCode.unknownError
            when description != null && description.isNotEmpty =>
          'Google sign-in failed: $description',
        _ => 'Google sign-in failed (${error.code.name}). Please try again.',
      };
      throw ServerException(
        message: message,
        code: 'GOOGLE_SIGN_IN_${error.code.name.toUpperCase()}',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ServerException(
        message:
            'Google did not provide an identity token. Check the mobile OAuth configuration.',
        code: 'GOOGLE_ID_TOKEN_MISSING',
      );
    }

    debugPrint(
      'Google sign-in: sending identity token to '
      '${ApiConfig.authBaseUrl}${register ? '/register/google' : '/login/google'}',
    );
    final response = await _apiClient.post<Map<String, dynamic>>(
      register ? '/register/google' : '/login/google',
      data: {'idToken': idToken, if (register && role != null) 'role': role},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _registerEmail(
    String firstName,
    String lastName,
    String email,
    String password,
    String role,
    bool termsAccepted,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/register/email',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role,
        'termsAccepted': termsAccepted,
      },
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _registerPhone(
    String firstName,
    String lastName,
    String phone,
    String password,
    String role,
    bool termsAccepted,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/register/phone',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
        'role': role,
        'termsAccepted': termsAccepted,
      },
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _registerPhoneOtp(
    String firstName,
    String lastName,
    String phone,
    String role,
    bool termsAccepted,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/register/phone-otp',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'role': role,
        'termsAccepted': termsAccepted,
      },
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _requestEmailOtp(String email) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/login/email/otp/request',
      data: {'email': email},
    );
    // OTP sent - user needs to verify
  }

  Future<void> _verifyEmailOtp(String email, String otp) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/login/email/otp/verify',
      data: {'email': email, 'otp': otp},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _requestPhoneOtp(String phone) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/login/phone/otp/request',
      data: {'phone': phone},
    );
  }

  Future<void> _verifyPhoneOtp(String phone, String otp) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/login/phone/otp/verify',
      data: {'phone': phone, 'otp': otp},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _verifyMfa(
    String challengeId,
    String code, {
    String methodType = 'totp',
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/mfa/verify',
      data: {
        'challengeId': challengeId,
        'methodType': methodType,
        'code': code,
      },
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> verifyMfaLoginCode({
    required String challengeId,
    required String methodType,
    required String code,
  }) async {
    try {
      await _verifyMfa(challengeId, code, methodType: methodType);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> requestMfaLoginCode({
    required String challengeId,
    required String methodType,
  }) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/mfa/challenge/request-code',
        data: {'challengeId': challengeId, 'methodType': methodType},
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> requestMfaEnrollmentCode(String methodId) async {
    final enrollmentToken = await _tokenStorage.getEnrollmentToken();
    final options = enrollmentToken == null || enrollmentToken.isEmpty
        ? null
        : Options(
            headers: {'Authorization': 'MFA-Enrollment $enrollmentToken'},
          );
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/mfa/enrollment/request-code',
        data: {'mfaMethodId': methodId},
        options: options,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> requestMfaMethodCode(String methodId) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/mfa/methods/request-code',
        data: {'mfaMethodId': methodId},
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> _startMfaEnrollment(
    String methodType,
    String? methodName,
    String? phoneNumber,
    bool? makePrimary,
  ) async {
    final enrollmentToken = await _tokenStorage.getEnrollmentToken();
    if (enrollmentToken == null || enrollmentToken.isEmpty) {
      throw const UnauthorizedException('MFA enrollment is not available.');
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/mfa/enrollment/start',
      data: {
        'methodType': methodType,
        'methodName': ?methodName,
        'phoneNumber': ?phoneNumber,
        'makePrimary': ?makePrimary,
      },
      options: Options(
        headers: {'Authorization': 'MFA-Enrollment $enrollmentToken'},
      ),
    );

    final payload = response.data?['data'];
    if (payload is! Map<String, dynamic>) {
      throw const ServerException(
        message: 'The server returned an invalid MFA setup response.',
      );
    }
    lastMfaEnrollment = payload;
  }

  Future<void> _verifyMfaEnrollment(String methodId, String code) async {
    final enrollmentToken = await _tokenStorage.getEnrollmentToken();
    if (enrollmentToken == null || enrollmentToken.isEmpty) {
      throw const UnauthorizedException('MFA enrollment is not available.');
    }

    await _apiClient.post<Map<String, dynamic>>(
      '/mfa/enrollment/verify',
      data: {'mfaMethodId': methodId, 'code': code},
      options: Options(
        headers: {'Authorization': 'MFA-Enrollment $enrollmentToken'},
      ),
    );

    await _tokenStorage.clearEnrollmentToken();
    // After enrollment, user needs to sign in again
    state = const AuthState.unauthenticated();
  }

  Future<void> _skipMfaEnrollment() async {
    final enrollmentToken = await _tokenStorage.getEnrollmentToken();
    if (enrollmentToken == null || enrollmentToken.isEmpty) {
      throw const UnauthorizedException('MFA enrollment is not available.');
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/mfa/enrollment/skip',
      options: Options(
        headers: {'Authorization': 'MFA-Enrollment $enrollmentToken'},
      ),
    );
    await _handleAuthResponse(response.data);
    await _tokenStorage.clearEnrollmentToken();
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const TokenRevokedException();
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/refresh',
      data: {'refreshToken': refreshToken},
    );

    final data = response.data;
    final payload = data is Map<String, dynamic> ? data['data'] : null;
    final accessToken = payload is Map<String, dynamic>
        ? payload['accessToken'] as String?
        : null;
    final newRefreshToken = payload is Map<String, dynamic>
        ? payload['refreshToken'] as String?
        : null;

    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );
    }
  }

  Future<void> _logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      await _apiClient.post<void>(
        '/logout',
        data: refreshToken == null ? {} : {'refreshToken': refreshToken},
      );
    } finally {
      await _tokenStorage.clearAllTokens();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _logoutAll() async {
    try {
      await _apiClient.post<void>('/logout-all');
    } finally {
      await _tokenStorage.clearAllTokens();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> restoreSession() async {
    if (!await _tokenStorage.hasTokens()) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/me');
      final userData = response.data;
      final payload = userData is Map<String, dynamic>
          ? userData['data']
          : null;
      final userJson = payload is Map<String, dynamic> ? payload['user'] : null;

      if (userJson is Map<String, dynamic>) {
        final user = AuthUser.fromJson(userJson);
        final accessToken = await _tokenStorage.getAccessToken();
        final refreshToken = await _tokenStorage.getRefreshToken();

        if (accessToken != null && refreshToken != null) {
          state = AuthState.authenticated(
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        } else {
          await _refreshToken();
          final newAccessToken = await _tokenStorage.getAccessToken();
          final newRefreshToken = await _tokenStorage.getRefreshToken();
          if (newAccessToken != null && newRefreshToken != null) {
            state = AuthState.authenticated(
              user: user,
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );
          } else {
            state = const AuthState.unauthenticated();
          }
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } on AppException {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _requestPasswordReset(String email) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> _resetPassword(String token, String password) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/reset-password',
      data: {'token': token, 'password': password},
    );
  }

  Future<void> _requestEmailVerification(String email) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/verify-email/request',
      data: {'email': email},
    );
  }

  Future<void> _confirmEmailVerification(String email, String code) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/verify-email/confirm',
      data: {'email': email, 'code': code},
    );
    await _handleAuthResponse(response.data);
  }

  Future<void> _requestPhoneVerification(String phone) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/verify-phone/request',
      data: {'phone': phone},
    );
  }

  Future<void> _confirmPhoneVerification(String phone, String code) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/verify-phone/confirm',
      data: {'phone': phone, 'otp': code},
    );
    state = const AuthState.unauthenticated();
  }

  Future<void> _registerDevice(Map<String, dynamic> deviceData) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/devices/register',
      data: deviceData,
    );
  }

  Future<void> _getDevices() async {
    await _apiClient.get<Map<String, dynamic>>('/devices');
  }

  Future<void> _revokeDevice(String deviceId) async {
    await _apiClient.delete<Map<String, dynamic>>('/devices/$deviceId');
  }

  Future<void> _getSessions() async {
    await _apiClient.get<Map<String, dynamic>>('/sessions');
  }

  Future<void> _revokeSession(String sessionId) async {
    await _apiClient.delete<Map<String, dynamic>>('/sessions/$sessionId');
  }

  Future<void> _getMfaStatus() async {
    await _apiClient.get<Map<String, dynamic>>('/mfa/status');
  }

  Future<void> _getMfaMethods() async {
    await _apiClient.get<Map<String, dynamic>>('/mfa/methods');
  }

  Future<void> _addMfaMethod(
    String methodType,
    String? methodName,
    String? phoneNumber,
    bool? makePrimary,
  ) async {
    lastMfaEnrollment = null;
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/mfa/methods/add',
      data: {
        'methodType': methodType,
        'methodName': ?methodName,
        'phoneNumber': ?phoneNumber,
        'makePrimary': ?makePrimary,
      },
    );
    final payload = response.data?['data'];
    if (payload is! Map<String, dynamic>) {
      throw const ServerException(
        message: 'The server returned an invalid MFA setup response.',
      );
    }
    lastMfaEnrollment = payload;
  }

  Future<void> _verifyMfaMethod(String methodId, String code) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/mfa/methods/verify',
      data: {'mfaMethodId': methodId, 'code': code},
    );
  }

  Future<void> _disableMfaMethod(
    String methodId,
    String verificationCode,
  ) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/mfa/methods/disable',
      data: {'mfaMethodId': methodId, 'verificationCode': verificationCode},
    );
  }

  Future<void> _setPrimaryMfaMethod(
    String methodId,
    String verificationCode,
  ) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/mfa/methods/set-primary',
      data: {'mfaMethodId': methodId, 'verificationCode': verificationCode},
    );
  }

  Future<void> _regenerateRecoveryCodes(String verificationCode) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/mfa/recovery-codes/regenerate',
      data: {'verificationCode': verificationCode},
    );
  }

  Future<void> _requestAccountRecoveryEmail(String email) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/account/recovery/request',
      data: {'email': email},
    );
  }

  Future<void> _requestAccountRecoveryPhone(String phone) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/account/recovery/phone',
      data: {'phone': phone},
    );
  }

  Future<void> _verifyAccountRecovery(
    String token,
    String password,
    String? mfaMethod,
    String? phoneNumber,
  ) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/account/recovery/verify',
      data: {
        'token': token,
        'password': password,
        'mfaMethod': ?mfaMethod,
        'phoneNumber': ?phoneNumber,
      },
    );
  }

  AppException _mapDioException(DioException error) {
    final status = error.response?.statusCode;
    final responseBody = error.response?.data;
    final response = responseBody is Map<String, dynamic> ? responseBody : null;
    final code = response?['code'] as String?;
    final message = response?['message'] as String?;
    debugPrint(
      'Auth API request failed: ${error.type.name}, '
      'status=${status ?? 'none'}, path=${error.requestOptions.path}',
    );

    if (status == 429) {
      final retryAfter = int.tryParse(
        error.response?.headers.value('retry-after') ?? '',
      );
      return RateLimitException(retryAfter: retryAfter);
    }
    if (status == 401) {
      return UnauthorizedException(
        code == 'INVALID_CREDENTIALS'
            ? 'Invalid credentials.'
            : 'Your session is no longer valid. Please sign in again.',
        code: code,
        statusCode: status,
      );
    }
    if (status == 403) {
      return ForbiddenException(
        message ?? 'You are not allowed to perform this action.',
        code: code,
        statusCode: status,
      );
    }
    if (status == 400 || status == 422) {
      return ValidationException(
        message ?? 'Please check the information and try again.',
        code: code,
        statusCode: status,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const OfflineException();
    }
    if (status != null && status >= 500) return const ServerException();
    return NetworkException(
      message ??
          (status == null
              ? 'Could not reach the server. Check the phone connection and API URL.'
              : 'The server returned HTTP $status. Please try again.'),
      code: code,
      statusCode: status,
      originalError: error,
    );
  }

  Future<void> _getSecurityEvents({int? limit, int? offset}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;
    await _apiClient.get<Map<String, dynamic>>(
      '/security-events',
      queryParameters: queryParams,
    );
  }

  Future<void> _linkGoogle(String idToken) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/google/link',
      data: {'idToken': idToken},
    );
  }

  Future<void> _unlinkGoogle(String password) async {
    await _apiClient.delete<Map<String, dynamic>>(
      '/google/unlink',
      data: {'password': password},
    );
  }

  Future<void> _handleAuthResponse(dynamic response) async {
    final data = response is Map<String, dynamic> ? response['data'] : null;
    emailVerificationDeliveryFailed =
        data is Map<String, dynamic> &&
        data['verificationDeliveryFailed'] == true;
    final authStatus = data is Map<String, dynamic>
        ? data['authenticationStatus'] as String?
        : null;
    final challengeId = data is Map<String, dynamic>
        ? data['challengeId'] as String?
        : null;
    final List<String> availableMethods = data is Map<String, dynamic>
        ? (data['availableMethods'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              []
        : [];
    final enrollmentToken = data is Map<String, dynamic>
        ? data['enrollmentToken'] as String?
        : null;
    final userJson = data is Map<String, dynamic> ? data['user'] : null;
    final accessToken = data is Map<String, dynamic>
        ? data['accessToken'] as String?
        : null;
    final refreshToken = data is Map<String, dynamic>
        ? data['refreshToken'] as String?
        : null;

    final user = userJson is Map<String, dynamic>
        ? AuthUser.fromJson(userJson)
        : null;

    switch (authStatus) {
      case 'mfa_required':
        if (challengeId != null) {
          state = AuthState.mfaRequired(
            challengeId: challengeId,
            availableMethods: availableMethods,
          );
        }
        break;
      case 'mfa_enrollment_required':
        if (enrollmentToken != null) {
          await _tokenStorage.saveEnrollmentToken(enrollmentToken);
          state = AuthState.mfaEnrollmentRequired(
            enrollmentToken: enrollmentToken,
          );
        }
        break;
      case 'verification_required':
        final channel = data is Map<String, dynamic>
            ? data['verificationChannel'] as String?
            : null;
        state = AuthState.verificationRequired(
          verificationType: channel == 'sms' || channel == 'phone'
              ? 'phone'
              : 'email',
          user: user,
        );
        break;
      case 'complete':
      case 'authenticated':
        if (user != null && accessToken != null && refreshToken != null) {
          await _tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          state = AuthState.authenticated(
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        }
        break;
      default:
        if (data is Map<String, dynamic> &&
            data['verificationRequired'] == true) {
          final channel = data['verificationChannel'] as String?;
          state = AuthState.verificationRequired(
            verificationType: channel == 'sms' || channel == 'phone'
                ? 'phone'
                : 'email',
            user: user,
          );
        } else if (user != null &&
            accessToken != null &&
            refreshToken != null) {
          await _tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          state = AuthState.authenticated(
            user: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        } else {
          state = const AuthState.unauthenticated();
        }
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    ref.watch(apiClientProvider),
    ref.watch(authTokenStorageProvider),
  );
});

extension AuthStateX on AuthState {
  bool get isAuthenticated => this is _Authenticated;
  bool get isUnauthenticated => this is _Unauthenticated;
  bool get isLoading => this is _Loading;
  bool get isError => this is _Error;
  bool get isMfaRequired => this is _MfaRequired;
  bool get isMfaEnrollmentRequired => this is _MfaEnrollmentRequired;
  bool get isVerificationRequired => this is _VerificationRequired;

  AuthUser? get user => switch (this) {
    _Authenticated(user: final u) => u,
    _VerificationRequired(user: final u) => u,
    _ => null,
  };

  String? get errorMessage => switch (this) {
    _Error(message: final m) => m,
    _ => null,
  };
}
