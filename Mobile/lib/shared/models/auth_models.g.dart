// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUser _$AuthUserFromJson(Map<String, dynamic> json) => _AuthUser(
  id: json['id'] as String,
  email: json['email'] as String?,
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  phone: json['phone'] as String?,
  emailVerified: json['emailVerified'] as bool? ?? false,
  phoneVerified: json['phoneVerified'] as bool? ?? false,
  mfaEnabled: json['mfaEnabled'] as bool? ?? false,
  mfaEnrolledAt: json['mfaEnrolledAt'] == null
      ? null
      : DateTime.parse(json['mfaEnrolledAt'] as String),
  accountStatus: json['accountStatus'] as String? ?? 'active',
  roles:
      (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  lastMfaVerifiedAt: json['lastMfaVerifiedAt'] == null
      ? null
      : DateTime.parse(json['lastMfaVerifiedAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$AuthUserToJson(_AuthUser instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'phone': instance.phone,
  'emailVerified': instance.emailVerified,
  'phoneVerified': instance.phoneVerified,
  'mfaEnabled': instance.mfaEnabled,
  'mfaEnrolledAt': instance.mfaEnrolledAt?.toIso8601String(),
  'accountStatus': instance.accountStatus,
  'roles': instance.roles,
  'lastMfaVerifiedAt': instance.lastMfaVerifiedAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

_LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    _LoginResponse(
      authenticationStatus: json['authenticationStatus'] as String,
      challengeId: json['challengeId'] as String?,
      availableMethods: (json['availableMethods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      enrollmentToken: json['enrollmentToken'] as String?,
      user: json['user'] == null
          ? null
          : AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      sessionId: json['sessionId'] as String?,
      expiresIn: (json['expiresIn'] as num?)?.toInt(),
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
    );

Map<String, dynamic> _$LoginResponseToJson(_LoginResponse instance) =>
    <String, dynamic>{
      'authenticationStatus': instance.authenticationStatus,
      'challengeId': instance.challengeId,
      'availableMethods': instance.availableMethods,
      'enrollmentToken': instance.enrollmentToken,
      'user': instance.user,
      'sessionId': instance.sessionId,
      'expiresIn': instance.expiresIn,
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
    };

_MfaEnrollmentStartResponse _$MfaEnrollmentStartResponseFromJson(
  Map<String, dynamic> json,
) => _MfaEnrollmentStartResponse(
  method: json['method'] as String,
  methodId: json['methodId'] as String,
  provisioningUri: json['provisioningUri'] as String?,
  qrCodeDataUrl: json['qrCodeDataUrl'] as String?,
  secret: json['secret'] as String?,
  recoveryCodes: (json['recoveryCodes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MfaEnrollmentStartResponseToJson(
  _MfaEnrollmentStartResponse instance,
) => <String, dynamic>{
  'method': instance.method,
  'methodId': instance.methodId,
  'provisioningUri': instance.provisioningUri,
  'qrCodeDataUrl': instance.qrCodeDataUrl,
  'secret': instance.secret,
  'recoveryCodes': instance.recoveryCodes,
};

_MfaEnrollmentVerifyResponse _$MfaEnrollmentVerifyResponseFromJson(
  Map<String, dynamic> json,
) => _MfaEnrollmentVerifyResponse(
  success: json['success'] as bool,
  message: json['message'] as String,
  mfaStatus: json['mfaStatus'] as String?,
);

Map<String, dynamic> _$MfaEnrollmentVerifyResponseToJson(
  _MfaEnrollmentVerifyResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'mfaStatus': instance.mfaStatus,
};

_MfaMethod _$MfaMethodFromJson(Map<String, dynamic> json) => _MfaMethod(
  id: json['id'] as String,
  userId: json['userId'] as String,
  methodType: json['methodType'] as String,
  methodName: json['methodName'] as String?,
  isPrimary: json['isPrimary'] as bool,
  isVerified: json['isVerified'] as bool,
  isActive: json['isActive'] as bool,
  verifiedAt: json['verifiedAt'] == null
      ? null
      : DateTime.parse(json['verifiedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MfaMethodToJson(_MfaMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'methodType': instance.methodType,
      'methodName': instance.methodName,
      'isPrimary': instance.isPrimary,
      'isVerified': instance.isVerified,
      'isActive': instance.isActive,
      'verifiedAt': instance.verifiedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_MfaStatusResponse _$MfaStatusResponseFromJson(Map<String, dynamic> json) =>
    _MfaStatusResponse(
      mfaEnabled: json['mfaEnabled'] as bool,
      mfaEnrolled: json['mfaEnrolled'] as bool,
      enrollmentRequired: json['enrollmentRequired'] as bool,
      methods: (json['methods'] as List<dynamic>)
          .map((e) => MfaMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
      recoveryCodesRemaining: (json['recoveryCodesRemaining'] as num).toInt(),
    );

Map<String, dynamic> _$MfaStatusResponseToJson(_MfaStatusResponse instance) =>
    <String, dynamic>{
      'mfaEnabled': instance.mfaEnabled,
      'mfaEnrolled': instance.mfaEnrolled,
      'enrollmentRequired': instance.enrollmentRequired,
      'methods': instance.methods,
      'recoveryCodesRemaining': instance.recoveryCodesRemaining,
    };

_MfaChallengeResponse _$MfaChallengeResponseFromJson(
  Map<String, dynamic> json,
) => _MfaChallengeResponse(
  challengeId: json['challengeId'] as String,
  availableMethods: (json['availableMethods'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$MfaChallengeResponseToJson(
  _MfaChallengeResponse instance,
) => <String, dynamic>{
  'challengeId': instance.challengeId,
  'availableMethods': instance.availableMethods,
  'expiresAt': instance.expiresAt.toIso8601String(),
};

_MfaVerifyResponse _$MfaVerifyResponseFromJson(Map<String, dynamic> json) =>
    _MfaVerifyResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      authenticationStatus: json['authenticationStatus'] as String?,
      sessionToken: json['sessionToken'] as String?,
      user: json['user'] == null
          ? null
          : AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MfaVerifyResponseToJson(_MfaVerifyResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'authenticationStatus': instance.authenticationStatus,
      'sessionToken': instance.sessionToken,
      'user': instance.user,
    };

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: json['id'] as String,
  deviceId: json['deviceId'] as String?,
  userAgent: json['userAgent'] as String?,
  ipAddress: json['ipAddress'] as String?,
  countryCode: json['countryCode'] as String?,
  city: json['city'] as String?,
  isCurrent: json['isCurrent'] as bool,
  idleExpiresAt: DateTime.parse(json['idleExpiresAt'] as String),
  absoluteExpiresAt: DateTime.parse(json['absoluteExpiresAt'] as String),
  revokedAt: json['revokedAt'] == null
      ? null
      : DateTime.parse(json['revokedAt'] as String),
  revokedReason: json['revokedReason'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'deviceId': instance.deviceId,
  'userAgent': instance.userAgent,
  'ipAddress': instance.ipAddress,
  'countryCode': instance.countryCode,
  'city': instance.city,
  'isCurrent': instance.isCurrent,
  'idleExpiresAt': instance.idleExpiresAt.toIso8601String(),
  'absoluteExpiresAt': instance.absoluteExpiresAt.toIso8601String(),
  'revokedAt': instance.revokedAt?.toIso8601String(),
  'revokedReason': instance.revokedReason,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_Device _$DeviceFromJson(Map<String, dynamic> json) => _Device(
  id: json['id'] as String,
  deviceIdentifier: json['deviceIdentifier'] as String,
  platform: json['platform'] as String,
  deviceName: json['deviceName'] as String?,
  deviceModel: json['deviceModel'] as String?,
  osVersion: json['osVersion'] as String?,
  appVersion: json['appVersion'] as String?,
  pushProvider: json['pushProvider'] as String?,
  lastIp: json['lastIp'] as String?,
  lastCountryCode: json['lastCountryCode'] as String?,
  lastCity: json['lastCity'] as String?,
  status: json['status'] as String,
  revokedAt: json['revokedAt'] == null
      ? null
      : DateTime.parse(json['revokedAt'] as String),
  revokedReason: json['revokedReason'] as String?,
  lastActivityAt: json['lastActivityAt'] == null
      ? null
      : DateTime.parse(json['lastActivityAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
  'id': instance.id,
  'deviceIdentifier': instance.deviceIdentifier,
  'platform': instance.platform,
  'deviceName': instance.deviceName,
  'deviceModel': instance.deviceModel,
  'osVersion': instance.osVersion,
  'appVersion': instance.appVersion,
  'pushProvider': instance.pushProvider,
  'lastIp': instance.lastIp,
  'lastCountryCode': instance.lastCountryCode,
  'lastCity': instance.lastCity,
  'status': instance.status,
  'revokedAt': instance.revokedAt?.toIso8601String(),
  'revokedReason': instance.revokedReason,
  'lastActivityAt': instance.lastActivityAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_MfaEnrollmentStartRequest _$MfaEnrollmentStartRequestFromJson(
  Map<String, dynamic> json,
) => _MfaEnrollmentStartRequest(
  methodType: json['methodType'] as String,
  methodName: json['methodName'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  makePrimary: json['makePrimary'] as bool?,
);

Map<String, dynamic> _$MfaEnrollmentStartRequestToJson(
  _MfaEnrollmentStartRequest instance,
) => <String, dynamic>{
  'methodType': instance.methodType,
  'methodName': instance.methodName,
  'phoneNumber': instance.phoneNumber,
  'makePrimary': instance.makePrimary,
};

_MfaEnrollmentVerifyRequest _$MfaEnrollmentVerifyRequestFromJson(
  Map<String, dynamic> json,
) => _MfaEnrollmentVerifyRequest(
  mfaMethodId: json['mfaMethodId'] as String,
  code: json['code'] as String,
);

Map<String, dynamic> _$MfaEnrollmentVerifyRequestToJson(
  _MfaEnrollmentVerifyRequest instance,
) => <String, dynamic>{
  'mfaMethodId': instance.mfaMethodId,
  'code': instance.code,
};

_MfaChallengeRequest _$MfaChallengeRequestFromJson(Map<String, dynamic> json) =>
    _MfaChallengeRequest(
      challengeId: json['challengeId'] as String,
      totpCode: json['totpCode'] as String,
    );

Map<String, dynamic> _$MfaChallengeRequestToJson(
  _MfaChallengeRequest instance,
) => <String, dynamic>{
  'challengeId': instance.challengeId,
  'totpCode': instance.totpCode,
};

_RefreshTokenRequest _$RefreshTokenRequestFromJson(Map<String, dynamic> json) =>
    _RefreshTokenRequest(refreshToken: json['refreshToken'] as String);

Map<String, dynamic> _$RefreshTokenRequestToJson(
  _RefreshTokenRequest instance,
) => <String, dynamic>{'refreshToken': instance.refreshToken};

_RefreshTokenResponse _$RefreshTokenResponseFromJson(
  Map<String, dynamic> json,
) => _RefreshTokenResponse(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  expiresIn: (json['expiresIn'] as num).toInt(),
);

Map<String, dynamic> _$RefreshTokenResponseToJson(
  _RefreshTokenResponse instance,
) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'refreshToken': instance.refreshToken,
  'expiresIn': instance.expiresIn,
};

_ForgotPasswordRequest _$ForgotPasswordRequestFromJson(
  Map<String, dynamic> json,
) => _ForgotPasswordRequest(email: json['email'] as String);

Map<String, dynamic> _$ForgotPasswordRequestToJson(
  _ForgotPasswordRequest instance,
) => <String, dynamic>{'email': instance.email};

_ResetPasswordRequest _$ResetPasswordRequestFromJson(
  Map<String, dynamic> json,
) => _ResetPasswordRequest(
  token: json['token'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$ResetPasswordRequestToJson(
  _ResetPasswordRequest instance,
) => <String, dynamic>{'token': instance.token, 'password': instance.password};

_DeviceRegistrationRequest _$DeviceRegistrationRequestFromJson(
  Map<String, dynamic> json,
) => _DeviceRegistrationRequest(
  deviceIdentifier: json['deviceIdentifier'] as String,
  platform: json['platform'] as String,
  deviceName: json['deviceName'] as String?,
  deviceModel: json['deviceModel'] as String?,
  osVersion: json['osVersion'] as String?,
  appVersion: json['appVersion'] as String?,
  pushProvider: json['pushProvider'] as String?,
  pushToken: json['pushToken'] as String?,
);

Map<String, dynamic> _$DeviceRegistrationRequestToJson(
  _DeviceRegistrationRequest instance,
) => <String, dynamic>{
  'deviceIdentifier': instance.deviceIdentifier,
  'platform': instance.platform,
  'deviceName': instance.deviceName,
  'deviceModel': instance.deviceModel,
  'osVersion': instance.osVersion,
  'appVersion': instance.appVersion,
  'pushProvider': instance.pushProvider,
  'pushToken': instance.pushToken,
};

_DeviceUpdateRequest _$DeviceUpdateRequestFromJson(Map<String, dynamic> json) =>
    _DeviceUpdateRequest(
      deviceName: json['deviceName'] as String?,
      pushToken: json['pushToken'] as String?,
    );

Map<String, dynamic> _$DeviceUpdateRequestToJson(
  _DeviceUpdateRequest instance,
) => <String, dynamic>{
  'deviceName': instance.deviceName,
  'pushToken': instance.pushToken,
};

_SecurityEvent _$SecurityEventFromJson(Map<String, dynamic> json) =>
    _SecurityEvent(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      eventType: json['eventType'] as String,
      eventCategory: json['eventCategory'] as String,
      severity: json['severity'] as String,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SecurityEventToJson(_SecurityEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'eventType': instance.eventType,
      'eventCategory': instance.eventCategory,
      'severity': instance.severity,
      'ipAddress': instance.ipAddress,
      'userAgent': instance.userAgent,
      'metadata': instance.metadata,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_GoogleAuthUrlResponse _$GoogleAuthUrlResponseFromJson(
  Map<String, dynamic> json,
) => _GoogleAuthUrlResponse(
  url: json['url'] as String,
  state: json['state'] as String,
);

Map<String, dynamic> _$GoogleAuthUrlResponseToJson(
  _GoogleAuthUrlResponse instance,
) => <String, dynamic>{'url': instance.url, 'state': instance.state};
