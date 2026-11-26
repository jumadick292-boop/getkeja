import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';

/// Routes completed auth actions from one place so required challenge/contact
/// data is not lost between individual auth screens.
void navigateForAuthState(
  BuildContext context,
  AuthState state, {
  String? email,
  String? phone,
  bool verificationDeliveryFailed = false,
}) {
  state.whenOrNull(
    authenticated: (_, _, _) => context.go('/dashboard'),
    mfaRequired: (challengeId, methods) {
      final uri = Uri(
        path: '/mfa/challenge',
        queryParameters: {
          'challengeId': challengeId,
          'methods': methods.join(','),
        },
      );
      context.go(uri.toString());
    },
    mfaEnrollmentRequired: (_) => context.go('/mfa/enroll'),
    verificationRequired: (type, _) {
      if (type == 'phone') {
        context.go('/verify-phone', extra: {'phone': phone});
      } else {
        context.go(
          '/verify-email',
          extra: {'email': email, 'deliveryFailed': verificationDeliveryFailed},
        );
      }
    },
  );
}
