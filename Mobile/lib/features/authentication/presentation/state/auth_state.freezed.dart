// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthState implements DiagnosticableTreeMixin {




@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState()';
}


}

/// @nodoc
class $AuthStateCopyWith<$Res>  {
$AuthStateCopyWith(AuthState _, $Res Function(AuthState) __);
}


/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Unauthenticated value)?  unauthenticated,TResult Function( _Authenticated value)?  authenticated,TResult Function( _MfaRequired value)?  mfaRequired,TResult Function( _MfaEnrollmentRequired value)?  mfaEnrollmentRequired,TResult Function( _VerificationRequired value)?  verificationRequired,TResult Function( _Loading value)?  loading,TResult Function( _Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Unauthenticated() when unauthenticated != null:
return unauthenticated(_that);case _Authenticated() when authenticated != null:
return authenticated(_that);case _MfaRequired() when mfaRequired != null:
return mfaRequired(_that);case _MfaEnrollmentRequired() when mfaEnrollmentRequired != null:
return mfaEnrollmentRequired(_that);case _VerificationRequired() when verificationRequired != null:
return verificationRequired(_that);case _Loading() when loading != null:
return loading(_that);case _Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Unauthenticated value)  unauthenticated,required TResult Function( _Authenticated value)  authenticated,required TResult Function( _MfaRequired value)  mfaRequired,required TResult Function( _MfaEnrollmentRequired value)  mfaEnrollmentRequired,required TResult Function( _VerificationRequired value)  verificationRequired,required TResult Function( _Loading value)  loading,required TResult Function( _Error value)  error,}){
final _that = this;
switch (_that) {
case _Unauthenticated():
return unauthenticated(_that);case _Authenticated():
return authenticated(_that);case _MfaRequired():
return mfaRequired(_that);case _MfaEnrollmentRequired():
return mfaEnrollmentRequired(_that);case _VerificationRequired():
return verificationRequired(_that);case _Loading():
return loading(_that);case _Error():
return error(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Unauthenticated value)?  unauthenticated,TResult? Function( _Authenticated value)?  authenticated,TResult? Function( _MfaRequired value)?  mfaRequired,TResult? Function( _MfaEnrollmentRequired value)?  mfaEnrollmentRequired,TResult? Function( _VerificationRequired value)?  verificationRequired,TResult? Function( _Loading value)?  loading,TResult? Function( _Error value)?  error,}){
final _that = this;
switch (_that) {
case _Unauthenticated() when unauthenticated != null:
return unauthenticated(_that);case _Authenticated() when authenticated != null:
return authenticated(_that);case _MfaRequired() when mfaRequired != null:
return mfaRequired(_that);case _MfaEnrollmentRequired() when mfaEnrollmentRequired != null:
return mfaEnrollmentRequired(_that);case _VerificationRequired() when verificationRequired != null:
return verificationRequired(_that);case _Loading() when loading != null:
return loading(_that);case _Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  unauthenticated,TResult Function( AuthUser user,  String accessToken,  String refreshToken)?  authenticated,TResult Function( String challengeId,  List<String> availableMethods)?  mfaRequired,TResult Function( String enrollmentToken)?  mfaEnrollmentRequired,TResult Function( String verificationType,  AuthUser? user)?  verificationRequired,TResult Function()?  loading,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Unauthenticated() when unauthenticated != null:
return unauthenticated();case _Authenticated() when authenticated != null:
return authenticated(_that.user,_that.accessToken,_that.refreshToken);case _MfaRequired() when mfaRequired != null:
return mfaRequired(_that.challengeId,_that.availableMethods);case _MfaEnrollmentRequired() when mfaEnrollmentRequired != null:
return mfaEnrollmentRequired(_that.enrollmentToken);case _VerificationRequired() when verificationRequired != null:
return verificationRequired(_that.verificationType,_that.user);case _Loading() when loading != null:
return loading();case _Error() when error != null:
return error(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  unauthenticated,required TResult Function( AuthUser user,  String accessToken,  String refreshToken)  authenticated,required TResult Function( String challengeId,  List<String> availableMethods)  mfaRequired,required TResult Function( String enrollmentToken)  mfaEnrollmentRequired,required TResult Function( String verificationType,  AuthUser? user)  verificationRequired,required TResult Function()  loading,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case _Unauthenticated():
return unauthenticated();case _Authenticated():
return authenticated(_that.user,_that.accessToken,_that.refreshToken);case _MfaRequired():
return mfaRequired(_that.challengeId,_that.availableMethods);case _MfaEnrollmentRequired():
return mfaEnrollmentRequired(_that.enrollmentToken);case _VerificationRequired():
return verificationRequired(_that.verificationType,_that.user);case _Loading():
return loading();case _Error():
return error(_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  unauthenticated,TResult? Function( AuthUser user,  String accessToken,  String refreshToken)?  authenticated,TResult? Function( String challengeId,  List<String> availableMethods)?  mfaRequired,TResult? Function( String enrollmentToken)?  mfaEnrollmentRequired,TResult? Function( String verificationType,  AuthUser? user)?  verificationRequired,TResult? Function()?  loading,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case _Unauthenticated() when unauthenticated != null:
return unauthenticated();case _Authenticated() when authenticated != null:
return authenticated(_that.user,_that.accessToken,_that.refreshToken);case _MfaRequired() when mfaRequired != null:
return mfaRequired(_that.challengeId,_that.availableMethods);case _MfaEnrollmentRequired() when mfaEnrollmentRequired != null:
return mfaEnrollmentRequired(_that.enrollmentToken);case _VerificationRequired() when verificationRequired != null:
return verificationRequired(_that.verificationType,_that.user);case _Loading() when loading != null:
return loading();case _Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _Unauthenticated with DiagnosticableTreeMixin implements AuthState {
  const _Unauthenticated();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.unauthenticated'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Unauthenticated);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.unauthenticated()';
}


}




/// @nodoc


class _Authenticated with DiagnosticableTreeMixin implements AuthState {
  const _Authenticated({required this.user, required this.accessToken, required this.refreshToken});
  

 final  AuthUser user;
 final  String accessToken;
 final  String refreshToken;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthenticatedCopyWith<_Authenticated> get copyWith => __$AuthenticatedCopyWithImpl<_Authenticated>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.authenticated'))
    ..add(DiagnosticsProperty('user', user))..add(DiagnosticsProperty('accessToken', accessToken))..add(DiagnosticsProperty('refreshToken', refreshToken));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Authenticated&&(identical(other.user, user) || other.user == user)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}


@override
int get hashCode {
    return Object.hash(runtimeType,user,accessToken,refreshToken);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.authenticated(user: $user, accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$AuthenticatedCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$AuthenticatedCopyWith(_Authenticated value, $Res Function(_Authenticated) _then) = __$AuthenticatedCopyWithImpl;
@useResult
$Res call({
 AuthUser user, String accessToken, String refreshToken
});


$AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class __$AuthenticatedCopyWithImpl<$Res>
    implements _$AuthenticatedCopyWith<$Res> {
  __$AuthenticatedCopyWithImpl(this._self, this._then);

  final _Authenticated _self;
  final $Res Function(_Authenticated) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = null,Object? accessToken = null,Object? refreshToken = null,}) {
  return _then(_Authenticated(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res> get user {
  
  return $AuthUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

/// @nodoc


class _MfaRequired with DiagnosticableTreeMixin implements AuthState {
  const _MfaRequired({required this.challengeId, required  List<String> availableMethods}): _availableMethods = availableMethods;
  

 final  String challengeId;
 final  List<String> _availableMethods;
 List<String> get availableMethods {
  if (_availableMethods is EqualUnmodifiableListView) return _availableMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableMethods);
}


/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaRequiredCopyWith<_MfaRequired> get copyWith => __$MfaRequiredCopyWithImpl<_MfaRequired>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.mfaRequired'))
    ..add(DiagnosticsProperty('challengeId', challengeId))..add(DiagnosticsProperty('availableMethods', availableMethods));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaRequired&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&const DeepCollectionEquality().equals(other.availableMethods, _availableMethods));
}


@override
int get hashCode {
    return Object.hash(runtimeType,challengeId,const DeepCollectionEquality().hash(_availableMethods));
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.mfaRequired(challengeId: $challengeId, availableMethods: $availableMethods)';
}


}

/// @nodoc
abstract mixin class _$MfaRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$MfaRequiredCopyWith(_MfaRequired value, $Res Function(_MfaRequired) _then) = __$MfaRequiredCopyWithImpl;
@useResult
$Res call({
 String challengeId, List<String> availableMethods
});




}
/// @nodoc
class __$MfaRequiredCopyWithImpl<$Res>
    implements _$MfaRequiredCopyWith<$Res> {
  __$MfaRequiredCopyWithImpl(this._self, this._then);

  final _MfaRequired _self;
  final $Res Function(_MfaRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? availableMethods = null,}) {
  return _then(_MfaRequired(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,availableMethods: null == availableMethods ? _self._availableMethods : availableMethods // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class _MfaEnrollmentRequired with DiagnosticableTreeMixin implements AuthState {
  const _MfaEnrollmentRequired({required this.enrollmentToken});
  

 final  String enrollmentToken;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaEnrollmentRequiredCopyWith<_MfaEnrollmentRequired> get copyWith => __$MfaEnrollmentRequiredCopyWithImpl<_MfaEnrollmentRequired>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.mfaEnrollmentRequired'))
    ..add(DiagnosticsProperty('enrollmentToken', enrollmentToken));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaEnrollmentRequired&&(identical(other.enrollmentToken, enrollmentToken) || other.enrollmentToken == enrollmentToken));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enrollmentToken);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.mfaEnrollmentRequired(enrollmentToken: $enrollmentToken)';
}


}

/// @nodoc
abstract mixin class _$MfaEnrollmentRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$MfaEnrollmentRequiredCopyWith(_MfaEnrollmentRequired value, $Res Function(_MfaEnrollmentRequired) _then) = __$MfaEnrollmentRequiredCopyWithImpl;
@useResult
$Res call({
 String enrollmentToken
});




}
/// @nodoc
class __$MfaEnrollmentRequiredCopyWithImpl<$Res>
    implements _$MfaEnrollmentRequiredCopyWith<$Res> {
  __$MfaEnrollmentRequiredCopyWithImpl(this._self, this._then);

  final _MfaEnrollmentRequired _self;
  final $Res Function(_MfaEnrollmentRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? enrollmentToken = null,}) {
  return _then(_MfaEnrollmentRequired(
enrollmentToken: null == enrollmentToken ? _self.enrollmentToken : enrollmentToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerificationRequired with DiagnosticableTreeMixin implements AuthState {
  const _VerificationRequired({required this.verificationType, this.user});
  

 final  String verificationType;
 final  AuthUser? user;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerificationRequiredCopyWith<_VerificationRequired> get copyWith => __$VerificationRequiredCopyWithImpl<_VerificationRequired>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.verificationRequired'))
    ..add(DiagnosticsProperty('verificationType', verificationType))..add(DiagnosticsProperty('user', user));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerificationRequired&&(identical(other.verificationType, verificationType) || other.verificationType == verificationType)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode {
    return Object.hash(runtimeType,verificationType,user);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.verificationRequired(verificationType: $verificationType, user: $user)';
}


}

/// @nodoc
abstract mixin class _$VerificationRequiredCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$VerificationRequiredCopyWith(_VerificationRequired value, $Res Function(_VerificationRequired) _then) = __$VerificationRequiredCopyWithImpl;
@useResult
$Res call({
 String verificationType, AuthUser? user
});


$AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class __$VerificationRequiredCopyWithImpl<$Res>
    implements _$VerificationRequiredCopyWith<$Res> {
  __$VerificationRequiredCopyWithImpl(this._self, this._then);

  final _VerificationRequired _self;
  final $Res Function(_VerificationRequired) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? verificationType = null,Object? user = freezed,}) {
  return _then(_VerificationRequired(
verificationType: null == verificationType ? _self.verificationType : verificationType // ignore: cast_nullable_to_non_nullable
as String,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $AuthUserCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

/// @nodoc


class _Loading with DiagnosticableTreeMixin implements AuthState {
  const _Loading();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.loading'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Loading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.loading()';
}


}




/// @nodoc


class _Error with DiagnosticableTreeMixin implements AuthState {
  const _Error({required this.message});
  

 final  String message;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthState.error'))
    ..add(DiagnosticsProperty('message', message));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AuthAction implements DiagnosticableTreeMixin {




@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthAction);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction()';
}


}

/// @nodoc
class $AuthActionCopyWith<$Res>  {
$AuthActionCopyWith(AuthAction _, $Res Function(AuthAction) __);
}


/// Adds pattern-matching-related methods to [AuthAction].
extension AuthActionPatterns on AuthAction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Login value)?  login,TResult Function( _LoginWithPhone value)?  loginWithPhone,TResult Function( _LoginWithGoogle value)?  loginWithGoogle,TResult Function( _RegisterWithGoogle value)?  registerWithGoogle,TResult Function( _RegisterEmail value)?  registerEmail,TResult Function( _RegisterPhone value)?  registerPhone,TResult Function( _RegisterPhoneOtp value)?  registerPhoneOtp,TResult Function( _RequestEmailOtp value)?  requestEmailOtp,TResult Function( _VerifyEmailOtp value)?  verifyEmailOtp,TResult Function( _RequestPhoneOtp value)?  requestPhoneOtp,TResult Function( _VerifyPhoneOtp value)?  verifyPhoneOtp,TResult Function( _VerifyMfa value)?  verifyMfa,TResult Function( _VerifyMfaRecoveryCode value)?  verifyMfaRecoveryCode,TResult Function( _StartMfaEnrollment value)?  startMfaEnrollment,TResult Function( _VerifyMfaEnrollment value)?  verifyMfaEnrollment,TResult Function( _SkipMfaEnrollment value)?  skipMfaEnrollment,TResult Function( _RefreshToken value)?  refreshToken,TResult Function( _Logout value)?  logout,TResult Function( _LogoutAll value)?  logoutAll,TResult Function( _RestoreSession value)?  restoreSession,TResult Function( _RequestPasswordReset value)?  requestPasswordReset,TResult Function( _ResetPassword value)?  resetPassword,TResult Function( _RequestEmailVerification value)?  requestEmailVerification,TResult Function( _ConfirmEmailVerification value)?  confirmEmailVerification,TResult Function( _RequestPhoneVerification value)?  requestPhoneVerification,TResult Function( _ConfirmPhoneVerification value)?  confirmPhoneVerification,TResult Function( _RegisterDevice value)?  registerDevice,TResult Function( _GetDevices value)?  getDevices,TResult Function( _RevokeDevice value)?  revokeDevice,TResult Function( _GetSessions value)?  getSessions,TResult Function( _RevokeSession value)?  revokeSession,TResult Function( _GetMfaStatus value)?  getMfaStatus,TResult Function( _GetMfaMethods value)?  getMfaMethods,TResult Function( _AddMfaMethod value)?  addMfaMethod,TResult Function( _VerifyMfaMethod value)?  verifyMfaMethod,TResult Function( _DisableMfaMethod value)?  disableMfaMethod,TResult Function( _SetPrimaryMfaMethod value)?  setPrimaryMfaMethod,TResult Function( _RegenerateRecoveryCodes value)?  regenerateRecoveryCodes,TResult Function( _RequestAccountRecoveryEmail value)?  requestAccountRecoveryEmail,TResult Function( _RequestAccountRecoveryPhone value)?  requestAccountRecoveryPhone,TResult Function( _VerifyAccountRecovery value)?  verifyAccountRecovery,TResult Function( _GetSecurityEvents value)?  getSecurityEvents,TResult Function( _LinkGoogle value)?  linkGoogle,TResult Function( _UnlinkGoogle value)?  unlinkGoogle,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Login() when login != null:
return login(_that);case _LoginWithPhone() when loginWithPhone != null:
return loginWithPhone(_that);case _LoginWithGoogle() when loginWithGoogle != null:
return loginWithGoogle(_that);case _RegisterWithGoogle() when registerWithGoogle != null:
return registerWithGoogle(_that);case _RegisterEmail() when registerEmail != null:
return registerEmail(_that);case _RegisterPhone() when registerPhone != null:
return registerPhone(_that);case _RegisterPhoneOtp() when registerPhoneOtp != null:
return registerPhoneOtp(_that);case _RequestEmailOtp() when requestEmailOtp != null:
return requestEmailOtp(_that);case _VerifyEmailOtp() when verifyEmailOtp != null:
return verifyEmailOtp(_that);case _RequestPhoneOtp() when requestPhoneOtp != null:
return requestPhoneOtp(_that);case _VerifyPhoneOtp() when verifyPhoneOtp != null:
return verifyPhoneOtp(_that);case _VerifyMfa() when verifyMfa != null:
return verifyMfa(_that);case _VerifyMfaRecoveryCode() when verifyMfaRecoveryCode != null:
return verifyMfaRecoveryCode(_that);case _StartMfaEnrollment() when startMfaEnrollment != null:
return startMfaEnrollment(_that);case _VerifyMfaEnrollment() when verifyMfaEnrollment != null:
return verifyMfaEnrollment(_that);case _SkipMfaEnrollment() when skipMfaEnrollment != null:
return skipMfaEnrollment(_that);case _RefreshToken() when refreshToken != null:
return refreshToken(_that);case _Logout() when logout != null:
return logout(_that);case _LogoutAll() when logoutAll != null:
return logoutAll(_that);case _RestoreSession() when restoreSession != null:
return restoreSession(_that);case _RequestPasswordReset() when requestPasswordReset != null:
return requestPasswordReset(_that);case _ResetPassword() when resetPassword != null:
return resetPassword(_that);case _RequestEmailVerification() when requestEmailVerification != null:
return requestEmailVerification(_that);case _ConfirmEmailVerification() when confirmEmailVerification != null:
return confirmEmailVerification(_that);case _RequestPhoneVerification() when requestPhoneVerification != null:
return requestPhoneVerification(_that);case _ConfirmPhoneVerification() when confirmPhoneVerification != null:
return confirmPhoneVerification(_that);case _RegisterDevice() when registerDevice != null:
return registerDevice(_that);case _GetDevices() when getDevices != null:
return getDevices(_that);case _RevokeDevice() when revokeDevice != null:
return revokeDevice(_that);case _GetSessions() when getSessions != null:
return getSessions(_that);case _RevokeSession() when revokeSession != null:
return revokeSession(_that);case _GetMfaStatus() when getMfaStatus != null:
return getMfaStatus(_that);case _GetMfaMethods() when getMfaMethods != null:
return getMfaMethods(_that);case _AddMfaMethod() when addMfaMethod != null:
return addMfaMethod(_that);case _VerifyMfaMethod() when verifyMfaMethod != null:
return verifyMfaMethod(_that);case _DisableMfaMethod() when disableMfaMethod != null:
return disableMfaMethod(_that);case _SetPrimaryMfaMethod() when setPrimaryMfaMethod != null:
return setPrimaryMfaMethod(_that);case _RegenerateRecoveryCodes() when regenerateRecoveryCodes != null:
return regenerateRecoveryCodes(_that);case _RequestAccountRecoveryEmail() when requestAccountRecoveryEmail != null:
return requestAccountRecoveryEmail(_that);case _RequestAccountRecoveryPhone() when requestAccountRecoveryPhone != null:
return requestAccountRecoveryPhone(_that);case _VerifyAccountRecovery() when verifyAccountRecovery != null:
return verifyAccountRecovery(_that);case _GetSecurityEvents() when getSecurityEvents != null:
return getSecurityEvents(_that);case _LinkGoogle() when linkGoogle != null:
return linkGoogle(_that);case _UnlinkGoogle() when unlinkGoogle != null:
return unlinkGoogle(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Login value)  login,required TResult Function( _LoginWithPhone value)  loginWithPhone,required TResult Function( _LoginWithGoogle value)  loginWithGoogle,required TResult Function( _RegisterWithGoogle value)  registerWithGoogle,required TResult Function( _RegisterEmail value)  registerEmail,required TResult Function( _RegisterPhone value)  registerPhone,required TResult Function( _RegisterPhoneOtp value)  registerPhoneOtp,required TResult Function( _RequestEmailOtp value)  requestEmailOtp,required TResult Function( _VerifyEmailOtp value)  verifyEmailOtp,required TResult Function( _RequestPhoneOtp value)  requestPhoneOtp,required TResult Function( _VerifyPhoneOtp value)  verifyPhoneOtp,required TResult Function( _VerifyMfa value)  verifyMfa,required TResult Function( _VerifyMfaRecoveryCode value)  verifyMfaRecoveryCode,required TResult Function( _StartMfaEnrollment value)  startMfaEnrollment,required TResult Function( _VerifyMfaEnrollment value)  verifyMfaEnrollment,required TResult Function( _SkipMfaEnrollment value)  skipMfaEnrollment,required TResult Function( _RefreshToken value)  refreshToken,required TResult Function( _Logout value)  logout,required TResult Function( _LogoutAll value)  logoutAll,required TResult Function( _RestoreSession value)  restoreSession,required TResult Function( _RequestPasswordReset value)  requestPasswordReset,required TResult Function( _ResetPassword value)  resetPassword,required TResult Function( _RequestEmailVerification value)  requestEmailVerification,required TResult Function( _ConfirmEmailVerification value)  confirmEmailVerification,required TResult Function( _RequestPhoneVerification value)  requestPhoneVerification,required TResult Function( _ConfirmPhoneVerification value)  confirmPhoneVerification,required TResult Function( _RegisterDevice value)  registerDevice,required TResult Function( _GetDevices value)  getDevices,required TResult Function( _RevokeDevice value)  revokeDevice,required TResult Function( _GetSessions value)  getSessions,required TResult Function( _RevokeSession value)  revokeSession,required TResult Function( _GetMfaStatus value)  getMfaStatus,required TResult Function( _GetMfaMethods value)  getMfaMethods,required TResult Function( _AddMfaMethod value)  addMfaMethod,required TResult Function( _VerifyMfaMethod value)  verifyMfaMethod,required TResult Function( _DisableMfaMethod value)  disableMfaMethod,required TResult Function( _SetPrimaryMfaMethod value)  setPrimaryMfaMethod,required TResult Function( _RegenerateRecoveryCodes value)  regenerateRecoveryCodes,required TResult Function( _RequestAccountRecoveryEmail value)  requestAccountRecoveryEmail,required TResult Function( _RequestAccountRecoveryPhone value)  requestAccountRecoveryPhone,required TResult Function( _VerifyAccountRecovery value)  verifyAccountRecovery,required TResult Function( _GetSecurityEvents value)  getSecurityEvents,required TResult Function( _LinkGoogle value)  linkGoogle,required TResult Function( _UnlinkGoogle value)  unlinkGoogle,}){
final _that = this;
switch (_that) {
case _Login():
return login(_that);case _LoginWithPhone():
return loginWithPhone(_that);case _LoginWithGoogle():
return loginWithGoogle(_that);case _RegisterWithGoogle():
return registerWithGoogle(_that);case _RegisterEmail():
return registerEmail(_that);case _RegisterPhone():
return registerPhone(_that);case _RegisterPhoneOtp():
return registerPhoneOtp(_that);case _RequestEmailOtp():
return requestEmailOtp(_that);case _VerifyEmailOtp():
return verifyEmailOtp(_that);case _RequestPhoneOtp():
return requestPhoneOtp(_that);case _VerifyPhoneOtp():
return verifyPhoneOtp(_that);case _VerifyMfa():
return verifyMfa(_that);case _VerifyMfaRecoveryCode():
return verifyMfaRecoveryCode(_that);case _StartMfaEnrollment():
return startMfaEnrollment(_that);case _VerifyMfaEnrollment():
return verifyMfaEnrollment(_that);case _SkipMfaEnrollment():
return skipMfaEnrollment(_that);case _RefreshToken():
return refreshToken(_that);case _Logout():
return logout(_that);case _LogoutAll():
return logoutAll(_that);case _RestoreSession():
return restoreSession(_that);case _RequestPasswordReset():
return requestPasswordReset(_that);case _ResetPassword():
return resetPassword(_that);case _RequestEmailVerification():
return requestEmailVerification(_that);case _ConfirmEmailVerification():
return confirmEmailVerification(_that);case _RequestPhoneVerification():
return requestPhoneVerification(_that);case _ConfirmPhoneVerification():
return confirmPhoneVerification(_that);case _RegisterDevice():
return registerDevice(_that);case _GetDevices():
return getDevices(_that);case _RevokeDevice():
return revokeDevice(_that);case _GetSessions():
return getSessions(_that);case _RevokeSession():
return revokeSession(_that);case _GetMfaStatus():
return getMfaStatus(_that);case _GetMfaMethods():
return getMfaMethods(_that);case _AddMfaMethod():
return addMfaMethod(_that);case _VerifyMfaMethod():
return verifyMfaMethod(_that);case _DisableMfaMethod():
return disableMfaMethod(_that);case _SetPrimaryMfaMethod():
return setPrimaryMfaMethod(_that);case _RegenerateRecoveryCodes():
return regenerateRecoveryCodes(_that);case _RequestAccountRecoveryEmail():
return requestAccountRecoveryEmail(_that);case _RequestAccountRecoveryPhone():
return requestAccountRecoveryPhone(_that);case _VerifyAccountRecovery():
return verifyAccountRecovery(_that);case _GetSecurityEvents():
return getSecurityEvents(_that);case _LinkGoogle():
return linkGoogle(_that);case _UnlinkGoogle():
return unlinkGoogle(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Login value)?  login,TResult? Function( _LoginWithPhone value)?  loginWithPhone,TResult? Function( _LoginWithGoogle value)?  loginWithGoogle,TResult? Function( _RegisterWithGoogle value)?  registerWithGoogle,TResult? Function( _RegisterEmail value)?  registerEmail,TResult? Function( _RegisterPhone value)?  registerPhone,TResult? Function( _RegisterPhoneOtp value)?  registerPhoneOtp,TResult? Function( _RequestEmailOtp value)?  requestEmailOtp,TResult? Function( _VerifyEmailOtp value)?  verifyEmailOtp,TResult? Function( _RequestPhoneOtp value)?  requestPhoneOtp,TResult? Function( _VerifyPhoneOtp value)?  verifyPhoneOtp,TResult? Function( _VerifyMfa value)?  verifyMfa,TResult? Function( _VerifyMfaRecoveryCode value)?  verifyMfaRecoveryCode,TResult? Function( _StartMfaEnrollment value)?  startMfaEnrollment,TResult? Function( _VerifyMfaEnrollment value)?  verifyMfaEnrollment,TResult? Function( _SkipMfaEnrollment value)?  skipMfaEnrollment,TResult? Function( _RefreshToken value)?  refreshToken,TResult? Function( _Logout value)?  logout,TResult? Function( _LogoutAll value)?  logoutAll,TResult? Function( _RestoreSession value)?  restoreSession,TResult? Function( _RequestPasswordReset value)?  requestPasswordReset,TResult? Function( _ResetPassword value)?  resetPassword,TResult? Function( _RequestEmailVerification value)?  requestEmailVerification,TResult? Function( _ConfirmEmailVerification value)?  confirmEmailVerification,TResult? Function( _RequestPhoneVerification value)?  requestPhoneVerification,TResult? Function( _ConfirmPhoneVerification value)?  confirmPhoneVerification,TResult? Function( _RegisterDevice value)?  registerDevice,TResult? Function( _GetDevices value)?  getDevices,TResult? Function( _RevokeDevice value)?  revokeDevice,TResult? Function( _GetSessions value)?  getSessions,TResult? Function( _RevokeSession value)?  revokeSession,TResult? Function( _GetMfaStatus value)?  getMfaStatus,TResult? Function( _GetMfaMethods value)?  getMfaMethods,TResult? Function( _AddMfaMethod value)?  addMfaMethod,TResult? Function( _VerifyMfaMethod value)?  verifyMfaMethod,TResult? Function( _DisableMfaMethod value)?  disableMfaMethod,TResult? Function( _SetPrimaryMfaMethod value)?  setPrimaryMfaMethod,TResult? Function( _RegenerateRecoveryCodes value)?  regenerateRecoveryCodes,TResult? Function( _RequestAccountRecoveryEmail value)?  requestAccountRecoveryEmail,TResult? Function( _RequestAccountRecoveryPhone value)?  requestAccountRecoveryPhone,TResult? Function( _VerifyAccountRecovery value)?  verifyAccountRecovery,TResult? Function( _GetSecurityEvents value)?  getSecurityEvents,TResult? Function( _LinkGoogle value)?  linkGoogle,TResult? Function( _UnlinkGoogle value)?  unlinkGoogle,}){
final _that = this;
switch (_that) {
case _Login() when login != null:
return login(_that);case _LoginWithPhone() when loginWithPhone != null:
return loginWithPhone(_that);case _LoginWithGoogle() when loginWithGoogle != null:
return loginWithGoogle(_that);case _RegisterWithGoogle() when registerWithGoogle != null:
return registerWithGoogle(_that);case _RegisterEmail() when registerEmail != null:
return registerEmail(_that);case _RegisterPhone() when registerPhone != null:
return registerPhone(_that);case _RegisterPhoneOtp() when registerPhoneOtp != null:
return registerPhoneOtp(_that);case _RequestEmailOtp() when requestEmailOtp != null:
return requestEmailOtp(_that);case _VerifyEmailOtp() when verifyEmailOtp != null:
return verifyEmailOtp(_that);case _RequestPhoneOtp() when requestPhoneOtp != null:
return requestPhoneOtp(_that);case _VerifyPhoneOtp() when verifyPhoneOtp != null:
return verifyPhoneOtp(_that);case _VerifyMfa() when verifyMfa != null:
return verifyMfa(_that);case _VerifyMfaRecoveryCode() when verifyMfaRecoveryCode != null:
return verifyMfaRecoveryCode(_that);case _StartMfaEnrollment() when startMfaEnrollment != null:
return startMfaEnrollment(_that);case _VerifyMfaEnrollment() when verifyMfaEnrollment != null:
return verifyMfaEnrollment(_that);case _SkipMfaEnrollment() when skipMfaEnrollment != null:
return skipMfaEnrollment(_that);case _RefreshToken() when refreshToken != null:
return refreshToken(_that);case _Logout() when logout != null:
return logout(_that);case _LogoutAll() when logoutAll != null:
return logoutAll(_that);case _RestoreSession() when restoreSession != null:
return restoreSession(_that);case _RequestPasswordReset() when requestPasswordReset != null:
return requestPasswordReset(_that);case _ResetPassword() when resetPassword != null:
return resetPassword(_that);case _RequestEmailVerification() when requestEmailVerification != null:
return requestEmailVerification(_that);case _ConfirmEmailVerification() when confirmEmailVerification != null:
return confirmEmailVerification(_that);case _RequestPhoneVerification() when requestPhoneVerification != null:
return requestPhoneVerification(_that);case _ConfirmPhoneVerification() when confirmPhoneVerification != null:
return confirmPhoneVerification(_that);case _RegisterDevice() when registerDevice != null:
return registerDevice(_that);case _GetDevices() when getDevices != null:
return getDevices(_that);case _RevokeDevice() when revokeDevice != null:
return revokeDevice(_that);case _GetSessions() when getSessions != null:
return getSessions(_that);case _RevokeSession() when revokeSession != null:
return revokeSession(_that);case _GetMfaStatus() when getMfaStatus != null:
return getMfaStatus(_that);case _GetMfaMethods() when getMfaMethods != null:
return getMfaMethods(_that);case _AddMfaMethod() when addMfaMethod != null:
return addMfaMethod(_that);case _VerifyMfaMethod() when verifyMfaMethod != null:
return verifyMfaMethod(_that);case _DisableMfaMethod() when disableMfaMethod != null:
return disableMfaMethod(_that);case _SetPrimaryMfaMethod() when setPrimaryMfaMethod != null:
return setPrimaryMfaMethod(_that);case _RegenerateRecoveryCodes() when regenerateRecoveryCodes != null:
return regenerateRecoveryCodes(_that);case _RequestAccountRecoveryEmail() when requestAccountRecoveryEmail != null:
return requestAccountRecoveryEmail(_that);case _RequestAccountRecoveryPhone() when requestAccountRecoveryPhone != null:
return requestAccountRecoveryPhone(_that);case _VerifyAccountRecovery() when verifyAccountRecovery != null:
return verifyAccountRecovery(_that);case _GetSecurityEvents() when getSecurityEvents != null:
return getSecurityEvents(_that);case _LinkGoogle() when linkGoogle != null:
return linkGoogle(_that);case _UnlinkGoogle() when unlinkGoogle != null:
return unlinkGoogle(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email,  String password)?  login,TResult Function( String phone,  String password)?  loginWithPhone,TResult Function()?  loginWithGoogle,TResult Function( String role)?  registerWithGoogle,TResult Function( String firstName,  String lastName,  String email,  String password,  String role,  bool termsAccepted)?  registerEmail,TResult Function( String firstName,  String lastName,  String phone,  String password,  String role,  bool termsAccepted)?  registerPhone,TResult Function( String firstName,  String lastName,  String phone,  String role,  bool termsAccepted)?  registerPhoneOtp,TResult Function( String email)?  requestEmailOtp,TResult Function( String email,  String otp)?  verifyEmailOtp,TResult Function( String phone)?  requestPhoneOtp,TResult Function( String phone,  String otp)?  verifyPhoneOtp,TResult Function( String challengeId,  String totpCode)?  verifyMfa,TResult Function( String challengeId,  String recoveryCode)?  verifyMfaRecoveryCode,TResult Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)?  startMfaEnrollment,TResult Function( String methodId,  String code)?  verifyMfaEnrollment,TResult Function()?  skipMfaEnrollment,TResult Function()?  refreshToken,TResult Function()?  logout,TResult Function()?  logoutAll,TResult Function()?  restoreSession,TResult Function( String email)?  requestPasswordReset,TResult Function( String token,  String password)?  resetPassword,TResult Function( String email)?  requestEmailVerification,TResult Function( String email,  String code)?  confirmEmailVerification,TResult Function( String phone)?  requestPhoneVerification,TResult Function( String phone,  String code)?  confirmPhoneVerification,TResult Function( Map<String, dynamic> deviceData)?  registerDevice,TResult Function()?  getDevices,TResult Function( String deviceId)?  revokeDevice,TResult Function()?  getSessions,TResult Function( String sessionId)?  revokeSession,TResult Function()?  getMfaStatus,TResult Function()?  getMfaMethods,TResult Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)?  addMfaMethod,TResult Function( String methodId,  String code)?  verifyMfaMethod,TResult Function( String methodId,  String verificationCode)?  disableMfaMethod,TResult Function( String methodId,  String verificationCode)?  setPrimaryMfaMethod,TResult Function( String verificationCode)?  regenerateRecoveryCodes,TResult Function( String email)?  requestAccountRecoveryEmail,TResult Function( String phone)?  requestAccountRecoveryPhone,TResult Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)?  verifyAccountRecovery,TResult Function( int? limit,  int? offset)?  getSecurityEvents,TResult Function( String idToken)?  linkGoogle,TResult Function( String password)?  unlinkGoogle,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Login() when login != null:
return login(_that.email,_that.password);case _LoginWithPhone() when loginWithPhone != null:
return loginWithPhone(_that.phone,_that.password);case _LoginWithGoogle() when loginWithGoogle != null:
return loginWithGoogle();case _RegisterWithGoogle() when registerWithGoogle != null:
return registerWithGoogle(_that.role);case _RegisterEmail() when registerEmail != null:
return registerEmail(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case _RegisterPhone() when registerPhone != null:
return registerPhone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case _RegisterPhoneOtp() when registerPhoneOtp != null:
return registerPhoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case _RequestEmailOtp() when requestEmailOtp != null:
return requestEmailOtp(_that.email);case _VerifyEmailOtp() when verifyEmailOtp != null:
return verifyEmailOtp(_that.email,_that.otp);case _RequestPhoneOtp() when requestPhoneOtp != null:
return requestPhoneOtp(_that.phone);case _VerifyPhoneOtp() when verifyPhoneOtp != null:
return verifyPhoneOtp(_that.phone,_that.otp);case _VerifyMfa() when verifyMfa != null:
return verifyMfa(_that.challengeId,_that.totpCode);case _VerifyMfaRecoveryCode() when verifyMfaRecoveryCode != null:
return verifyMfaRecoveryCode(_that.challengeId,_that.recoveryCode);case _StartMfaEnrollment() when startMfaEnrollment != null:
return startMfaEnrollment(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaEnrollment() when verifyMfaEnrollment != null:
return verifyMfaEnrollment(_that.methodId,_that.code);case _SkipMfaEnrollment() when skipMfaEnrollment != null:
return skipMfaEnrollment();case _RefreshToken() when refreshToken != null:
return refreshToken();case _Logout() when logout != null:
return logout();case _LogoutAll() when logoutAll != null:
return logoutAll();case _RestoreSession() when restoreSession != null:
return restoreSession();case _RequestPasswordReset() when requestPasswordReset != null:
return requestPasswordReset(_that.email);case _ResetPassword() when resetPassword != null:
return resetPassword(_that.token,_that.password);case _RequestEmailVerification() when requestEmailVerification != null:
return requestEmailVerification(_that.email);case _ConfirmEmailVerification() when confirmEmailVerification != null:
return confirmEmailVerification(_that.email,_that.code);case _RequestPhoneVerification() when requestPhoneVerification != null:
return requestPhoneVerification(_that.phone);case _ConfirmPhoneVerification() when confirmPhoneVerification != null:
return confirmPhoneVerification(_that.phone,_that.code);case _RegisterDevice() when registerDevice != null:
return registerDevice(_that.deviceData);case _GetDevices() when getDevices != null:
return getDevices();case _RevokeDevice() when revokeDevice != null:
return revokeDevice(_that.deviceId);case _GetSessions() when getSessions != null:
return getSessions();case _RevokeSession() when revokeSession != null:
return revokeSession(_that.sessionId);case _GetMfaStatus() when getMfaStatus != null:
return getMfaStatus();case _GetMfaMethods() when getMfaMethods != null:
return getMfaMethods();case _AddMfaMethod() when addMfaMethod != null:
return addMfaMethod(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaMethod() when verifyMfaMethod != null:
return verifyMfaMethod(_that.methodId,_that.code);case _DisableMfaMethod() when disableMfaMethod != null:
return disableMfaMethod(_that.methodId,_that.verificationCode);case _SetPrimaryMfaMethod() when setPrimaryMfaMethod != null:
return setPrimaryMfaMethod(_that.methodId,_that.verificationCode);case _RegenerateRecoveryCodes() when regenerateRecoveryCodes != null:
return regenerateRecoveryCodes(_that.verificationCode);case _RequestAccountRecoveryEmail() when requestAccountRecoveryEmail != null:
return requestAccountRecoveryEmail(_that.email);case _RequestAccountRecoveryPhone() when requestAccountRecoveryPhone != null:
return requestAccountRecoveryPhone(_that.phone);case _VerifyAccountRecovery() when verifyAccountRecovery != null:
return verifyAccountRecovery(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _GetSecurityEvents() when getSecurityEvents != null:
return getSecurityEvents(_that.limit,_that.offset);case _LinkGoogle() when linkGoogle != null:
return linkGoogle(_that.idToken);case _UnlinkGoogle() when unlinkGoogle != null:
return unlinkGoogle(_that.password);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email,  String password)  login,required TResult Function( String phone,  String password)  loginWithPhone,required TResult Function()  loginWithGoogle,required TResult Function( String role)  registerWithGoogle,required TResult Function( String firstName,  String lastName,  String email,  String password,  String role,  bool termsAccepted)  registerEmail,required TResult Function( String firstName,  String lastName,  String phone,  String password,  String role,  bool termsAccepted)  registerPhone,required TResult Function( String firstName,  String lastName,  String phone,  String role,  bool termsAccepted)  registerPhoneOtp,required TResult Function( String email)  requestEmailOtp,required TResult Function( String email,  String otp)  verifyEmailOtp,required TResult Function( String phone)  requestPhoneOtp,required TResult Function( String phone,  String otp)  verifyPhoneOtp,required TResult Function( String challengeId,  String totpCode)  verifyMfa,required TResult Function( String challengeId,  String recoveryCode)  verifyMfaRecoveryCode,required TResult Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)  startMfaEnrollment,required TResult Function( String methodId,  String code)  verifyMfaEnrollment,required TResult Function()  skipMfaEnrollment,required TResult Function()  refreshToken,required TResult Function()  logout,required TResult Function()  logoutAll,required TResult Function()  restoreSession,required TResult Function( String email)  requestPasswordReset,required TResult Function( String token,  String password)  resetPassword,required TResult Function( String email)  requestEmailVerification,required TResult Function( String email,  String code)  confirmEmailVerification,required TResult Function( String phone)  requestPhoneVerification,required TResult Function( String phone,  String code)  confirmPhoneVerification,required TResult Function( Map<String, dynamic> deviceData)  registerDevice,required TResult Function()  getDevices,required TResult Function( String deviceId)  revokeDevice,required TResult Function()  getSessions,required TResult Function( String sessionId)  revokeSession,required TResult Function()  getMfaStatus,required TResult Function()  getMfaMethods,required TResult Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)  addMfaMethod,required TResult Function( String methodId,  String code)  verifyMfaMethod,required TResult Function( String methodId,  String verificationCode)  disableMfaMethod,required TResult Function( String methodId,  String verificationCode)  setPrimaryMfaMethod,required TResult Function( String verificationCode)  regenerateRecoveryCodes,required TResult Function( String email)  requestAccountRecoveryEmail,required TResult Function( String phone)  requestAccountRecoveryPhone,required TResult Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)  verifyAccountRecovery,required TResult Function( int? limit,  int? offset)  getSecurityEvents,required TResult Function( String idToken)  linkGoogle,required TResult Function( String password)  unlinkGoogle,}) {final _that = this;
switch (_that) {
case _Login():
return login(_that.email,_that.password);case _LoginWithPhone():
return loginWithPhone(_that.phone,_that.password);case _LoginWithGoogle():
return loginWithGoogle();case _RegisterWithGoogle():
return registerWithGoogle(_that.role);case _RegisterEmail():
return registerEmail(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case _RegisterPhone():
return registerPhone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case _RegisterPhoneOtp():
return registerPhoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case _RequestEmailOtp():
return requestEmailOtp(_that.email);case _VerifyEmailOtp():
return verifyEmailOtp(_that.email,_that.otp);case _RequestPhoneOtp():
return requestPhoneOtp(_that.phone);case _VerifyPhoneOtp():
return verifyPhoneOtp(_that.phone,_that.otp);case _VerifyMfa():
return verifyMfa(_that.challengeId,_that.totpCode);case _VerifyMfaRecoveryCode():
return verifyMfaRecoveryCode(_that.challengeId,_that.recoveryCode);case _StartMfaEnrollment():
return startMfaEnrollment(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaEnrollment():
return verifyMfaEnrollment(_that.methodId,_that.code);case _SkipMfaEnrollment():
return skipMfaEnrollment();case _RefreshToken():
return refreshToken();case _Logout():
return logout();case _LogoutAll():
return logoutAll();case _RestoreSession():
return restoreSession();case _RequestPasswordReset():
return requestPasswordReset(_that.email);case _ResetPassword():
return resetPassword(_that.token,_that.password);case _RequestEmailVerification():
return requestEmailVerification(_that.email);case _ConfirmEmailVerification():
return confirmEmailVerification(_that.email,_that.code);case _RequestPhoneVerification():
return requestPhoneVerification(_that.phone);case _ConfirmPhoneVerification():
return confirmPhoneVerification(_that.phone,_that.code);case _RegisterDevice():
return registerDevice(_that.deviceData);case _GetDevices():
return getDevices();case _RevokeDevice():
return revokeDevice(_that.deviceId);case _GetSessions():
return getSessions();case _RevokeSession():
return revokeSession(_that.sessionId);case _GetMfaStatus():
return getMfaStatus();case _GetMfaMethods():
return getMfaMethods();case _AddMfaMethod():
return addMfaMethod(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaMethod():
return verifyMfaMethod(_that.methodId,_that.code);case _DisableMfaMethod():
return disableMfaMethod(_that.methodId,_that.verificationCode);case _SetPrimaryMfaMethod():
return setPrimaryMfaMethod(_that.methodId,_that.verificationCode);case _RegenerateRecoveryCodes():
return regenerateRecoveryCodes(_that.verificationCode);case _RequestAccountRecoveryEmail():
return requestAccountRecoveryEmail(_that.email);case _RequestAccountRecoveryPhone():
return requestAccountRecoveryPhone(_that.phone);case _VerifyAccountRecovery():
return verifyAccountRecovery(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _GetSecurityEvents():
return getSecurityEvents(_that.limit,_that.offset);case _LinkGoogle():
return linkGoogle(_that.idToken);case _UnlinkGoogle():
return unlinkGoogle(_that.password);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email,  String password)?  login,TResult? Function( String phone,  String password)?  loginWithPhone,TResult? Function()?  loginWithGoogle,TResult? Function( String role)?  registerWithGoogle,TResult? Function( String firstName,  String lastName,  String email,  String password,  String role,  bool termsAccepted)?  registerEmail,TResult? Function( String firstName,  String lastName,  String phone,  String password,  String role,  bool termsAccepted)?  registerPhone,TResult? Function( String firstName,  String lastName,  String phone,  String role,  bool termsAccepted)?  registerPhoneOtp,TResult? Function( String email)?  requestEmailOtp,TResult? Function( String email,  String otp)?  verifyEmailOtp,TResult? Function( String phone)?  requestPhoneOtp,TResult? Function( String phone,  String otp)?  verifyPhoneOtp,TResult? Function( String challengeId,  String totpCode)?  verifyMfa,TResult? Function( String challengeId,  String recoveryCode)?  verifyMfaRecoveryCode,TResult? Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)?  startMfaEnrollment,TResult? Function( String methodId,  String code)?  verifyMfaEnrollment,TResult? Function()?  skipMfaEnrollment,TResult? Function()?  refreshToken,TResult? Function()?  logout,TResult? Function()?  logoutAll,TResult? Function()?  restoreSession,TResult? Function( String email)?  requestPasswordReset,TResult? Function( String token,  String password)?  resetPassword,TResult? Function( String email)?  requestEmailVerification,TResult? Function( String email,  String code)?  confirmEmailVerification,TResult? Function( String phone)?  requestPhoneVerification,TResult? Function( String phone,  String code)?  confirmPhoneVerification,TResult? Function( Map<String, dynamic> deviceData)?  registerDevice,TResult? Function()?  getDevices,TResult? Function( String deviceId)?  revokeDevice,TResult? Function()?  getSessions,TResult? Function( String sessionId)?  revokeSession,TResult? Function()?  getMfaStatus,TResult? Function()?  getMfaMethods,TResult? Function( String methodType,  String? methodName,  String? phoneNumber,  bool? makePrimary)?  addMfaMethod,TResult? Function( String methodId,  String code)?  verifyMfaMethod,TResult? Function( String methodId,  String verificationCode)?  disableMfaMethod,TResult? Function( String methodId,  String verificationCode)?  setPrimaryMfaMethod,TResult? Function( String verificationCode)?  regenerateRecoveryCodes,TResult? Function( String email)?  requestAccountRecoveryEmail,TResult? Function( String phone)?  requestAccountRecoveryPhone,TResult? Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)?  verifyAccountRecovery,TResult? Function( int? limit,  int? offset)?  getSecurityEvents,TResult? Function( String idToken)?  linkGoogle,TResult? Function( String password)?  unlinkGoogle,}) {final _that = this;
switch (_that) {
case _Login() when login != null:
return login(_that.email,_that.password);case _LoginWithPhone() when loginWithPhone != null:
return loginWithPhone(_that.phone,_that.password);case _LoginWithGoogle() when loginWithGoogle != null:
return loginWithGoogle();case _RegisterWithGoogle() when registerWithGoogle != null:
return registerWithGoogle(_that.role);case _RegisterEmail() when registerEmail != null:
return registerEmail(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case _RegisterPhone() when registerPhone != null:
return registerPhone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case _RegisterPhoneOtp() when registerPhoneOtp != null:
return registerPhoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case _RequestEmailOtp() when requestEmailOtp != null:
return requestEmailOtp(_that.email);case _VerifyEmailOtp() when verifyEmailOtp != null:
return verifyEmailOtp(_that.email,_that.otp);case _RequestPhoneOtp() when requestPhoneOtp != null:
return requestPhoneOtp(_that.phone);case _VerifyPhoneOtp() when verifyPhoneOtp != null:
return verifyPhoneOtp(_that.phone,_that.otp);case _VerifyMfa() when verifyMfa != null:
return verifyMfa(_that.challengeId,_that.totpCode);case _VerifyMfaRecoveryCode() when verifyMfaRecoveryCode != null:
return verifyMfaRecoveryCode(_that.challengeId,_that.recoveryCode);case _StartMfaEnrollment() when startMfaEnrollment != null:
return startMfaEnrollment(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaEnrollment() when verifyMfaEnrollment != null:
return verifyMfaEnrollment(_that.methodId,_that.code);case _SkipMfaEnrollment() when skipMfaEnrollment != null:
return skipMfaEnrollment();case _RefreshToken() when refreshToken != null:
return refreshToken();case _Logout() when logout != null:
return logout();case _LogoutAll() when logoutAll != null:
return logoutAll();case _RestoreSession() when restoreSession != null:
return restoreSession();case _RequestPasswordReset() when requestPasswordReset != null:
return requestPasswordReset(_that.email);case _ResetPassword() when resetPassword != null:
return resetPassword(_that.token,_that.password);case _RequestEmailVerification() when requestEmailVerification != null:
return requestEmailVerification(_that.email);case _ConfirmEmailVerification() when confirmEmailVerification != null:
return confirmEmailVerification(_that.email,_that.code);case _RequestPhoneVerification() when requestPhoneVerification != null:
return requestPhoneVerification(_that.phone);case _ConfirmPhoneVerification() when confirmPhoneVerification != null:
return confirmPhoneVerification(_that.phone,_that.code);case _RegisterDevice() when registerDevice != null:
return registerDevice(_that.deviceData);case _GetDevices() when getDevices != null:
return getDevices();case _RevokeDevice() when revokeDevice != null:
return revokeDevice(_that.deviceId);case _GetSessions() when getSessions != null:
return getSessions();case _RevokeSession() when revokeSession != null:
return revokeSession(_that.sessionId);case _GetMfaStatus() when getMfaStatus != null:
return getMfaStatus();case _GetMfaMethods() when getMfaMethods != null:
return getMfaMethods();case _AddMfaMethod() when addMfaMethod != null:
return addMfaMethod(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _VerifyMfaMethod() when verifyMfaMethod != null:
return verifyMfaMethod(_that.methodId,_that.code);case _DisableMfaMethod() when disableMfaMethod != null:
return disableMfaMethod(_that.methodId,_that.verificationCode);case _SetPrimaryMfaMethod() when setPrimaryMfaMethod != null:
return setPrimaryMfaMethod(_that.methodId,_that.verificationCode);case _RegenerateRecoveryCodes() when regenerateRecoveryCodes != null:
return regenerateRecoveryCodes(_that.verificationCode);case _RequestAccountRecoveryEmail() when requestAccountRecoveryEmail != null:
return requestAccountRecoveryEmail(_that.email);case _RequestAccountRecoveryPhone() when requestAccountRecoveryPhone != null:
return requestAccountRecoveryPhone(_that.phone);case _VerifyAccountRecovery() when verifyAccountRecovery != null:
return verifyAccountRecovery(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _GetSecurityEvents() when getSecurityEvents != null:
return getSecurityEvents(_that.limit,_that.offset);case _LinkGoogle() when linkGoogle != null:
return linkGoogle(_that.idToken);case _UnlinkGoogle() when unlinkGoogle != null:
return unlinkGoogle(_that.password);case _:
  return null;

}
}

}

/// @nodoc


class _Login with DiagnosticableTreeMixin implements AuthAction {
  const _Login({required this.email, required this.password});
  

 final  String email;
 final  String password;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginCopyWith<_Login> get copyWith => __$LoginCopyWithImpl<_Login>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.login'))
    ..add(DiagnosticsProperty('email', email))..add(DiagnosticsProperty('password', password));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Login&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,password);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.login(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class _$LoginCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$LoginCopyWith(_Login value, $Res Function(_Login) _then) = __$LoginCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class __$LoginCopyWithImpl<$Res>
    implements _$LoginCopyWith<$Res> {
  __$LoginCopyWithImpl(this._self, this._then);

  final _Login _self;
  final $Res Function(_Login) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(_Login(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _LoginWithPhone with DiagnosticableTreeMixin implements AuthAction {
  const _LoginWithPhone({required this.phone, required this.password});
  

 final  String phone;
 final  String password;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginWithPhoneCopyWith<_LoginWithPhone> get copyWith => __$LoginWithPhoneCopyWithImpl<_LoginWithPhone>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.loginWithPhone'))
    ..add(DiagnosticsProperty('phone', phone))..add(DiagnosticsProperty('password', password));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginWithPhone&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,password);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.loginWithPhone(phone: $phone, password: $password)';
}


}

/// @nodoc
abstract mixin class _$LoginWithPhoneCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$LoginWithPhoneCopyWith(_LoginWithPhone value, $Res Function(_LoginWithPhone) _then) = __$LoginWithPhoneCopyWithImpl;
@useResult
$Res call({
 String phone, String password
});




}
/// @nodoc
class __$LoginWithPhoneCopyWithImpl<$Res>
    implements _$LoginWithPhoneCopyWith<$Res> {
  __$LoginWithPhoneCopyWithImpl(this._self, this._then);

  final _LoginWithPhone _self;
  final $Res Function(_LoginWithPhone) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? password = null,}) {
  return _then(_LoginWithPhone(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _LoginWithGoogle with DiagnosticableTreeMixin implements AuthAction {
  const _LoginWithGoogle();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.loginWithGoogle'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginWithGoogle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.loginWithGoogle()';
}


}




/// @nodoc


class _RegisterWithGoogle with DiagnosticableTreeMixin implements AuthAction {
  const _RegisterWithGoogle({required this.role});
  

 final  String role;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterWithGoogleCopyWith<_RegisterWithGoogle> get copyWith => __$RegisterWithGoogleCopyWithImpl<_RegisterWithGoogle>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.registerWithGoogle'))
    ..add(DiagnosticsProperty('role', role));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterWithGoogle&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode {
    return Object.hash(runtimeType,role);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.registerWithGoogle(role: $role)';
}


}

/// @nodoc
abstract mixin class _$RegisterWithGoogleCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegisterWithGoogleCopyWith(_RegisterWithGoogle value, $Res Function(_RegisterWithGoogle) _then) = __$RegisterWithGoogleCopyWithImpl;
@useResult
$Res call({
 String role
});




}
/// @nodoc
class __$RegisterWithGoogleCopyWithImpl<$Res>
    implements _$RegisterWithGoogleCopyWith<$Res> {
  __$RegisterWithGoogleCopyWithImpl(this._self, this._then);

  final _RegisterWithGoogle _self;
  final $Res Function(_RegisterWithGoogle) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? role = null,}) {
  return _then(_RegisterWithGoogle(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RegisterEmail with DiagnosticableTreeMixin implements AuthAction {
  const _RegisterEmail({required this.firstName, required this.lastName, required this.email, required this.password, required this.role, required this.termsAccepted});
  

 final  String firstName;
 final  String lastName;
 final  String email;
 final  String password;
 final  String role;
 final  bool termsAccepted;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterEmailCopyWith<_RegisterEmail> get copyWith => __$RegisterEmailCopyWithImpl<_RegisterEmail>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.registerEmail'))
    ..add(DiagnosticsProperty('firstName', firstName))..add(DiagnosticsProperty('lastName', lastName))..add(DiagnosticsProperty('email', email))..add(DiagnosticsProperty('password', password))..add(DiagnosticsProperty('role', role))..add(DiagnosticsProperty('termsAccepted', termsAccepted));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterEmail&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,email,password,role,termsAccepted);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.registerEmail(firstName: $firstName, lastName: $lastName, email: $email, password: $password, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class _$RegisterEmailCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegisterEmailCopyWith(_RegisterEmail value, $Res Function(_RegisterEmail) _then) = __$RegisterEmailCopyWithImpl;
@useResult
$Res call({
 String firstName, String lastName, String email, String password, String role, bool termsAccepted
});




}
/// @nodoc
class __$RegisterEmailCopyWithImpl<$Res>
    implements _$RegisterEmailCopyWith<$Res> {
  __$RegisterEmailCopyWithImpl(this._self, this._then);

  final _RegisterEmail _self;
  final $Res Function(_RegisterEmail) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? email = null,Object? password = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(_RegisterEmail(
firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,termsAccepted: null == termsAccepted ? _self.termsAccepted : termsAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _RegisterPhone with DiagnosticableTreeMixin implements AuthAction {
  const _RegisterPhone({required this.firstName, required this.lastName, required this.phone, required this.password, required this.role, required this.termsAccepted});
  

 final  String firstName;
 final  String lastName;
 final  String phone;
 final  String password;
 final  String role;
 final  bool termsAccepted;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterPhoneCopyWith<_RegisterPhone> get copyWith => __$RegisterPhoneCopyWithImpl<_RegisterPhone>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.registerPhone'))
    ..add(DiagnosticsProperty('firstName', firstName))..add(DiagnosticsProperty('lastName', lastName))..add(DiagnosticsProperty('phone', phone))..add(DiagnosticsProperty('password', password))..add(DiagnosticsProperty('role', role))..add(DiagnosticsProperty('termsAccepted', termsAccepted));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterPhone&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,phone,password,role,termsAccepted);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.registerPhone(firstName: $firstName, lastName: $lastName, phone: $phone, password: $password, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class _$RegisterPhoneCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegisterPhoneCopyWith(_RegisterPhone value, $Res Function(_RegisterPhone) _then) = __$RegisterPhoneCopyWithImpl;
@useResult
$Res call({
 String firstName, String lastName, String phone, String password, String role, bool termsAccepted
});




}
/// @nodoc
class __$RegisterPhoneCopyWithImpl<$Res>
    implements _$RegisterPhoneCopyWith<$Res> {
  __$RegisterPhoneCopyWithImpl(this._self, this._then);

  final _RegisterPhone _self;
  final $Res Function(_RegisterPhone) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? phone = null,Object? password = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(_RegisterPhone(
firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,termsAccepted: null == termsAccepted ? _self.termsAccepted : termsAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _RegisterPhoneOtp with DiagnosticableTreeMixin implements AuthAction {
  const _RegisterPhoneOtp({required this.firstName, required this.lastName, required this.phone, required this.role, required this.termsAccepted});
  

 final  String firstName;
 final  String lastName;
 final  String phone;
 final  String role;
 final  bool termsAccepted;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterPhoneOtpCopyWith<_RegisterPhoneOtp> get copyWith => __$RegisterPhoneOtpCopyWithImpl<_RegisterPhoneOtp>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.registerPhoneOtp'))
    ..add(DiagnosticsProperty('firstName', firstName))..add(DiagnosticsProperty('lastName', lastName))..add(DiagnosticsProperty('phone', phone))..add(DiagnosticsProperty('role', role))..add(DiagnosticsProperty('termsAccepted', termsAccepted));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterPhoneOtp&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,phone,role,termsAccepted);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.registerPhoneOtp(firstName: $firstName, lastName: $lastName, phone: $phone, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class _$RegisterPhoneOtpCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegisterPhoneOtpCopyWith(_RegisterPhoneOtp value, $Res Function(_RegisterPhoneOtp) _then) = __$RegisterPhoneOtpCopyWithImpl;
@useResult
$Res call({
 String firstName, String lastName, String phone, String role, bool termsAccepted
});




}
/// @nodoc
class __$RegisterPhoneOtpCopyWithImpl<$Res>
    implements _$RegisterPhoneOtpCopyWith<$Res> {
  __$RegisterPhoneOtpCopyWithImpl(this._self, this._then);

  final _RegisterPhoneOtp _self;
  final $Res Function(_RegisterPhoneOtp) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? phone = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(_RegisterPhoneOtp(
firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,termsAccepted: null == termsAccepted ? _self.termsAccepted : termsAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _RequestEmailOtp with DiagnosticableTreeMixin implements AuthAction {
  const _RequestEmailOtp({required this.email});
  

 final  String email;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestEmailOtpCopyWith<_RequestEmailOtp> get copyWith => __$RequestEmailOtpCopyWithImpl<_RequestEmailOtp>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestEmailOtp'))
    ..add(DiagnosticsProperty('email', email));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestEmailOtp&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestEmailOtp(email: $email)';
}


}

/// @nodoc
abstract mixin class _$RequestEmailOtpCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestEmailOtpCopyWith(_RequestEmailOtp value, $Res Function(_RequestEmailOtp) _then) = __$RequestEmailOtpCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class __$RequestEmailOtpCopyWithImpl<$Res>
    implements _$RequestEmailOtpCopyWith<$Res> {
  __$RequestEmailOtpCopyWithImpl(this._self, this._then);

  final _RequestEmailOtp _self;
  final $Res Function(_RequestEmailOtp) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_RequestEmailOtp(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyEmailOtp with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyEmailOtp({required this.email, required this.otp});
  

 final  String email;
 final  String otp;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyEmailOtpCopyWith<_VerifyEmailOtp> get copyWith => __$VerifyEmailOtpCopyWithImpl<_VerifyEmailOtp>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyEmailOtp'))
    ..add(DiagnosticsProperty('email', email))..add(DiagnosticsProperty('otp', otp));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyEmailOtp&&(identical(other.email, email) || other.email == email)&&(identical(other.otp, otp) || other.otp == otp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,otp);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyEmailOtp(email: $email, otp: $otp)';
}


}

/// @nodoc
abstract mixin class _$VerifyEmailOtpCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyEmailOtpCopyWith(_VerifyEmailOtp value, $Res Function(_VerifyEmailOtp) _then) = __$VerifyEmailOtpCopyWithImpl;
@useResult
$Res call({
 String email, String otp
});




}
/// @nodoc
class __$VerifyEmailOtpCopyWithImpl<$Res>
    implements _$VerifyEmailOtpCopyWith<$Res> {
  __$VerifyEmailOtpCopyWithImpl(this._self, this._then);

  final _VerifyEmailOtp _self;
  final $Res Function(_VerifyEmailOtp) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? otp = null,}) {
  return _then(_VerifyEmailOtp(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RequestPhoneOtp with DiagnosticableTreeMixin implements AuthAction {
  const _RequestPhoneOtp({required this.phone});
  

 final  String phone;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestPhoneOtpCopyWith<_RequestPhoneOtp> get copyWith => __$RequestPhoneOtpCopyWithImpl<_RequestPhoneOtp>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestPhoneOtp'))
    ..add(DiagnosticsProperty('phone', phone));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestPhoneOtp&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestPhoneOtp(phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$RequestPhoneOtpCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestPhoneOtpCopyWith(_RequestPhoneOtp value, $Res Function(_RequestPhoneOtp) _then) = __$RequestPhoneOtpCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class __$RequestPhoneOtpCopyWithImpl<$Res>
    implements _$RequestPhoneOtpCopyWith<$Res> {
  __$RequestPhoneOtpCopyWithImpl(this._self, this._then);

  final _RequestPhoneOtp _self;
  final $Res Function(_RequestPhoneOtp) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(_RequestPhoneOtp(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyPhoneOtp with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyPhoneOtp({required this.phone, required this.otp});
  

 final  String phone;
 final  String otp;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyPhoneOtpCopyWith<_VerifyPhoneOtp> get copyWith => __$VerifyPhoneOtpCopyWithImpl<_VerifyPhoneOtp>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyPhoneOtp'))
    ..add(DiagnosticsProperty('phone', phone))..add(DiagnosticsProperty('otp', otp));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyPhoneOtp&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.otp, otp) || other.otp == otp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,otp);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyPhoneOtp(phone: $phone, otp: $otp)';
}


}

/// @nodoc
abstract mixin class _$VerifyPhoneOtpCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyPhoneOtpCopyWith(_VerifyPhoneOtp value, $Res Function(_VerifyPhoneOtp) _then) = __$VerifyPhoneOtpCopyWithImpl;
@useResult
$Res call({
 String phone, String otp
});




}
/// @nodoc
class __$VerifyPhoneOtpCopyWithImpl<$Res>
    implements _$VerifyPhoneOtpCopyWith<$Res> {
  __$VerifyPhoneOtpCopyWithImpl(this._self, this._then);

  final _VerifyPhoneOtp _self;
  final $Res Function(_VerifyPhoneOtp) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? otp = null,}) {
  return _then(_VerifyPhoneOtp(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyMfa with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyMfa({required this.challengeId, required this.totpCode});
  

 final  String challengeId;
 final  String totpCode;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyMfaCopyWith<_VerifyMfa> get copyWith => __$VerifyMfaCopyWithImpl<_VerifyMfa>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyMfa'))
    ..add(DiagnosticsProperty('challengeId', challengeId))..add(DiagnosticsProperty('totpCode', totpCode));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyMfa&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&(identical(other.totpCode, totpCode) || other.totpCode == totpCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,challengeId,totpCode);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyMfa(challengeId: $challengeId, totpCode: $totpCode)';
}


}

/// @nodoc
abstract mixin class _$VerifyMfaCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyMfaCopyWith(_VerifyMfa value, $Res Function(_VerifyMfa) _then) = __$VerifyMfaCopyWithImpl;
@useResult
$Res call({
 String challengeId, String totpCode
});




}
/// @nodoc
class __$VerifyMfaCopyWithImpl<$Res>
    implements _$VerifyMfaCopyWith<$Res> {
  __$VerifyMfaCopyWithImpl(this._self, this._then);

  final _VerifyMfa _self;
  final $Res Function(_VerifyMfa) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? totpCode = null,}) {
  return _then(_VerifyMfa(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,totpCode: null == totpCode ? _self.totpCode : totpCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyMfaRecoveryCode with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyMfaRecoveryCode({required this.challengeId, required this.recoveryCode});
  

 final  String challengeId;
 final  String recoveryCode;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyMfaRecoveryCodeCopyWith<_VerifyMfaRecoveryCode> get copyWith => __$VerifyMfaRecoveryCodeCopyWithImpl<_VerifyMfaRecoveryCode>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyMfaRecoveryCode'))
    ..add(DiagnosticsProperty('challengeId', challengeId))..add(DiagnosticsProperty('recoveryCode', recoveryCode));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyMfaRecoveryCode&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&(identical(other.recoveryCode, recoveryCode) || other.recoveryCode == recoveryCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,challengeId,recoveryCode);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyMfaRecoveryCode(challengeId: $challengeId, recoveryCode: $recoveryCode)';
}


}

/// @nodoc
abstract mixin class _$VerifyMfaRecoveryCodeCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyMfaRecoveryCodeCopyWith(_VerifyMfaRecoveryCode value, $Res Function(_VerifyMfaRecoveryCode) _then) = __$VerifyMfaRecoveryCodeCopyWithImpl;
@useResult
$Res call({
 String challengeId, String recoveryCode
});




}
/// @nodoc
class __$VerifyMfaRecoveryCodeCopyWithImpl<$Res>
    implements _$VerifyMfaRecoveryCodeCopyWith<$Res> {
  __$VerifyMfaRecoveryCodeCopyWithImpl(this._self, this._then);

  final _VerifyMfaRecoveryCode _self;
  final $Res Function(_VerifyMfaRecoveryCode) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? recoveryCode = null,}) {
  return _then(_VerifyMfaRecoveryCode(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,recoveryCode: null == recoveryCode ? _self.recoveryCode : recoveryCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _StartMfaEnrollment with DiagnosticableTreeMixin implements AuthAction {
  const _StartMfaEnrollment({required this.methodType, this.methodName, this.phoneNumber, this.makePrimary});
  

 final  String methodType;
 final  String? methodName;
 final  String? phoneNumber;
 final  bool? makePrimary;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartMfaEnrollmentCopyWith<_StartMfaEnrollment> get copyWith => __$StartMfaEnrollmentCopyWithImpl<_StartMfaEnrollment>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.startMfaEnrollment'))
    ..add(DiagnosticsProperty('methodType', methodType))..add(DiagnosticsProperty('methodName', methodName))..add(DiagnosticsProperty('phoneNumber', phoneNumber))..add(DiagnosticsProperty('makePrimary', makePrimary));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StartMfaEnrollment&&(identical(other.methodType, methodType) || other.methodType == methodType)&&(identical(other.methodName, methodName) || other.methodName == methodName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.makePrimary, makePrimary) || other.makePrimary == makePrimary));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodType,methodName,phoneNumber,makePrimary);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.startMfaEnrollment(methodType: $methodType, methodName: $methodName, phoneNumber: $phoneNumber, makePrimary: $makePrimary)';
}


}

/// @nodoc
abstract mixin class _$StartMfaEnrollmentCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$StartMfaEnrollmentCopyWith(_StartMfaEnrollment value, $Res Function(_StartMfaEnrollment) _then) = __$StartMfaEnrollmentCopyWithImpl;
@useResult
$Res call({
 String methodType, String? methodName, String? phoneNumber, bool? makePrimary
});




}
/// @nodoc
class __$StartMfaEnrollmentCopyWithImpl<$Res>
    implements _$StartMfaEnrollmentCopyWith<$Res> {
  __$StartMfaEnrollmentCopyWithImpl(this._self, this._then);

  final _StartMfaEnrollment _self;
  final $Res Function(_StartMfaEnrollment) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodType = null,Object? methodName = freezed,Object? phoneNumber = freezed,Object? makePrimary = freezed,}) {
  return _then(_StartMfaEnrollment(
methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,makePrimary: freezed == makePrimary ? _self.makePrimary : makePrimary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc


class _VerifyMfaEnrollment with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyMfaEnrollment({required this.methodId, required this.code});
  

 final  String methodId;
 final  String code;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyMfaEnrollmentCopyWith<_VerifyMfaEnrollment> get copyWith => __$VerifyMfaEnrollmentCopyWithImpl<_VerifyMfaEnrollment>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyMfaEnrollment'))
    ..add(DiagnosticsProperty('methodId', methodId))..add(DiagnosticsProperty('code', code));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyMfaEnrollment&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodId,code);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyMfaEnrollment(methodId: $methodId, code: $code)';
}


}

/// @nodoc
abstract mixin class _$VerifyMfaEnrollmentCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyMfaEnrollmentCopyWith(_VerifyMfaEnrollment value, $Res Function(_VerifyMfaEnrollment) _then) = __$VerifyMfaEnrollmentCopyWithImpl;
@useResult
$Res call({
 String methodId, String code
});




}
/// @nodoc
class __$VerifyMfaEnrollmentCopyWithImpl<$Res>
    implements _$VerifyMfaEnrollmentCopyWith<$Res> {
  __$VerifyMfaEnrollmentCopyWithImpl(this._self, this._then);

  final _VerifyMfaEnrollment _self;
  final $Res Function(_VerifyMfaEnrollment) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodId = null,Object? code = null,}) {
  return _then(_VerifyMfaEnrollment(
methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _SkipMfaEnrollment with DiagnosticableTreeMixin implements AuthAction {
  const _SkipMfaEnrollment();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.skipMfaEnrollment'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkipMfaEnrollment);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.skipMfaEnrollment()';
}


}




/// @nodoc


class _RefreshToken with DiagnosticableTreeMixin implements AuthAction {
  const _RefreshToken();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.refreshToken'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshToken);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.refreshToken()';
}


}




/// @nodoc


class _Logout with DiagnosticableTreeMixin implements AuthAction {
  const _Logout();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.logout'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Logout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.logout()';
}


}




/// @nodoc


class _LogoutAll with DiagnosticableTreeMixin implements AuthAction {
  const _LogoutAll();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.logoutAll'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogoutAll);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.logoutAll()';
}


}




/// @nodoc


class _RestoreSession with DiagnosticableTreeMixin implements AuthAction {
  const _RestoreSession();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.restoreSession'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestoreSession);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.restoreSession()';
}


}




/// @nodoc


class _RequestPasswordReset with DiagnosticableTreeMixin implements AuthAction {
  const _RequestPasswordReset({required this.email});
  

 final  String email;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestPasswordResetCopyWith<_RequestPasswordReset> get copyWith => __$RequestPasswordResetCopyWithImpl<_RequestPasswordReset>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestPasswordReset'))
    ..add(DiagnosticsProperty('email', email));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestPasswordReset&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestPasswordReset(email: $email)';
}


}

/// @nodoc
abstract mixin class _$RequestPasswordResetCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestPasswordResetCopyWith(_RequestPasswordReset value, $Res Function(_RequestPasswordReset) _then) = __$RequestPasswordResetCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class __$RequestPasswordResetCopyWithImpl<$Res>
    implements _$RequestPasswordResetCopyWith<$Res> {
  __$RequestPasswordResetCopyWithImpl(this._self, this._then);

  final _RequestPasswordReset _self;
  final $Res Function(_RequestPasswordReset) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_RequestPasswordReset(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _ResetPassword with DiagnosticableTreeMixin implements AuthAction {
  const _ResetPassword({required this.token, required this.password});
  

 final  String token;
 final  String password;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResetPasswordCopyWith<_ResetPassword> get copyWith => __$ResetPasswordCopyWithImpl<_ResetPassword>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.resetPassword'))
    ..add(DiagnosticsProperty('token', token))..add(DiagnosticsProperty('password', password));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResetPassword&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,token,password);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.resetPassword(token: $token, password: $password)';
}


}

/// @nodoc
abstract mixin class _$ResetPasswordCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$ResetPasswordCopyWith(_ResetPassword value, $Res Function(_ResetPassword) _then) = __$ResetPasswordCopyWithImpl;
@useResult
$Res call({
 String token, String password
});




}
/// @nodoc
class __$ResetPasswordCopyWithImpl<$Res>
    implements _$ResetPasswordCopyWith<$Res> {
  __$ResetPasswordCopyWithImpl(this._self, this._then);

  final _ResetPassword _self;
  final $Res Function(_ResetPassword) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? password = null,}) {
  return _then(_ResetPassword(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RequestEmailVerification with DiagnosticableTreeMixin implements AuthAction {
  const _RequestEmailVerification({required this.email});
  

 final  String email;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestEmailVerificationCopyWith<_RequestEmailVerification> get copyWith => __$RequestEmailVerificationCopyWithImpl<_RequestEmailVerification>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestEmailVerification'))
    ..add(DiagnosticsProperty('email', email));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestEmailVerification&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestEmailVerification(email: $email)';
}


}

/// @nodoc
abstract mixin class _$RequestEmailVerificationCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestEmailVerificationCopyWith(_RequestEmailVerification value, $Res Function(_RequestEmailVerification) _then) = __$RequestEmailVerificationCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class __$RequestEmailVerificationCopyWithImpl<$Res>
    implements _$RequestEmailVerificationCopyWith<$Res> {
  __$RequestEmailVerificationCopyWithImpl(this._self, this._then);

  final _RequestEmailVerification _self;
  final $Res Function(_RequestEmailVerification) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_RequestEmailVerification(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _ConfirmEmailVerification with DiagnosticableTreeMixin implements AuthAction {
  const _ConfirmEmailVerification({required this.email, required this.code});
  

 final  String email;
 final  String code;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfirmEmailVerificationCopyWith<_ConfirmEmailVerification> get copyWith => __$ConfirmEmailVerificationCopyWithImpl<_ConfirmEmailVerification>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.confirmEmailVerification'))
    ..add(DiagnosticsProperty('email', email))..add(DiagnosticsProperty('code', code));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfirmEmailVerification&&(identical(other.email, email) || other.email == email)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,code);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.confirmEmailVerification(email: $email, code: $code)';
}


}

/// @nodoc
abstract mixin class _$ConfirmEmailVerificationCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$ConfirmEmailVerificationCopyWith(_ConfirmEmailVerification value, $Res Function(_ConfirmEmailVerification) _then) = __$ConfirmEmailVerificationCopyWithImpl;
@useResult
$Res call({
 String email, String code
});




}
/// @nodoc
class __$ConfirmEmailVerificationCopyWithImpl<$Res>
    implements _$ConfirmEmailVerificationCopyWith<$Res> {
  __$ConfirmEmailVerificationCopyWithImpl(this._self, this._then);

  final _ConfirmEmailVerification _self;
  final $Res Function(_ConfirmEmailVerification) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? code = null,}) {
  return _then(_ConfirmEmailVerification(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RequestPhoneVerification with DiagnosticableTreeMixin implements AuthAction {
  const _RequestPhoneVerification({required this.phone});
  

 final  String phone;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestPhoneVerificationCopyWith<_RequestPhoneVerification> get copyWith => __$RequestPhoneVerificationCopyWithImpl<_RequestPhoneVerification>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestPhoneVerification'))
    ..add(DiagnosticsProperty('phone', phone));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestPhoneVerification&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestPhoneVerification(phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$RequestPhoneVerificationCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestPhoneVerificationCopyWith(_RequestPhoneVerification value, $Res Function(_RequestPhoneVerification) _then) = __$RequestPhoneVerificationCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class __$RequestPhoneVerificationCopyWithImpl<$Res>
    implements _$RequestPhoneVerificationCopyWith<$Res> {
  __$RequestPhoneVerificationCopyWithImpl(this._self, this._then);

  final _RequestPhoneVerification _self;
  final $Res Function(_RequestPhoneVerification) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(_RequestPhoneVerification(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _ConfirmPhoneVerification with DiagnosticableTreeMixin implements AuthAction {
  const _ConfirmPhoneVerification({required this.phone, required this.code});
  

 final  String phone;
 final  String code;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfirmPhoneVerificationCopyWith<_ConfirmPhoneVerification> get copyWith => __$ConfirmPhoneVerificationCopyWithImpl<_ConfirmPhoneVerification>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.confirmPhoneVerification'))
    ..add(DiagnosticsProperty('phone', phone))..add(DiagnosticsProperty('code', code));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfirmPhoneVerification&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,code);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.confirmPhoneVerification(phone: $phone, code: $code)';
}


}

/// @nodoc
abstract mixin class _$ConfirmPhoneVerificationCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$ConfirmPhoneVerificationCopyWith(_ConfirmPhoneVerification value, $Res Function(_ConfirmPhoneVerification) _then) = __$ConfirmPhoneVerificationCopyWithImpl;
@useResult
$Res call({
 String phone, String code
});




}
/// @nodoc
class __$ConfirmPhoneVerificationCopyWithImpl<$Res>
    implements _$ConfirmPhoneVerificationCopyWith<$Res> {
  __$ConfirmPhoneVerificationCopyWithImpl(this._self, this._then);

  final _ConfirmPhoneVerification _self;
  final $Res Function(_ConfirmPhoneVerification) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? code = null,}) {
  return _then(_ConfirmPhoneVerification(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RegisterDevice with DiagnosticableTreeMixin implements AuthAction {
  const _RegisterDevice({required  Map<String, dynamic> deviceData}): _deviceData = deviceData;
  

 final  Map<String, dynamic> _deviceData;
 Map<String, dynamic> get deviceData {
  if (_deviceData is EqualUnmodifiableMapView) return _deviceData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_deviceData);
}


/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterDeviceCopyWith<_RegisterDevice> get copyWith => __$RegisterDeviceCopyWithImpl<_RegisterDevice>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.registerDevice'))
    ..add(DiagnosticsProperty('deviceData', deviceData));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterDevice&&const DeepCollectionEquality().equals(other.deviceData, _deviceData));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_deviceData));
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.registerDevice(deviceData: $deviceData)';
}


}

/// @nodoc
abstract mixin class _$RegisterDeviceCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegisterDeviceCopyWith(_RegisterDevice value, $Res Function(_RegisterDevice) _then) = __$RegisterDeviceCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> deviceData
});




}
/// @nodoc
class __$RegisterDeviceCopyWithImpl<$Res>
    implements _$RegisterDeviceCopyWith<$Res> {
  __$RegisterDeviceCopyWithImpl(this._self, this._then);

  final _RegisterDevice _self;
  final $Res Function(_RegisterDevice) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceData = null,}) {
  return _then(_RegisterDevice(
deviceData: null == deviceData ? _self._deviceData : deviceData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc


class _GetDevices with DiagnosticableTreeMixin implements AuthAction {
  const _GetDevices();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.getDevices'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetDevices);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.getDevices()';
}


}




/// @nodoc


class _RevokeDevice with DiagnosticableTreeMixin implements AuthAction {
  const _RevokeDevice({required this.deviceId});
  

 final  String deviceId;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevokeDeviceCopyWith<_RevokeDevice> get copyWith => __$RevokeDeviceCopyWithImpl<_RevokeDevice>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.revokeDevice'))
    ..add(DiagnosticsProperty('deviceId', deviceId));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevokeDevice&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,deviceId);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.revokeDevice(deviceId: $deviceId)';
}


}

/// @nodoc
abstract mixin class _$RevokeDeviceCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RevokeDeviceCopyWith(_RevokeDevice value, $Res Function(_RevokeDevice) _then) = __$RevokeDeviceCopyWithImpl;
@useResult
$Res call({
 String deviceId
});




}
/// @nodoc
class __$RevokeDeviceCopyWithImpl<$Res>
    implements _$RevokeDeviceCopyWith<$Res> {
  __$RevokeDeviceCopyWithImpl(this._self, this._then);

  final _RevokeDevice _self;
  final $Res Function(_RevokeDevice) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? deviceId = null,}) {
  return _then(_RevokeDevice(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _GetSessions with DiagnosticableTreeMixin implements AuthAction {
  const _GetSessions();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.getSessions'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetSessions);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.getSessions()';
}


}




/// @nodoc


class _RevokeSession with DiagnosticableTreeMixin implements AuthAction {
  const _RevokeSession({required this.sessionId});
  

 final  String sessionId;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevokeSessionCopyWith<_RevokeSession> get copyWith => __$RevokeSessionCopyWithImpl<_RevokeSession>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.revokeSession'))
    ..add(DiagnosticsProperty('sessionId', sessionId));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevokeSession&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.revokeSession(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$RevokeSessionCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RevokeSessionCopyWith(_RevokeSession value, $Res Function(_RevokeSession) _then) = __$RevokeSessionCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$RevokeSessionCopyWithImpl<$Res>
    implements _$RevokeSessionCopyWith<$Res> {
  __$RevokeSessionCopyWithImpl(this._self, this._then);

  final _RevokeSession _self;
  final $Res Function(_RevokeSession) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_RevokeSession(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _GetMfaStatus with DiagnosticableTreeMixin implements AuthAction {
  const _GetMfaStatus();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.getMfaStatus'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetMfaStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.getMfaStatus()';
}


}




/// @nodoc


class _GetMfaMethods with DiagnosticableTreeMixin implements AuthAction {
  const _GetMfaMethods();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.getMfaMethods'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetMfaMethods);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.getMfaMethods()';
}


}




/// @nodoc


class _AddMfaMethod with DiagnosticableTreeMixin implements AuthAction {
  const _AddMfaMethod({required this.methodType, this.methodName, this.phoneNumber, this.makePrimary});
  

 final  String methodType;
 final  String? methodName;
 final  String? phoneNumber;
 final  bool? makePrimary;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddMfaMethodCopyWith<_AddMfaMethod> get copyWith => __$AddMfaMethodCopyWithImpl<_AddMfaMethod>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.addMfaMethod'))
    ..add(DiagnosticsProperty('methodType', methodType))..add(DiagnosticsProperty('methodName', methodName))..add(DiagnosticsProperty('phoneNumber', phoneNumber))..add(DiagnosticsProperty('makePrimary', makePrimary));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddMfaMethod&&(identical(other.methodType, methodType) || other.methodType == methodType)&&(identical(other.methodName, methodName) || other.methodName == methodName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.makePrimary, makePrimary) || other.makePrimary == makePrimary));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodType,methodName,phoneNumber,makePrimary);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.addMfaMethod(methodType: $methodType, methodName: $methodName, phoneNumber: $phoneNumber, makePrimary: $makePrimary)';
}


}

/// @nodoc
abstract mixin class _$AddMfaMethodCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$AddMfaMethodCopyWith(_AddMfaMethod value, $Res Function(_AddMfaMethod) _then) = __$AddMfaMethodCopyWithImpl;
@useResult
$Res call({
 String methodType, String? methodName, String? phoneNumber, bool? makePrimary
});




}
/// @nodoc
class __$AddMfaMethodCopyWithImpl<$Res>
    implements _$AddMfaMethodCopyWith<$Res> {
  __$AddMfaMethodCopyWithImpl(this._self, this._then);

  final _AddMfaMethod _self;
  final $Res Function(_AddMfaMethod) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodType = null,Object? methodName = freezed,Object? phoneNumber = freezed,Object? makePrimary = freezed,}) {
  return _then(_AddMfaMethod(
methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,makePrimary: freezed == makePrimary ? _self.makePrimary : makePrimary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc


class _VerifyMfaMethod with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyMfaMethod({required this.methodId, required this.code});
  

 final  String methodId;
 final  String code;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyMfaMethodCopyWith<_VerifyMfaMethod> get copyWith => __$VerifyMfaMethodCopyWithImpl<_VerifyMfaMethod>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyMfaMethod'))
    ..add(DiagnosticsProperty('methodId', methodId))..add(DiagnosticsProperty('code', code));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyMfaMethod&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodId,code);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyMfaMethod(methodId: $methodId, code: $code)';
}


}

/// @nodoc
abstract mixin class _$VerifyMfaMethodCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyMfaMethodCopyWith(_VerifyMfaMethod value, $Res Function(_VerifyMfaMethod) _then) = __$VerifyMfaMethodCopyWithImpl;
@useResult
$Res call({
 String methodId, String code
});




}
/// @nodoc
class __$VerifyMfaMethodCopyWithImpl<$Res>
    implements _$VerifyMfaMethodCopyWith<$Res> {
  __$VerifyMfaMethodCopyWithImpl(this._self, this._then);

  final _VerifyMfaMethod _self;
  final $Res Function(_VerifyMfaMethod) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodId = null,Object? code = null,}) {
  return _then(_VerifyMfaMethod(
methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _DisableMfaMethod with DiagnosticableTreeMixin implements AuthAction {
  const _DisableMfaMethod({required this.methodId, required this.verificationCode});
  

 final  String methodId;
 final  String verificationCode;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DisableMfaMethodCopyWith<_DisableMfaMethod> get copyWith => __$DisableMfaMethodCopyWithImpl<_DisableMfaMethod>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.disableMfaMethod'))
    ..add(DiagnosticsProperty('methodId', methodId))..add(DiagnosticsProperty('verificationCode', verificationCode));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DisableMfaMethod&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.verificationCode, verificationCode) || other.verificationCode == verificationCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodId,verificationCode);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.disableMfaMethod(methodId: $methodId, verificationCode: $verificationCode)';
}


}

/// @nodoc
abstract mixin class _$DisableMfaMethodCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$DisableMfaMethodCopyWith(_DisableMfaMethod value, $Res Function(_DisableMfaMethod) _then) = __$DisableMfaMethodCopyWithImpl;
@useResult
$Res call({
 String methodId, String verificationCode
});




}
/// @nodoc
class __$DisableMfaMethodCopyWithImpl<$Res>
    implements _$DisableMfaMethodCopyWith<$Res> {
  __$DisableMfaMethodCopyWithImpl(this._self, this._then);

  final _DisableMfaMethod _self;
  final $Res Function(_DisableMfaMethod) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodId = null,Object? verificationCode = null,}) {
  return _then(_DisableMfaMethod(
methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,verificationCode: null == verificationCode ? _self.verificationCode : verificationCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _SetPrimaryMfaMethod with DiagnosticableTreeMixin implements AuthAction {
  const _SetPrimaryMfaMethod({required this.methodId, required this.verificationCode});
  

 final  String methodId;
 final  String verificationCode;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetPrimaryMfaMethodCopyWith<_SetPrimaryMfaMethod> get copyWith => __$SetPrimaryMfaMethodCopyWithImpl<_SetPrimaryMfaMethod>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.setPrimaryMfaMethod'))
    ..add(DiagnosticsProperty('methodId', methodId))..add(DiagnosticsProperty('verificationCode', verificationCode));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetPrimaryMfaMethod&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.verificationCode, verificationCode) || other.verificationCode == verificationCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,methodId,verificationCode);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.setPrimaryMfaMethod(methodId: $methodId, verificationCode: $verificationCode)';
}


}

/// @nodoc
abstract mixin class _$SetPrimaryMfaMethodCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$SetPrimaryMfaMethodCopyWith(_SetPrimaryMfaMethod value, $Res Function(_SetPrimaryMfaMethod) _then) = __$SetPrimaryMfaMethodCopyWithImpl;
@useResult
$Res call({
 String methodId, String verificationCode
});




}
/// @nodoc
class __$SetPrimaryMfaMethodCopyWithImpl<$Res>
    implements _$SetPrimaryMfaMethodCopyWith<$Res> {
  __$SetPrimaryMfaMethodCopyWithImpl(this._self, this._then);

  final _SetPrimaryMfaMethod _self;
  final $Res Function(_SetPrimaryMfaMethod) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? methodId = null,Object? verificationCode = null,}) {
  return _then(_SetPrimaryMfaMethod(
methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,verificationCode: null == verificationCode ? _self.verificationCode : verificationCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RegenerateRecoveryCodes with DiagnosticableTreeMixin implements AuthAction {
  const _RegenerateRecoveryCodes({required this.verificationCode});
  

 final  String verificationCode;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegenerateRecoveryCodesCopyWith<_RegenerateRecoveryCodes> get copyWith => __$RegenerateRecoveryCodesCopyWithImpl<_RegenerateRecoveryCodes>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.regenerateRecoveryCodes'))
    ..add(DiagnosticsProperty('verificationCode', verificationCode));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegenerateRecoveryCodes&&(identical(other.verificationCode, verificationCode) || other.verificationCode == verificationCode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,verificationCode);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.regenerateRecoveryCodes(verificationCode: $verificationCode)';
}


}

/// @nodoc
abstract mixin class _$RegenerateRecoveryCodesCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RegenerateRecoveryCodesCopyWith(_RegenerateRecoveryCodes value, $Res Function(_RegenerateRecoveryCodes) _then) = __$RegenerateRecoveryCodesCopyWithImpl;
@useResult
$Res call({
 String verificationCode
});




}
/// @nodoc
class __$RegenerateRecoveryCodesCopyWithImpl<$Res>
    implements _$RegenerateRecoveryCodesCopyWith<$Res> {
  __$RegenerateRecoveryCodesCopyWithImpl(this._self, this._then);

  final _RegenerateRecoveryCodes _self;
  final $Res Function(_RegenerateRecoveryCodes) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? verificationCode = null,}) {
  return _then(_RegenerateRecoveryCodes(
verificationCode: null == verificationCode ? _self.verificationCode : verificationCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RequestAccountRecoveryEmail with DiagnosticableTreeMixin implements AuthAction {
  const _RequestAccountRecoveryEmail({required this.email});
  

 final  String email;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestAccountRecoveryEmailCopyWith<_RequestAccountRecoveryEmail> get copyWith => __$RequestAccountRecoveryEmailCopyWithImpl<_RequestAccountRecoveryEmail>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestAccountRecoveryEmail'))
    ..add(DiagnosticsProperty('email', email));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestAccountRecoveryEmail&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestAccountRecoveryEmail(email: $email)';
}


}

/// @nodoc
abstract mixin class _$RequestAccountRecoveryEmailCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestAccountRecoveryEmailCopyWith(_RequestAccountRecoveryEmail value, $Res Function(_RequestAccountRecoveryEmail) _then) = __$RequestAccountRecoveryEmailCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class __$RequestAccountRecoveryEmailCopyWithImpl<$Res>
    implements _$RequestAccountRecoveryEmailCopyWith<$Res> {
  __$RequestAccountRecoveryEmailCopyWithImpl(this._self, this._then);

  final _RequestAccountRecoveryEmail _self;
  final $Res Function(_RequestAccountRecoveryEmail) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_RequestAccountRecoveryEmail(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RequestAccountRecoveryPhone with DiagnosticableTreeMixin implements AuthAction {
  const _RequestAccountRecoveryPhone({required this.phone});
  

 final  String phone;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestAccountRecoveryPhoneCopyWith<_RequestAccountRecoveryPhone> get copyWith => __$RequestAccountRecoveryPhoneCopyWithImpl<_RequestAccountRecoveryPhone>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.requestAccountRecoveryPhone'))
    ..add(DiagnosticsProperty('phone', phone));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestAccountRecoveryPhone&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.requestAccountRecoveryPhone(phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$RequestAccountRecoveryPhoneCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$RequestAccountRecoveryPhoneCopyWith(_RequestAccountRecoveryPhone value, $Res Function(_RequestAccountRecoveryPhone) _then) = __$RequestAccountRecoveryPhoneCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class __$RequestAccountRecoveryPhoneCopyWithImpl<$Res>
    implements _$RequestAccountRecoveryPhoneCopyWith<$Res> {
  __$RequestAccountRecoveryPhoneCopyWithImpl(this._self, this._then);

  final _RequestAccountRecoveryPhone _self;
  final $Res Function(_RequestAccountRecoveryPhone) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(_RequestAccountRecoveryPhone(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyAccountRecovery with DiagnosticableTreeMixin implements AuthAction {
  const _VerifyAccountRecovery({required this.token, required this.password, this.mfaMethod, this.phoneNumber});
  

 final  String token;
 final  String password;
 final  String? mfaMethod;
 final  String? phoneNumber;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyAccountRecoveryCopyWith<_VerifyAccountRecovery> get copyWith => __$VerifyAccountRecoveryCopyWithImpl<_VerifyAccountRecovery>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.verifyAccountRecovery'))
    ..add(DiagnosticsProperty('token', token))..add(DiagnosticsProperty('password', password))..add(DiagnosticsProperty('mfaMethod', mfaMethod))..add(DiagnosticsProperty('phoneNumber', phoneNumber));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyAccountRecovery&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password)&&(identical(other.mfaMethod, mfaMethod) || other.mfaMethod == mfaMethod)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}


@override
int get hashCode {
    return Object.hash(runtimeType,token,password,mfaMethod,phoneNumber);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.verifyAccountRecovery(token: $token, password: $password, mfaMethod: $mfaMethod, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class _$VerifyAccountRecoveryCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$VerifyAccountRecoveryCopyWith(_VerifyAccountRecovery value, $Res Function(_VerifyAccountRecovery) _then) = __$VerifyAccountRecoveryCopyWithImpl;
@useResult
$Res call({
 String token, String password, String? mfaMethod, String? phoneNumber
});




}
/// @nodoc
class __$VerifyAccountRecoveryCopyWithImpl<$Res>
    implements _$VerifyAccountRecoveryCopyWith<$Res> {
  __$VerifyAccountRecoveryCopyWithImpl(this._self, this._then);

  final _VerifyAccountRecovery _self;
  final $Res Function(_VerifyAccountRecovery) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? password = null,Object? mfaMethod = freezed,Object? phoneNumber = freezed,}) {
  return _then(_VerifyAccountRecovery(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,mfaMethod: freezed == mfaMethod ? _self.mfaMethod : mfaMethod // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _GetSecurityEvents with DiagnosticableTreeMixin implements AuthAction {
  const _GetSecurityEvents({this.limit, this.offset});
  

 final  int? limit;
 final  int? offset;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GetSecurityEventsCopyWith<_GetSecurityEvents> get copyWith => __$GetSecurityEventsCopyWithImpl<_GetSecurityEvents>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.getSecurityEvents'))
    ..add(DiagnosticsProperty('limit', limit))..add(DiagnosticsProperty('offset', offset));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetSecurityEvents&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,limit,offset);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.getSecurityEvents(limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class _$GetSecurityEventsCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$GetSecurityEventsCopyWith(_GetSecurityEvents value, $Res Function(_GetSecurityEvents) _then) = __$GetSecurityEventsCopyWithImpl;
@useResult
$Res call({
 int? limit, int? offset
});




}
/// @nodoc
class __$GetSecurityEventsCopyWithImpl<$Res>
    implements _$GetSecurityEventsCopyWith<$Res> {
  __$GetSecurityEventsCopyWithImpl(this._self, this._then);

  final _GetSecurityEvents _self;
  final $Res Function(_GetSecurityEvents) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? limit = freezed,Object? offset = freezed,}) {
  return _then(_GetSecurityEvents(
limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class _LinkGoogle with DiagnosticableTreeMixin implements AuthAction {
  const _LinkGoogle({required this.idToken});
  

 final  String idToken;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkGoogleCopyWith<_LinkGoogle> get copyWith => __$LinkGoogleCopyWithImpl<_LinkGoogle>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.linkGoogle'))
    ..add(DiagnosticsProperty('idToken', idToken));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkGoogle&&(identical(other.idToken, idToken) || other.idToken == idToken));
}


@override
int get hashCode {
    return Object.hash(runtimeType,idToken);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.linkGoogle(idToken: $idToken)';
}


}

/// @nodoc
abstract mixin class _$LinkGoogleCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$LinkGoogleCopyWith(_LinkGoogle value, $Res Function(_LinkGoogle) _then) = __$LinkGoogleCopyWithImpl;
@useResult
$Res call({
 String idToken
});




}
/// @nodoc
class __$LinkGoogleCopyWithImpl<$Res>
    implements _$LinkGoogleCopyWith<$Res> {
  __$LinkGoogleCopyWithImpl(this._self, this._then);

  final _LinkGoogle _self;
  final $Res Function(_LinkGoogle) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? idToken = null,}) {
  return _then(_LinkGoogle(
idToken: null == idToken ? _self.idToken : idToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _UnlinkGoogle with DiagnosticableTreeMixin implements AuthAction {
  const _UnlinkGoogle({required this.password});
  

 final  String password;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnlinkGoogleCopyWith<_UnlinkGoogle> get copyWith => __$UnlinkGoogleCopyWithImpl<_UnlinkGoogle>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AuthAction.unlinkGoogle'))
    ..add(DiagnosticsProperty('password', password));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnlinkGoogle&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,password);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AuthAction.unlinkGoogle(password: $password)';
}


}

/// @nodoc
abstract mixin class _$UnlinkGoogleCopyWith<$Res> implements $AuthActionCopyWith<$Res> {
  factory _$UnlinkGoogleCopyWith(_UnlinkGoogle value, $Res Function(_UnlinkGoogle) _then) = __$UnlinkGoogleCopyWithImpl;
@useResult
$Res call({
 String password
});




}
/// @nodoc
class __$UnlinkGoogleCopyWithImpl<$Res>
    implements _$UnlinkGoogleCopyWith<$Res> {
  __$UnlinkGoogleCopyWithImpl(this._self, this._then);

  final _UnlinkGoogle _self;
  final $Res Function(_UnlinkGoogle) _then;

/// Create a copy of AuthAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? password = null,}) {
  return _then(_UnlinkGoogle(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
