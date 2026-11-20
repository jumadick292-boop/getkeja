import { describe, expect, it } from 'vitest';
import {
  confirmEmailVerificationSchema,
  emailChangeConfirmSchema,
  googleRegistrationSchema,
} from './auth.schema.js';

describe('Google registration schema', () => {
  it('accepts a selected account role', () => {
    expect(googleRegistrationSchema.safeParse({
      idToken: 'google-id-token',
      role: 'landlord',
    }).success).toBe(true);
  });

  it('defaults the role to house seeker for older clients', () => {
    expect(googleRegistrationSchema.parse({
      idToken: 'google-id-token',
    }).role).toBe('house_seeker');
  });

  it('rejects roles not permitted in registration', () => {
    expect(googleRegistrationSchema.safeParse({
      idToken: 'google-id-token',
      role: 'platform_admin',
    }).success).toBe(false);
  });
});

describe('email verification code schema', () => {
  it('accepts a six-digit numeric code including leading zeroes', () => {
    expect(
      confirmEmailVerificationSchema.safeParse({
        email: 'person@example.com',
        code: '012345',
      }).success,
    ).toBe(true);
  });

  it.each(['12345', '1234567', '12a456'])(
    'rejects invalid verification codes: %s',
    (code) => {
      expect(
        confirmEmailVerificationSchema.safeParse({
          email: 'person@example.com',
          code,
        }).success,
      ).toBe(false);
    },
  );

  it('requires a six-digit numeric code to confirm an email change', () => {
    expect(emailChangeConfirmSchema.safeParse({ token: '012345' }).success).toBe(
      true,
    );
    expect(emailChangeConfirmSchema.safeParse({ token: 'A'.repeat(43) }).success).toBe(
      false,
    );
  });
});
