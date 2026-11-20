// Application error types.

abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode, this.originalError});

  final String message;
  final String? code;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.statusCode, super.originalError});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code, super.statusCode, super.originalError});
}

class ForbiddenException extends AppException {
  const ForbiddenException(super.message, {super.code, super.statusCode, super.originalError});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.statusCode, this.errors, super.originalError});

  final Map<String, List<String>>? errors;

  @override
  String toString() => 'ValidationException: $message${errors != null ? ' Errors: $errors' : ''}';
}

class MfaRequiredException extends AppException {
  const MfaRequiredException({
    required this.challengeId,
    required this.availableMethods,
    String message = 'MFA verification required',
    String code = 'MFA_REQUIRED',
    int statusCode = 401,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);

  final String challengeId;
  final List<String> availableMethods;
}

class MfaEnrollmentRequiredException extends AppException {
  const MfaEnrollmentRequiredException({
    required this.enrollmentToken,
    String message = 'MFA enrollment required',
    String code = 'MFA_ENROLLMENT_REQUIRED',
    int statusCode = 401,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);

  final String enrollmentToken;
}

class VerificationRequiredException extends AppException {
  const VerificationRequiredException({
    required this.verificationType,
    String message = 'Account verification required',
    String code = 'VERIFICATION_REQUIRED',
    int statusCode = 401,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);

  final String verificationType; // 'email' or 'phone'
}

class AccountSuspendedException extends AppException {
  const AccountSuspendedException({
    String message = 'Account has been suspended',
    String code = 'ACCOUNT_SUSPENDED',
    int statusCode = 403,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);
}

class AccountLockedException extends AppException {
  const AccountLockedException({
    String message = 'Account is temporarily locked',
    String code = 'ACCOUNT_LOCKED',
    int statusCode = 403,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);
}

class RateLimitException extends AppException {
  const RateLimitException({
    String message = 'Too many requests. Please try again later.',
    String code = 'RATE_LIMITED',
    int statusCode = 429,
    this.retryAfter,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);

  final int? retryAfter;
}

class ServerException extends AppException {
  const ServerException({
    String message = 'Server error. Please try again later.',
    String code = 'SERVER_ERROR',
    int statusCode = 500,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);
}

class OfflineException extends AppException {
  const OfflineException({
    String message = 'No internet connection. Please check your network.',
    String code = 'OFFLINE',
    Object? originalError,
  }) : super(message, code: code, originalError: originalError);
}

class TokenExpiredException extends AppException {
  const TokenExpiredException({
    String message = 'Session expired. Please sign in again.',
    String code = 'TOKEN_EXPIRED',
    int statusCode = 401,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);
}

class TokenRevokedException extends AppException {
  const TokenRevokedException({
    String message = 'Session has been revoked. Please sign in again.',
    String code = 'TOKEN_REVOKED',
    int statusCode = 401,
    Object? originalError,
  }) : super(message, code: code, statusCode: statusCode, originalError: originalError);
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.originalError});
}

class BiometricException extends AppException {
  const BiometricException(super.message, {super.code, super.originalError});
}

class DeepLinkException extends AppException {
  const DeepLinkException(super.message, {super.code, super.originalError});
}