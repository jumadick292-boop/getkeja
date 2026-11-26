import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/authentication/presentation/state/auth_state.dart';

void main() {
  group('AuthStateX.user', () {
    test('returns null for MFA states that do not contain a user', () {
      expect(
        AuthState.mfaRequired(
          challengeId: 'challenge-id',
          availableMethods: const ['totp'],
        ).user,
        isNull,
      );
      expect(
        AuthState.mfaEnrollmentRequired(
          enrollmentToken: 'enrollment-token',
        ).user,
        isNull,
      );
    });

    test('returns user only from states that carry one', () {
      const user = AuthUser(id: 'user-id', firstName: 'Test', lastName: 'User');

      expect(
        AuthState.authenticated(
          user: user,
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ).user,
        user,
      );
      expect(
        AuthState.verificationRequired(
          verificationType: 'email',
          user: user,
        ).user,
        user,
      );
    });
  });
}
