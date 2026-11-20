// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthUser {

 String get id; String? get email; String get firstName; String get lastName; String? get phone;@JsonKey(name: 'emailVerified') bool get emailVerified;@JsonKey(name: 'phoneVerified') bool get phoneVerified;@JsonKey(name: 'mfaEnabled') bool get mfaEnabled;@JsonKey(name: 'mfaEnrolledAt') DateTime? get mfaEnrolledAt;@JsonKey(name: 'accountStatus') String get accountStatus;@JsonKey(name: 'roles') List<String> get roles;@JsonKey(name: 'lastMfaVerifiedAt') DateTime? get lastMfaVerifiedAt;@JsonKey(name: 'createdAt') DateTime? get createdAt;@JsonKey(name: 'updatedAt') DateTime? get updatedAt;
/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthUserCopyWith<AuthUser> get copyWith => _$AuthUserCopyWithImpl<AuthUser>(this as AuthUser, _$identity);

  /// Serializes this AuthUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AuthUser;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUser&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.firstName, _this.firstName) || other.firstName == _this.firstName)&&(identical(other.lastName, _this.lastName) || other.lastName == _this.lastName)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.emailVerified, _this.emailVerified) || other.emailVerified == _this.emailVerified)&&(identical(other.phoneVerified, _this.phoneVerified) || other.phoneVerified == _this.phoneVerified)&&(identical(other.mfaEnabled, _this.mfaEnabled) || other.mfaEnabled == _this.mfaEnabled)&&(identical(other.mfaEnrolledAt, _this.mfaEnrolledAt) || other.mfaEnrolledAt == _this.mfaEnrolledAt)&&(identical(other.accountStatus, _this.accountStatus) || other.accountStatus == _this.accountStatus)&&const DeepCollectionEquality().equals(other.roles, _this.roles)&&(identical(other.lastMfaVerifiedAt, _this.lastMfaVerifiedAt) || other.lastMfaVerifiedAt == _this.lastMfaVerifiedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AuthUser;
  return Object.hash(runtimeType,_this.id,_this.email,_this.firstName,_this.lastName,_this.phone,_this.emailVerified,_this.phoneVerified,_this.mfaEnabled,_this.mfaEnrolledAt,_this.accountStatus,const DeepCollectionEquality().hash(_this.roles),_this.lastMfaVerifiedAt,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as AuthUser;
  return 'AuthUser(id: ${_this.id}, email: ${_this.email}, firstName: ${_this.firstName}, lastName: ${_this.lastName}, phone: ${_this.phone}, emailVerified: ${_this.emailVerified}, phoneVerified: ${_this.phoneVerified}, mfaEnabled: ${_this.mfaEnabled}, mfaEnrolledAt: ${_this.mfaEnrolledAt}, accountStatus: ${_this.accountStatus}, roles: ${_this.roles}, lastMfaVerifiedAt: ${_this.lastMfaVerifiedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $AuthUserCopyWith<$Res>  {
  factory $AuthUserCopyWith(AuthUser value, $Res Function(AuthUser) _then) = _$AuthUserCopyWithImpl;
@useResult
$Res call({
 String id, String? email, String firstName, String lastName, String? phone,@JsonKey(name: 'emailVerified') bool emailVerified,@JsonKey(name: 'phoneVerified') bool phoneVerified,@JsonKey(name: 'mfaEnabled') bool mfaEnabled,@JsonKey(name: 'mfaEnrolledAt') DateTime? mfaEnrolledAt,@JsonKey(name: 'accountStatus') String accountStatus,@JsonKey(name: 'roles') List<String> roles,@JsonKey(name: 'lastMfaVerifiedAt') DateTime? lastMfaVerifiedAt,@JsonKey(name: 'createdAt') DateTime? createdAt,@JsonKey(name: 'updatedAt') DateTime? updatedAt
});




}
/// @nodoc
class _$AuthUserCopyWithImpl<$Res>
    implements $AuthUserCopyWith<$Res> {
  _$AuthUserCopyWithImpl(this._self, this._then);

  final AuthUser _self;
  final $Res Function(AuthUser) _then;

/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = freezed,Object? firstName = null,Object? lastName = null,Object? phone = freezed,Object? emailVerified = null,Object? phoneVerified = null,Object? mfaEnabled = null,Object? mfaEnrolledAt = freezed,Object? accountStatus = null,Object? roles = null,Object? lastMfaVerifiedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(AuthUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolledAt: freezed == mfaEnrolledAt ? _self.mfaEnrolledAt : mfaEnrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,lastMfaVerifiedAt: freezed == lastMfaVerifiedAt ? _self.lastMfaVerifiedAt : lastMfaVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthUser].
extension AuthUserPatterns on AuthUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthUser() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthUser value)  $default,){
final _that = this;
switch (_that) {
case _AuthUser():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthUser value)?  $default,){
final _that = this;
switch (_that) {
case _AuthUser() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? email,  String firstName,  String lastName,  String? phone, @JsonKey(name: 'emailVerified')  bool emailVerified, @JsonKey(name: 'phoneVerified')  bool phoneVerified, @JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolledAt')  DateTime? mfaEnrolledAt, @JsonKey(name: 'accountStatus')  String accountStatus, @JsonKey(name: 'roles')  List<String> roles, @JsonKey(name: 'lastMfaVerifiedAt')  DateTime? lastMfaVerifiedAt, @JsonKey(name: 'createdAt')  DateTime? createdAt, @JsonKey(name: 'updatedAt')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthUser() when $default != null:
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phone,_that.emailVerified,_that.phoneVerified,_that.mfaEnabled,_that.mfaEnrolledAt,_that.accountStatus,_that.roles,_that.lastMfaVerifiedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? email,  String firstName,  String lastName,  String? phone, @JsonKey(name: 'emailVerified')  bool emailVerified, @JsonKey(name: 'phoneVerified')  bool phoneVerified, @JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolledAt')  DateTime? mfaEnrolledAt, @JsonKey(name: 'accountStatus')  String accountStatus, @JsonKey(name: 'roles')  List<String> roles, @JsonKey(name: 'lastMfaVerifiedAt')  DateTime? lastMfaVerifiedAt, @JsonKey(name: 'createdAt')  DateTime? createdAt, @JsonKey(name: 'updatedAt')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AuthUser():
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phone,_that.emailVerified,_that.phoneVerified,_that.mfaEnabled,_that.mfaEnrolledAt,_that.accountStatus,_that.roles,_that.lastMfaVerifiedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? email,  String firstName,  String lastName,  String? phone, @JsonKey(name: 'emailVerified')  bool emailVerified, @JsonKey(name: 'phoneVerified')  bool phoneVerified, @JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolledAt')  DateTime? mfaEnrolledAt, @JsonKey(name: 'accountStatus')  String accountStatus, @JsonKey(name: 'roles')  List<String> roles, @JsonKey(name: 'lastMfaVerifiedAt')  DateTime? lastMfaVerifiedAt, @JsonKey(name: 'createdAt')  DateTime? createdAt, @JsonKey(name: 'updatedAt')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AuthUser() when $default != null:
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phone,_that.emailVerified,_that.phoneVerified,_that.mfaEnabled,_that.mfaEnrolledAt,_that.accountStatus,_that.roles,_that.lastMfaVerifiedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthUser implements AuthUser {
  const _AuthUser({required this.id, this.email, required this.firstName, required this.lastName, this.phone, @JsonKey(name: 'emailVerified') this.emailVerified = false, @JsonKey(name: 'phoneVerified') this.phoneVerified = false, @JsonKey(name: 'mfaEnabled') this.mfaEnabled = false, @JsonKey(name: 'mfaEnrolledAt') this.mfaEnrolledAt, @JsonKey(name: 'accountStatus') this.accountStatus = 'active', @JsonKey(name: 'roles')  List<String> roles = const <String>[], @JsonKey(name: 'lastMfaVerifiedAt') this.lastMfaVerifiedAt, @JsonKey(name: 'createdAt') this.createdAt, @JsonKey(name: 'updatedAt') this.updatedAt}): _roles = roles;
  factory _AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);

@override final  String id;
@override final  String? email;
@override final  String firstName;
@override final  String lastName;
@override final  String? phone;
@override@JsonKey(name: 'emailVerified') final  bool emailVerified;
@override@JsonKey(name: 'phoneVerified') final  bool phoneVerified;
@override@JsonKey(name: 'mfaEnabled') final  bool mfaEnabled;
@override@JsonKey(name: 'mfaEnrolledAt') final  DateTime? mfaEnrolledAt;
@override@JsonKey(name: 'accountStatus') final  String accountStatus;
 final  List<String> _roles;
@override@JsonKey(name: 'roles') List<String> get roles {
  if (_roles is EqualUnmodifiableListView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roles);
}

@override@JsonKey(name: 'lastMfaVerifiedAt') final  DateTime? lastMfaVerifiedAt;
@override@JsonKey(name: 'createdAt') final  DateTime? createdAt;
@override@JsonKey(name: 'updatedAt') final  DateTime? updatedAt;

/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthUserCopyWith<_AuthUser> get copyWith => __$AuthUserCopyWithImpl<_AuthUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthUserToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthUser&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phoneVerified, phoneVerified) || other.phoneVerified == phoneVerified)&&(identical(other.mfaEnabled, mfaEnabled) || other.mfaEnabled == mfaEnabled)&&(identical(other.mfaEnrolledAt, mfaEnrolledAt) || other.mfaEnrolledAt == mfaEnrolledAt)&&(identical(other.accountStatus, accountStatus) || other.accountStatus == accountStatus)&&const DeepCollectionEquality().equals(other.roles, _roles)&&(identical(other.lastMfaVerifiedAt, lastMfaVerifiedAt) || other.lastMfaVerifiedAt == lastMfaVerifiedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,email,firstName,lastName,phone,emailVerified,phoneVerified,mfaEnabled,mfaEnrolledAt,accountStatus,const DeepCollectionEquality().hash(_roles),lastMfaVerifiedAt,createdAt,updatedAt);
}

@override
String toString() {
    return 'AuthUser(id: $id, email: $email, firstName: $firstName, lastName: $lastName, phone: $phone, emailVerified: $emailVerified, phoneVerified: $phoneVerified, mfaEnabled: $mfaEnabled, mfaEnrolledAt: $mfaEnrolledAt, accountStatus: $accountStatus, roles: $roles, lastMfaVerifiedAt: $lastMfaVerifiedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AuthUserCopyWith<$Res> implements $AuthUserCopyWith<$Res> {
  factory _$AuthUserCopyWith(_AuthUser value, $Res Function(_AuthUser) _then) = __$AuthUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String? email, String firstName, String lastName, String? phone,@JsonKey(name: 'emailVerified') bool emailVerified,@JsonKey(name: 'phoneVerified') bool phoneVerified,@JsonKey(name: 'mfaEnabled') bool mfaEnabled,@JsonKey(name: 'mfaEnrolledAt') DateTime? mfaEnrolledAt,@JsonKey(name: 'accountStatus') String accountStatus,@JsonKey(name: 'roles') List<String> roles,@JsonKey(name: 'lastMfaVerifiedAt') DateTime? lastMfaVerifiedAt,@JsonKey(name: 'createdAt') DateTime? createdAt,@JsonKey(name: 'updatedAt') DateTime? updatedAt
});




}
/// @nodoc
class __$AuthUserCopyWithImpl<$Res>
    implements _$AuthUserCopyWith<$Res> {
  __$AuthUserCopyWithImpl(this._self, this._then);

  final _AuthUser _self;
  final $Res Function(_AuthUser) _then;

/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = freezed,Object? firstName = null,Object? lastName = null,Object? phone = freezed,Object? emailVerified = null,Object? phoneVerified = null,Object? mfaEnabled = null,Object? mfaEnrolledAt = freezed,Object? accountStatus = null,Object? roles = null,Object? lastMfaVerifiedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_AuthUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolledAt: freezed == mfaEnrolledAt ? _self.mfaEnrolledAt : mfaEnrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as List<String>,lastMfaVerifiedAt: freezed == lastMfaVerifiedAt ? _self.lastMfaVerifiedAt : lastMfaVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$LoginResponse {

@JsonKey(name: 'authenticationStatus') String get authenticationStatus;@JsonKey(name: 'challengeId') String? get challengeId;@JsonKey(name: 'availableMethods') List<String>? get availableMethods;@JsonKey(name: 'enrollmentToken') String? get enrollmentToken; AuthUser? get user;@JsonKey(name: 'sessionId') String? get sessionId;@JsonKey(name: 'expiresIn') int? get expiresIn;@JsonKey(name: 'accessToken') String? get accessToken;@JsonKey(name: 'refreshToken') String? get refreshToken;
/// Create a copy of LoginResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginResponseCopyWith<LoginResponse> get copyWith => _$LoginResponseCopyWithImpl<LoginResponse>(this as LoginResponse, _$identity);

  /// Serializes this LoginResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LoginResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginResponse&&(identical(other.authenticationStatus, _this.authenticationStatus) || other.authenticationStatus == _this.authenticationStatus)&&(identical(other.challengeId, _this.challengeId) || other.challengeId == _this.challengeId)&&const DeepCollectionEquality().equals(other.availableMethods, _this.availableMethods)&&(identical(other.enrollmentToken, _this.enrollmentToken) || other.enrollmentToken == _this.enrollmentToken)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.expiresIn, _this.expiresIn) || other.expiresIn == _this.expiresIn)&&(identical(other.accessToken, _this.accessToken) || other.accessToken == _this.accessToken)&&(identical(other.refreshToken, _this.refreshToken) || other.refreshToken == _this.refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LoginResponse;
  return Object.hash(runtimeType,_this.authenticationStatus,_this.challengeId,const DeepCollectionEquality().hash(_this.availableMethods),_this.enrollmentToken,_this.user,_this.sessionId,_this.expiresIn,_this.accessToken,_this.refreshToken);
}

@override
String toString() {
  final _this = this as LoginResponse;
  return 'LoginResponse(authenticationStatus: ${_this.authenticationStatus}, challengeId: ${_this.challengeId}, availableMethods: ${_this.availableMethods}, enrollmentToken: ${_this.enrollmentToken}, user: ${_this.user}, sessionId: ${_this.sessionId}, expiresIn: ${_this.expiresIn}, accessToken: ${_this.accessToken}, refreshToken: ${_this.refreshToken})';
}


}

/// @nodoc
abstract mixin class $LoginResponseCopyWith<$Res>  {
  factory $LoginResponseCopyWith(LoginResponse value, $Res Function(LoginResponse) _then) = _$LoginResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'authenticationStatus') String authenticationStatus,@JsonKey(name: 'challengeId') String? challengeId,@JsonKey(name: 'availableMethods') List<String>? availableMethods,@JsonKey(name: 'enrollmentToken') String? enrollmentToken, AuthUser? user,@JsonKey(name: 'sessionId') String? sessionId,@JsonKey(name: 'expiresIn') int? expiresIn,@JsonKey(name: 'accessToken') String? accessToken,@JsonKey(name: 'refreshToken') String? refreshToken
});


$AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class _$LoginResponseCopyWithImpl<$Res>
    implements $LoginResponseCopyWith<$Res> {
  _$LoginResponseCopyWithImpl(this._self, this._then);

  final LoginResponse _self;
  final $Res Function(LoginResponse) _then;

/// Create a copy of LoginResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? authenticationStatus = null,Object? challengeId = freezed,Object? availableMethods = freezed,Object? enrollmentToken = freezed,Object? user = freezed,Object? sessionId = freezed,Object? expiresIn = freezed,Object? accessToken = freezed,Object? refreshToken = freezed,}) {
  return _then(LoginResponse(
authenticationStatus: null == authenticationStatus ? _self.authenticationStatus : authenticationStatus // ignore: cast_nullable_to_non_nullable
as String,challengeId: freezed == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String?,availableMethods: freezed == availableMethods ? _self.availableMethods : availableMethods // ignore: cast_nullable_to_non_nullable
as List<String>?,enrollmentToken: freezed == enrollmentToken ? _self.enrollmentToken : enrollmentToken // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,expiresIn: freezed == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int?,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of LoginResponse
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


/// Adds pattern-matching-related methods to [LoginResponse].
extension LoginResponsePatterns on LoginResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginResponse value)  $default,){
final _that = this;
switch (_that) {
case _LoginResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginResponse value)?  $default,){
final _that = this;
switch (_that) {
case _LoginResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'authenticationStatus')  String authenticationStatus, @JsonKey(name: 'challengeId')  String? challengeId, @JsonKey(name: 'availableMethods')  List<String>? availableMethods, @JsonKey(name: 'enrollmentToken')  String? enrollmentToken,  AuthUser? user, @JsonKey(name: 'sessionId')  String? sessionId, @JsonKey(name: 'expiresIn')  int? expiresIn, @JsonKey(name: 'accessToken')  String? accessToken, @JsonKey(name: 'refreshToken')  String? refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginResponse() when $default != null:
return $default(_that.authenticationStatus,_that.challengeId,_that.availableMethods,_that.enrollmentToken,_that.user,_that.sessionId,_that.expiresIn,_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'authenticationStatus')  String authenticationStatus, @JsonKey(name: 'challengeId')  String? challengeId, @JsonKey(name: 'availableMethods')  List<String>? availableMethods, @JsonKey(name: 'enrollmentToken')  String? enrollmentToken,  AuthUser? user, @JsonKey(name: 'sessionId')  String? sessionId, @JsonKey(name: 'expiresIn')  int? expiresIn, @JsonKey(name: 'accessToken')  String? accessToken, @JsonKey(name: 'refreshToken')  String? refreshToken)  $default,) {final _that = this;
switch (_that) {
case _LoginResponse():
return $default(_that.authenticationStatus,_that.challengeId,_that.availableMethods,_that.enrollmentToken,_that.user,_that.sessionId,_that.expiresIn,_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'authenticationStatus')  String authenticationStatus, @JsonKey(name: 'challengeId')  String? challengeId, @JsonKey(name: 'availableMethods')  List<String>? availableMethods, @JsonKey(name: 'enrollmentToken')  String? enrollmentToken,  AuthUser? user, @JsonKey(name: 'sessionId')  String? sessionId, @JsonKey(name: 'expiresIn')  int? expiresIn, @JsonKey(name: 'accessToken')  String? accessToken, @JsonKey(name: 'refreshToken')  String? refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _LoginResponse() when $default != null:
return $default(_that.authenticationStatus,_that.challengeId,_that.availableMethods,_that.enrollmentToken,_that.user,_that.sessionId,_that.expiresIn,_that.accessToken,_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginResponse implements LoginResponse {
  const _LoginResponse({@JsonKey(name: 'authenticationStatus') required this.authenticationStatus, @JsonKey(name: 'challengeId') this.challengeId, @JsonKey(name: 'availableMethods')  List<String>? availableMethods, @JsonKey(name: 'enrollmentToken') this.enrollmentToken, this.user, @JsonKey(name: 'sessionId') this.sessionId, @JsonKey(name: 'expiresIn') this.expiresIn, @JsonKey(name: 'accessToken') this.accessToken, @JsonKey(name: 'refreshToken') this.refreshToken}): _availableMethods = availableMethods;
  factory _LoginResponse.fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);

@override@JsonKey(name: 'authenticationStatus') final  String authenticationStatus;
@override@JsonKey(name: 'challengeId') final  String? challengeId;
 final  List<String>? _availableMethods;
@override@JsonKey(name: 'availableMethods') List<String>? get availableMethods {
  final value = _availableMethods;
  if (value == null) return null;
  if (_availableMethods is EqualUnmodifiableListView) return _availableMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'enrollmentToken') final  String? enrollmentToken;
@override final  AuthUser? user;
@override@JsonKey(name: 'sessionId') final  String? sessionId;
@override@JsonKey(name: 'expiresIn') final  int? expiresIn;
@override@JsonKey(name: 'accessToken') final  String? accessToken;
@override@JsonKey(name: 'refreshToken') final  String? refreshToken;

/// Create a copy of LoginResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginResponseCopyWith<_LoginResponse> get copyWith => __$LoginResponseCopyWithImpl<_LoginResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginResponse&&(identical(other.authenticationStatus, authenticationStatus) || other.authenticationStatus == authenticationStatus)&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&const DeepCollectionEquality().equals(other.availableMethods, _availableMethods)&&(identical(other.enrollmentToken, enrollmentToken) || other.enrollmentToken == enrollmentToken)&&(identical(other.user, user) || other.user == user)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,authenticationStatus,challengeId,const DeepCollectionEquality().hash(_availableMethods),enrollmentToken,user,sessionId,expiresIn,accessToken,refreshToken);
}

@override
String toString() {
    return 'LoginResponse(authenticationStatus: $authenticationStatus, challengeId: $challengeId, availableMethods: $availableMethods, enrollmentToken: $enrollmentToken, user: $user, sessionId: $sessionId, expiresIn: $expiresIn, accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$LoginResponseCopyWith<$Res> implements $LoginResponseCopyWith<$Res> {
  factory _$LoginResponseCopyWith(_LoginResponse value, $Res Function(_LoginResponse) _then) = __$LoginResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'authenticationStatus') String authenticationStatus,@JsonKey(name: 'challengeId') String? challengeId,@JsonKey(name: 'availableMethods') List<String>? availableMethods,@JsonKey(name: 'enrollmentToken') String? enrollmentToken, AuthUser? user,@JsonKey(name: 'sessionId') String? sessionId,@JsonKey(name: 'expiresIn') int? expiresIn,@JsonKey(name: 'accessToken') String? accessToken,@JsonKey(name: 'refreshToken') String? refreshToken
});


@override $AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class __$LoginResponseCopyWithImpl<$Res>
    implements _$LoginResponseCopyWith<$Res> {
  __$LoginResponseCopyWithImpl(this._self, this._then);

  final _LoginResponse _self;
  final $Res Function(_LoginResponse) _then;

/// Create a copy of LoginResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? authenticationStatus = null,Object? challengeId = freezed,Object? availableMethods = freezed,Object? enrollmentToken = freezed,Object? user = freezed,Object? sessionId = freezed,Object? expiresIn = freezed,Object? accessToken = freezed,Object? refreshToken = freezed,}) {
  return _then(_LoginResponse(
authenticationStatus: null == authenticationStatus ? _self.authenticationStatus : authenticationStatus // ignore: cast_nullable_to_non_nullable
as String,challengeId: freezed == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String?,availableMethods: freezed == availableMethods ? _self._availableMethods : availableMethods // ignore: cast_nullable_to_non_nullable
as List<String>?,enrollmentToken: freezed == enrollmentToken ? _self.enrollmentToken : enrollmentToken // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,expiresIn: freezed == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int?,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LoginResponse
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
mixin _$MfaEnrollmentStartResponse {

 String get method;@JsonKey(name: 'methodId') String get methodId;@JsonKey(name: 'provisioningUri') String? get provisioningUri;@JsonKey(name: 'qrCodeDataUrl') String? get qrCodeDataUrl; String? get secret;@JsonKey(name: 'recoveryCodes') List<String>? get recoveryCodes;
/// Create a copy of MfaEnrollmentStartResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaEnrollmentStartResponseCopyWith<MfaEnrollmentStartResponse> get copyWith => _$MfaEnrollmentStartResponseCopyWithImpl<MfaEnrollmentStartResponse>(this as MfaEnrollmentStartResponse, _$identity);

  /// Serializes this MfaEnrollmentStartResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaEnrollmentStartResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaEnrollmentStartResponse&&(identical(other.method, _this.method) || other.method == _this.method)&&(identical(other.methodId, _this.methodId) || other.methodId == _this.methodId)&&(identical(other.provisioningUri, _this.provisioningUri) || other.provisioningUri == _this.provisioningUri)&&(identical(other.qrCodeDataUrl, _this.qrCodeDataUrl) || other.qrCodeDataUrl == _this.qrCodeDataUrl)&&(identical(other.secret, _this.secret) || other.secret == _this.secret)&&const DeepCollectionEquality().equals(other.recoveryCodes, _this.recoveryCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaEnrollmentStartResponse;
  return Object.hash(runtimeType,_this.method,_this.methodId,_this.provisioningUri,_this.qrCodeDataUrl,_this.secret,const DeepCollectionEquality().hash(_this.recoveryCodes));
}

@override
String toString() {
  final _this = this as MfaEnrollmentStartResponse;
  return 'MfaEnrollmentStartResponse(method: ${_this.method}, methodId: ${_this.methodId}, provisioningUri: ${_this.provisioningUri}, qrCodeDataUrl: ${_this.qrCodeDataUrl}, secret: ${_this.secret}, recoveryCodes: ${_this.recoveryCodes})';
}


}

/// @nodoc
abstract mixin class $MfaEnrollmentStartResponseCopyWith<$Res>  {
  factory $MfaEnrollmentStartResponseCopyWith(MfaEnrollmentStartResponse value, $Res Function(MfaEnrollmentStartResponse) _then) = _$MfaEnrollmentStartResponseCopyWithImpl;
@useResult
$Res call({
 String method,@JsonKey(name: 'methodId') String methodId,@JsonKey(name: 'provisioningUri') String? provisioningUri,@JsonKey(name: 'qrCodeDataUrl') String? qrCodeDataUrl, String? secret,@JsonKey(name: 'recoveryCodes') List<String>? recoveryCodes
});




}
/// @nodoc
class _$MfaEnrollmentStartResponseCopyWithImpl<$Res>
    implements $MfaEnrollmentStartResponseCopyWith<$Res> {
  _$MfaEnrollmentStartResponseCopyWithImpl(this._self, this._then);

  final MfaEnrollmentStartResponse _self;
  final $Res Function(MfaEnrollmentStartResponse) _then;

/// Create a copy of MfaEnrollmentStartResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,Object? methodId = null,Object? provisioningUri = freezed,Object? qrCodeDataUrl = freezed,Object? secret = freezed,Object? recoveryCodes = freezed,}) {
  return _then(MfaEnrollmentStartResponse(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,provisioningUri: freezed == provisioningUri ? _self.provisioningUri : provisioningUri // ignore: cast_nullable_to_non_nullable
as String?,qrCodeDataUrl: freezed == qrCodeDataUrl ? _self.qrCodeDataUrl : qrCodeDataUrl // ignore: cast_nullable_to_non_nullable
as String?,secret: freezed == secret ? _self.secret : secret // ignore: cast_nullable_to_non_nullable
as String?,recoveryCodes: freezed == recoveryCodes ? _self.recoveryCodes : recoveryCodes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaEnrollmentStartResponse].
extension MfaEnrollmentStartResponsePatterns on MfaEnrollmentStartResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaEnrollmentStartResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaEnrollmentStartResponse value)  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaEnrollmentStartResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String method, @JsonKey(name: 'methodId')  String methodId, @JsonKey(name: 'provisioningUri')  String? provisioningUri, @JsonKey(name: 'qrCodeDataUrl')  String? qrCodeDataUrl,  String? secret, @JsonKey(name: 'recoveryCodes')  List<String>? recoveryCodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse() when $default != null:
return $default(_that.method,_that.methodId,_that.provisioningUri,_that.qrCodeDataUrl,_that.secret,_that.recoveryCodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String method, @JsonKey(name: 'methodId')  String methodId, @JsonKey(name: 'provisioningUri')  String? provisioningUri, @JsonKey(name: 'qrCodeDataUrl')  String? qrCodeDataUrl,  String? secret, @JsonKey(name: 'recoveryCodes')  List<String>? recoveryCodes)  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse():
return $default(_that.method,_that.methodId,_that.provisioningUri,_that.qrCodeDataUrl,_that.secret,_that.recoveryCodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String method, @JsonKey(name: 'methodId')  String methodId, @JsonKey(name: 'provisioningUri')  String? provisioningUri, @JsonKey(name: 'qrCodeDataUrl')  String? qrCodeDataUrl,  String? secret, @JsonKey(name: 'recoveryCodes')  List<String>? recoveryCodes)?  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartResponse() when $default != null:
return $default(_that.method,_that.methodId,_that.provisioningUri,_that.qrCodeDataUrl,_that.secret,_that.recoveryCodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaEnrollmentStartResponse implements MfaEnrollmentStartResponse {
  const _MfaEnrollmentStartResponse({required this.method, @JsonKey(name: 'methodId') required this.methodId, @JsonKey(name: 'provisioningUri') this.provisioningUri, @JsonKey(name: 'qrCodeDataUrl') this.qrCodeDataUrl, this.secret, @JsonKey(name: 'recoveryCodes')  List<String>? recoveryCodes}): _recoveryCodes = recoveryCodes;
  factory _MfaEnrollmentStartResponse.fromJson(Map<String, dynamic> json) => _$MfaEnrollmentStartResponseFromJson(json);

@override final  String method;
@override@JsonKey(name: 'methodId') final  String methodId;
@override@JsonKey(name: 'provisioningUri') final  String? provisioningUri;
@override@JsonKey(name: 'qrCodeDataUrl') final  String? qrCodeDataUrl;
@override final  String? secret;
 final  List<String>? _recoveryCodes;
@override@JsonKey(name: 'recoveryCodes') List<String>? get recoveryCodes {
  final value = _recoveryCodes;
  if (value == null) return null;
  if (_recoveryCodes is EqualUnmodifiableListView) return _recoveryCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of MfaEnrollmentStartResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaEnrollmentStartResponseCopyWith<_MfaEnrollmentStartResponse> get copyWith => __$MfaEnrollmentStartResponseCopyWithImpl<_MfaEnrollmentStartResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaEnrollmentStartResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaEnrollmentStartResponse&&(identical(other.method, method) || other.method == method)&&(identical(other.methodId, methodId) || other.methodId == methodId)&&(identical(other.provisioningUri, provisioningUri) || other.provisioningUri == provisioningUri)&&(identical(other.qrCodeDataUrl, qrCodeDataUrl) || other.qrCodeDataUrl == qrCodeDataUrl)&&(identical(other.secret, secret) || other.secret == secret)&&const DeepCollectionEquality().equals(other.recoveryCodes, _recoveryCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,method,methodId,provisioningUri,qrCodeDataUrl,secret,const DeepCollectionEquality().hash(_recoveryCodes));
}

@override
String toString() {
    return 'MfaEnrollmentStartResponse(method: $method, methodId: $methodId, provisioningUri: $provisioningUri, qrCodeDataUrl: $qrCodeDataUrl, secret: $secret, recoveryCodes: $recoveryCodes)';
}


}

/// @nodoc
abstract mixin class _$MfaEnrollmentStartResponseCopyWith<$Res> implements $MfaEnrollmentStartResponseCopyWith<$Res> {
  factory _$MfaEnrollmentStartResponseCopyWith(_MfaEnrollmentStartResponse value, $Res Function(_MfaEnrollmentStartResponse) _then) = __$MfaEnrollmentStartResponseCopyWithImpl;
@override @useResult
$Res call({
 String method,@JsonKey(name: 'methodId') String methodId,@JsonKey(name: 'provisioningUri') String? provisioningUri,@JsonKey(name: 'qrCodeDataUrl') String? qrCodeDataUrl, String? secret,@JsonKey(name: 'recoveryCodes') List<String>? recoveryCodes
});




}
/// @nodoc
class __$MfaEnrollmentStartResponseCopyWithImpl<$Res>
    implements _$MfaEnrollmentStartResponseCopyWith<$Res> {
  __$MfaEnrollmentStartResponseCopyWithImpl(this._self, this._then);

  final _MfaEnrollmentStartResponse _self;
  final $Res Function(_MfaEnrollmentStartResponse) _then;

/// Create a copy of MfaEnrollmentStartResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? methodId = null,Object? provisioningUri = freezed,Object? qrCodeDataUrl = freezed,Object? secret = freezed,Object? recoveryCodes = freezed,}) {
  return _then(_MfaEnrollmentStartResponse(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,methodId: null == methodId ? _self.methodId : methodId // ignore: cast_nullable_to_non_nullable
as String,provisioningUri: freezed == provisioningUri ? _self.provisioningUri : provisioningUri // ignore: cast_nullable_to_non_nullable
as String?,qrCodeDataUrl: freezed == qrCodeDataUrl ? _self.qrCodeDataUrl : qrCodeDataUrl // ignore: cast_nullable_to_non_nullable
as String?,secret: freezed == secret ? _self.secret : secret // ignore: cast_nullable_to_non_nullable
as String?,recoveryCodes: freezed == recoveryCodes ? _self._recoveryCodes : recoveryCodes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$MfaEnrollmentVerifyResponse {

 bool get success; String get message;@JsonKey(name: 'mfaStatus') String? get mfaStatus;
/// Create a copy of MfaEnrollmentVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaEnrollmentVerifyResponseCopyWith<MfaEnrollmentVerifyResponse> get copyWith => _$MfaEnrollmentVerifyResponseCopyWithImpl<MfaEnrollmentVerifyResponse>(this as MfaEnrollmentVerifyResponse, _$identity);

  /// Serializes this MfaEnrollmentVerifyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaEnrollmentVerifyResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaEnrollmentVerifyResponse&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.mfaStatus, _this.mfaStatus) || other.mfaStatus == _this.mfaStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaEnrollmentVerifyResponse;
  return Object.hash(runtimeType,_this.success,_this.message,_this.mfaStatus);
}

@override
String toString() {
  final _this = this as MfaEnrollmentVerifyResponse;
  return 'MfaEnrollmentVerifyResponse(success: ${_this.success}, message: ${_this.message}, mfaStatus: ${_this.mfaStatus})';
}


}

/// @nodoc
abstract mixin class $MfaEnrollmentVerifyResponseCopyWith<$Res>  {
  factory $MfaEnrollmentVerifyResponseCopyWith(MfaEnrollmentVerifyResponse value, $Res Function(MfaEnrollmentVerifyResponse) _then) = _$MfaEnrollmentVerifyResponseCopyWithImpl;
@useResult
$Res call({
 bool success, String message,@JsonKey(name: 'mfaStatus') String? mfaStatus
});




}
/// @nodoc
class _$MfaEnrollmentVerifyResponseCopyWithImpl<$Res>
    implements $MfaEnrollmentVerifyResponseCopyWith<$Res> {
  _$MfaEnrollmentVerifyResponseCopyWithImpl(this._self, this._then);

  final MfaEnrollmentVerifyResponse _self;
  final $Res Function(MfaEnrollmentVerifyResponse) _then;

/// Create a copy of MfaEnrollmentVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? message = null,Object? mfaStatus = freezed,}) {
  return _then(MfaEnrollmentVerifyResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,mfaStatus: freezed == mfaStatus ? _self.mfaStatus : mfaStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaEnrollmentVerifyResponse].
extension MfaEnrollmentVerifyResponsePatterns on MfaEnrollmentVerifyResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaEnrollmentVerifyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaEnrollmentVerifyResponse value)  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaEnrollmentVerifyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String message, @JsonKey(name: 'mfaStatus')  String? mfaStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse() when $default != null:
return $default(_that.success,_that.message,_that.mfaStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String message, @JsonKey(name: 'mfaStatus')  String? mfaStatus)  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse():
return $default(_that.success,_that.message,_that.mfaStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String message, @JsonKey(name: 'mfaStatus')  String? mfaStatus)?  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyResponse() when $default != null:
return $default(_that.success,_that.message,_that.mfaStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaEnrollmentVerifyResponse implements MfaEnrollmentVerifyResponse {
  const _MfaEnrollmentVerifyResponse({required this.success, required this.message, @JsonKey(name: 'mfaStatus') this.mfaStatus});
  factory _MfaEnrollmentVerifyResponse.fromJson(Map<String, dynamic> json) => _$MfaEnrollmentVerifyResponseFromJson(json);

@override final  bool success;
@override final  String message;
@override@JsonKey(name: 'mfaStatus') final  String? mfaStatus;

/// Create a copy of MfaEnrollmentVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaEnrollmentVerifyResponseCopyWith<_MfaEnrollmentVerifyResponse> get copyWith => __$MfaEnrollmentVerifyResponseCopyWithImpl<_MfaEnrollmentVerifyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaEnrollmentVerifyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaEnrollmentVerifyResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message)&&(identical(other.mfaStatus, mfaStatus) || other.mfaStatus == mfaStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,success,message,mfaStatus);
}

@override
String toString() {
    return 'MfaEnrollmentVerifyResponse(success: $success, message: $message, mfaStatus: $mfaStatus)';
}


}

/// @nodoc
abstract mixin class _$MfaEnrollmentVerifyResponseCopyWith<$Res> implements $MfaEnrollmentVerifyResponseCopyWith<$Res> {
  factory _$MfaEnrollmentVerifyResponseCopyWith(_MfaEnrollmentVerifyResponse value, $Res Function(_MfaEnrollmentVerifyResponse) _then) = __$MfaEnrollmentVerifyResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, String message,@JsonKey(name: 'mfaStatus') String? mfaStatus
});




}
/// @nodoc
class __$MfaEnrollmentVerifyResponseCopyWithImpl<$Res>
    implements _$MfaEnrollmentVerifyResponseCopyWith<$Res> {
  __$MfaEnrollmentVerifyResponseCopyWithImpl(this._self, this._then);

  final _MfaEnrollmentVerifyResponse _self;
  final $Res Function(_MfaEnrollmentVerifyResponse) _then;

/// Create a copy of MfaEnrollmentVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? message = null,Object? mfaStatus = freezed,}) {
  return _then(_MfaEnrollmentVerifyResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,mfaStatus: freezed == mfaStatus ? _self.mfaStatus : mfaStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MfaMethod {

 String get id;@JsonKey(name: 'userId') String get userId;@JsonKey(name: 'methodType') String get methodType;@JsonKey(name: 'methodName') String? get methodName;@JsonKey(name: 'isPrimary') bool get isPrimary;@JsonKey(name: 'isVerified') bool get isVerified;@JsonKey(name: 'isActive') bool get isActive;@JsonKey(name: 'verifiedAt') DateTime? get verifiedAt;@JsonKey(name: 'createdAt') DateTime get createdAt;@JsonKey(name: 'updatedAt') DateTime get updatedAt;
/// Create a copy of MfaMethod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaMethodCopyWith<MfaMethod> get copyWith => _$MfaMethodCopyWithImpl<MfaMethod>(this as MfaMethod, _$identity);

  /// Serializes this MfaMethod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaMethod;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaMethod&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.methodType, _this.methodType) || other.methodType == _this.methodType)&&(identical(other.methodName, _this.methodName) || other.methodName == _this.methodName)&&(identical(other.isPrimary, _this.isPrimary) || other.isPrimary == _this.isPrimary)&&(identical(other.isVerified, _this.isVerified) || other.isVerified == _this.isVerified)&&(identical(other.isActive, _this.isActive) || other.isActive == _this.isActive)&&(identical(other.verifiedAt, _this.verifiedAt) || other.verifiedAt == _this.verifiedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaMethod;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.methodType,_this.methodName,_this.isPrimary,_this.isVerified,_this.isActive,_this.verifiedAt,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as MfaMethod;
  return 'MfaMethod(id: ${_this.id}, userId: ${_this.userId}, methodType: ${_this.methodType}, methodName: ${_this.methodName}, isPrimary: ${_this.isPrimary}, isVerified: ${_this.isVerified}, isActive: ${_this.isActive}, verifiedAt: ${_this.verifiedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $MfaMethodCopyWith<$Res>  {
  factory $MfaMethodCopyWith(MfaMethod value, $Res Function(MfaMethod) _then) = _$MfaMethodCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'userId') String userId,@JsonKey(name: 'methodType') String methodType,@JsonKey(name: 'methodName') String? methodName,@JsonKey(name: 'isPrimary') bool isPrimary,@JsonKey(name: 'isVerified') bool isVerified,@JsonKey(name: 'isActive') bool isActive,@JsonKey(name: 'verifiedAt') DateTime? verifiedAt,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class _$MfaMethodCopyWithImpl<$Res>
    implements $MfaMethodCopyWith<$Res> {
  _$MfaMethodCopyWithImpl(this._self, this._then);

  final MfaMethod _self;
  final $Res Function(MfaMethod) _then;

/// Create a copy of MfaMethod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? methodType = null,Object? methodName = freezed,Object? isPrimary = null,Object? isVerified = null,Object? isActive = null,Object? verifiedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(MfaMethod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaMethod].
extension MfaMethodPatterns on MfaMethod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaMethod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaMethod() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaMethod value)  $default,){
final _that = this;
switch (_that) {
case _MfaMethod():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaMethod value)?  $default,){
final _that = this;
switch (_that) {
case _MfaMethod() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String userId, @JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'isPrimary')  bool isPrimary, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'isActive')  bool isActive, @JsonKey(name: 'verifiedAt')  DateTime? verifiedAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaMethod() when $default != null:
return $default(_that.id,_that.userId,_that.methodType,_that.methodName,_that.isPrimary,_that.isVerified,_that.isActive,_that.verifiedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String userId, @JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'isPrimary')  bool isPrimary, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'isActive')  bool isActive, @JsonKey(name: 'verifiedAt')  DateTime? verifiedAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MfaMethod():
return $default(_that.id,_that.userId,_that.methodType,_that.methodName,_that.isPrimary,_that.isVerified,_that.isActive,_that.verifiedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'userId')  String userId, @JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'isPrimary')  bool isPrimary, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'isActive')  bool isActive, @JsonKey(name: 'verifiedAt')  DateTime? verifiedAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MfaMethod() when $default != null:
return $default(_that.id,_that.userId,_that.methodType,_that.methodName,_that.isPrimary,_that.isVerified,_that.isActive,_that.verifiedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaMethod implements MfaMethod {
  const _MfaMethod({required this.id, @JsonKey(name: 'userId') required this.userId, @JsonKey(name: 'methodType') required this.methodType, @JsonKey(name: 'methodName') this.methodName, @JsonKey(name: 'isPrimary') required this.isPrimary, @JsonKey(name: 'isVerified') required this.isVerified, @JsonKey(name: 'isActive') required this.isActive, @JsonKey(name: 'verifiedAt') this.verifiedAt, @JsonKey(name: 'createdAt') required this.createdAt, @JsonKey(name: 'updatedAt') required this.updatedAt});
  factory _MfaMethod.fromJson(Map<String, dynamic> json) => _$MfaMethodFromJson(json);

@override final  String id;
@override@JsonKey(name: 'userId') final  String userId;
@override@JsonKey(name: 'methodType') final  String methodType;
@override@JsonKey(name: 'methodName') final  String? methodName;
@override@JsonKey(name: 'isPrimary') final  bool isPrimary;
@override@JsonKey(name: 'isVerified') final  bool isVerified;
@override@JsonKey(name: 'isActive') final  bool isActive;
@override@JsonKey(name: 'verifiedAt') final  DateTime? verifiedAt;
@override@JsonKey(name: 'createdAt') final  DateTime createdAt;
@override@JsonKey(name: 'updatedAt') final  DateTime updatedAt;

/// Create a copy of MfaMethod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaMethodCopyWith<_MfaMethod> get copyWith => __$MfaMethodCopyWithImpl<_MfaMethod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaMethodToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaMethod&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.methodType, methodType) || other.methodType == methodType)&&(identical(other.methodName, methodName) || other.methodName == methodName)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,methodType,methodName,isPrimary,isVerified,isActive,verifiedAt,createdAt,updatedAt);
}

@override
String toString() {
    return 'MfaMethod(id: $id, userId: $userId, methodType: $methodType, methodName: $methodName, isPrimary: $isPrimary, isVerified: $isVerified, isActive: $isActive, verifiedAt: $verifiedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MfaMethodCopyWith<$Res> implements $MfaMethodCopyWith<$Res> {
  factory _$MfaMethodCopyWith(_MfaMethod value, $Res Function(_MfaMethod) _then) = __$MfaMethodCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'userId') String userId,@JsonKey(name: 'methodType') String methodType,@JsonKey(name: 'methodName') String? methodName,@JsonKey(name: 'isPrimary') bool isPrimary,@JsonKey(name: 'isVerified') bool isVerified,@JsonKey(name: 'isActive') bool isActive,@JsonKey(name: 'verifiedAt') DateTime? verifiedAt,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class __$MfaMethodCopyWithImpl<$Res>
    implements _$MfaMethodCopyWith<$Res> {
  __$MfaMethodCopyWithImpl(this._self, this._then);

  final _MfaMethod _self;
  final $Res Function(_MfaMethod) _then;

/// Create a copy of MfaMethod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? methodType = null,Object? methodName = freezed,Object? isPrimary = null,Object? isVerified = null,Object? isActive = null,Object? verifiedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_MfaMethod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$MfaStatusResponse {

@JsonKey(name: 'mfaEnabled') bool get mfaEnabled;@JsonKey(name: 'mfaEnrolled') bool get mfaEnrolled;@JsonKey(name: 'enrollmentRequired') bool get enrollmentRequired; List<MfaMethod> get methods;@JsonKey(name: 'recoveryCodesRemaining') int get recoveryCodesRemaining;
/// Create a copy of MfaStatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaStatusResponseCopyWith<MfaStatusResponse> get copyWith => _$MfaStatusResponseCopyWithImpl<MfaStatusResponse>(this as MfaStatusResponse, _$identity);

  /// Serializes this MfaStatusResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaStatusResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaStatusResponse&&(identical(other.mfaEnabled, _this.mfaEnabled) || other.mfaEnabled == _this.mfaEnabled)&&(identical(other.mfaEnrolled, _this.mfaEnrolled) || other.mfaEnrolled == _this.mfaEnrolled)&&(identical(other.enrollmentRequired, _this.enrollmentRequired) || other.enrollmentRequired == _this.enrollmentRequired)&&const DeepCollectionEquality().equals(other.methods, _this.methods)&&(identical(other.recoveryCodesRemaining, _this.recoveryCodesRemaining) || other.recoveryCodesRemaining == _this.recoveryCodesRemaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaStatusResponse;
  return Object.hash(runtimeType,_this.mfaEnabled,_this.mfaEnrolled,_this.enrollmentRequired,const DeepCollectionEquality().hash(_this.methods),_this.recoveryCodesRemaining);
}

@override
String toString() {
  final _this = this as MfaStatusResponse;
  return 'MfaStatusResponse(mfaEnabled: ${_this.mfaEnabled}, mfaEnrolled: ${_this.mfaEnrolled}, enrollmentRequired: ${_this.enrollmentRequired}, methods: ${_this.methods}, recoveryCodesRemaining: ${_this.recoveryCodesRemaining})';
}


}

/// @nodoc
abstract mixin class $MfaStatusResponseCopyWith<$Res>  {
  factory $MfaStatusResponseCopyWith(MfaStatusResponse value, $Res Function(MfaStatusResponse) _then) = _$MfaStatusResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'mfaEnabled') bool mfaEnabled,@JsonKey(name: 'mfaEnrolled') bool mfaEnrolled,@JsonKey(name: 'enrollmentRequired') bool enrollmentRequired, List<MfaMethod> methods,@JsonKey(name: 'recoveryCodesRemaining') int recoveryCodesRemaining
});




}
/// @nodoc
class _$MfaStatusResponseCopyWithImpl<$Res>
    implements $MfaStatusResponseCopyWith<$Res> {
  _$MfaStatusResponseCopyWithImpl(this._self, this._then);

  final MfaStatusResponse _self;
  final $Res Function(MfaStatusResponse) _then;

/// Create a copy of MfaStatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mfaEnabled = null,Object? mfaEnrolled = null,Object? enrollmentRequired = null,Object? methods = null,Object? recoveryCodesRemaining = null,}) {
  return _then(MfaStatusResponse(
mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolled: null == mfaEnrolled ? _self.mfaEnrolled : mfaEnrolled // ignore: cast_nullable_to_non_nullable
as bool,enrollmentRequired: null == enrollmentRequired ? _self.enrollmentRequired : enrollmentRequired // ignore: cast_nullable_to_non_nullable
as bool,methods: null == methods ? _self.methods : methods // ignore: cast_nullable_to_non_nullable
as List<MfaMethod>,recoveryCodesRemaining: null == recoveryCodesRemaining ? _self.recoveryCodesRemaining : recoveryCodesRemaining // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaStatusResponse].
extension MfaStatusResponsePatterns on MfaStatusResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaStatusResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaStatusResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaStatusResponse value)  $default,){
final _that = this;
switch (_that) {
case _MfaStatusResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaStatusResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MfaStatusResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolled')  bool mfaEnrolled, @JsonKey(name: 'enrollmentRequired')  bool enrollmentRequired,  List<MfaMethod> methods, @JsonKey(name: 'recoveryCodesRemaining')  int recoveryCodesRemaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaStatusResponse() when $default != null:
return $default(_that.mfaEnabled,_that.mfaEnrolled,_that.enrollmentRequired,_that.methods,_that.recoveryCodesRemaining);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolled')  bool mfaEnrolled, @JsonKey(name: 'enrollmentRequired')  bool enrollmentRequired,  List<MfaMethod> methods, @JsonKey(name: 'recoveryCodesRemaining')  int recoveryCodesRemaining)  $default,) {final _that = this;
switch (_that) {
case _MfaStatusResponse():
return $default(_that.mfaEnabled,_that.mfaEnrolled,_that.enrollmentRequired,_that.methods,_that.recoveryCodesRemaining);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'mfaEnabled')  bool mfaEnabled, @JsonKey(name: 'mfaEnrolled')  bool mfaEnrolled, @JsonKey(name: 'enrollmentRequired')  bool enrollmentRequired,  List<MfaMethod> methods, @JsonKey(name: 'recoveryCodesRemaining')  int recoveryCodesRemaining)?  $default,) {final _that = this;
switch (_that) {
case _MfaStatusResponse() when $default != null:
return $default(_that.mfaEnabled,_that.mfaEnrolled,_that.enrollmentRequired,_that.methods,_that.recoveryCodesRemaining);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaStatusResponse implements MfaStatusResponse {
  const _MfaStatusResponse({@JsonKey(name: 'mfaEnabled') required this.mfaEnabled, @JsonKey(name: 'mfaEnrolled') required this.mfaEnrolled, @JsonKey(name: 'enrollmentRequired') required this.enrollmentRequired, required  List<MfaMethod> methods, @JsonKey(name: 'recoveryCodesRemaining') required this.recoveryCodesRemaining}): _methods = methods;
  factory _MfaStatusResponse.fromJson(Map<String, dynamic> json) => _$MfaStatusResponseFromJson(json);

@override@JsonKey(name: 'mfaEnabled') final  bool mfaEnabled;
@override@JsonKey(name: 'mfaEnrolled') final  bool mfaEnrolled;
@override@JsonKey(name: 'enrollmentRequired') final  bool enrollmentRequired;
 final  List<MfaMethod> _methods;
@override List<MfaMethod> get methods {
  if (_methods is EqualUnmodifiableListView) return _methods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_methods);
}

@override@JsonKey(name: 'recoveryCodesRemaining') final  int recoveryCodesRemaining;

/// Create a copy of MfaStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaStatusResponseCopyWith<_MfaStatusResponse> get copyWith => __$MfaStatusResponseCopyWithImpl<_MfaStatusResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaStatusResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaStatusResponse&&(identical(other.mfaEnabled, mfaEnabled) || other.mfaEnabled == mfaEnabled)&&(identical(other.mfaEnrolled, mfaEnrolled) || other.mfaEnrolled == mfaEnrolled)&&(identical(other.enrollmentRequired, enrollmentRequired) || other.enrollmentRequired == enrollmentRequired)&&const DeepCollectionEquality().equals(other.methods, _methods)&&(identical(other.recoveryCodesRemaining, recoveryCodesRemaining) || other.recoveryCodesRemaining == recoveryCodesRemaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mfaEnabled,mfaEnrolled,enrollmentRequired,const DeepCollectionEquality().hash(_methods),recoveryCodesRemaining);
}

@override
String toString() {
    return 'MfaStatusResponse(mfaEnabled: $mfaEnabled, mfaEnrolled: $mfaEnrolled, enrollmentRequired: $enrollmentRequired, methods: $methods, recoveryCodesRemaining: $recoveryCodesRemaining)';
}


}

/// @nodoc
abstract mixin class _$MfaStatusResponseCopyWith<$Res> implements $MfaStatusResponseCopyWith<$Res> {
  factory _$MfaStatusResponseCopyWith(_MfaStatusResponse value, $Res Function(_MfaStatusResponse) _then) = __$MfaStatusResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'mfaEnabled') bool mfaEnabled,@JsonKey(name: 'mfaEnrolled') bool mfaEnrolled,@JsonKey(name: 'enrollmentRequired') bool enrollmentRequired, List<MfaMethod> methods,@JsonKey(name: 'recoveryCodesRemaining') int recoveryCodesRemaining
});




}
/// @nodoc
class __$MfaStatusResponseCopyWithImpl<$Res>
    implements _$MfaStatusResponseCopyWith<$Res> {
  __$MfaStatusResponseCopyWithImpl(this._self, this._then);

  final _MfaStatusResponse _self;
  final $Res Function(_MfaStatusResponse) _then;

/// Create a copy of MfaStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mfaEnabled = null,Object? mfaEnrolled = null,Object? enrollmentRequired = null,Object? methods = null,Object? recoveryCodesRemaining = null,}) {
  return _then(_MfaStatusResponse(
mfaEnabled: null == mfaEnabled ? _self.mfaEnabled : mfaEnabled // ignore: cast_nullable_to_non_nullable
as bool,mfaEnrolled: null == mfaEnrolled ? _self.mfaEnrolled : mfaEnrolled // ignore: cast_nullable_to_non_nullable
as bool,enrollmentRequired: null == enrollmentRequired ? _self.enrollmentRequired : enrollmentRequired // ignore: cast_nullable_to_non_nullable
as bool,methods: null == methods ? _self._methods : methods // ignore: cast_nullable_to_non_nullable
as List<MfaMethod>,recoveryCodesRemaining: null == recoveryCodesRemaining ? _self.recoveryCodesRemaining : recoveryCodesRemaining // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MfaChallengeResponse {

@JsonKey(name: 'challengeId') String get challengeId;@JsonKey(name: 'availableMethods') List<String> get availableMethods;@JsonKey(name: 'expiresAt') DateTime get expiresAt;
/// Create a copy of MfaChallengeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaChallengeResponseCopyWith<MfaChallengeResponse> get copyWith => _$MfaChallengeResponseCopyWithImpl<MfaChallengeResponse>(this as MfaChallengeResponse, _$identity);

  /// Serializes this MfaChallengeResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaChallengeResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaChallengeResponse&&(identical(other.challengeId, _this.challengeId) || other.challengeId == _this.challengeId)&&const DeepCollectionEquality().equals(other.availableMethods, _this.availableMethods)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaChallengeResponse;
  return Object.hash(runtimeType,_this.challengeId,const DeepCollectionEquality().hash(_this.availableMethods),_this.expiresAt);
}

@override
String toString() {
  final _this = this as MfaChallengeResponse;
  return 'MfaChallengeResponse(challengeId: ${_this.challengeId}, availableMethods: ${_this.availableMethods}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $MfaChallengeResponseCopyWith<$Res>  {
  factory $MfaChallengeResponseCopyWith(MfaChallengeResponse value, $Res Function(MfaChallengeResponse) _then) = _$MfaChallengeResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'challengeId') String challengeId,@JsonKey(name: 'availableMethods') List<String> availableMethods,@JsonKey(name: 'expiresAt') DateTime expiresAt
});




}
/// @nodoc
class _$MfaChallengeResponseCopyWithImpl<$Res>
    implements $MfaChallengeResponseCopyWith<$Res> {
  _$MfaChallengeResponseCopyWithImpl(this._self, this._then);

  final MfaChallengeResponse _self;
  final $Res Function(MfaChallengeResponse) _then;

/// Create a copy of MfaChallengeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? challengeId = null,Object? availableMethods = null,Object? expiresAt = null,}) {
  return _then(MfaChallengeResponse(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,availableMethods: null == availableMethods ? _self.availableMethods : availableMethods // ignore: cast_nullable_to_non_nullable
as List<String>,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaChallengeResponse].
extension MfaChallengeResponsePatterns on MfaChallengeResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaChallengeResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaChallengeResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaChallengeResponse value)  $default,){
final _that = this;
switch (_that) {
case _MfaChallengeResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaChallengeResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MfaChallengeResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'availableMethods')  List<String> availableMethods, @JsonKey(name: 'expiresAt')  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaChallengeResponse() when $default != null:
return $default(_that.challengeId,_that.availableMethods,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'availableMethods')  List<String> availableMethods, @JsonKey(name: 'expiresAt')  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _MfaChallengeResponse():
return $default(_that.challengeId,_that.availableMethods,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'availableMethods')  List<String> availableMethods, @JsonKey(name: 'expiresAt')  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _MfaChallengeResponse() when $default != null:
return $default(_that.challengeId,_that.availableMethods,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaChallengeResponse implements MfaChallengeResponse {
  const _MfaChallengeResponse({@JsonKey(name: 'challengeId') required this.challengeId, @JsonKey(name: 'availableMethods') required  List<String> availableMethods, @JsonKey(name: 'expiresAt') required this.expiresAt}): _availableMethods = availableMethods;
  factory _MfaChallengeResponse.fromJson(Map<String, dynamic> json) => _$MfaChallengeResponseFromJson(json);

@override@JsonKey(name: 'challengeId') final  String challengeId;
 final  List<String> _availableMethods;
@override@JsonKey(name: 'availableMethods') List<String> get availableMethods {
  if (_availableMethods is EqualUnmodifiableListView) return _availableMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableMethods);
}

@override@JsonKey(name: 'expiresAt') final  DateTime expiresAt;

/// Create a copy of MfaChallengeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaChallengeResponseCopyWith<_MfaChallengeResponse> get copyWith => __$MfaChallengeResponseCopyWithImpl<_MfaChallengeResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaChallengeResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaChallengeResponse&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&const DeepCollectionEquality().equals(other.availableMethods, _availableMethods)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,challengeId,const DeepCollectionEquality().hash(_availableMethods),expiresAt);
}

@override
String toString() {
    return 'MfaChallengeResponse(challengeId: $challengeId, availableMethods: $availableMethods, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$MfaChallengeResponseCopyWith<$Res> implements $MfaChallengeResponseCopyWith<$Res> {
  factory _$MfaChallengeResponseCopyWith(_MfaChallengeResponse value, $Res Function(_MfaChallengeResponse) _then) = __$MfaChallengeResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'challengeId') String challengeId,@JsonKey(name: 'availableMethods') List<String> availableMethods,@JsonKey(name: 'expiresAt') DateTime expiresAt
});




}
/// @nodoc
class __$MfaChallengeResponseCopyWithImpl<$Res>
    implements _$MfaChallengeResponseCopyWith<$Res> {
  __$MfaChallengeResponseCopyWithImpl(this._self, this._then);

  final _MfaChallengeResponse _self;
  final $Res Function(_MfaChallengeResponse) _then;

/// Create a copy of MfaChallengeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? availableMethods = null,Object? expiresAt = null,}) {
  return _then(_MfaChallengeResponse(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,availableMethods: null == availableMethods ? _self._availableMethods : availableMethods // ignore: cast_nullable_to_non_nullable
as List<String>,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$MfaVerifyResponse {

 bool get success; String get message;@JsonKey(name: 'authenticationStatus') String? get authenticationStatus;@JsonKey(name: 'sessionToken') String? get sessionToken; AuthUser? get user;
/// Create a copy of MfaVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaVerifyResponseCopyWith<MfaVerifyResponse> get copyWith => _$MfaVerifyResponseCopyWithImpl<MfaVerifyResponse>(this as MfaVerifyResponse, _$identity);

  /// Serializes this MfaVerifyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaVerifyResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaVerifyResponse&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.authenticationStatus, _this.authenticationStatus) || other.authenticationStatus == _this.authenticationStatus)&&(identical(other.sessionToken, _this.sessionToken) || other.sessionToken == _this.sessionToken)&&(identical(other.user, _this.user) || other.user == _this.user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaVerifyResponse;
  return Object.hash(runtimeType,_this.success,_this.message,_this.authenticationStatus,_this.sessionToken,_this.user);
}

@override
String toString() {
  final _this = this as MfaVerifyResponse;
  return 'MfaVerifyResponse(success: ${_this.success}, message: ${_this.message}, authenticationStatus: ${_this.authenticationStatus}, sessionToken: ${_this.sessionToken}, user: ${_this.user})';
}


}

/// @nodoc
abstract mixin class $MfaVerifyResponseCopyWith<$Res>  {
  factory $MfaVerifyResponseCopyWith(MfaVerifyResponse value, $Res Function(MfaVerifyResponse) _then) = _$MfaVerifyResponseCopyWithImpl;
@useResult
$Res call({
 bool success, String message,@JsonKey(name: 'authenticationStatus') String? authenticationStatus,@JsonKey(name: 'sessionToken') String? sessionToken, AuthUser? user
});


$AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class _$MfaVerifyResponseCopyWithImpl<$Res>
    implements $MfaVerifyResponseCopyWith<$Res> {
  _$MfaVerifyResponseCopyWithImpl(this._self, this._then);

  final MfaVerifyResponse _self;
  final $Res Function(MfaVerifyResponse) _then;

/// Create a copy of MfaVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? message = null,Object? authenticationStatus = freezed,Object? sessionToken = freezed,Object? user = freezed,}) {
  return _then(MfaVerifyResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,authenticationStatus: freezed == authenticationStatus ? _self.authenticationStatus : authenticationStatus // ignore: cast_nullable_to_non_nullable
as String?,sessionToken: freezed == sessionToken ? _self.sessionToken : sessionToken // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,
  ));
}
/// Create a copy of MfaVerifyResponse
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


/// Adds pattern-matching-related methods to [MfaVerifyResponse].
extension MfaVerifyResponsePatterns on MfaVerifyResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaVerifyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaVerifyResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaVerifyResponse value)  $default,){
final _that = this;
switch (_that) {
case _MfaVerifyResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaVerifyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MfaVerifyResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String message, @JsonKey(name: 'authenticationStatus')  String? authenticationStatus, @JsonKey(name: 'sessionToken')  String? sessionToken,  AuthUser? user)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaVerifyResponse() when $default != null:
return $default(_that.success,_that.message,_that.authenticationStatus,_that.sessionToken,_that.user);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String message, @JsonKey(name: 'authenticationStatus')  String? authenticationStatus, @JsonKey(name: 'sessionToken')  String? sessionToken,  AuthUser? user)  $default,) {final _that = this;
switch (_that) {
case _MfaVerifyResponse():
return $default(_that.success,_that.message,_that.authenticationStatus,_that.sessionToken,_that.user);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String message, @JsonKey(name: 'authenticationStatus')  String? authenticationStatus, @JsonKey(name: 'sessionToken')  String? sessionToken,  AuthUser? user)?  $default,) {final _that = this;
switch (_that) {
case _MfaVerifyResponse() when $default != null:
return $default(_that.success,_that.message,_that.authenticationStatus,_that.sessionToken,_that.user);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaVerifyResponse implements MfaVerifyResponse {
  const _MfaVerifyResponse({required this.success, required this.message, @JsonKey(name: 'authenticationStatus') this.authenticationStatus, @JsonKey(name: 'sessionToken') this.sessionToken, this.user});
  factory _MfaVerifyResponse.fromJson(Map<String, dynamic> json) => _$MfaVerifyResponseFromJson(json);

@override final  bool success;
@override final  String message;
@override@JsonKey(name: 'authenticationStatus') final  String? authenticationStatus;
@override@JsonKey(name: 'sessionToken') final  String? sessionToken;
@override final  AuthUser? user;

/// Create a copy of MfaVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaVerifyResponseCopyWith<_MfaVerifyResponse> get copyWith => __$MfaVerifyResponseCopyWithImpl<_MfaVerifyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaVerifyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaVerifyResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message)&&(identical(other.authenticationStatus, authenticationStatus) || other.authenticationStatus == authenticationStatus)&&(identical(other.sessionToken, sessionToken) || other.sessionToken == sessionToken)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,success,message,authenticationStatus,sessionToken,user);
}

@override
String toString() {
    return 'MfaVerifyResponse(success: $success, message: $message, authenticationStatus: $authenticationStatus, sessionToken: $sessionToken, user: $user)';
}


}

/// @nodoc
abstract mixin class _$MfaVerifyResponseCopyWith<$Res> implements $MfaVerifyResponseCopyWith<$Res> {
  factory _$MfaVerifyResponseCopyWith(_MfaVerifyResponse value, $Res Function(_MfaVerifyResponse) _then) = __$MfaVerifyResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, String message,@JsonKey(name: 'authenticationStatus') String? authenticationStatus,@JsonKey(name: 'sessionToken') String? sessionToken, AuthUser? user
});


@override $AuthUserCopyWith<$Res>? get user;

}
/// @nodoc
class __$MfaVerifyResponseCopyWithImpl<$Res>
    implements _$MfaVerifyResponseCopyWith<$Res> {
  __$MfaVerifyResponseCopyWithImpl(this._self, this._then);

  final _MfaVerifyResponse _self;
  final $Res Function(_MfaVerifyResponse) _then;

/// Create a copy of MfaVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? message = null,Object? authenticationStatus = freezed,Object? sessionToken = freezed,Object? user = freezed,}) {
  return _then(_MfaVerifyResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,authenticationStatus: freezed == authenticationStatus ? _self.authenticationStatus : authenticationStatus // ignore: cast_nullable_to_non_nullable
as String?,sessionToken: freezed == sessionToken ? _self.sessionToken : sessionToken // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser?,
  ));
}

/// Create a copy of MfaVerifyResponse
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
mixin _$Session {

 String get id;@JsonKey(name: 'deviceId') String? get deviceId;@JsonKey(name: 'userAgent') String? get userAgent;@JsonKey(name: 'ipAddress') String? get ipAddress;@JsonKey(name: 'countryCode') String? get countryCode;@JsonKey(name: 'city') String? get city;@JsonKey(name: 'isCurrent') bool get isCurrent;@JsonKey(name: 'idleExpiresAt') DateTime get idleExpiresAt;@JsonKey(name: 'absoluteExpiresAt') DateTime get absoluteExpiresAt;@JsonKey(name: 'revokedAt') DateTime? get revokedAt;@JsonKey(name: 'revokedReason') String? get revokedReason;@JsonKey(name: 'createdAt') DateTime get createdAt;@JsonKey(name: 'updatedAt') DateTime get updatedAt;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Session;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.userAgent, _this.userAgent) || other.userAgent == _this.userAgent)&&(identical(other.ipAddress, _this.ipAddress) || other.ipAddress == _this.ipAddress)&&(identical(other.countryCode, _this.countryCode) || other.countryCode == _this.countryCode)&&(identical(other.city, _this.city) || other.city == _this.city)&&(identical(other.isCurrent, _this.isCurrent) || other.isCurrent == _this.isCurrent)&&(identical(other.idleExpiresAt, _this.idleExpiresAt) || other.idleExpiresAt == _this.idleExpiresAt)&&(identical(other.absoluteExpiresAt, _this.absoluteExpiresAt) || other.absoluteExpiresAt == _this.absoluteExpiresAt)&&(identical(other.revokedAt, _this.revokedAt) || other.revokedAt == _this.revokedAt)&&(identical(other.revokedReason, _this.revokedReason) || other.revokedReason == _this.revokedReason)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Session;
  return Object.hash(runtimeType,_this.id,_this.deviceId,_this.userAgent,_this.ipAddress,_this.countryCode,_this.city,_this.isCurrent,_this.idleExpiresAt,_this.absoluteExpiresAt,_this.revokedAt,_this.revokedReason,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Session;
  return 'Session(id: ${_this.id}, deviceId: ${_this.deviceId}, userAgent: ${_this.userAgent}, ipAddress: ${_this.ipAddress}, countryCode: ${_this.countryCode}, city: ${_this.city}, isCurrent: ${_this.isCurrent}, idleExpiresAt: ${_this.idleExpiresAt}, absoluteExpiresAt: ${_this.absoluteExpiresAt}, revokedAt: ${_this.revokedAt}, revokedReason: ${_this.revokedReason}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'deviceId') String? deviceId,@JsonKey(name: 'userAgent') String? userAgent,@JsonKey(name: 'ipAddress') String? ipAddress,@JsonKey(name: 'countryCode') String? countryCode,@JsonKey(name: 'city') String? city,@JsonKey(name: 'isCurrent') bool isCurrent,@JsonKey(name: 'idleExpiresAt') DateTime idleExpiresAt,@JsonKey(name: 'absoluteExpiresAt') DateTime absoluteExpiresAt,@JsonKey(name: 'revokedAt') DateTime? revokedAt,@JsonKey(name: 'revokedReason') String? revokedReason,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = freezed,Object? userAgent = freezed,Object? ipAddress = freezed,Object? countryCode = freezed,Object? city = freezed,Object? isCurrent = null,Object? idleExpiresAt = null,Object? absoluteExpiresAt = null,Object? revokedAt = freezed,Object? revokedReason = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,idleExpiresAt: null == idleExpiresAt ? _self.idleExpiresAt : idleExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,absoluteExpiresAt: null == absoluteExpiresAt ? _self.absoluteExpiresAt : absoluteExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedReason: freezed == revokedReason ? _self.revokedReason : revokedReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'deviceId')  String? deviceId, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'countryCode')  String? countryCode, @JsonKey(name: 'city')  String? city, @JsonKey(name: 'isCurrent')  bool isCurrent, @JsonKey(name: 'idleExpiresAt')  DateTime idleExpiresAt, @JsonKey(name: 'absoluteExpiresAt')  DateTime absoluteExpiresAt, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.deviceId,_that.userAgent,_that.ipAddress,_that.countryCode,_that.city,_that.isCurrent,_that.idleExpiresAt,_that.absoluteExpiresAt,_that.revokedAt,_that.revokedReason,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'deviceId')  String? deviceId, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'countryCode')  String? countryCode, @JsonKey(name: 'city')  String? city, @JsonKey(name: 'isCurrent')  bool isCurrent, @JsonKey(name: 'idleExpiresAt')  DateTime idleExpiresAt, @JsonKey(name: 'absoluteExpiresAt')  DateTime absoluteExpiresAt, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.deviceId,_that.userAgent,_that.ipAddress,_that.countryCode,_that.city,_that.isCurrent,_that.idleExpiresAt,_that.absoluteExpiresAt,_that.revokedAt,_that.revokedReason,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'deviceId')  String? deviceId, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'countryCode')  String? countryCode, @JsonKey(name: 'city')  String? city, @JsonKey(name: 'isCurrent')  bool isCurrent, @JsonKey(name: 'idleExpiresAt')  DateTime idleExpiresAt, @JsonKey(name: 'absoluteExpiresAt')  DateTime absoluteExpiresAt, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.deviceId,_that.userAgent,_that.ipAddress,_that.countryCode,_that.city,_that.isCurrent,_that.idleExpiresAt,_that.absoluteExpiresAt,_that.revokedAt,_that.revokedReason,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session implements Session {
  const _Session({required this.id, @JsonKey(name: 'deviceId') this.deviceId, @JsonKey(name: 'userAgent') this.userAgent, @JsonKey(name: 'ipAddress') this.ipAddress, @JsonKey(name: 'countryCode') this.countryCode, @JsonKey(name: 'city') this.city, @JsonKey(name: 'isCurrent') required this.isCurrent, @JsonKey(name: 'idleExpiresAt') required this.idleExpiresAt, @JsonKey(name: 'absoluteExpiresAt') required this.absoluteExpiresAt, @JsonKey(name: 'revokedAt') this.revokedAt, @JsonKey(name: 'revokedReason') this.revokedReason, @JsonKey(name: 'createdAt') required this.createdAt, @JsonKey(name: 'updatedAt') required this.updatedAt});
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String id;
@override@JsonKey(name: 'deviceId') final  String? deviceId;
@override@JsonKey(name: 'userAgent') final  String? userAgent;
@override@JsonKey(name: 'ipAddress') final  String? ipAddress;
@override@JsonKey(name: 'countryCode') final  String? countryCode;
@override@JsonKey(name: 'city') final  String? city;
@override@JsonKey(name: 'isCurrent') final  bool isCurrent;
@override@JsonKey(name: 'idleExpiresAt') final  DateTime idleExpiresAt;
@override@JsonKey(name: 'absoluteExpiresAt') final  DateTime absoluteExpiresAt;
@override@JsonKey(name: 'revokedAt') final  DateTime? revokedAt;
@override@JsonKey(name: 'revokedReason') final  String? revokedReason;
@override@JsonKey(name: 'createdAt') final  DateTime createdAt;
@override@JsonKey(name: 'updatedAt') final  DateTime updatedAt;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.city, city) || other.city == city)&&(identical(other.isCurrent, isCurrent) || other.isCurrent == isCurrent)&&(identical(other.idleExpiresAt, idleExpiresAt) || other.idleExpiresAt == idleExpiresAt)&&(identical(other.absoluteExpiresAt, absoluteExpiresAt) || other.absoluteExpiresAt == absoluteExpiresAt)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedReason, revokedReason) || other.revokedReason == revokedReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,deviceId,userAgent,ipAddress,countryCode,city,isCurrent,idleExpiresAt,absoluteExpiresAt,revokedAt,revokedReason,createdAt,updatedAt);
}

@override
String toString() {
    return 'Session(id: $id, deviceId: $deviceId, userAgent: $userAgent, ipAddress: $ipAddress, countryCode: $countryCode, city: $city, isCurrent: $isCurrent, idleExpiresAt: $idleExpiresAt, absoluteExpiresAt: $absoluteExpiresAt, revokedAt: $revokedAt, revokedReason: $revokedReason, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'deviceId') String? deviceId,@JsonKey(name: 'userAgent') String? userAgent,@JsonKey(name: 'ipAddress') String? ipAddress,@JsonKey(name: 'countryCode') String? countryCode,@JsonKey(name: 'city') String? city,@JsonKey(name: 'isCurrent') bool isCurrent,@JsonKey(name: 'idleExpiresAt') DateTime idleExpiresAt,@JsonKey(name: 'absoluteExpiresAt') DateTime absoluteExpiresAt,@JsonKey(name: 'revokedAt') DateTime? revokedAt,@JsonKey(name: 'revokedReason') String? revokedReason,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = freezed,Object? userAgent = freezed,Object? ipAddress = freezed,Object? countryCode = freezed,Object? city = freezed,Object? isCurrent = null,Object? idleExpiresAt = null,Object? absoluteExpiresAt = null,Object? revokedAt = freezed,Object? revokedReason = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,idleExpiresAt: null == idleExpiresAt ? _self.idleExpiresAt : idleExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,absoluteExpiresAt: null == absoluteExpiresAt ? _self.absoluteExpiresAt : absoluteExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedReason: freezed == revokedReason ? _self.revokedReason : revokedReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Device {

 String get id;@JsonKey(name: 'deviceIdentifier') String get deviceIdentifier; String get platform;@JsonKey(name: 'deviceName') String? get deviceName;@JsonKey(name: 'deviceModel') String? get deviceModel;@JsonKey(name: 'osVersion') String? get osVersion;@JsonKey(name: 'appVersion') String? get appVersion;@JsonKey(name: 'pushProvider') String? get pushProvider;@JsonKey(name: 'lastIp') String? get lastIp;@JsonKey(name: 'lastCountryCode') String? get lastCountryCode;@JsonKey(name: 'lastCity') String? get lastCity; String get status;@JsonKey(name: 'revokedAt') DateTime? get revokedAt;@JsonKey(name: 'revokedReason') String? get revokedReason;@JsonKey(name: 'lastActivityAt') DateTime? get lastActivityAt;@JsonKey(name: 'createdAt') DateTime get createdAt;@JsonKey(name: 'updatedAt') DateTime get updatedAt;
/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCopyWith<Device> get copyWith => _$DeviceCopyWithImpl<Device>(this as Device, _$identity);

  /// Serializes this Device to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Device;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Device&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deviceIdentifier, _this.deviceIdentifier) || other.deviceIdentifier == _this.deviceIdentifier)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.deviceName, _this.deviceName) || other.deviceName == _this.deviceName)&&(identical(other.deviceModel, _this.deviceModel) || other.deviceModel == _this.deviceModel)&&(identical(other.osVersion, _this.osVersion) || other.osVersion == _this.osVersion)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.pushProvider, _this.pushProvider) || other.pushProvider == _this.pushProvider)&&(identical(other.lastIp, _this.lastIp) || other.lastIp == _this.lastIp)&&(identical(other.lastCountryCode, _this.lastCountryCode) || other.lastCountryCode == _this.lastCountryCode)&&(identical(other.lastCity, _this.lastCity) || other.lastCity == _this.lastCity)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.revokedAt, _this.revokedAt) || other.revokedAt == _this.revokedAt)&&(identical(other.revokedReason, _this.revokedReason) || other.revokedReason == _this.revokedReason)&&(identical(other.lastActivityAt, _this.lastActivityAt) || other.lastActivityAt == _this.lastActivityAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Device;
  return Object.hash(runtimeType,_this.id,_this.deviceIdentifier,_this.platform,_this.deviceName,_this.deviceModel,_this.osVersion,_this.appVersion,_this.pushProvider,_this.lastIp,_this.lastCountryCode,_this.lastCity,_this.status,_this.revokedAt,_this.revokedReason,_this.lastActivityAt,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Device;
  return 'Device(id: ${_this.id}, deviceIdentifier: ${_this.deviceIdentifier}, platform: ${_this.platform}, deviceName: ${_this.deviceName}, deviceModel: ${_this.deviceModel}, osVersion: ${_this.osVersion}, appVersion: ${_this.appVersion}, pushProvider: ${_this.pushProvider}, lastIp: ${_this.lastIp}, lastCountryCode: ${_this.lastCountryCode}, lastCity: ${_this.lastCity}, status: ${_this.status}, revokedAt: ${_this.revokedAt}, revokedReason: ${_this.revokedReason}, lastActivityAt: ${_this.lastActivityAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $DeviceCopyWith<$Res>  {
  factory $DeviceCopyWith(Device value, $Res Function(Device) _then) = _$DeviceCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'deviceIdentifier') String deviceIdentifier, String platform,@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'deviceModel') String? deviceModel,@JsonKey(name: 'osVersion') String? osVersion,@JsonKey(name: 'appVersion') String? appVersion,@JsonKey(name: 'pushProvider') String? pushProvider,@JsonKey(name: 'lastIp') String? lastIp,@JsonKey(name: 'lastCountryCode') String? lastCountryCode,@JsonKey(name: 'lastCity') String? lastCity, String status,@JsonKey(name: 'revokedAt') DateTime? revokedAt,@JsonKey(name: 'revokedReason') String? revokedReason,@JsonKey(name: 'lastActivityAt') DateTime? lastActivityAt,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class _$DeviceCopyWithImpl<$Res>
    implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._self, this._then);

  final Device _self;
  final $Res Function(Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceIdentifier = null,Object? platform = null,Object? deviceName = freezed,Object? deviceModel = freezed,Object? osVersion = freezed,Object? appVersion = freezed,Object? pushProvider = freezed,Object? lastIp = freezed,Object? lastCountryCode = freezed,Object? lastCity = freezed,Object? status = null,Object? revokedAt = freezed,Object? revokedReason = freezed,Object? lastActivityAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Device(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceIdentifier: null == deviceIdentifier ? _self.deviceIdentifier : deviceIdentifier // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,deviceModel: freezed == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String?,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,pushProvider: freezed == pushProvider ? _self.pushProvider : pushProvider // ignore: cast_nullable_to_non_nullable
as String?,lastIp: freezed == lastIp ? _self.lastIp : lastIp // ignore: cast_nullable_to_non_nullable
as String?,lastCountryCode: freezed == lastCountryCode ? _self.lastCountryCode : lastCountryCode // ignore: cast_nullable_to_non_nullable
as String?,lastCity: freezed == lastCity ? _self.lastCity : lastCity // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedReason: freezed == revokedReason ? _self.revokedReason : revokedReason // ignore: cast_nullable_to_non_nullable
as String?,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Device].
extension DevicePatterns on Device {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Device value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Device value)  $default,){
final _that = this;
switch (_that) {
case _Device():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Device value)?  $default,){
final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'lastIp')  String? lastIp, @JsonKey(name: 'lastCountryCode')  String? lastCountryCode, @JsonKey(name: 'lastCity')  String? lastCity,  String status, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'lastActivityAt')  DateTime? lastActivityAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.id,_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.lastIp,_that.lastCountryCode,_that.lastCity,_that.status,_that.revokedAt,_that.revokedReason,_that.lastActivityAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'lastIp')  String? lastIp, @JsonKey(name: 'lastCountryCode')  String? lastCountryCode, @JsonKey(name: 'lastCity')  String? lastCity,  String status, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'lastActivityAt')  DateTime? lastActivityAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Device():
return $default(_that.id,_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.lastIp,_that.lastCountryCode,_that.lastCity,_that.status,_that.revokedAt,_that.revokedReason,_that.lastActivityAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'lastIp')  String? lastIp, @JsonKey(name: 'lastCountryCode')  String? lastCountryCode, @JsonKey(name: 'lastCity')  String? lastCity,  String status, @JsonKey(name: 'revokedAt')  DateTime? revokedAt, @JsonKey(name: 'revokedReason')  String? revokedReason, @JsonKey(name: 'lastActivityAt')  DateTime? lastActivityAt, @JsonKey(name: 'createdAt')  DateTime createdAt, @JsonKey(name: 'updatedAt')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.id,_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.lastIp,_that.lastCountryCode,_that.lastCity,_that.status,_that.revokedAt,_that.revokedReason,_that.lastActivityAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Device implements Device {
  const _Device({required this.id, @JsonKey(name: 'deviceIdentifier') required this.deviceIdentifier, required this.platform, @JsonKey(name: 'deviceName') this.deviceName, @JsonKey(name: 'deviceModel') this.deviceModel, @JsonKey(name: 'osVersion') this.osVersion, @JsonKey(name: 'appVersion') this.appVersion, @JsonKey(name: 'pushProvider') this.pushProvider, @JsonKey(name: 'lastIp') this.lastIp, @JsonKey(name: 'lastCountryCode') this.lastCountryCode, @JsonKey(name: 'lastCity') this.lastCity, required this.status, @JsonKey(name: 'revokedAt') this.revokedAt, @JsonKey(name: 'revokedReason') this.revokedReason, @JsonKey(name: 'lastActivityAt') this.lastActivityAt, @JsonKey(name: 'createdAt') required this.createdAt, @JsonKey(name: 'updatedAt') required this.updatedAt});
  factory _Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

@override final  String id;
@override@JsonKey(name: 'deviceIdentifier') final  String deviceIdentifier;
@override final  String platform;
@override@JsonKey(name: 'deviceName') final  String? deviceName;
@override@JsonKey(name: 'deviceModel') final  String? deviceModel;
@override@JsonKey(name: 'osVersion') final  String? osVersion;
@override@JsonKey(name: 'appVersion') final  String? appVersion;
@override@JsonKey(name: 'pushProvider') final  String? pushProvider;
@override@JsonKey(name: 'lastIp') final  String? lastIp;
@override@JsonKey(name: 'lastCountryCode') final  String? lastCountryCode;
@override@JsonKey(name: 'lastCity') final  String? lastCity;
@override final  String status;
@override@JsonKey(name: 'revokedAt') final  DateTime? revokedAt;
@override@JsonKey(name: 'revokedReason') final  String? revokedReason;
@override@JsonKey(name: 'lastActivityAt') final  DateTime? lastActivityAt;
@override@JsonKey(name: 'createdAt') final  DateTime createdAt;
@override@JsonKey(name: 'updatedAt') final  DateTime updatedAt;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCopyWith<_Device> get copyWith => __$DeviceCopyWithImpl<_Device>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Device&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceIdentifier, deviceIdentifier) || other.deviceIdentifier == deviceIdentifier)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.osVersion, osVersion) || other.osVersion == osVersion)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.pushProvider, pushProvider) || other.pushProvider == pushProvider)&&(identical(other.lastIp, lastIp) || other.lastIp == lastIp)&&(identical(other.lastCountryCode, lastCountryCode) || other.lastCountryCode == lastCountryCode)&&(identical(other.lastCity, lastCity) || other.lastCity == lastCity)&&(identical(other.status, status) || other.status == status)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedReason, revokedReason) || other.revokedReason == revokedReason)&&(identical(other.lastActivityAt, lastActivityAt) || other.lastActivityAt == lastActivityAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,deviceIdentifier,platform,deviceName,deviceModel,osVersion,appVersion,pushProvider,lastIp,lastCountryCode,lastCity,status,revokedAt,revokedReason,lastActivityAt,createdAt,updatedAt);
}

@override
String toString() {
    return 'Device(id: $id, deviceIdentifier: $deviceIdentifier, platform: $platform, deviceName: $deviceName, deviceModel: $deviceModel, osVersion: $osVersion, appVersion: $appVersion, pushProvider: $pushProvider, lastIp: $lastIp, lastCountryCode: $lastCountryCode, lastCity: $lastCity, status: $status, revokedAt: $revokedAt, revokedReason: $revokedReason, lastActivityAt: $lastActivityAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$DeviceCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$DeviceCopyWith(_Device value, $Res Function(_Device) _then) = __$DeviceCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'deviceIdentifier') String deviceIdentifier, String platform,@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'deviceModel') String? deviceModel,@JsonKey(name: 'osVersion') String? osVersion,@JsonKey(name: 'appVersion') String? appVersion,@JsonKey(name: 'pushProvider') String? pushProvider,@JsonKey(name: 'lastIp') String? lastIp,@JsonKey(name: 'lastCountryCode') String? lastCountryCode,@JsonKey(name: 'lastCity') String? lastCity, String status,@JsonKey(name: 'revokedAt') DateTime? revokedAt,@JsonKey(name: 'revokedReason') String? revokedReason,@JsonKey(name: 'lastActivityAt') DateTime? lastActivityAt,@JsonKey(name: 'createdAt') DateTime createdAt,@JsonKey(name: 'updatedAt') DateTime updatedAt
});




}
/// @nodoc
class __$DeviceCopyWithImpl<$Res>
    implements _$DeviceCopyWith<$Res> {
  __$DeviceCopyWithImpl(this._self, this._then);

  final _Device _self;
  final $Res Function(_Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceIdentifier = null,Object? platform = null,Object? deviceName = freezed,Object? deviceModel = freezed,Object? osVersion = freezed,Object? appVersion = freezed,Object? pushProvider = freezed,Object? lastIp = freezed,Object? lastCountryCode = freezed,Object? lastCity = freezed,Object? status = null,Object? revokedAt = freezed,Object? revokedReason = freezed,Object? lastActivityAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Device(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceIdentifier: null == deviceIdentifier ? _self.deviceIdentifier : deviceIdentifier // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,deviceModel: freezed == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String?,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,pushProvider: freezed == pushProvider ? _self.pushProvider : pushProvider // ignore: cast_nullable_to_non_nullable
as String?,lastIp: freezed == lastIp ? _self.lastIp : lastIp // ignore: cast_nullable_to_non_nullable
as String?,lastCountryCode: freezed == lastCountryCode ? _self.lastCountryCode : lastCountryCode // ignore: cast_nullable_to_non_nullable
as String?,lastCity: freezed == lastCity ? _self.lastCity : lastCity // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedReason: freezed == revokedReason ? _self.revokedReason : revokedReason // ignore: cast_nullable_to_non_nullable
as String?,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$RegisterRequest {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'RegisterRequest()';
}


}

/// @nodoc
class $RegisterRequestCopyWith<$Res>  {
$RegisterRequestCopyWith(RegisterRequest _, $Res Function(RegisterRequest) __);
}


/// Adds pattern-matching-related methods to [RegisterRequest].
extension RegisterRequestPatterns on RegisterRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RegisterEmailRequest value)?  email,TResult Function( RegisterPhoneRequest value)?  phone,TResult Function( RegisterPhoneOtpRequest value)?  phoneOtp,TResult Function( RegisterGoogleRequest value)?  google,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RegisterEmailRequest() when email != null:
return email(_that);case RegisterPhoneRequest() when phone != null:
return phone(_that);case RegisterPhoneOtpRequest() when phoneOtp != null:
return phoneOtp(_that);case RegisterGoogleRequest() when google != null:
return google(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RegisterEmailRequest value)  email,required TResult Function( RegisterPhoneRequest value)  phone,required TResult Function( RegisterPhoneOtpRequest value)  phoneOtp,required TResult Function( RegisterGoogleRequest value)  google,}){
final _that = this;
switch (_that) {
case RegisterEmailRequest():
return email(_that);case RegisterPhoneRequest():
return phone(_that);case RegisterPhoneOtpRequest():
return phoneOtp(_that);case RegisterGoogleRequest():
return google(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RegisterEmailRequest value)?  email,TResult? Function( RegisterPhoneRequest value)?  phone,TResult? Function( RegisterPhoneOtpRequest value)?  phoneOtp,TResult? Function( RegisterGoogleRequest value)?  google,}){
final _that = this;
switch (_that) {
case RegisterEmailRequest() when email != null:
return email(_that);case RegisterPhoneRequest() when phone != null:
return phone(_that);case RegisterPhoneOtpRequest() when phoneOtp != null:
return phoneOtp(_that);case RegisterGoogleRequest() when google != null:
return google(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String email,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  email,TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  phone,TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  phoneOtp,TResult Function(@JsonKey(name: 'idToken')  String idToken)?  google,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RegisterEmailRequest() when email != null:
return email(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneRequest() when phone != null:
return phone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneOtpRequest() when phoneOtp != null:
return phoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case RegisterGoogleRequest() when google != null:
return google(_that.idToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String email,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)  email,required TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)  phone,required TResult Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)  phoneOtp,required TResult Function(@JsonKey(name: 'idToken')  String idToken)  google,}) {final _that = this;
switch (_that) {
case RegisterEmailRequest():
return email(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneRequest():
return phone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneOtpRequest():
return phoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case RegisterGoogleRequest():
return google(_that.idToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String email,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  email,TResult? Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String password,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  phone,TResult? Function(@JsonKey(name: 'firstName')  String firstName, @JsonKey(name: 'lastName')  String lastName,  String phone,  String role, @JsonKey(name: 'termsAccepted')  bool termsAccepted)?  phoneOtp,TResult? Function(@JsonKey(name: 'idToken')  String idToken)?  google,}) {final _that = this;
switch (_that) {
case RegisterEmailRequest() when email != null:
return email(_that.firstName,_that.lastName,_that.email,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneRequest() when phone != null:
return phone(_that.firstName,_that.lastName,_that.phone,_that.password,_that.role,_that.termsAccepted);case RegisterPhoneOtpRequest() when phoneOtp != null:
return phoneOtp(_that.firstName,_that.lastName,_that.phone,_that.role,_that.termsAccepted);case RegisterGoogleRequest() when google != null:
return google(_that.idToken);case _:
  return null;

}
}

}

/// @nodoc


class RegisterEmailRequest implements RegisterRequest {
  const RegisterEmailRequest({@JsonKey(name: 'firstName') required this.firstName, @JsonKey(name: 'lastName') required this.lastName, required this.email, required this.password, required this.role, @JsonKey(name: 'termsAccepted') required this.termsAccepted});
  

@JsonKey(name: 'firstName') final  String firstName;
@JsonKey(name: 'lastName') final  String lastName;
 final  String email;
 final  String password;
 final  String role;
@JsonKey(name: 'termsAccepted') final  bool termsAccepted;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterEmailRequestCopyWith<RegisterEmailRequest> get copyWith => _$RegisterEmailRequestCopyWithImpl<RegisterEmailRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterEmailRequest&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,email,password,role,termsAccepted);
}

@override
String toString() {
    return 'RegisterRequest.email(firstName: $firstName, lastName: $lastName, email: $email, password: $password, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class $RegisterEmailRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory $RegisterEmailRequestCopyWith(RegisterEmailRequest value, $Res Function(RegisterEmailRequest) _then) = _$RegisterEmailRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'firstName') String firstName,@JsonKey(name: 'lastName') String lastName, String email, String password, String role,@JsonKey(name: 'termsAccepted') bool termsAccepted
});




}
/// @nodoc
class _$RegisterEmailRequestCopyWithImpl<$Res>
    implements $RegisterEmailRequestCopyWith<$Res> {
  _$RegisterEmailRequestCopyWithImpl(this._self, this._then);

  final RegisterEmailRequest _self;
  final $Res Function(RegisterEmailRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? email = null,Object? password = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(RegisterEmailRequest(
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


class RegisterPhoneRequest implements RegisterRequest {
  const RegisterPhoneRequest({@JsonKey(name: 'firstName') required this.firstName, @JsonKey(name: 'lastName') required this.lastName, required this.phone, required this.password, required this.role, @JsonKey(name: 'termsAccepted') required this.termsAccepted});
  

@JsonKey(name: 'firstName') final  String firstName;
@JsonKey(name: 'lastName') final  String lastName;
 final  String phone;
 final  String password;
 final  String role;
@JsonKey(name: 'termsAccepted') final  bool termsAccepted;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterPhoneRequestCopyWith<RegisterPhoneRequest> get copyWith => _$RegisterPhoneRequestCopyWithImpl<RegisterPhoneRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterPhoneRequest&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,phone,password,role,termsAccepted);
}

@override
String toString() {
    return 'RegisterRequest.phone(firstName: $firstName, lastName: $lastName, phone: $phone, password: $password, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class $RegisterPhoneRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory $RegisterPhoneRequestCopyWith(RegisterPhoneRequest value, $Res Function(RegisterPhoneRequest) _then) = _$RegisterPhoneRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'firstName') String firstName,@JsonKey(name: 'lastName') String lastName, String phone, String password, String role,@JsonKey(name: 'termsAccepted') bool termsAccepted
});




}
/// @nodoc
class _$RegisterPhoneRequestCopyWithImpl<$Res>
    implements $RegisterPhoneRequestCopyWith<$Res> {
  _$RegisterPhoneRequestCopyWithImpl(this._self, this._then);

  final RegisterPhoneRequest _self;
  final $Res Function(RegisterPhoneRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? phone = null,Object? password = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(RegisterPhoneRequest(
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


class RegisterPhoneOtpRequest implements RegisterRequest {
  const RegisterPhoneOtpRequest({@JsonKey(name: 'firstName') required this.firstName, @JsonKey(name: 'lastName') required this.lastName, required this.phone, required this.role, @JsonKey(name: 'termsAccepted') required this.termsAccepted});
  

@JsonKey(name: 'firstName') final  String firstName;
@JsonKey(name: 'lastName') final  String lastName;
 final  String phone;
 final  String role;
@JsonKey(name: 'termsAccepted') final  bool termsAccepted;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterPhoneOtpRequestCopyWith<RegisterPhoneOtpRequest> get copyWith => _$RegisterPhoneOtpRequestCopyWithImpl<RegisterPhoneOtpRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterPhoneOtpRequest&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.role, role) || other.role == role)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted));
}


@override
int get hashCode {
    return Object.hash(runtimeType,firstName,lastName,phone,role,termsAccepted);
}

@override
String toString() {
    return 'RegisterRequest.phoneOtp(firstName: $firstName, lastName: $lastName, phone: $phone, role: $role, termsAccepted: $termsAccepted)';
}


}

/// @nodoc
abstract mixin class $RegisterPhoneOtpRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory $RegisterPhoneOtpRequestCopyWith(RegisterPhoneOtpRequest value, $Res Function(RegisterPhoneOtpRequest) _then) = _$RegisterPhoneOtpRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'firstName') String firstName,@JsonKey(name: 'lastName') String lastName, String phone, String role,@JsonKey(name: 'termsAccepted') bool termsAccepted
});




}
/// @nodoc
class _$RegisterPhoneOtpRequestCopyWithImpl<$Res>
    implements $RegisterPhoneOtpRequestCopyWith<$Res> {
  _$RegisterPhoneOtpRequestCopyWithImpl(this._self, this._then);

  final RegisterPhoneOtpRequest _self;
  final $Res Function(RegisterPhoneOtpRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? phone = null,Object? role = null,Object? termsAccepted = null,}) {
  return _then(RegisterPhoneOtpRequest(
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


class RegisterGoogleRequest implements RegisterRequest {
  const RegisterGoogleRequest({@JsonKey(name: 'idToken') required this.idToken});
  

@JsonKey(name: 'idToken') final  String idToken;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterGoogleRequestCopyWith<RegisterGoogleRequest> get copyWith => _$RegisterGoogleRequestCopyWithImpl<RegisterGoogleRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterGoogleRequest&&(identical(other.idToken, idToken) || other.idToken == idToken));
}


@override
int get hashCode {
    return Object.hash(runtimeType,idToken);
}

@override
String toString() {
    return 'RegisterRequest.google(idToken: $idToken)';
}


}

/// @nodoc
abstract mixin class $RegisterGoogleRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory $RegisterGoogleRequestCopyWith(RegisterGoogleRequest value, $Res Function(RegisterGoogleRequest) _then) = _$RegisterGoogleRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'idToken') String idToken
});




}
/// @nodoc
class _$RegisterGoogleRequestCopyWithImpl<$Res>
    implements $RegisterGoogleRequestCopyWith<$Res> {
  _$RegisterGoogleRequestCopyWithImpl(this._self, this._then);

  final RegisterGoogleRequest _self;
  final $Res Function(RegisterGoogleRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? idToken = null,}) {
  return _then(RegisterGoogleRequest(
idToken: null == idToken ? _self.idToken : idToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$LoginRequest {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LoginRequest()';
}


}

/// @nodoc
class $LoginRequestCopyWith<$Res>  {
$LoginRequestCopyWith(LoginRequest _, $Res Function(LoginRequest) __);
}


/// Adds pattern-matching-related methods to [LoginRequest].
extension LoginRequestPatterns on LoginRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoginEmailRequest value)?  email,TResult Function( LoginPhoneRequest value)?  phone,TResult Function( LoginGoogleRequest value)?  google,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoginEmailRequest() when email != null:
return email(_that);case LoginPhoneRequest() when phone != null:
return phone(_that);case LoginGoogleRequest() when google != null:
return google(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoginEmailRequest value)  email,required TResult Function( LoginPhoneRequest value)  phone,required TResult Function( LoginGoogleRequest value)  google,}){
final _that = this;
switch (_that) {
case LoginEmailRequest():
return email(_that);case LoginPhoneRequest():
return phone(_that);case LoginGoogleRequest():
return google(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoginEmailRequest value)?  email,TResult? Function( LoginPhoneRequest value)?  phone,TResult? Function( LoginGoogleRequest value)?  google,}){
final _that = this;
switch (_that) {
case LoginEmailRequest() when email != null:
return email(_that);case LoginPhoneRequest() when phone != null:
return phone(_that);case LoginGoogleRequest() when google != null:
return google(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email,  String password)?  email,TResult Function( String phone,  String password)?  phone,TResult Function(@JsonKey(name: 'idToken')  String idToken)?  google,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoginEmailRequest() when email != null:
return email(_that.email,_that.password);case LoginPhoneRequest() when phone != null:
return phone(_that.phone,_that.password);case LoginGoogleRequest() when google != null:
return google(_that.idToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email,  String password)  email,required TResult Function( String phone,  String password)  phone,required TResult Function(@JsonKey(name: 'idToken')  String idToken)  google,}) {final _that = this;
switch (_that) {
case LoginEmailRequest():
return email(_that.email,_that.password);case LoginPhoneRequest():
return phone(_that.phone,_that.password);case LoginGoogleRequest():
return google(_that.idToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email,  String password)?  email,TResult? Function( String phone,  String password)?  phone,TResult? Function(@JsonKey(name: 'idToken')  String idToken)?  google,}) {final _that = this;
switch (_that) {
case LoginEmailRequest() when email != null:
return email(_that.email,_that.password);case LoginPhoneRequest() when phone != null:
return phone(_that.phone,_that.password);case LoginGoogleRequest() when google != null:
return google(_that.idToken);case _:
  return null;

}
}

}

/// @nodoc


class LoginEmailRequest implements LoginRequest {
  const LoginEmailRequest({required this.email, required this.password});
  

 final  String email;
 final  String password;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginEmailRequestCopyWith<LoginEmailRequest> get copyWith => _$LoginEmailRequestCopyWithImpl<LoginEmailRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginEmailRequest&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,password);
}

@override
String toString() {
    return 'LoginRequest.email(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginEmailRequestCopyWith<$Res> implements $LoginRequestCopyWith<$Res> {
  factory $LoginEmailRequestCopyWith(LoginEmailRequest value, $Res Function(LoginEmailRequest) _then) = _$LoginEmailRequestCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class _$LoginEmailRequestCopyWithImpl<$Res>
    implements $LoginEmailRequestCopyWith<$Res> {
  _$LoginEmailRequestCopyWithImpl(this._self, this._then);

  final LoginEmailRequest _self;
  final $Res Function(LoginEmailRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(LoginEmailRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginPhoneRequest implements LoginRequest {
  const LoginPhoneRequest({required this.phone, required this.password});
  

 final  String phone;
 final  String password;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginPhoneRequestCopyWith<LoginPhoneRequest> get copyWith => _$LoginPhoneRequestCopyWithImpl<LoginPhoneRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginPhoneRequest&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,password);
}

@override
String toString() {
    return 'LoginRequest.phone(phone: $phone, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginPhoneRequestCopyWith<$Res> implements $LoginRequestCopyWith<$Res> {
  factory $LoginPhoneRequestCopyWith(LoginPhoneRequest value, $Res Function(LoginPhoneRequest) _then) = _$LoginPhoneRequestCopyWithImpl;
@useResult
$Res call({
 String phone, String password
});




}
/// @nodoc
class _$LoginPhoneRequestCopyWithImpl<$Res>
    implements $LoginPhoneRequestCopyWith<$Res> {
  _$LoginPhoneRequestCopyWithImpl(this._self, this._then);

  final LoginPhoneRequest _self;
  final $Res Function(LoginPhoneRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? password = null,}) {
  return _then(LoginPhoneRequest(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LoginGoogleRequest implements LoginRequest {
  const LoginGoogleRequest({@JsonKey(name: 'idToken') required this.idToken});
  

@JsonKey(name: 'idToken') final  String idToken;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginGoogleRequestCopyWith<LoginGoogleRequest> get copyWith => _$LoginGoogleRequestCopyWithImpl<LoginGoogleRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginGoogleRequest&&(identical(other.idToken, idToken) || other.idToken == idToken));
}


@override
int get hashCode {
    return Object.hash(runtimeType,idToken);
}

@override
String toString() {
    return 'LoginRequest.google(idToken: $idToken)';
}


}

/// @nodoc
abstract mixin class $LoginGoogleRequestCopyWith<$Res> implements $LoginRequestCopyWith<$Res> {
  factory $LoginGoogleRequestCopyWith(LoginGoogleRequest value, $Res Function(LoginGoogleRequest) _then) = _$LoginGoogleRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'idToken') String idToken
});




}
/// @nodoc
class _$LoginGoogleRequestCopyWithImpl<$Res>
    implements $LoginGoogleRequestCopyWith<$Res> {
  _$LoginGoogleRequestCopyWithImpl(this._self, this._then);

  final LoginGoogleRequest _self;
  final $Res Function(LoginGoogleRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? idToken = null,}) {
  return _then(LoginGoogleRequest(
idToken: null == idToken ? _self.idToken : idToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$OtpRequest {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OtpRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'OtpRequest()';
}


}

/// @nodoc
class $OtpRequestCopyWith<$Res>  {
$OtpRequestCopyWith(OtpRequest _, $Res Function(OtpRequest) __);
}


/// Adds pattern-matching-related methods to [OtpRequest].
extension OtpRequestPatterns on OtpRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EmailOtpRequest value)?  email,TResult Function( PhoneOtpRequest value)?  phone,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EmailOtpRequest() when email != null:
return email(_that);case PhoneOtpRequest() when phone != null:
return phone(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EmailOtpRequest value)  email,required TResult Function( PhoneOtpRequest value)  phone,}){
final _that = this;
switch (_that) {
case EmailOtpRequest():
return email(_that);case PhoneOtpRequest():
return phone(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EmailOtpRequest value)?  email,TResult? Function( PhoneOtpRequest value)?  phone,}){
final _that = this;
switch (_that) {
case EmailOtpRequest() when email != null:
return email(_that);case PhoneOtpRequest() when phone != null:
return phone(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  email,TResult Function( String phone)?  phone,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EmailOtpRequest() when email != null:
return email(_that.email);case PhoneOtpRequest() when phone != null:
return phone(_that.phone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  email,required TResult Function( String phone)  phone,}) {final _that = this;
switch (_that) {
case EmailOtpRequest():
return email(_that.email);case PhoneOtpRequest():
return phone(_that.phone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  email,TResult? Function( String phone)?  phone,}) {final _that = this;
switch (_that) {
case EmailOtpRequest() when email != null:
return email(_that.email);case PhoneOtpRequest() when phone != null:
return phone(_that.phone);case _:
  return null;

}
}

}

/// @nodoc


class EmailOtpRequest implements OtpRequest {
  const EmailOtpRequest({required this.email});
  

 final  String email;

/// Create a copy of OtpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailOtpRequestCopyWith<EmailOtpRequest> get copyWith => _$EmailOtpRequestCopyWithImpl<EmailOtpRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailOtpRequest&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString() {
    return 'OtpRequest.email(email: $email)';
}


}

/// @nodoc
abstract mixin class $EmailOtpRequestCopyWith<$Res> implements $OtpRequestCopyWith<$Res> {
  factory $EmailOtpRequestCopyWith(EmailOtpRequest value, $Res Function(EmailOtpRequest) _then) = _$EmailOtpRequestCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$EmailOtpRequestCopyWithImpl<$Res>
    implements $EmailOtpRequestCopyWith<$Res> {
  _$EmailOtpRequestCopyWithImpl(this._self, this._then);

  final EmailOtpRequest _self;
  final $Res Function(EmailOtpRequest) _then;

/// Create a copy of OtpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(EmailOtpRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PhoneOtpRequest implements OtpRequest {
  const PhoneOtpRequest({required this.phone});
  

 final  String phone;

/// Create a copy of OtpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneOtpRequestCopyWith<PhoneOtpRequest> get copyWith => _$PhoneOtpRequestCopyWithImpl<PhoneOtpRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneOtpRequest&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString() {
    return 'OtpRequest.phone(phone: $phone)';
}


}

/// @nodoc
abstract mixin class $PhoneOtpRequestCopyWith<$Res> implements $OtpRequestCopyWith<$Res> {
  factory $PhoneOtpRequestCopyWith(PhoneOtpRequest value, $Res Function(PhoneOtpRequest) _then) = _$PhoneOtpRequestCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class _$PhoneOtpRequestCopyWithImpl<$Res>
    implements $PhoneOtpRequestCopyWith<$Res> {
  _$PhoneOtpRequestCopyWithImpl(this._self, this._then);

  final PhoneOtpRequest _self;
  final $Res Function(PhoneOtpRequest) _then;

/// Create a copy of OtpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(PhoneOtpRequest(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$OtpVerifyRequest {

 String get otp;
/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OtpVerifyRequestCopyWith<OtpVerifyRequest> get copyWith => _$OtpVerifyRequestCopyWithImpl<OtpVerifyRequest>(this as OtpVerifyRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OtpVerifyRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OtpVerifyRequest&&(identical(other.otp, _this.otp) || other.otp == _this.otp));
}


@override
int get hashCode {
  final _this = this as OtpVerifyRequest;
  return Object.hash(runtimeType,_this.otp);
}

@override
String toString() {
  final _this = this as OtpVerifyRequest;
  return 'OtpVerifyRequest(otp: ${_this.otp})';
}


}

/// @nodoc
abstract mixin class $OtpVerifyRequestCopyWith<$Res>  {
  factory $OtpVerifyRequestCopyWith(OtpVerifyRequest value, $Res Function(OtpVerifyRequest) _then) = _$OtpVerifyRequestCopyWithImpl;
@useResult
$Res call({
 String otp
});




}
/// @nodoc
class _$OtpVerifyRequestCopyWithImpl<$Res>
    implements $OtpVerifyRequestCopyWith<$Res> {
  _$OtpVerifyRequestCopyWithImpl(this._self, this._then);

  final OtpVerifyRequest _self;
  final $Res Function(OtpVerifyRequest) _then;

/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? otp = null,}) {
  return _then(_self.copyWith(
otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OtpVerifyRequest].
extension OtpVerifyRequestPatterns on OtpVerifyRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EmailOtpVerifyRequest value)?  email,TResult Function( PhoneOtpVerifyRequest value)?  phone,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EmailOtpVerifyRequest() when email != null:
return email(_that);case PhoneOtpVerifyRequest() when phone != null:
return phone(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EmailOtpVerifyRequest value)  email,required TResult Function( PhoneOtpVerifyRequest value)  phone,}){
final _that = this;
switch (_that) {
case EmailOtpVerifyRequest():
return email(_that);case PhoneOtpVerifyRequest():
return phone(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EmailOtpVerifyRequest value)?  email,TResult? Function( PhoneOtpVerifyRequest value)?  phone,}){
final _that = this;
switch (_that) {
case EmailOtpVerifyRequest() when email != null:
return email(_that);case PhoneOtpVerifyRequest() when phone != null:
return phone(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email,  String otp)?  email,TResult Function( String phone,  String otp)?  phone,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EmailOtpVerifyRequest() when email != null:
return email(_that.email,_that.otp);case PhoneOtpVerifyRequest() when phone != null:
return phone(_that.phone,_that.otp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email,  String otp)  email,required TResult Function( String phone,  String otp)  phone,}) {final _that = this;
switch (_that) {
case EmailOtpVerifyRequest():
return email(_that.email,_that.otp);case PhoneOtpVerifyRequest():
return phone(_that.phone,_that.otp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email,  String otp)?  email,TResult? Function( String phone,  String otp)?  phone,}) {final _that = this;
switch (_that) {
case EmailOtpVerifyRequest() when email != null:
return email(_that.email,_that.otp);case PhoneOtpVerifyRequest() when phone != null:
return phone(_that.phone,_that.otp);case _:
  return null;

}
}

}

/// @nodoc


class EmailOtpVerifyRequest implements OtpVerifyRequest {
  const EmailOtpVerifyRequest({required this.email, required this.otp});
  

 final  String email;
@override final  String otp;

/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailOtpVerifyRequestCopyWith<EmailOtpVerifyRequest> get copyWith => _$EmailOtpVerifyRequestCopyWithImpl<EmailOtpVerifyRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailOtpVerifyRequest&&(identical(other.email, email) || other.email == email)&&(identical(other.otp, otp) || other.otp == otp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,otp);
}

@override
String toString() {
    return 'OtpVerifyRequest.email(email: $email, otp: $otp)';
}


}

/// @nodoc
abstract mixin class $EmailOtpVerifyRequestCopyWith<$Res> implements $OtpVerifyRequestCopyWith<$Res> {
  factory $EmailOtpVerifyRequestCopyWith(EmailOtpVerifyRequest value, $Res Function(EmailOtpVerifyRequest) _then) = _$EmailOtpVerifyRequestCopyWithImpl;
@override @useResult
$Res call({
 String email, String otp
});




}
/// @nodoc
class _$EmailOtpVerifyRequestCopyWithImpl<$Res>
    implements $EmailOtpVerifyRequestCopyWith<$Res> {
  _$EmailOtpVerifyRequestCopyWithImpl(this._self, this._then);

  final EmailOtpVerifyRequest _self;
  final $Res Function(EmailOtpVerifyRequest) _then;

/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? otp = null,}) {
  return _then(EmailOtpVerifyRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PhoneOtpVerifyRequest implements OtpVerifyRequest {
  const PhoneOtpVerifyRequest({required this.phone, required this.otp});
  

 final  String phone;
@override final  String otp;

/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneOtpVerifyRequestCopyWith<PhoneOtpVerifyRequest> get copyWith => _$PhoneOtpVerifyRequestCopyWithImpl<PhoneOtpVerifyRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneOtpVerifyRequest&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.otp, otp) || other.otp == otp));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,otp);
}

@override
String toString() {
    return 'OtpVerifyRequest.phone(phone: $phone, otp: $otp)';
}


}

/// @nodoc
abstract mixin class $PhoneOtpVerifyRequestCopyWith<$Res> implements $OtpVerifyRequestCopyWith<$Res> {
  factory $PhoneOtpVerifyRequestCopyWith(PhoneOtpVerifyRequest value, $Res Function(PhoneOtpVerifyRequest) _then) = _$PhoneOtpVerifyRequestCopyWithImpl;
@override @useResult
$Res call({
 String phone, String otp
});




}
/// @nodoc
class _$PhoneOtpVerifyRequestCopyWithImpl<$Res>
    implements $PhoneOtpVerifyRequestCopyWith<$Res> {
  _$PhoneOtpVerifyRequestCopyWithImpl(this._self, this._then);

  final PhoneOtpVerifyRequest _self;
  final $Res Function(PhoneOtpVerifyRequest) _then;

/// Create a copy of OtpVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? otp = null,}) {
  return _then(PhoneOtpVerifyRequest(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,otp: null == otp ? _self.otp : otp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MfaEnrollmentStartRequest {

@JsonKey(name: 'methodType') String get methodType;@JsonKey(name: 'methodName') String? get methodName;@JsonKey(name: 'phoneNumber') String? get phoneNumber;@JsonKey(name: 'makePrimary') bool? get makePrimary;
/// Create a copy of MfaEnrollmentStartRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaEnrollmentStartRequestCopyWith<MfaEnrollmentStartRequest> get copyWith => _$MfaEnrollmentStartRequestCopyWithImpl<MfaEnrollmentStartRequest>(this as MfaEnrollmentStartRequest, _$identity);

  /// Serializes this MfaEnrollmentStartRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaEnrollmentStartRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaEnrollmentStartRequest&&(identical(other.methodType, _this.methodType) || other.methodType == _this.methodType)&&(identical(other.methodName, _this.methodName) || other.methodName == _this.methodName)&&(identical(other.phoneNumber, _this.phoneNumber) || other.phoneNumber == _this.phoneNumber)&&(identical(other.makePrimary, _this.makePrimary) || other.makePrimary == _this.makePrimary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaEnrollmentStartRequest;
  return Object.hash(runtimeType,_this.methodType,_this.methodName,_this.phoneNumber,_this.makePrimary);
}

@override
String toString() {
  final _this = this as MfaEnrollmentStartRequest;
  return 'MfaEnrollmentStartRequest(methodType: ${_this.methodType}, methodName: ${_this.methodName}, phoneNumber: ${_this.phoneNumber}, makePrimary: ${_this.makePrimary})';
}


}

/// @nodoc
abstract mixin class $MfaEnrollmentStartRequestCopyWith<$Res>  {
  factory $MfaEnrollmentStartRequestCopyWith(MfaEnrollmentStartRequest value, $Res Function(MfaEnrollmentStartRequest) _then) = _$MfaEnrollmentStartRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'methodType') String methodType,@JsonKey(name: 'methodName') String? methodName,@JsonKey(name: 'phoneNumber') String? phoneNumber,@JsonKey(name: 'makePrimary') bool? makePrimary
});




}
/// @nodoc
class _$MfaEnrollmentStartRequestCopyWithImpl<$Res>
    implements $MfaEnrollmentStartRequestCopyWith<$Res> {
  _$MfaEnrollmentStartRequestCopyWithImpl(this._self, this._then);

  final MfaEnrollmentStartRequest _self;
  final $Res Function(MfaEnrollmentStartRequest) _then;

/// Create a copy of MfaEnrollmentStartRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? methodType = null,Object? methodName = freezed,Object? phoneNumber = freezed,Object? makePrimary = freezed,}) {
  return _then(MfaEnrollmentStartRequest(
methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,makePrimary: freezed == makePrimary ? _self.makePrimary : makePrimary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaEnrollmentStartRequest].
extension MfaEnrollmentStartRequestPatterns on MfaEnrollmentStartRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaEnrollmentStartRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaEnrollmentStartRequest value)  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaEnrollmentStartRequest value)?  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'phoneNumber')  String? phoneNumber, @JsonKey(name: 'makePrimary')  bool? makePrimary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest() when $default != null:
return $default(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'phoneNumber')  String? phoneNumber, @JsonKey(name: 'makePrimary')  bool? makePrimary)  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest():
return $default(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'methodType')  String methodType, @JsonKey(name: 'methodName')  String? methodName, @JsonKey(name: 'phoneNumber')  String? phoneNumber, @JsonKey(name: 'makePrimary')  bool? makePrimary)?  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentStartRequest() when $default != null:
return $default(_that.methodType,_that.methodName,_that.phoneNumber,_that.makePrimary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaEnrollmentStartRequest implements MfaEnrollmentStartRequest {
  const _MfaEnrollmentStartRequest({@JsonKey(name: 'methodType') required this.methodType, @JsonKey(name: 'methodName') this.methodName, @JsonKey(name: 'phoneNumber') this.phoneNumber, @JsonKey(name: 'makePrimary') this.makePrimary});
  factory _MfaEnrollmentStartRequest.fromJson(Map<String, dynamic> json) => _$MfaEnrollmentStartRequestFromJson(json);

@override@JsonKey(name: 'methodType') final  String methodType;
@override@JsonKey(name: 'methodName') final  String? methodName;
@override@JsonKey(name: 'phoneNumber') final  String? phoneNumber;
@override@JsonKey(name: 'makePrimary') final  bool? makePrimary;

/// Create a copy of MfaEnrollmentStartRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaEnrollmentStartRequestCopyWith<_MfaEnrollmentStartRequest> get copyWith => __$MfaEnrollmentStartRequestCopyWithImpl<_MfaEnrollmentStartRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaEnrollmentStartRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaEnrollmentStartRequest&&(identical(other.methodType, methodType) || other.methodType == methodType)&&(identical(other.methodName, methodName) || other.methodName == methodName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.makePrimary, makePrimary) || other.makePrimary == makePrimary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,methodType,methodName,phoneNumber,makePrimary);
}

@override
String toString() {
    return 'MfaEnrollmentStartRequest(methodType: $methodType, methodName: $methodName, phoneNumber: $phoneNumber, makePrimary: $makePrimary)';
}


}

/// @nodoc
abstract mixin class _$MfaEnrollmentStartRequestCopyWith<$Res> implements $MfaEnrollmentStartRequestCopyWith<$Res> {
  factory _$MfaEnrollmentStartRequestCopyWith(_MfaEnrollmentStartRequest value, $Res Function(_MfaEnrollmentStartRequest) _then) = __$MfaEnrollmentStartRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'methodType') String methodType,@JsonKey(name: 'methodName') String? methodName,@JsonKey(name: 'phoneNumber') String? phoneNumber,@JsonKey(name: 'makePrimary') bool? makePrimary
});




}
/// @nodoc
class __$MfaEnrollmentStartRequestCopyWithImpl<$Res>
    implements _$MfaEnrollmentStartRequestCopyWith<$Res> {
  __$MfaEnrollmentStartRequestCopyWithImpl(this._self, this._then);

  final _MfaEnrollmentStartRequest _self;
  final $Res Function(_MfaEnrollmentStartRequest) _then;

/// Create a copy of MfaEnrollmentStartRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? methodType = null,Object? methodName = freezed,Object? phoneNumber = freezed,Object? makePrimary = freezed,}) {
  return _then(_MfaEnrollmentStartRequest(
methodType: null == methodType ? _self.methodType : methodType // ignore: cast_nullable_to_non_nullable
as String,methodName: freezed == methodName ? _self.methodName : methodName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,makePrimary: freezed == makePrimary ? _self.makePrimary : makePrimary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$MfaEnrollmentVerifyRequest {

@JsonKey(name: 'mfaMethodId') String get mfaMethodId; String get code;
/// Create a copy of MfaEnrollmentVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaEnrollmentVerifyRequestCopyWith<MfaEnrollmentVerifyRequest> get copyWith => _$MfaEnrollmentVerifyRequestCopyWithImpl<MfaEnrollmentVerifyRequest>(this as MfaEnrollmentVerifyRequest, _$identity);

  /// Serializes this MfaEnrollmentVerifyRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaEnrollmentVerifyRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaEnrollmentVerifyRequest&&(identical(other.mfaMethodId, _this.mfaMethodId) || other.mfaMethodId == _this.mfaMethodId)&&(identical(other.code, _this.code) || other.code == _this.code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaEnrollmentVerifyRequest;
  return Object.hash(runtimeType,_this.mfaMethodId,_this.code);
}

@override
String toString() {
  final _this = this as MfaEnrollmentVerifyRequest;
  return 'MfaEnrollmentVerifyRequest(mfaMethodId: ${_this.mfaMethodId}, code: ${_this.code})';
}


}

/// @nodoc
abstract mixin class $MfaEnrollmentVerifyRequestCopyWith<$Res>  {
  factory $MfaEnrollmentVerifyRequestCopyWith(MfaEnrollmentVerifyRequest value, $Res Function(MfaEnrollmentVerifyRequest) _then) = _$MfaEnrollmentVerifyRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'mfaMethodId') String mfaMethodId, String code
});




}
/// @nodoc
class _$MfaEnrollmentVerifyRequestCopyWithImpl<$Res>
    implements $MfaEnrollmentVerifyRequestCopyWith<$Res> {
  _$MfaEnrollmentVerifyRequestCopyWithImpl(this._self, this._then);

  final MfaEnrollmentVerifyRequest _self;
  final $Res Function(MfaEnrollmentVerifyRequest) _then;

/// Create a copy of MfaEnrollmentVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mfaMethodId = null,Object? code = null,}) {
  return _then(MfaEnrollmentVerifyRequest(
mfaMethodId: null == mfaMethodId ? _self.mfaMethodId : mfaMethodId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaEnrollmentVerifyRequest].
extension MfaEnrollmentVerifyRequestPatterns on MfaEnrollmentVerifyRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaEnrollmentVerifyRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaEnrollmentVerifyRequest value)  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaEnrollmentVerifyRequest value)?  $default,){
final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'mfaMethodId')  String mfaMethodId,  String code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest() when $default != null:
return $default(_that.mfaMethodId,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'mfaMethodId')  String mfaMethodId,  String code)  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest():
return $default(_that.mfaMethodId,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'mfaMethodId')  String mfaMethodId,  String code)?  $default,) {final _that = this;
switch (_that) {
case _MfaEnrollmentVerifyRequest() when $default != null:
return $default(_that.mfaMethodId,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaEnrollmentVerifyRequest implements MfaEnrollmentVerifyRequest {
  const _MfaEnrollmentVerifyRequest({@JsonKey(name: 'mfaMethodId') required this.mfaMethodId, required this.code});
  factory _MfaEnrollmentVerifyRequest.fromJson(Map<String, dynamic> json) => _$MfaEnrollmentVerifyRequestFromJson(json);

@override@JsonKey(name: 'mfaMethodId') final  String mfaMethodId;
@override final  String code;

/// Create a copy of MfaEnrollmentVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaEnrollmentVerifyRequestCopyWith<_MfaEnrollmentVerifyRequest> get copyWith => __$MfaEnrollmentVerifyRequestCopyWithImpl<_MfaEnrollmentVerifyRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaEnrollmentVerifyRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaEnrollmentVerifyRequest&&(identical(other.mfaMethodId, mfaMethodId) || other.mfaMethodId == mfaMethodId)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mfaMethodId,code);
}

@override
String toString() {
    return 'MfaEnrollmentVerifyRequest(mfaMethodId: $mfaMethodId, code: $code)';
}


}

/// @nodoc
abstract mixin class _$MfaEnrollmentVerifyRequestCopyWith<$Res> implements $MfaEnrollmentVerifyRequestCopyWith<$Res> {
  factory _$MfaEnrollmentVerifyRequestCopyWith(_MfaEnrollmentVerifyRequest value, $Res Function(_MfaEnrollmentVerifyRequest) _then) = __$MfaEnrollmentVerifyRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'mfaMethodId') String mfaMethodId, String code
});




}
/// @nodoc
class __$MfaEnrollmentVerifyRequestCopyWithImpl<$Res>
    implements _$MfaEnrollmentVerifyRequestCopyWith<$Res> {
  __$MfaEnrollmentVerifyRequestCopyWithImpl(this._self, this._then);

  final _MfaEnrollmentVerifyRequest _self;
  final $Res Function(_MfaEnrollmentVerifyRequest) _then;

/// Create a copy of MfaEnrollmentVerifyRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mfaMethodId = null,Object? code = null,}) {
  return _then(_MfaEnrollmentVerifyRequest(
mfaMethodId: null == mfaMethodId ? _self.mfaMethodId : mfaMethodId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MfaChallengeRequest {

@JsonKey(name: 'challengeId') String get challengeId;@JsonKey(name: 'totpCode') String get totpCode;
/// Create a copy of MfaChallengeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MfaChallengeRequestCopyWith<MfaChallengeRequest> get copyWith => _$MfaChallengeRequestCopyWithImpl<MfaChallengeRequest>(this as MfaChallengeRequest, _$identity);

  /// Serializes this MfaChallengeRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MfaChallengeRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MfaChallengeRequest&&(identical(other.challengeId, _this.challengeId) || other.challengeId == _this.challengeId)&&(identical(other.totpCode, _this.totpCode) || other.totpCode == _this.totpCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MfaChallengeRequest;
  return Object.hash(runtimeType,_this.challengeId,_this.totpCode);
}

@override
String toString() {
  final _this = this as MfaChallengeRequest;
  return 'MfaChallengeRequest(challengeId: ${_this.challengeId}, totpCode: ${_this.totpCode})';
}


}

/// @nodoc
abstract mixin class $MfaChallengeRequestCopyWith<$Res>  {
  factory $MfaChallengeRequestCopyWith(MfaChallengeRequest value, $Res Function(MfaChallengeRequest) _then) = _$MfaChallengeRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'challengeId') String challengeId,@JsonKey(name: 'totpCode') String totpCode
});




}
/// @nodoc
class _$MfaChallengeRequestCopyWithImpl<$Res>
    implements $MfaChallengeRequestCopyWith<$Res> {
  _$MfaChallengeRequestCopyWithImpl(this._self, this._then);

  final MfaChallengeRequest _self;
  final $Res Function(MfaChallengeRequest) _then;

/// Create a copy of MfaChallengeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? challengeId = null,Object? totpCode = null,}) {
  return _then(MfaChallengeRequest(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,totpCode: null == totpCode ? _self.totpCode : totpCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MfaChallengeRequest].
extension MfaChallengeRequestPatterns on MfaChallengeRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MfaChallengeRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MfaChallengeRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MfaChallengeRequest value)  $default,){
final _that = this;
switch (_that) {
case _MfaChallengeRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MfaChallengeRequest value)?  $default,){
final _that = this;
switch (_that) {
case _MfaChallengeRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'totpCode')  String totpCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MfaChallengeRequest() when $default != null:
return $default(_that.challengeId,_that.totpCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'totpCode')  String totpCode)  $default,) {final _that = this;
switch (_that) {
case _MfaChallengeRequest():
return $default(_that.challengeId,_that.totpCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'challengeId')  String challengeId, @JsonKey(name: 'totpCode')  String totpCode)?  $default,) {final _that = this;
switch (_that) {
case _MfaChallengeRequest() when $default != null:
return $default(_that.challengeId,_that.totpCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MfaChallengeRequest implements MfaChallengeRequest {
  const _MfaChallengeRequest({@JsonKey(name: 'challengeId') required this.challengeId, @JsonKey(name: 'totpCode') required this.totpCode});
  factory _MfaChallengeRequest.fromJson(Map<String, dynamic> json) => _$MfaChallengeRequestFromJson(json);

@override@JsonKey(name: 'challengeId') final  String challengeId;
@override@JsonKey(name: 'totpCode') final  String totpCode;

/// Create a copy of MfaChallengeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MfaChallengeRequestCopyWith<_MfaChallengeRequest> get copyWith => __$MfaChallengeRequestCopyWithImpl<_MfaChallengeRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MfaChallengeRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MfaChallengeRequest&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&(identical(other.totpCode, totpCode) || other.totpCode == totpCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,challengeId,totpCode);
}

@override
String toString() {
    return 'MfaChallengeRequest(challengeId: $challengeId, totpCode: $totpCode)';
}


}

/// @nodoc
abstract mixin class _$MfaChallengeRequestCopyWith<$Res> implements $MfaChallengeRequestCopyWith<$Res> {
  factory _$MfaChallengeRequestCopyWith(_MfaChallengeRequest value, $Res Function(_MfaChallengeRequest) _then) = __$MfaChallengeRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'challengeId') String challengeId,@JsonKey(name: 'totpCode') String totpCode
});




}
/// @nodoc
class __$MfaChallengeRequestCopyWithImpl<$Res>
    implements _$MfaChallengeRequestCopyWith<$Res> {
  __$MfaChallengeRequestCopyWithImpl(this._self, this._then);

  final _MfaChallengeRequest _self;
  final $Res Function(_MfaChallengeRequest) _then;

/// Create a copy of MfaChallengeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? totpCode = null,}) {
  return _then(_MfaChallengeRequest(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,totpCode: null == totpCode ? _self.totpCode : totpCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RefreshTokenRequest {

@JsonKey(name: 'refreshToken') String get refreshToken;
/// Create a copy of RefreshTokenRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefreshTokenRequestCopyWith<RefreshTokenRequest> get copyWith => _$RefreshTokenRequestCopyWithImpl<RefreshTokenRequest>(this as RefreshTokenRequest, _$identity);

  /// Serializes this RefreshTokenRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RefreshTokenRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefreshTokenRequest&&(identical(other.refreshToken, _this.refreshToken) || other.refreshToken == _this.refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RefreshTokenRequest;
  return Object.hash(runtimeType,_this.refreshToken);
}

@override
String toString() {
  final _this = this as RefreshTokenRequest;
  return 'RefreshTokenRequest(refreshToken: ${_this.refreshToken})';
}


}

/// @nodoc
abstract mixin class $RefreshTokenRequestCopyWith<$Res>  {
  factory $RefreshTokenRequestCopyWith(RefreshTokenRequest value, $Res Function(RefreshTokenRequest) _then) = _$RefreshTokenRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'refreshToken') String refreshToken
});




}
/// @nodoc
class _$RefreshTokenRequestCopyWithImpl<$Res>
    implements $RefreshTokenRequestCopyWith<$Res> {
  _$RefreshTokenRequestCopyWithImpl(this._self, this._then);

  final RefreshTokenRequest _self;
  final $Res Function(RefreshTokenRequest) _then;

/// Create a copy of RefreshTokenRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? refreshToken = null,}) {
  return _then(RefreshTokenRequest(
refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RefreshTokenRequest].
extension RefreshTokenRequestPatterns on RefreshTokenRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefreshTokenRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefreshTokenRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefreshTokenRequest value)  $default,){
final _that = this;
switch (_that) {
case _RefreshTokenRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefreshTokenRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RefreshTokenRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'refreshToken')  String refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefreshTokenRequest() when $default != null:
return $default(_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'refreshToken')  String refreshToken)  $default,) {final _that = this;
switch (_that) {
case _RefreshTokenRequest():
return $default(_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'refreshToken')  String refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _RefreshTokenRequest() when $default != null:
return $default(_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefreshTokenRequest implements RefreshTokenRequest {
  const _RefreshTokenRequest({@JsonKey(name: 'refreshToken') required this.refreshToken});
  factory _RefreshTokenRequest.fromJson(Map<String, dynamic> json) => _$RefreshTokenRequestFromJson(json);

@override@JsonKey(name: 'refreshToken') final  String refreshToken;

/// Create a copy of RefreshTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefreshTokenRequestCopyWith<_RefreshTokenRequest> get copyWith => __$RefreshTokenRequestCopyWithImpl<_RefreshTokenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefreshTokenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshTokenRequest&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,refreshToken);
}

@override
String toString() {
    return 'RefreshTokenRequest(refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$RefreshTokenRequestCopyWith<$Res> implements $RefreshTokenRequestCopyWith<$Res> {
  factory _$RefreshTokenRequestCopyWith(_RefreshTokenRequest value, $Res Function(_RefreshTokenRequest) _then) = __$RefreshTokenRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'refreshToken') String refreshToken
});




}
/// @nodoc
class __$RefreshTokenRequestCopyWithImpl<$Res>
    implements _$RefreshTokenRequestCopyWith<$Res> {
  __$RefreshTokenRequestCopyWithImpl(this._self, this._then);

  final _RefreshTokenRequest _self;
  final $Res Function(_RefreshTokenRequest) _then;

/// Create a copy of RefreshTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? refreshToken = null,}) {
  return _then(_RefreshTokenRequest(
refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RefreshTokenResponse {

@JsonKey(name: 'accessToken') String get accessToken;@JsonKey(name: 'refreshToken') String get refreshToken;@JsonKey(name: 'expiresIn') int get expiresIn;
/// Create a copy of RefreshTokenResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefreshTokenResponseCopyWith<RefreshTokenResponse> get copyWith => _$RefreshTokenResponseCopyWithImpl<RefreshTokenResponse>(this as RefreshTokenResponse, _$identity);

  /// Serializes this RefreshTokenResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RefreshTokenResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefreshTokenResponse&&(identical(other.accessToken, _this.accessToken) || other.accessToken == _this.accessToken)&&(identical(other.refreshToken, _this.refreshToken) || other.refreshToken == _this.refreshToken)&&(identical(other.expiresIn, _this.expiresIn) || other.expiresIn == _this.expiresIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RefreshTokenResponse;
  return Object.hash(runtimeType,_this.accessToken,_this.refreshToken,_this.expiresIn);
}

@override
String toString() {
  final _this = this as RefreshTokenResponse;
  return 'RefreshTokenResponse(accessToken: ${_this.accessToken}, refreshToken: ${_this.refreshToken}, expiresIn: ${_this.expiresIn})';
}


}

/// @nodoc
abstract mixin class $RefreshTokenResponseCopyWith<$Res>  {
  factory $RefreshTokenResponseCopyWith(RefreshTokenResponse value, $Res Function(RefreshTokenResponse) _then) = _$RefreshTokenResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'accessToken') String accessToken,@JsonKey(name: 'refreshToken') String refreshToken,@JsonKey(name: 'expiresIn') int expiresIn
});




}
/// @nodoc
class _$RefreshTokenResponseCopyWithImpl<$Res>
    implements $RefreshTokenResponseCopyWith<$Res> {
  _$RefreshTokenResponseCopyWithImpl(this._self, this._then);

  final RefreshTokenResponse _self;
  final $Res Function(RefreshTokenResponse) _then;

/// Create a copy of RefreshTokenResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? expiresIn = null,}) {
  return _then(RefreshTokenResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RefreshTokenResponse].
extension RefreshTokenResponsePatterns on RefreshTokenResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefreshTokenResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefreshTokenResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefreshTokenResponse value)  $default,){
final _that = this;
switch (_that) {
case _RefreshTokenResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefreshTokenResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RefreshTokenResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'accessToken')  String accessToken, @JsonKey(name: 'refreshToken')  String refreshToken, @JsonKey(name: 'expiresIn')  int expiresIn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefreshTokenResponse() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'accessToken')  String accessToken, @JsonKey(name: 'refreshToken')  String refreshToken, @JsonKey(name: 'expiresIn')  int expiresIn)  $default,) {final _that = this;
switch (_that) {
case _RefreshTokenResponse():
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'accessToken')  String accessToken, @JsonKey(name: 'refreshToken')  String refreshToken, @JsonKey(name: 'expiresIn')  int expiresIn)?  $default,) {final _that = this;
switch (_that) {
case _RefreshTokenResponse() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefreshTokenResponse implements RefreshTokenResponse {
  const _RefreshTokenResponse({@JsonKey(name: 'accessToken') required this.accessToken, @JsonKey(name: 'refreshToken') required this.refreshToken, @JsonKey(name: 'expiresIn') required this.expiresIn});
  factory _RefreshTokenResponse.fromJson(Map<String, dynamic> json) => _$RefreshTokenResponseFromJson(json);

@override@JsonKey(name: 'accessToken') final  String accessToken;
@override@JsonKey(name: 'refreshToken') final  String refreshToken;
@override@JsonKey(name: 'expiresIn') final  int expiresIn;

/// Create a copy of RefreshTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefreshTokenResponseCopyWith<_RefreshTokenResponse> get copyWith => __$RefreshTokenResponseCopyWithImpl<_RefreshTokenResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefreshTokenResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshTokenResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,accessToken,refreshToken,expiresIn);
}

@override
String toString() {
    return 'RefreshTokenResponse(accessToken: $accessToken, refreshToken: $refreshToken, expiresIn: $expiresIn)';
}


}

/// @nodoc
abstract mixin class _$RefreshTokenResponseCopyWith<$Res> implements $RefreshTokenResponseCopyWith<$Res> {
  factory _$RefreshTokenResponseCopyWith(_RefreshTokenResponse value, $Res Function(_RefreshTokenResponse) _then) = __$RefreshTokenResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'accessToken') String accessToken,@JsonKey(name: 'refreshToken') String refreshToken,@JsonKey(name: 'expiresIn') int expiresIn
});




}
/// @nodoc
class __$RefreshTokenResponseCopyWithImpl<$Res>
    implements _$RefreshTokenResponseCopyWith<$Res> {
  __$RefreshTokenResponseCopyWithImpl(this._self, this._then);

  final _RefreshTokenResponse _self;
  final $Res Function(_RefreshTokenResponse) _then;

/// Create a copy of RefreshTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? expiresIn = null,}) {
  return _then(_RefreshTokenResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ForgotPasswordRequest {

 String get email;
/// Create a copy of ForgotPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForgotPasswordRequestCopyWith<ForgotPasswordRequest> get copyWith => _$ForgotPasswordRequestCopyWithImpl<ForgotPasswordRequest>(this as ForgotPasswordRequest, _$identity);

  /// Serializes this ForgotPasswordRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ForgotPasswordRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ForgotPasswordRequest&&(identical(other.email, _this.email) || other.email == _this.email));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ForgotPasswordRequest;
  return Object.hash(runtimeType,_this.email);
}

@override
String toString() {
  final _this = this as ForgotPasswordRequest;
  return 'ForgotPasswordRequest(email: ${_this.email})';
}


}

/// @nodoc
abstract mixin class $ForgotPasswordRequestCopyWith<$Res>  {
  factory $ForgotPasswordRequestCopyWith(ForgotPasswordRequest value, $Res Function(ForgotPasswordRequest) _then) = _$ForgotPasswordRequestCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$ForgotPasswordRequestCopyWithImpl<$Res>
    implements $ForgotPasswordRequestCopyWith<$Res> {
  _$ForgotPasswordRequestCopyWithImpl(this._self, this._then);

  final ForgotPasswordRequest _self;
  final $Res Function(ForgotPasswordRequest) _then;

/// Create a copy of ForgotPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,}) {
  return _then(ForgotPasswordRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ForgotPasswordRequest].
extension ForgotPasswordRequestPatterns on ForgotPasswordRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ForgotPasswordRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ForgotPasswordRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ForgotPasswordRequest value)  $default,){
final _that = this;
switch (_that) {
case _ForgotPasswordRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ForgotPasswordRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ForgotPasswordRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String email)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ForgotPasswordRequest() when $default != null:
return $default(_that.email);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String email)  $default,) {final _that = this;
switch (_that) {
case _ForgotPasswordRequest():
return $default(_that.email);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String email)?  $default,) {final _that = this;
switch (_that) {
case _ForgotPasswordRequest() when $default != null:
return $default(_that.email);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ForgotPasswordRequest implements ForgotPasswordRequest {
  const _ForgotPasswordRequest({required this.email});
  factory _ForgotPasswordRequest.fromJson(Map<String, dynamic> json) => _$ForgotPasswordRequestFromJson(json);

@override final  String email;

/// Create a copy of ForgotPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ForgotPasswordRequestCopyWith<_ForgotPasswordRequest> get copyWith => __$ForgotPasswordRequestCopyWithImpl<_ForgotPasswordRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ForgotPasswordRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ForgotPasswordRequest&&(identical(other.email, email) || other.email == email));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString() {
    return 'ForgotPasswordRequest(email: $email)';
}


}

/// @nodoc
abstract mixin class _$ForgotPasswordRequestCopyWith<$Res> implements $ForgotPasswordRequestCopyWith<$Res> {
  factory _$ForgotPasswordRequestCopyWith(_ForgotPasswordRequest value, $Res Function(_ForgotPasswordRequest) _then) = __$ForgotPasswordRequestCopyWithImpl;
@override @useResult
$Res call({
 String email
});




}
/// @nodoc
class __$ForgotPasswordRequestCopyWithImpl<$Res>
    implements _$ForgotPasswordRequestCopyWith<$Res> {
  __$ForgotPasswordRequestCopyWithImpl(this._self, this._then);

  final _ForgotPasswordRequest _self;
  final $Res Function(_ForgotPasswordRequest) _then;

/// Create a copy of ForgotPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_ForgotPasswordRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ResetPasswordRequest {

 String get token; String get password;
/// Create a copy of ResetPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResetPasswordRequestCopyWith<ResetPasswordRequest> get copyWith => _$ResetPasswordRequestCopyWithImpl<ResetPasswordRequest>(this as ResetPasswordRequest, _$identity);

  /// Serializes this ResetPasswordRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ResetPasswordRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResetPasswordRequest&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.password, _this.password) || other.password == _this.password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ResetPasswordRequest;
  return Object.hash(runtimeType,_this.token,_this.password);
}

@override
String toString() {
  final _this = this as ResetPasswordRequest;
  return 'ResetPasswordRequest(token: ${_this.token}, password: ${_this.password})';
}


}

/// @nodoc
abstract mixin class $ResetPasswordRequestCopyWith<$Res>  {
  factory $ResetPasswordRequestCopyWith(ResetPasswordRequest value, $Res Function(ResetPasswordRequest) _then) = _$ResetPasswordRequestCopyWithImpl;
@useResult
$Res call({
 String token, String password
});




}
/// @nodoc
class _$ResetPasswordRequestCopyWithImpl<$Res>
    implements $ResetPasswordRequestCopyWith<$Res> {
  _$ResetPasswordRequestCopyWithImpl(this._self, this._then);

  final ResetPasswordRequest _self;
  final $Res Function(ResetPasswordRequest) _then;

/// Create a copy of ResetPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? password = null,}) {
  return _then(ResetPasswordRequest(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ResetPasswordRequest].
extension ResetPasswordRequestPatterns on ResetPasswordRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResetPasswordRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResetPasswordRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResetPasswordRequest value)  $default,){
final _that = this;
switch (_that) {
case _ResetPasswordRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResetPasswordRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ResetPasswordRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResetPasswordRequest() when $default != null:
return $default(_that.token,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String password)  $default,) {final _that = this;
switch (_that) {
case _ResetPasswordRequest():
return $default(_that.token,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String password)?  $default,) {final _that = this;
switch (_that) {
case _ResetPasswordRequest() when $default != null:
return $default(_that.token,_that.password);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResetPasswordRequest implements ResetPasswordRequest {
  const _ResetPasswordRequest({required this.token, required this.password});
  factory _ResetPasswordRequest.fromJson(Map<String, dynamic> json) => _$ResetPasswordRequestFromJson(json);

@override final  String token;
@override final  String password;

/// Create a copy of ResetPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResetPasswordRequestCopyWith<_ResetPasswordRequest> get copyWith => __$ResetPasswordRequestCopyWithImpl<_ResetPasswordRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResetPasswordRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResetPasswordRequest&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,token,password);
}

@override
String toString() {
    return 'ResetPasswordRequest(token: $token, password: $password)';
}


}

/// @nodoc
abstract mixin class _$ResetPasswordRequestCopyWith<$Res> implements $ResetPasswordRequestCopyWith<$Res> {
  factory _$ResetPasswordRequestCopyWith(_ResetPasswordRequest value, $Res Function(_ResetPasswordRequest) _then) = __$ResetPasswordRequestCopyWithImpl;
@override @useResult
$Res call({
 String token, String password
});




}
/// @nodoc
class __$ResetPasswordRequestCopyWithImpl<$Res>
    implements _$ResetPasswordRequestCopyWith<$Res> {
  __$ResetPasswordRequestCopyWithImpl(this._self, this._then);

  final _ResetPasswordRequest _self;
  final $Res Function(_ResetPasswordRequest) _then;

/// Create a copy of ResetPasswordRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? password = null,}) {
  return _then(_ResetPasswordRequest(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$EmailVerificationRequest {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailVerificationRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'EmailVerificationRequest()';
}


}

/// @nodoc
class $EmailVerificationRequestCopyWith<$Res>  {
$EmailVerificationRequestCopyWith(EmailVerificationRequest _, $Res Function(EmailVerificationRequest) __);
}


/// Adds pattern-matching-related methods to [EmailVerificationRequest].
extension EmailVerificationRequestPatterns on EmailVerificationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RequestEmailVerification value)?  request,TResult Function( ConfirmEmailVerification value)?  confirm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RequestEmailVerification() when request != null:
return request(_that);case ConfirmEmailVerification() when confirm != null:
return confirm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RequestEmailVerification value)  request,required TResult Function( ConfirmEmailVerification value)  confirm,}){
final _that = this;
switch (_that) {
case RequestEmailVerification():
return request(_that);case ConfirmEmailVerification():
return confirm(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RequestEmailVerification value)?  request,TResult? Function( ConfirmEmailVerification value)?  confirm,}){
final _that = this;
switch (_that) {
case RequestEmailVerification() when request != null:
return request(_that);case ConfirmEmailVerification() when confirm != null:
return confirm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  request,TResult Function( String code)?  confirm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RequestEmailVerification() when request != null:
return request(_that.email);case ConfirmEmailVerification() when confirm != null:
return confirm(_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  request,required TResult Function( String code)  confirm,}) {final _that = this;
switch (_that) {
case RequestEmailVerification():
return request(_that.email);case ConfirmEmailVerification():
return confirm(_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  request,TResult? Function( String code)?  confirm,}) {final _that = this;
switch (_that) {
case RequestEmailVerification() when request != null:
return request(_that.email);case ConfirmEmailVerification() when confirm != null:
return confirm(_that.code);case _:
  return null;

}
}

}

/// @nodoc


class RequestEmailVerification implements EmailVerificationRequest {
  const RequestEmailVerification({required this.email});
  

 final  String email;

/// Create a copy of EmailVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequestEmailVerificationCopyWith<RequestEmailVerification> get copyWith => _$RequestEmailVerificationCopyWithImpl<RequestEmailVerification>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RequestEmailVerification&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString() {
    return 'EmailVerificationRequest.request(email: $email)';
}


}

/// @nodoc
abstract mixin class $RequestEmailVerificationCopyWith<$Res> implements $EmailVerificationRequestCopyWith<$Res> {
  factory $RequestEmailVerificationCopyWith(RequestEmailVerification value, $Res Function(RequestEmailVerification) _then) = _$RequestEmailVerificationCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$RequestEmailVerificationCopyWithImpl<$Res>
    implements $RequestEmailVerificationCopyWith<$Res> {
  _$RequestEmailVerificationCopyWithImpl(this._self, this._then);

  final RequestEmailVerification _self;
  final $Res Function(RequestEmailVerification) _then;

/// Create a copy of EmailVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(RequestEmailVerification(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConfirmEmailVerification implements EmailVerificationRequest {
  const ConfirmEmailVerification({required this.code});
  

 final  String code;

/// Create a copy of EmailVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmEmailVerificationCopyWith<ConfirmEmailVerification> get copyWith => _$ConfirmEmailVerificationCopyWithImpl<ConfirmEmailVerification>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmEmailVerification&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code);
}

@override
String toString() {
    return 'EmailVerificationRequest.confirm(code: $code)';
}


}

/// @nodoc
abstract mixin class $ConfirmEmailVerificationCopyWith<$Res> implements $EmailVerificationRequestCopyWith<$Res> {
  factory $ConfirmEmailVerificationCopyWith(ConfirmEmailVerification value, $Res Function(ConfirmEmailVerification) _then) = _$ConfirmEmailVerificationCopyWithImpl;
@useResult
$Res call({
 String code
});




}
/// @nodoc
class _$ConfirmEmailVerificationCopyWithImpl<$Res>
    implements $ConfirmEmailVerificationCopyWith<$Res> {
  _$ConfirmEmailVerificationCopyWithImpl(this._self, this._then);

  final ConfirmEmailVerification _self;
  final $Res Function(ConfirmEmailVerification) _then;

/// Create a copy of EmailVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(ConfirmEmailVerification(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PhoneVerificationRequest {

 String get phone;
/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneVerificationRequestCopyWith<PhoneVerificationRequest> get copyWith => _$PhoneVerificationRequestCopyWithImpl<PhoneVerificationRequest>(this as PhoneVerificationRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PhoneVerificationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneVerificationRequest&&(identical(other.phone, _this.phone) || other.phone == _this.phone));
}


@override
int get hashCode {
  final _this = this as PhoneVerificationRequest;
  return Object.hash(runtimeType,_this.phone);
}

@override
String toString() {
  final _this = this as PhoneVerificationRequest;
  return 'PhoneVerificationRequest(phone: ${_this.phone})';
}


}

/// @nodoc
abstract mixin class $PhoneVerificationRequestCopyWith<$Res>  {
  factory $PhoneVerificationRequestCopyWith(PhoneVerificationRequest value, $Res Function(PhoneVerificationRequest) _then) = _$PhoneVerificationRequestCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class _$PhoneVerificationRequestCopyWithImpl<$Res>
    implements $PhoneVerificationRequestCopyWith<$Res> {
  _$PhoneVerificationRequestCopyWithImpl(this._self, this._then);

  final PhoneVerificationRequest _self;
  final $Res Function(PhoneVerificationRequest) _then;

/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phone = null,}) {
  return _then(_self.copyWith(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PhoneVerificationRequest].
extension PhoneVerificationRequestPatterns on PhoneVerificationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RequestPhoneVerification value)?  request,TResult Function( ConfirmPhoneVerification value)?  confirm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RequestPhoneVerification() when request != null:
return request(_that);case ConfirmPhoneVerification() when confirm != null:
return confirm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RequestPhoneVerification value)  request,required TResult Function( ConfirmPhoneVerification value)  confirm,}){
final _that = this;
switch (_that) {
case RequestPhoneVerification():
return request(_that);case ConfirmPhoneVerification():
return confirm(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RequestPhoneVerification value)?  request,TResult? Function( ConfirmPhoneVerification value)?  confirm,}){
final _that = this;
switch (_that) {
case RequestPhoneVerification() when request != null:
return request(_that);case ConfirmPhoneVerification() when confirm != null:
return confirm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String phone)?  request,TResult Function( String phone,  String code)?  confirm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RequestPhoneVerification() when request != null:
return request(_that.phone);case ConfirmPhoneVerification() when confirm != null:
return confirm(_that.phone,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String phone)  request,required TResult Function( String phone,  String code)  confirm,}) {final _that = this;
switch (_that) {
case RequestPhoneVerification():
return request(_that.phone);case ConfirmPhoneVerification():
return confirm(_that.phone,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String phone)?  request,TResult? Function( String phone,  String code)?  confirm,}) {final _that = this;
switch (_that) {
case RequestPhoneVerification() when request != null:
return request(_that.phone);case ConfirmPhoneVerification() when confirm != null:
return confirm(_that.phone,_that.code);case _:
  return null;

}
}

}

/// @nodoc


class RequestPhoneVerification implements PhoneVerificationRequest {
  const RequestPhoneVerification({required this.phone});
  

@override final  String phone;

/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequestPhoneVerificationCopyWith<RequestPhoneVerification> get copyWith => _$RequestPhoneVerificationCopyWithImpl<RequestPhoneVerification>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RequestPhoneVerification&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString() {
    return 'PhoneVerificationRequest.request(phone: $phone)';
}


}

/// @nodoc
abstract mixin class $RequestPhoneVerificationCopyWith<$Res> implements $PhoneVerificationRequestCopyWith<$Res> {
  factory $RequestPhoneVerificationCopyWith(RequestPhoneVerification value, $Res Function(RequestPhoneVerification) _then) = _$RequestPhoneVerificationCopyWithImpl;
@override @useResult
$Res call({
 String phone
});




}
/// @nodoc
class _$RequestPhoneVerificationCopyWithImpl<$Res>
    implements $RequestPhoneVerificationCopyWith<$Res> {
  _$RequestPhoneVerificationCopyWithImpl(this._self, this._then);

  final RequestPhoneVerification _self;
  final $Res Function(RequestPhoneVerification) _then;

/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(RequestPhoneVerification(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConfirmPhoneVerification implements PhoneVerificationRequest {
  const ConfirmPhoneVerification({required this.phone, required this.code});
  

@override final  String phone;
 final  String code;

/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfirmPhoneVerificationCopyWith<ConfirmPhoneVerification> get copyWith => _$ConfirmPhoneVerificationCopyWithImpl<ConfirmPhoneVerification>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfirmPhoneVerification&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.code, code) || other.code == code));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone,code);
}

@override
String toString() {
    return 'PhoneVerificationRequest.confirm(phone: $phone, code: $code)';
}


}

/// @nodoc
abstract mixin class $ConfirmPhoneVerificationCopyWith<$Res> implements $PhoneVerificationRequestCopyWith<$Res> {
  factory $ConfirmPhoneVerificationCopyWith(ConfirmPhoneVerification value, $Res Function(ConfirmPhoneVerification) _then) = _$ConfirmPhoneVerificationCopyWithImpl;
@override @useResult
$Res call({
 String phone, String code
});




}
/// @nodoc
class _$ConfirmPhoneVerificationCopyWithImpl<$Res>
    implements $ConfirmPhoneVerificationCopyWith<$Res> {
  _$ConfirmPhoneVerificationCopyWithImpl(this._self, this._then);

  final ConfirmPhoneVerification _self;
  final $Res Function(ConfirmPhoneVerification) _then;

/// Create a copy of PhoneVerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phone = null,Object? code = null,}) {
  return _then(ConfirmPhoneVerification(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeviceRegistrationRequest {

@JsonKey(name: 'deviceIdentifier') String get deviceIdentifier; String get platform;@JsonKey(name: 'deviceName') String? get deviceName;@JsonKey(name: 'deviceModel') String? get deviceModel;@JsonKey(name: 'osVersion') String? get osVersion;@JsonKey(name: 'appVersion') String? get appVersion;@JsonKey(name: 'pushProvider') String? get pushProvider;@JsonKey(name: 'pushToken') String? get pushToken;
/// Create a copy of DeviceRegistrationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRegistrationRequestCopyWith<DeviceRegistrationRequest> get copyWith => _$DeviceRegistrationRequestCopyWithImpl<DeviceRegistrationRequest>(this as DeviceRegistrationRequest, _$identity);

  /// Serializes this DeviceRegistrationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRegistrationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRegistrationRequest&&(identical(other.deviceIdentifier, _this.deviceIdentifier) || other.deviceIdentifier == _this.deviceIdentifier)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.deviceName, _this.deviceName) || other.deviceName == _this.deviceName)&&(identical(other.deviceModel, _this.deviceModel) || other.deviceModel == _this.deviceModel)&&(identical(other.osVersion, _this.osVersion) || other.osVersion == _this.osVersion)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.pushProvider, _this.pushProvider) || other.pushProvider == _this.pushProvider)&&(identical(other.pushToken, _this.pushToken) || other.pushToken == _this.pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRegistrationRequest;
  return Object.hash(runtimeType,_this.deviceIdentifier,_this.platform,_this.deviceName,_this.deviceModel,_this.osVersion,_this.appVersion,_this.pushProvider,_this.pushToken);
}

@override
String toString() {
  final _this = this as DeviceRegistrationRequest;
  return 'DeviceRegistrationRequest(deviceIdentifier: ${_this.deviceIdentifier}, platform: ${_this.platform}, deviceName: ${_this.deviceName}, deviceModel: ${_this.deviceModel}, osVersion: ${_this.osVersion}, appVersion: ${_this.appVersion}, pushProvider: ${_this.pushProvider}, pushToken: ${_this.pushToken})';
}


}

/// @nodoc
abstract mixin class $DeviceRegistrationRequestCopyWith<$Res>  {
  factory $DeviceRegistrationRequestCopyWith(DeviceRegistrationRequest value, $Res Function(DeviceRegistrationRequest) _then) = _$DeviceRegistrationRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'deviceIdentifier') String deviceIdentifier, String platform,@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'deviceModel') String? deviceModel,@JsonKey(name: 'osVersion') String? osVersion,@JsonKey(name: 'appVersion') String? appVersion,@JsonKey(name: 'pushProvider') String? pushProvider,@JsonKey(name: 'pushToken') String? pushToken
});




}
/// @nodoc
class _$DeviceRegistrationRequestCopyWithImpl<$Res>
    implements $DeviceRegistrationRequestCopyWith<$Res> {
  _$DeviceRegistrationRequestCopyWithImpl(this._self, this._then);

  final DeviceRegistrationRequest _self;
  final $Res Function(DeviceRegistrationRequest) _then;

/// Create a copy of DeviceRegistrationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceIdentifier = null,Object? platform = null,Object? deviceName = freezed,Object? deviceModel = freezed,Object? osVersion = freezed,Object? appVersion = freezed,Object? pushProvider = freezed,Object? pushToken = freezed,}) {
  return _then(DeviceRegistrationRequest(
deviceIdentifier: null == deviceIdentifier ? _self.deviceIdentifier : deviceIdentifier // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,deviceModel: freezed == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String?,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,pushProvider: freezed == pushProvider ? _self.pushProvider : pushProvider // ignore: cast_nullable_to_non_nullable
as String?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRegistrationRequest].
extension DeviceRegistrationRequestPatterns on DeviceRegistrationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRegistrationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRegistrationRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRegistrationRequest value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRegistrationRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRegistrationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRegistrationRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'pushToken')  String? pushToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRegistrationRequest() when $default != null:
return $default(_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.pushToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'pushToken')  String? pushToken)  $default,) {final _that = this;
switch (_that) {
case _DeviceRegistrationRequest():
return $default(_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.pushToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'deviceIdentifier')  String deviceIdentifier,  String platform, @JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'deviceModel')  String? deviceModel, @JsonKey(name: 'osVersion')  String? osVersion, @JsonKey(name: 'appVersion')  String? appVersion, @JsonKey(name: 'pushProvider')  String? pushProvider, @JsonKey(name: 'pushToken')  String? pushToken)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRegistrationRequest() when $default != null:
return $default(_that.deviceIdentifier,_that.platform,_that.deviceName,_that.deviceModel,_that.osVersion,_that.appVersion,_that.pushProvider,_that.pushToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRegistrationRequest implements DeviceRegistrationRequest {
  const _DeviceRegistrationRequest({@JsonKey(name: 'deviceIdentifier') required this.deviceIdentifier, required this.platform, @JsonKey(name: 'deviceName') this.deviceName, @JsonKey(name: 'deviceModel') this.deviceModel, @JsonKey(name: 'osVersion') this.osVersion, @JsonKey(name: 'appVersion') this.appVersion, @JsonKey(name: 'pushProvider') this.pushProvider, @JsonKey(name: 'pushToken') this.pushToken});
  factory _DeviceRegistrationRequest.fromJson(Map<String, dynamic> json) => _$DeviceRegistrationRequestFromJson(json);

@override@JsonKey(name: 'deviceIdentifier') final  String deviceIdentifier;
@override final  String platform;
@override@JsonKey(name: 'deviceName') final  String? deviceName;
@override@JsonKey(name: 'deviceModel') final  String? deviceModel;
@override@JsonKey(name: 'osVersion') final  String? osVersion;
@override@JsonKey(name: 'appVersion') final  String? appVersion;
@override@JsonKey(name: 'pushProvider') final  String? pushProvider;
@override@JsonKey(name: 'pushToken') final  String? pushToken;

/// Create a copy of DeviceRegistrationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRegistrationRequestCopyWith<_DeviceRegistrationRequest> get copyWith => __$DeviceRegistrationRequestCopyWithImpl<_DeviceRegistrationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRegistrationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRegistrationRequest&&(identical(other.deviceIdentifier, deviceIdentifier) || other.deviceIdentifier == deviceIdentifier)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.osVersion, osVersion) || other.osVersion == osVersion)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.pushProvider, pushProvider) || other.pushProvider == pushProvider)&&(identical(other.pushToken, pushToken) || other.pushToken == pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,deviceIdentifier,platform,deviceName,deviceModel,osVersion,appVersion,pushProvider,pushToken);
}

@override
String toString() {
    return 'DeviceRegistrationRequest(deviceIdentifier: $deviceIdentifier, platform: $platform, deviceName: $deviceName, deviceModel: $deviceModel, osVersion: $osVersion, appVersion: $appVersion, pushProvider: $pushProvider, pushToken: $pushToken)';
}


}

/// @nodoc
abstract mixin class _$DeviceRegistrationRequestCopyWith<$Res> implements $DeviceRegistrationRequestCopyWith<$Res> {
  factory _$DeviceRegistrationRequestCopyWith(_DeviceRegistrationRequest value, $Res Function(_DeviceRegistrationRequest) _then) = __$DeviceRegistrationRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'deviceIdentifier') String deviceIdentifier, String platform,@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'deviceModel') String? deviceModel,@JsonKey(name: 'osVersion') String? osVersion,@JsonKey(name: 'appVersion') String? appVersion,@JsonKey(name: 'pushProvider') String? pushProvider,@JsonKey(name: 'pushToken') String? pushToken
});




}
/// @nodoc
class __$DeviceRegistrationRequestCopyWithImpl<$Res>
    implements _$DeviceRegistrationRequestCopyWith<$Res> {
  __$DeviceRegistrationRequestCopyWithImpl(this._self, this._then);

  final _DeviceRegistrationRequest _self;
  final $Res Function(_DeviceRegistrationRequest) _then;

/// Create a copy of DeviceRegistrationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceIdentifier = null,Object? platform = null,Object? deviceName = freezed,Object? deviceModel = freezed,Object? osVersion = freezed,Object? appVersion = freezed,Object? pushProvider = freezed,Object? pushToken = freezed,}) {
  return _then(_DeviceRegistrationRequest(
deviceIdentifier: null == deviceIdentifier ? _self.deviceIdentifier : deviceIdentifier // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,deviceModel: freezed == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String?,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,pushProvider: freezed == pushProvider ? _self.pushProvider : pushProvider // ignore: cast_nullable_to_non_nullable
as String?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DeviceUpdateRequest {

@JsonKey(name: 'deviceName') String? get deviceName;@JsonKey(name: 'pushToken') String? get pushToken;
/// Create a copy of DeviceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceUpdateRequestCopyWith<DeviceUpdateRequest> get copyWith => _$DeviceUpdateRequestCopyWithImpl<DeviceUpdateRequest>(this as DeviceUpdateRequest, _$identity);

  /// Serializes this DeviceUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceUpdateRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceUpdateRequest&&(identical(other.deviceName, _this.deviceName) || other.deviceName == _this.deviceName)&&(identical(other.pushToken, _this.pushToken) || other.pushToken == _this.pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceUpdateRequest;
  return Object.hash(runtimeType,_this.deviceName,_this.pushToken);
}

@override
String toString() {
  final _this = this as DeviceUpdateRequest;
  return 'DeviceUpdateRequest(deviceName: ${_this.deviceName}, pushToken: ${_this.pushToken})';
}


}

/// @nodoc
abstract mixin class $DeviceUpdateRequestCopyWith<$Res>  {
  factory $DeviceUpdateRequestCopyWith(DeviceUpdateRequest value, $Res Function(DeviceUpdateRequest) _then) = _$DeviceUpdateRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'pushToken') String? pushToken
});




}
/// @nodoc
class _$DeviceUpdateRequestCopyWithImpl<$Res>
    implements $DeviceUpdateRequestCopyWith<$Res> {
  _$DeviceUpdateRequestCopyWithImpl(this._self, this._then);

  final DeviceUpdateRequest _self;
  final $Res Function(DeviceUpdateRequest) _then;

/// Create a copy of DeviceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceName = freezed,Object? pushToken = freezed,}) {
  return _then(DeviceUpdateRequest(
deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceUpdateRequest].
extension DeviceUpdateRequestPatterns on DeviceUpdateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceUpdateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceUpdateRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceUpdateRequest value)  $default,){
final _that = this;
switch (_that) {
case _DeviceUpdateRequest():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceUpdateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceUpdateRequest() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'pushToken')  String? pushToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceUpdateRequest() when $default != null:
return $default(_that.deviceName,_that.pushToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'pushToken')  String? pushToken)  $default,) {final _that = this;
switch (_that) {
case _DeviceUpdateRequest():
return $default(_that.deviceName,_that.pushToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'deviceName')  String? deviceName, @JsonKey(name: 'pushToken')  String? pushToken)?  $default,) {final _that = this;
switch (_that) {
case _DeviceUpdateRequest() when $default != null:
return $default(_that.deviceName,_that.pushToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceUpdateRequest implements DeviceUpdateRequest {
  const _DeviceUpdateRequest({@JsonKey(name: 'deviceName') this.deviceName, @JsonKey(name: 'pushToken') this.pushToken});
  factory _DeviceUpdateRequest.fromJson(Map<String, dynamic> json) => _$DeviceUpdateRequestFromJson(json);

@override@JsonKey(name: 'deviceName') final  String? deviceName;
@override@JsonKey(name: 'pushToken') final  String? pushToken;

/// Create a copy of DeviceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceUpdateRequestCopyWith<_DeviceUpdateRequest> get copyWith => __$DeviceUpdateRequestCopyWithImpl<_DeviceUpdateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceUpdateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceUpdateRequest&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.pushToken, pushToken) || other.pushToken == pushToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,deviceName,pushToken);
}

@override
String toString() {
    return 'DeviceUpdateRequest(deviceName: $deviceName, pushToken: $pushToken)';
}


}

/// @nodoc
abstract mixin class _$DeviceUpdateRequestCopyWith<$Res> implements $DeviceUpdateRequestCopyWith<$Res> {
  factory _$DeviceUpdateRequestCopyWith(_DeviceUpdateRequest value, $Res Function(_DeviceUpdateRequest) _then) = __$DeviceUpdateRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'deviceName') String? deviceName,@JsonKey(name: 'pushToken') String? pushToken
});




}
/// @nodoc
class __$DeviceUpdateRequestCopyWithImpl<$Res>
    implements _$DeviceUpdateRequestCopyWith<$Res> {
  __$DeviceUpdateRequestCopyWithImpl(this._self, this._then);

  final _DeviceUpdateRequest _self;
  final $Res Function(_DeviceUpdateRequest) _then;

/// Create a copy of DeviceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceName = freezed,Object? pushToken = freezed,}) {
  return _then(_DeviceUpdateRequest(
deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AccountRecoveryRequest {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountRecoveryRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AccountRecoveryRequest()';
}


}

/// @nodoc
class $AccountRecoveryRequestCopyWith<$Res>  {
$AccountRecoveryRequestCopyWith(AccountRecoveryRequest _, $Res Function(AccountRecoveryRequest) __);
}


/// Adds pattern-matching-related methods to [AccountRecoveryRequest].
extension AccountRecoveryRequestPatterns on AccountRecoveryRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RecoveryEmailRequest value)?  email,TResult Function( RecoveryPhoneRequest value)?  phone,TResult Function( RecoveryVerifyRequest value)?  verify,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RecoveryEmailRequest() when email != null:
return email(_that);case RecoveryPhoneRequest() when phone != null:
return phone(_that);case RecoveryVerifyRequest() when verify != null:
return verify(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RecoveryEmailRequest value)  email,required TResult Function( RecoveryPhoneRequest value)  phone,required TResult Function( RecoveryVerifyRequest value)  verify,}){
final _that = this;
switch (_that) {
case RecoveryEmailRequest():
return email(_that);case RecoveryPhoneRequest():
return phone(_that);case RecoveryVerifyRequest():
return verify(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RecoveryEmailRequest value)?  email,TResult? Function( RecoveryPhoneRequest value)?  phone,TResult? Function( RecoveryVerifyRequest value)?  verify,}){
final _that = this;
switch (_that) {
case RecoveryEmailRequest() when email != null:
return email(_that);case RecoveryPhoneRequest() when phone != null:
return phone(_that);case RecoveryVerifyRequest() when verify != null:
return verify(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  email,TResult Function( String phone)?  phone,TResult Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)?  verify,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RecoveryEmailRequest() when email != null:
return email(_that.email);case RecoveryPhoneRequest() when phone != null:
return phone(_that.phone);case RecoveryVerifyRequest() when verify != null:
return verify(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  email,required TResult Function( String phone)  phone,required TResult Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)  verify,}) {final _that = this;
switch (_that) {
case RecoveryEmailRequest():
return email(_that.email);case RecoveryPhoneRequest():
return phone(_that.phone);case RecoveryVerifyRequest():
return verify(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  email,TResult? Function( String phone)?  phone,TResult? Function( String token,  String password,  String? mfaMethod,  String? phoneNumber)?  verify,}) {final _that = this;
switch (_that) {
case RecoveryEmailRequest() when email != null:
return email(_that.email);case RecoveryPhoneRequest() when phone != null:
return phone(_that.phone);case RecoveryVerifyRequest() when verify != null:
return verify(_that.token,_that.password,_that.mfaMethod,_that.phoneNumber);case _:
  return null;

}
}

}

/// @nodoc


class RecoveryEmailRequest implements AccountRecoveryRequest {
  const RecoveryEmailRequest({required this.email});
  

 final  String email;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecoveryEmailRequestCopyWith<RecoveryEmailRequest> get copyWith => _$RecoveryEmailRequestCopyWithImpl<RecoveryEmailRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RecoveryEmailRequest&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email);
}

@override
String toString() {
    return 'AccountRecoveryRequest.email(email: $email)';
}


}

/// @nodoc
abstract mixin class $RecoveryEmailRequestCopyWith<$Res> implements $AccountRecoveryRequestCopyWith<$Res> {
  factory $RecoveryEmailRequestCopyWith(RecoveryEmailRequest value, $Res Function(RecoveryEmailRequest) _then) = _$RecoveryEmailRequestCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class _$RecoveryEmailRequestCopyWithImpl<$Res>
    implements $RecoveryEmailRequestCopyWith<$Res> {
  _$RecoveryEmailRequestCopyWithImpl(this._self, this._then);

  final RecoveryEmailRequest _self;
  final $Res Function(RecoveryEmailRequest) _then;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(RecoveryEmailRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RecoveryPhoneRequest implements AccountRecoveryRequest {
  const RecoveryPhoneRequest({required this.phone});
  

 final  String phone;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecoveryPhoneRequestCopyWith<RecoveryPhoneRequest> get copyWith => _$RecoveryPhoneRequestCopyWithImpl<RecoveryPhoneRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RecoveryPhoneRequest&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phone);
}

@override
String toString() {
    return 'AccountRecoveryRequest.phone(phone: $phone)';
}


}

/// @nodoc
abstract mixin class $RecoveryPhoneRequestCopyWith<$Res> implements $AccountRecoveryRequestCopyWith<$Res> {
  factory $RecoveryPhoneRequestCopyWith(RecoveryPhoneRequest value, $Res Function(RecoveryPhoneRequest) _then) = _$RecoveryPhoneRequestCopyWithImpl;
@useResult
$Res call({
 String phone
});




}
/// @nodoc
class _$RecoveryPhoneRequestCopyWithImpl<$Res>
    implements $RecoveryPhoneRequestCopyWith<$Res> {
  _$RecoveryPhoneRequestCopyWithImpl(this._self, this._then);

  final RecoveryPhoneRequest _self;
  final $Res Function(RecoveryPhoneRequest) _then;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phone = null,}) {
  return _then(RecoveryPhoneRequest(
phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RecoveryVerifyRequest implements AccountRecoveryRequest {
  const RecoveryVerifyRequest({required this.token, required this.password, this.mfaMethod, this.phoneNumber});
  

 final  String token;
 final  String password;
 final  String? mfaMethod;
 final  String? phoneNumber;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecoveryVerifyRequestCopyWith<RecoveryVerifyRequest> get copyWith => _$RecoveryVerifyRequestCopyWithImpl<RecoveryVerifyRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RecoveryVerifyRequest&&(identical(other.token, token) || other.token == token)&&(identical(other.password, password) || other.password == password)&&(identical(other.mfaMethod, mfaMethod) || other.mfaMethod == mfaMethod)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}


@override
int get hashCode {
    return Object.hash(runtimeType,token,password,mfaMethod,phoneNumber);
}

@override
String toString() {
    return 'AccountRecoveryRequest.verify(token: $token, password: $password, mfaMethod: $mfaMethod, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class $RecoveryVerifyRequestCopyWith<$Res> implements $AccountRecoveryRequestCopyWith<$Res> {
  factory $RecoveryVerifyRequestCopyWith(RecoveryVerifyRequest value, $Res Function(RecoveryVerifyRequest) _then) = _$RecoveryVerifyRequestCopyWithImpl;
@useResult
$Res call({
 String token, String password, String? mfaMethod, String? phoneNumber
});




}
/// @nodoc
class _$RecoveryVerifyRequestCopyWithImpl<$Res>
    implements $RecoveryVerifyRequestCopyWith<$Res> {
  _$RecoveryVerifyRequestCopyWithImpl(this._self, this._then);

  final RecoveryVerifyRequest _self;
  final $Res Function(RecoveryVerifyRequest) _then;

/// Create a copy of AccountRecoveryRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? password = null,Object? mfaMethod = freezed,Object? phoneNumber = freezed,}) {
  return _then(RecoveryVerifyRequest(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,mfaMethod: freezed == mfaMethod ? _self.mfaMethod : mfaMethod // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SecurityEvent {

 String get id;@JsonKey(name: 'userId') String? get userId;@JsonKey(name: 'eventType') String get eventType;@JsonKey(name: 'eventCategory') String get eventCategory; String get severity;@JsonKey(name: 'ipAddress') String? get ipAddress;@JsonKey(name: 'userAgent') String? get userAgent;@JsonKey(name: 'metadata') Map<String, dynamic>? get metadata;@JsonKey(name: 'createdAt') DateTime get createdAt;
/// Create a copy of SecurityEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecurityEventCopyWith<SecurityEvent> get copyWith => _$SecurityEventCopyWithImpl<SecurityEvent>(this as SecurityEvent, _$identity);

  /// Serializes this SecurityEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SecurityEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SecurityEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.eventType, _this.eventType) || other.eventType == _this.eventType)&&(identical(other.eventCategory, _this.eventCategory) || other.eventCategory == _this.eventCategory)&&(identical(other.severity, _this.severity) || other.severity == _this.severity)&&(identical(other.ipAddress, _this.ipAddress) || other.ipAddress == _this.ipAddress)&&(identical(other.userAgent, _this.userAgent) || other.userAgent == _this.userAgent)&&const DeepCollectionEquality().equals(other.metadata, _this.metadata)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SecurityEvent;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.eventType,_this.eventCategory,_this.severity,_this.ipAddress,_this.userAgent,const DeepCollectionEquality().hash(_this.metadata),_this.createdAt);
}

@override
String toString() {
  final _this = this as SecurityEvent;
  return 'SecurityEvent(id: ${_this.id}, userId: ${_this.userId}, eventType: ${_this.eventType}, eventCategory: ${_this.eventCategory}, severity: ${_this.severity}, ipAddress: ${_this.ipAddress}, userAgent: ${_this.userAgent}, metadata: ${_this.metadata}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $SecurityEventCopyWith<$Res>  {
  factory $SecurityEventCopyWith(SecurityEvent value, $Res Function(SecurityEvent) _then) = _$SecurityEventCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'userId') String? userId,@JsonKey(name: 'eventType') String eventType,@JsonKey(name: 'eventCategory') String eventCategory, String severity,@JsonKey(name: 'ipAddress') String? ipAddress,@JsonKey(name: 'userAgent') String? userAgent,@JsonKey(name: 'metadata') Map<String, dynamic>? metadata,@JsonKey(name: 'createdAt') DateTime createdAt
});




}
/// @nodoc
class _$SecurityEventCopyWithImpl<$Res>
    implements $SecurityEventCopyWith<$Res> {
  _$SecurityEventCopyWithImpl(this._self, this._then);

  final SecurityEvent _self;
  final $Res Function(SecurityEvent) _then;

/// Create a copy of SecurityEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = freezed,Object? eventType = null,Object? eventCategory = null,Object? severity = null,Object? ipAddress = freezed,Object? userAgent = freezed,Object? metadata = freezed,Object? createdAt = null,}) {
  return _then(SecurityEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,eventCategory: null == eventCategory ? _self.eventCategory : eventCategory // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SecurityEvent].
extension SecurityEventPatterns on SecurityEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SecurityEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SecurityEvent() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SecurityEvent value)  $default,){
final _that = this;
switch (_that) {
case _SecurityEvent():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SecurityEvent value)?  $default,){
final _that = this;
switch (_that) {
case _SecurityEvent() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String? userId, @JsonKey(name: 'eventType')  String eventType, @JsonKey(name: 'eventCategory')  String eventCategory,  String severity, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'metadata')  Map<String, dynamic>? metadata, @JsonKey(name: 'createdAt')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SecurityEvent() when $default != null:
return $default(_that.id,_that.userId,_that.eventType,_that.eventCategory,_that.severity,_that.ipAddress,_that.userAgent,_that.metadata,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String? userId, @JsonKey(name: 'eventType')  String eventType, @JsonKey(name: 'eventCategory')  String eventCategory,  String severity, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'metadata')  Map<String, dynamic>? metadata, @JsonKey(name: 'createdAt')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SecurityEvent():
return $default(_that.id,_that.userId,_that.eventType,_that.eventCategory,_that.severity,_that.ipAddress,_that.userAgent,_that.metadata,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'userId')  String? userId, @JsonKey(name: 'eventType')  String eventType, @JsonKey(name: 'eventCategory')  String eventCategory,  String severity, @JsonKey(name: 'ipAddress')  String? ipAddress, @JsonKey(name: 'userAgent')  String? userAgent, @JsonKey(name: 'metadata')  Map<String, dynamic>? metadata, @JsonKey(name: 'createdAt')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SecurityEvent() when $default != null:
return $default(_that.id,_that.userId,_that.eventType,_that.eventCategory,_that.severity,_that.ipAddress,_that.userAgent,_that.metadata,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SecurityEvent implements SecurityEvent {
  const _SecurityEvent({required this.id, @JsonKey(name: 'userId') this.userId, @JsonKey(name: 'eventType') required this.eventType, @JsonKey(name: 'eventCategory') required this.eventCategory, required this.severity, @JsonKey(name: 'ipAddress') this.ipAddress, @JsonKey(name: 'userAgent') this.userAgent, @JsonKey(name: 'metadata')  Map<String, dynamic>? metadata, @JsonKey(name: 'createdAt') required this.createdAt}): _metadata = metadata;
  factory _SecurityEvent.fromJson(Map<String, dynamic> json) => _$SecurityEventFromJson(json);

@override final  String id;
@override@JsonKey(name: 'userId') final  String? userId;
@override@JsonKey(name: 'eventType') final  String eventType;
@override@JsonKey(name: 'eventCategory') final  String eventCategory;
@override final  String severity;
@override@JsonKey(name: 'ipAddress') final  String? ipAddress;
@override@JsonKey(name: 'userAgent') final  String? userAgent;
 final  Map<String, dynamic>? _metadata;
@override@JsonKey(name: 'metadata') Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'createdAt') final  DateTime createdAt;

/// Create a copy of SecurityEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecurityEventCopyWith<_SecurityEvent> get copyWith => __$SecurityEventCopyWithImpl<_SecurityEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SecurityEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecurityEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.eventCategory, eventCategory) || other.eventCategory == eventCategory)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.ipAddress, ipAddress) || other.ipAddress == ipAddress)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&const DeepCollectionEquality().equals(other.metadata, _metadata)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,eventType,eventCategory,severity,ipAddress,userAgent,const DeepCollectionEquality().hash(_metadata),createdAt);
}

@override
String toString() {
    return 'SecurityEvent(id: $id, userId: $userId, eventType: $eventType, eventCategory: $eventCategory, severity: $severity, ipAddress: $ipAddress, userAgent: $userAgent, metadata: $metadata, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SecurityEventCopyWith<$Res> implements $SecurityEventCopyWith<$Res> {
  factory _$SecurityEventCopyWith(_SecurityEvent value, $Res Function(_SecurityEvent) _then) = __$SecurityEventCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'userId') String? userId,@JsonKey(name: 'eventType') String eventType,@JsonKey(name: 'eventCategory') String eventCategory, String severity,@JsonKey(name: 'ipAddress') String? ipAddress,@JsonKey(name: 'userAgent') String? userAgent,@JsonKey(name: 'metadata') Map<String, dynamic>? metadata,@JsonKey(name: 'createdAt') DateTime createdAt
});




}
/// @nodoc
class __$SecurityEventCopyWithImpl<$Res>
    implements _$SecurityEventCopyWith<$Res> {
  __$SecurityEventCopyWithImpl(this._self, this._then);

  final _SecurityEvent _self;
  final $Res Function(_SecurityEvent) _then;

/// Create a copy of SecurityEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = freezed,Object? eventType = null,Object? eventCategory = null,Object? severity = null,Object? ipAddress = freezed,Object? userAgent = freezed,Object? metadata = freezed,Object? createdAt = null,}) {
  return _then(_SecurityEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,eventCategory: null == eventCategory ? _self.eventCategory : eventCategory // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,ipAddress: freezed == ipAddress ? _self.ipAddress : ipAddress // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$GoogleAuthUrlResponse {

 String get url; String get state;
/// Create a copy of GoogleAuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoogleAuthUrlResponseCopyWith<GoogleAuthUrlResponse> get copyWith => _$GoogleAuthUrlResponseCopyWithImpl<GoogleAuthUrlResponse>(this as GoogleAuthUrlResponse, _$identity);

  /// Serializes this GoogleAuthUrlResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GoogleAuthUrlResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoogleAuthUrlResponse&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.state, _this.state) || other.state == _this.state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GoogleAuthUrlResponse;
  return Object.hash(runtimeType,_this.url,_this.state);
}

@override
String toString() {
  final _this = this as GoogleAuthUrlResponse;
  return 'GoogleAuthUrlResponse(url: ${_this.url}, state: ${_this.state})';
}


}

/// @nodoc
abstract mixin class $GoogleAuthUrlResponseCopyWith<$Res>  {
  factory $GoogleAuthUrlResponseCopyWith(GoogleAuthUrlResponse value, $Res Function(GoogleAuthUrlResponse) _then) = _$GoogleAuthUrlResponseCopyWithImpl;
@useResult
$Res call({
 String url, String state
});




}
/// @nodoc
class _$GoogleAuthUrlResponseCopyWithImpl<$Res>
    implements $GoogleAuthUrlResponseCopyWith<$Res> {
  _$GoogleAuthUrlResponseCopyWithImpl(this._self, this._then);

  final GoogleAuthUrlResponse _self;
  final $Res Function(GoogleAuthUrlResponse) _then;

/// Create a copy of GoogleAuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? state = null,}) {
  return _then(GoogleAuthUrlResponse(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GoogleAuthUrlResponse].
extension GoogleAuthUrlResponsePatterns on GoogleAuthUrlResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoogleAuthUrlResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoogleAuthUrlResponse value)  $default,){
final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoogleAuthUrlResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse() when $default != null:
return $default(_that.url,_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String state)  $default,) {final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse():
return $default(_that.url,_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String state)?  $default,) {final _that = this;
switch (_that) {
case _GoogleAuthUrlResponse() when $default != null:
return $default(_that.url,_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoogleAuthUrlResponse implements GoogleAuthUrlResponse {
  const _GoogleAuthUrlResponse({required this.url, required this.state});
  factory _GoogleAuthUrlResponse.fromJson(Map<String, dynamic> json) => _$GoogleAuthUrlResponseFromJson(json);

@override final  String url;
@override final  String state;

/// Create a copy of GoogleAuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoogleAuthUrlResponseCopyWith<_GoogleAuthUrlResponse> get copyWith => __$GoogleAuthUrlResponseCopyWithImpl<_GoogleAuthUrlResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoogleAuthUrlResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoogleAuthUrlResponse&&(identical(other.url, url) || other.url == url)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,state);
}

@override
String toString() {
    return 'GoogleAuthUrlResponse(url: $url, state: $state)';
}


}

/// @nodoc
abstract mixin class _$GoogleAuthUrlResponseCopyWith<$Res> implements $GoogleAuthUrlResponseCopyWith<$Res> {
  factory _$GoogleAuthUrlResponseCopyWith(_GoogleAuthUrlResponse value, $Res Function(_GoogleAuthUrlResponse) _then) = __$GoogleAuthUrlResponseCopyWithImpl;
@override @useResult
$Res call({
 String url, String state
});




}
/// @nodoc
class __$GoogleAuthUrlResponseCopyWithImpl<$Res>
    implements _$GoogleAuthUrlResponseCopyWith<$Res> {
  __$GoogleAuthUrlResponseCopyWithImpl(this._self, this._then);

  final _GoogleAuthUrlResponse _self;
  final $Res Function(_GoogleAuthUrlResponse) _then;

/// Create a copy of GoogleAuthUrlResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? state = null,}) {
  return _then(_GoogleAuthUrlResponse(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
