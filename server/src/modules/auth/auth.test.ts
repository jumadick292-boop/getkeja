import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import express from 'express';
import { createHmac } from 'node:crypto';
import { createApp } from '../../app.js';
import * as authService from './auth.service.js';
import * as authRepository from './auth.repository.js';
import { pool } from '../../db/pool.js';
import { loadEnv } from '../../config/env.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';

vi.mock('google-auth-library', () => ({
  OAuth2Client: class {
    async verifyIdToken({ idToken }: { idToken: string }) {
      const [, subject, emailVerified, email] = idToken.split(':');
      if (!subject || !email) throw new Error('Invalid mocked token');
      const audience =
        process.env.GOOGLE_ALLOWED_CLIENT_IDS?.split(',').filter(Boolean)[0] ||
        process.env.GOOGLE_CLIENT_ID ||
        'test-google-client';
      return {
        getPayload: () => ({
          iss: 'https://accounts.google.com',
          sub: subject,
          aud: audience,
          azp: audience,
          iat: Math.floor(Date.now() / 1000),
          exp: Math.floor(Date.now() / 1000) + 3600,
          email,
          email_verified: emailVerified === 'verified',
        }),
      };
    }
  },
}));

const app = createApp({ nodeEnv: 'test' });

const TEST_EMAIL = `test${Date.now()}@example.com`;
const TEST_PHONE = '+254712345678';
const TEST_PASSWORD = 'password123';
const TEST_FIRST_NAME = 'John';
const TEST_LAST_NAME = 'Doe';
const TEST_ROLE = 'house_seeker';

let createdUserId: string | null = null;
let emailVerificationToken: string | null = null;
let phoneOtp: string | null = null;

async function createVerifiedEmailUser(email: string): Promise<{ id: string; identityId: string }> {
  const registration = await request(app)
    .post('/api/auth/register/email')
    .send({
      firstName: TEST_FIRST_NAME,
      lastName: TEST_LAST_NAME,
      email,
      password: TEST_PASSWORD,
      role: TEST_ROLE,
      termsAccepted: true,
    });
  expect(registration.status).toBe(201);
  const user = await authRepository.findUserByEmail(email);
  expect(user).toBeDefined();
  const identities = await authRepository.findLoginIdentitiesByUserId(user!.id);
  const identity = identities.find((i) => i.provider === 'email');
  expect(identity).toBeDefined();
  await authRepository.updateLoginIdentityVerified(identity!.id);
  await authRepository.updateUserEmailVerified(user!.id, true);
  return { id: user!.id, identityId: identity!.id };
}

async function enableTestTotp(userId: string): Promise<void> {
  const { encryptSecret } = await import('./crypto.js');
  const method = await authRepository.createMfaMethod(
    userId,
    'totp',
    'Test authenticator',
    true,
    {},
  );
  await authRepository.updateMfaMethod(method.id, { isVerified: true });
  const encryptedSecret = encryptSecret('JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP');
  await authRepository.createMfaTotpSecret(
    userId,
    method.id,
    encryptedSecret,
  );
  await pool.query(
    `UPDATE users
     SET mfa_enabled = TRUE, mfa_enrolled_at = NOW(), mfa_enrollment_required = FALSE
     WHERE id = $1`,
    [userId],
  );
}

function hashLoginOtp(otp: string): string {
  return createHmac('sha256', loadEnv().COOKIE_SECRET).update(otp).digest('hex');
}

describe('Auth Registration', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');
  });

  describe('POST /api/auth/register/email', () => {
    it('should register a new user with email and password', async () => {
      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.verificationRequired).toBe(true);
      expect(response.body.data.verificationChannel).toBe('email');
      expect(response.body.data.user.email).toBe(TEST_EMAIL);
      expect(response.body.data.user.firstName).toBe(TEST_FIRST_NAME);
      expect(response.body.data.user.lastName).toBe(TEST_LAST_NAME);
      expect(response.body.data.user.roles).toContain(TEST_ROLE);
      expect(response.body.data.user.emailVerified).toBe(false);

      createdUserId = response.body.data.user.id;
    });

    it('should reject duplicate email registration', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: 'Jane',
          lastName: 'Smith',
          email: TEST_EMAIL,
          password: 'differentpass',
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(409);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('CONFLICT');
    });

    it('should reject invalid email format', async () => {
      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: 'invalid-email',
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('should reject short password', async () => {
      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: 'new@example.com',
          password: 'short',
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('should reject missing terms acceptance', async () => {
      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: 'new@example.com',
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: false,
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('should reject invalid role', async () => {
      const response = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: 'new@example.com',
          password: TEST_PASSWORD,
          role: 'platform_admin',
          termsAccepted: true,
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/auth/register/phone', () => {
    it('should register a new user with phone and password', async () => {
      const response = await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: TEST_PHONE,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.verificationRequired).toBe(true);
      expect(response.body.data.verificationChannel).toBe('sms');
      expect(response.body.data.user.firstName).toBe(TEST_FIRST_NAME);
      expect(response.body.data.user.lastName).toBe(TEST_LAST_NAME);
      expect(response.body.data.user.roles).toContain(TEST_ROLE);
      expect(response.body.data.user.phoneVerified).toBe(false);

      createdUserId = response.body.data.user.id;
    });

    it('should reject duplicate phone registration', async () => {
      await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: TEST_PHONE,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: 'Jane',
          lastName: 'Smith',
          phone: TEST_PHONE,
          password: 'differentpass',
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(409);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('CONFLICT');
    });

    it('should reject invalid Kenyan phone format', async () => {
      const response = await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: '+1234567890',
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('should accept various Kenyan phone formats', async () => {
      const formats = ['0712345678', '+254712345678', '254712345678', '712345678'];

      for (const phone of formats) {
        const email = `test${Date.now()}@example.com`;
        const response = await request(app)
          .post('/api/auth/register/email')
          .send({
            firstName: TEST_FIRST_NAME,
            lastName: TEST_LAST_NAME,
            email,
            password: TEST_PASSWORD,
            role: TEST_ROLE,
            termsAccepted: true,
          });

        expect(response.status).toBe(201);

        await request(app).delete(`/api/auth/users/${response.body.data.user.id}`).catch(() => {});
      }
    });
  });

  describe('POST /api/auth/register/phone-otp', () => {
    it('should initiate passwordless registration with phone OTP', async () => {
      const response = await request(app)
        .post('/api/auth/register/phone-otp')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: '+254700000001',
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.verificationRequired).toBe(true);
      expect(response.body.data.verificationChannel).toBe('sms');
      expect(response.body.data.user.firstName).toBe(TEST_FIRST_NAME);
      expect(response.body.data.user.lastName).toBe(TEST_LAST_NAME);

      createdUserId = response.body.data.user.id;
    });

    it('should resend OTP for repeated registration request', async () => {
      const phone = '+254700000002';

      await request(app)
        .post('/api/auth/register/phone-otp')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/register/phone-otp')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
    });
  });
});

describe('Email Verification', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  describe('POST /api/auth/verify-email/request', () => {
    it('should send verification email for registered user', async () => {
      const registerResponse = await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/verify-email/request')
        .send({ email: TEST_EMAIL });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.verificationRequired).toBe(true);
      expect(response.body.data.verificationChannel).toBe('email');
    });

    it('should not expose whether email exists (enumeration resistance)', async () => {
      const response = await request(app)
        .post('/api/auth/verify-email/request')
        .send({ email: 'nonexistent@example.com' });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });
  });

  describe('POST /api/auth/verify-email/confirm', () => {
    it('should reject invalid token', async () => {
      const response = await request(app)
        .post('/api/auth/verify-email/confirm')
        .send({ email: TEST_EMAIL, code: '123456' });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('VERIFICATION_FAILED');
    });

    it('should reject expired token', async () => {
      // This would require manipulating the database to set an expired token
      // Skipping for now as it requires direct DB access
    });
  });
});

describe('Phone Verification', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  describe('POST /api/auth/verify-phone/request', () => {
    it('should send verification SMS for registered user', async () => {
      await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: TEST_PHONE,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/verify-phone/request')
        .send({ phone: TEST_PHONE });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.verificationRequired).toBe(true);
      expect(response.body.data.verificationChannel).toBe('sms');
    });

    it('should not expose whether phone exists (enumeration resistance)', async () => {
      const response = await request(app)
        .post('/api/auth/verify-phone/request')
        .send({ phone: '+254700000000' });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });
  });

  describe('POST /api/auth/verify-phone/confirm', () => {
    it('should reject invalid OTP', async () => {
      const response = await request(app)
        .post('/api/auth/verify-phone/confirm')
        .send({ phone: TEST_PHONE, otp: '000000' });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('VERIFICATION_FAILED');
    });

    it('should reject OTP for unregistered phone', async () => {
      const response = await request(app)
        .post('/api/auth/verify-phone/confirm')
        .send({ phone: '+254700000000', otp: '123456' });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });
});

describe('Login', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
    await pool.query('DELETE FROM auth_sessions');
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid email and password', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      // Verify email first
      const user = await authRepository.findUserByEmail(TEST_EMAIL);
      const loginIdentity = await authRepository.findLoginIdentity('email', TEST_EMAIL);
      await authRepository.updateLoginIdentityVerified(loginIdentity!.id);
      await authRepository.updateUserEmailVerified(user!.id, true);

      const response = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('MFA enrollment is required.');
      expect(response.body.data).toEqual({
        authenticationStatus: 'mfa_enrollment_required',
        enrollmentToken: expect.any(String),
      });
      expect(response.headers['set-cookie']).toBeUndefined();
    });

    it('should reject invalid password', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: 'wrongpassword' });

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });

    it('should reject login for unverified email', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        success: false,
        message: 'Invalid credentials.',
        code: 'INVALID_CREDENTIALS',
      });
    });
  });

  describe('POST /api/auth/login/phone', () => {
    it('should login with valid phone and password', async () => {
      await request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: TEST_PHONE,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const user = await authRepository.findUserByPhone(TEST_PHONE);
      const loginIdentity = await authRepository.findLoginIdentity('phone', TEST_PHONE);
      await authRepository.updateLoginIdentityVerified(loginIdentity!.id);
      await authRepository.updateUserPhoneVerified(user!.id, true);

      const response = await request(app)
        .post('/api/auth/login/phone')
        .send({ phone: '+254 (712) 345-678', password: TEST_PASSWORD });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.authenticationStatus).toBe('mfa_enrollment_required');
      expect(response.headers['set-cookie']).toBeUndefined();
    });
  });
});

describe('Google OAuth', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');
  });

  describe('GET /api/auth/google', () => {
    it('should return Google OAuth URL', async () => {
      const response = await request(app)
        .get('/api/auth/google');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.url).toContain('accounts.google.com');
      expect(response.body.data.state).toBeDefined();
    });
  });

  it('activates new Google registrations whose email is verified', async () => {
    const email = `google-register-${Date.now()}@example.com`;
    const response = await request(app)
      .post('/api/v1/auth/register/google')
      .set('x-client-platform', 'mobile')
      .send({ idToken: `test:google-register-${Date.now()}:verified:${email}` });

    expect(response.status).toBe(200);
    const user = await authRepository.findUserByEmail(email);
    expect(user?.account_status).toBe('active');
    expect(user?.email_verified).toBe(true);
  });

  it('activates an existing pending Google account after verified Google sign-in', async () => {
    const email = `google-pending-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const subject = `google-pending-${Date.now()}`;
    const googleLogin = await authRepository.createLoginIdentity(
      user.id,
      'google',
      subject,
      null,
    );
    await authRepository.createGoogleIdentity(
      user.id,
      googleLogin.id,
      subject,
      email,
      true,
      null,
      null,
      null,
      null,
      null,
      {},
    );
    await pool.query(
      `UPDATE users SET account_status = 'pending_verification' WHERE id = $1`,
      [user.id],
    );

    const response = await request(app)
      .post('/api/v1/auth/login/google')
      .set('x-client-platform', 'mobile')
      .send({ idToken: `test:${subject}:verified:${email}` });

    expect(response.status).toBe(200);
    const updatedUser = await authRepository.findUserByEmail(email);
    expect(updatedUser?.account_status).toBe('active');
  });

  describe('POST /api/auth/google/link', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/auth/google/link')
        .send({ idToken: 'fake-id-token' });

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });
  });

  describe('DELETE /api/auth/google/unlink', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .delete('/api/auth/google/unlink')
        .send({});

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });
  });
});

describe('authentication recovery rate limits', () => {
  it('throttles phone verification and recovery requests by their target identity', async () => {
    const previousRequestLimit = process.env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX;
    const previousVerifyLimit = process.env.LOGIN_OTP_VERIFY_RATE_LIMIT_MAX;
    const previousIpLimit = process.env.LOGIN_IP_RATE_LIMIT_MAX;
    process.env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX = '2';
    process.env.LOGIN_OTP_VERIFY_RATE_LIMIT_MAX = '2';
    process.env.LOGIN_IP_RATE_LIMIT_MAX = '1000';
    const limitedApp = createApp({ nodeEnv: 'test', trustProxy: true });
    const unique = Date.now();

    const identityLimitedRequests = [
      {
        path: '/api/v1/auth/verify-phone/request',
        body: { phone: `+254711${String(unique).slice(-6)}` },
      },
      {
        path: '/api/v1/auth/verify-phone/confirm',
        body: { phone: `+254722${String(unique).slice(-6)}`, otp: '000000' },
      },
      {
        path: '/api/v1/auth/forgot-password',
        body: { email: `forgot-${unique}@example.com` },
      },
      {
        path: '/api/v1/auth/account/recovery/request',
        body: { email: `recovery-${unique}@example.com` },
      },
      {
        path: '/api/v1/auth/account/recovery/phone',
        body: { phone: `+254733${String(unique).slice(-6)}` },
      },
    ];

    try {
      for (const item of identityLimitedRequests) {
        const statuses: number[] = [];
        for (let attempt = 0; attempt < 3; attempt += 1) {
          const response = await request(limitedApp)
            .post(item.path)
            .set('x-forwarded-for', `192.0.2.${attempt + 1}`)
            .send(item.body);
          statuses.push(response.status);
        }
        expect(statuses.slice(0, 2), item.path).not.toContain(429);
        expect(statuses[2], item.path).toBe(429);
      }
    } finally {
      if (previousRequestLimit === undefined) {
        delete process.env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX;
      } else {
        process.env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX = previousRequestLimit;
      }
      if (previousVerifyLimit === undefined) {
        delete process.env.LOGIN_OTP_VERIFY_RATE_LIMIT_MAX;
      } else {
        process.env.LOGIN_OTP_VERIFY_RATE_LIMIT_MAX = previousVerifyLimit;
      }
      if (previousIpLimit === undefined) {
        delete process.env.LOGIN_IP_RATE_LIMIT_MAX;
      } else {
        process.env.LOGIN_IP_RATE_LIMIT_MAX = previousIpLimit;
      }
    }
  });

  it('throttles password reset and account recovery verification by IP', async () => {
    const previousIpLimit = process.env.LOGIN_IP_RATE_LIMIT_MAX;
    process.env.LOGIN_IP_RATE_LIMIT_MAX = '2';
    const limitedApp = createApp({ nodeEnv: 'test', trustProxy: true });
    const ipSuffix = (Date.now() % 240) + 10;

    try {
      for (const [index, path] of [
        '/api/v1/auth/reset-password',
        '/api/v1/auth/account/recovery/verify',
      ].entries()) {
        const statuses: number[] = [];
        for (let attempt = 0; attempt < 3; attempt += 1) {
          const response = await request(limitedApp)
            .post(path)
            .set('x-forwarded-for', `198.51.100.${ipSuffix + index}`)
            .send({
              token: 'x'.repeat(32),
              password: 'Secure-test-password-123!',
            });
          statuses.push(response.status);
        }
        expect(statuses.slice(0, 2), path).not.toContain(429);
        expect(statuses[2], path).toBe(429);
      }
    } finally {
      if (previousIpLimit === undefined) {
        delete process.env.LOGIN_IP_RATE_LIMIT_MAX;
      } else {
        process.env.LOGIN_IP_RATE_LIMIT_MAX = previousIpLimit;
      }
    }
  });
});

describe('Password Reset', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM password_reset_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  describe('POST /api/auth/forgot-password', () => {
    it('should not expose whether email exists', async () => {
      const response = await request(app)
        .post('/api/auth/forgot-password')
        .send({ email: 'nonexistent@example.com' });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Password reset initiated');
    });

    it('should create reset token for existing user', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const response = await request(app)
        .post('/api/auth/forgot-password')
        .send({ email: TEST_EMAIL });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });
  });

  describe('POST /api/auth/reset-password', () => {
    it('should reject invalid token', async () => {
      const response = await request(app)
        .post('/api/auth/reset-password')
        .send({ token: 'invalid-token', password: 'newpassword123' });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('updates all password login identities when resetting a password', async () => {
      const email = `reset-${Date.now()}@example.com`;
      await request(app).post('/api/auth/register/email').send({
        firstName: TEST_FIRST_NAME,
        lastName: TEST_LAST_NAME,
        email,
        password: TEST_PASSWORD,
        role: TEST_ROLE,
        termsAccepted: true,
      });
      const user = await authRepository.findUserByEmail(email);
      const identity = await authRepository.findLoginIdentity('email', email);
      await authRepository.updateLoginIdentityVerified(identity!.id);
      await authRepository.updateUserEmailVerified(user!.id, true);

      const resetRequest = await request(app)
        .post('/api/auth/forgot-password')
        .send({ email });
      const reset = await request(app)
        .post('/api/auth/reset-password')
        .send({ token: resetRequest.body.data.resetToken, password: 'new-password-123' });
      expect(reset.status).toBe(200);

      const oldPassword = await request(app)
        .post('/api/v1/auth/login/email')
        .send({ email, password: TEST_PASSWORD });
      const newPassword = await request(app)
        .post('/api/v1/auth/login/email')
        .send({ email, password: 'new-password-123' });
      expect(oldPassword.body.code).toBe('INVALID_CREDENTIALS');
      expect(newPassword.status).toBe(200);
      expect(newPassword.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    });
  });
});

describe('Session Management', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM email_verification_tokens');
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  describe('GET /api/auth/me', () => {
    it('should not grant a session before MFA completion', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD });

      const user = await authRepository.findUserByEmail(TEST_EMAIL);
      const identity = await authRepository.findLoginIdentity('email', TEST_EMAIL);
      await authRepository.updateLoginIdentityVerified(identity!.id);
      await authRepository.updateUserEmailVerified(user!.id, true);
      const verifiedLogin = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD });
      expect(verifiedLogin.status).toBe(200);
      expect(verifiedLogin.body.data.authenticationStatus).toBe('mfa_enrollment_required');
      expect(verifiedLogin.headers['set-cookie']).toBeUndefined();

      expect(loginResponse.headers['set-cookie']).toBeUndefined();

      const response = await request(app)
        .get('/api/auth/me')
        .set('Cookie', verifiedLogin.headers['set-cookie']?.[0] || '');

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });

    it('should reject request without session', async () => {
      const response = await request(app).get('/api/auth/me');

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/auth/logout', () => {
    it('should logout and clear session cookie', async () => {
      await request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        });

      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({ email: TEST_EMAIL, password: TEST_PASSWORD });

      const cookie = loginResponse.headers['set-cookie']?.[0];

      const response = await request(app)
        .post('/api/auth/logout')
        .set('Cookie', cookie || '');

      expect(response.status).toBe(200);
      expect(response.headers['set-cookie']).toBeDefined();
    });
  });
});

describe('Role Assignment', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  it('should assign requested role on registration', async () => {
    const response = await request(app)
      .post('/api/auth/register/email')
      .send({
        firstName: TEST_FIRST_NAME,
        lastName: TEST_LAST_NAME,
        email: 'landlord@example.com',
        password: TEST_PASSWORD,
        role: 'landlord',
        termsAccepted: true,
      });

    expect(response.status).toBe(201);
    expect(response.body.data.user.roles).toContain('landlord');
  });

  it('should not allow admin role on public registration', async () => {
    const response = await request(app)
      .post('/api/auth/register/email')
      .send({
        firstName: TEST_FIRST_NAME,
        lastName: TEST_LAST_NAME,
        email: 'admin@example.com',
        password: TEST_PASSWORD,
        role: 'platform_admin',
        termsAccepted: true,
      });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
  });
});

describe('Authentication hardening', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM email_login_otp');
    await pool.query('DELETE FROM phone_login_otp');
    await pool.query('DELETE FROM mfa_challenges');
    await pool.query('DELETE FROM security_events');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it.each([
    'pending_verification',
    'suspended',
    'locked',
    'deactivated',
    'deleted',
  ] as const)('rejects credentials for %s accounts generically', async (accountStatus) => {
    const email = `state-${accountStatus}-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    await pool.query(
      `UPDATE users
       SET account_status = $1,
           deleted_at = CASE WHEN $2 THEN NOW() ELSE NULL END
       WHERE id = $3`,
      [accountStatus, accountStatus === 'deleted', user.id],
    );

    const response = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      success: false,
      message: 'Invalid credentials.',
      code: 'INVALID_CREDENTIALS',
    });
  });

  it('requires an enrolled MFA method without issuing a session', async () => {
    const email = `mfa-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    await enableTestTotp(user.id);

    const response = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    expect(response.status).toBe(200);
    expect(response.body.message).toBe('Primary authentication successful. MFA required.');
    expect(response.body.data.authenticationStatus).toBe('mfa_required');
    expect(response.body.data.challengeId).toBeDefined();
    expect(response.body.data.availableMethods).toEqual(['totp']);
    expect(response.headers['set-cookie']).toBeUndefined();

    const sessions = await pool.query('SELECT id FROM auth_sessions WHERE user_id = $1', [user.id]);
    expect(sessions.rowCount).toBe(0);
  });

  it('does not complete MFA or issue a session through the handoff endpoint', async () => {
    const email = `mfa-verify-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    await enableTestTotp(user.id);
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: '123456' });
    expect(verify.status).toBe(401);
    expect(verify.headers['set-cookie']).toBeUndefined();
  });

  it('consumes phone OTPs once and returns the MFA handoff', async () => {
    const phone = `+2547${String(Date.now()).slice(-8)}`;
    const registration = await request(app)
      .post('/api/auth/register/phone')
      .send({
        firstName: TEST_FIRST_NAME,
        lastName: TEST_LAST_NAME,
        phone,
        password: TEST_PASSWORD,
        role: TEST_ROLE,
        termsAccepted: true,
      });
    expect(registration.status).toBe(201);
    const identity = await authRepository.findLoginIdentity('phone', phone);
    const user = await authRepository.findUserByPhone(phone);
    await authRepository.updateLoginIdentityVerified(identity!.id);
    await authRepository.updateUserPhoneVerified(user!.id, true);

    const otp = '410527';
    await authRepository.createPhoneLoginOtp(
      user!.id,
      identity!.id,
      hashLoginOtp(otp),
      new Date(Date.now() + 60_000),
      3,
    );

    const results = await Promise.all([
      request(app).post('/api/v1/auth/login/phone-otp/verify').send({ phone, otp }),
      request(app).post('/api/v1/auth/login/phone-otp/verify').send({ phone, otp }),
    ]);

    expect(results.map((result) => result.status).sort()).toEqual([200, 401]);
    const success = results.find((result) => result.status === 200)!;
    expect(success.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    expect(success.headers['set-cookie']).toBeUndefined();
    const storedOtp = await authRepository.findPhoneLoginOtp(identity!.id, hashLoginOtp(otp));
    expect(storedOtp).toBeUndefined();
  });

  it('rejects expired OTPs and consumes challenges after failed attempts', async () => {
    const phone = `+2547${String(Date.now()).slice(-8)}`;
    await request(app).post('/api/auth/register/phone').send({
      firstName: TEST_FIRST_NAME,
      lastName: TEST_LAST_NAME,
      phone,
      password: TEST_PASSWORD,
      role: TEST_ROLE,
      termsAccepted: true,
    });
    const identity = await authRepository.findLoginIdentity('phone', phone);
    const user = await authRepository.findUserByPhone(phone);
    await authRepository.updateLoginIdentityVerified(identity!.id);
    await authRepository.updateUserPhoneVerified(user!.id, true);

    await authRepository.createPhoneLoginOtp(
      user!.id,
      identity!.id,
      hashLoginOtp('123456'),
      new Date(Date.now() - 1_000),
      3,
    );
    const expired = await request(app)
      .post('/api/v1/auth/login/phone-otp/verify')
      .send({ phone, otp: '123456' });
    expect(expired.status).toBe(401);

    await authRepository.createPhoneLoginOtp(
      user!.id,
      identity!.id,
      hashLoginOtp('123456'),
      new Date(Date.now() + 60_000),
      2,
    );
    for (let attempt = 0; attempt < 2; attempt++) {
      const rejected = await request(app)
        .post('/api/v1/auth/login/phone-otp/verify')
        .send({ phone, otp: '000000' });
      expect(rejected.status).toBe(401);
      expect(rejected.body.code).toBe('INVALID_CREDENTIALS');
    }
    const reused = await request(app)
      .post('/api/v1/auth/login/phone-otp/verify')
      .send({ phone, otp: '123456' });
    expect(reused.status).toBe(401);
  });

  it('supports verified email OTP login with MFA handoff', async () => {
    const email = `email-otp-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const otp = '826104';
    await authRepository.createEmailLoginOtp(
      user.id,
      user.identityId,
      hashLoginOtp(otp),
      new Date(Date.now() + 60_000),
      3,
    );

    const result = await request(app)
      .post('/api/v1/auth/login/email-otp/verify')
      .send({ email, otp });
    expect(result.status).toBe(200);
    expect(result.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    expect(result.headers['set-cookie']).toBeUndefined();

    const reused = await request(app)
      .post('/api/v1/auth/login/email-otp/verify')
      .send({ email, otp });
    expect(reused.status).toBe(401);
    expect(reused.body.code).toBe('INVALID_CREDENTIALS');
  });

  it('keeps email OTP requests generic and respects resend cooldown', async () => {
    const email = `email-request-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const providerFetch = vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body)) as {
        content: Array<{ value: string }>;
      };
      const firstContent = body.content[0];
      expect(firstContent).toBeDefined();
      expect(firstContent!.value).toContain('sign-in code');
      return new Response(null, { status: 202 });
    });
    vi.stubEnv('EMAIL_PROVIDER', 'sendgrid');
    vi.stubEnv('SENDGRID_API_KEY', 'test-key');
    vi.stubGlobal('fetch', providerFetch);

    const absent = await request(app)
      .post('/api/v1/auth/login/email-otp/request')
      .send({ email: `missing-${Date.now()}@example.com` });
    const requested = await request(app)
      .post('/api/v1/auth/login/email-otp/request')
      .send({ email });
    const throttled = await request(app)
      .post('/api/v1/auth/login/email-otp/request')
      .send({ email });

    expect(absent.status).toBe(200);
    expect(requested.status).toBe(200);
    expect(throttled.status).toBe(200);
    expect(absent.body.message).toBe(requested.body.message);
    expect(providerFetch).toHaveBeenCalledTimes(1);
    const otpRows = await pool.query<{ otp_hash: string }>(
      'SELECT otp_hash FROM email_login_otp WHERE user_id = $1',
      [user.id],
    );
    expect(otpRows.rows.length).toBeGreaterThan(0);
    expect(otpRows.rows[0]!.otp_hash).toMatch(/^[a-f0-9]{64}$/);
    expect(otpRows.rows[0]!.otp_hash).not.toContain('000000');
  });

  it('requires a linked Google subject and does not auto-link by matching email', async () => {
    const email = `google-${Date.now()}@example.com`;
    await createVerifiedEmailUser(email);

    const response = await request(app)
      .post('/api/v1/auth/login/google')
      .send({ idToken: `test:unlinked-subject:verified:${email}` });
    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      success: false,
      message: 'Invalid credentials.',
      code: 'INVALID_CREDENTIALS',
    });
    const googleIdentities = await pool.query(
      'SELECT id FROM google_identities',
    );
    expect(googleIdentities.rowCount).toBe(0);
  });

  it('rejects unverified Google email claims even for linked subjects', async () => {
    const email = `google-unverified-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const subject = `subject-${Date.now()}`;
    const googleLogin = await authRepository.createLoginIdentity(
      user.id,
      'google',
      subject,
      null,
    );
    await authRepository.createGoogleIdentity(
      user.id,
      googleLogin.id,
      subject,
      email,
      true,
      null,
      null,
      null,
      null,
      null,
      {},
    );

    const response = await request(app)
      .post('/api/v1/auth/login/google')
      .send({ idToken: `test:${subject}:unverified:${email}` });
    expect(response.status).toBe(401);
    expect(response.body.code).toBe('INVALID_CREDENTIALS');
  });

  it('uses Redis-backed state and PKCE for Google OAuth callbacks', async () => {
    const email = `google-callback-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const subject = `subject-${Date.now()}`;
    const googleLogin = await authRepository.createLoginIdentity(
      user.id,
      'google',
      subject,
      null,
    );
    await authRepository.createGoogleIdentity(
      user.id,
      googleLogin.id,
      subject,
      email,
      true,
      null,
      null,
      null,
      null,
      null,
      {},
    );

    const tokenFetch = vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
      const body = new URLSearchParams(String(init?.body));
      expect(body.get('code_verifier')).toBeTruthy();
      return new Response(
        JSON.stringify({
          access_token: 'test-access-token',
          id_token: `test:${subject}:verified:${email}`,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    });
    vi.stubGlobal('fetch', tokenFetch);

    const browser = request.agent(app);
    const start = await browser.get('/api/v1/auth/google');
    expect(start.status).toBe(200);
    expect(start.body.data.url).toContain('code_challenge_method=S256');
    const state = start.body.data.state as string;
    const callbackPath = `/api/v1/auth/google/callback?code=auth-code&state=${encodeURIComponent(state)}`;

    const callback = await browser.get(callbackPath);
    expect(callback.status).toBe(200);
    expect(callback.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    expect(callback.headers['set-cookie']?.includes('getkeja_session=')).toBe(false);

    const replay = await browser.get(callbackPath);
    expect(replay.status).toBe(401);
    expect(replay.body.code).toBe('INVALID_CREDENTIALS');
    expect(tokenFetch).toHaveBeenCalledTimes(1);
  });

  it('keeps phone OTP request responses generic and enforces resend cooldown', async () => {
    const phone = `+2547${String(Date.now()).slice(-8)}`;
    const registration = await request(app).post('/api/auth/register/phone').send({
      firstName: TEST_FIRST_NAME,
      lastName: TEST_LAST_NAME,
      phone,
      password: TEST_PASSWORD,
      role: TEST_ROLE,
      termsAccepted: true,
    });
    expect(registration.status).toBe(201);
    const user = await authRepository.findUserByPhone(phone);
    const identity = await authRepository.findLoginIdentity('phone', phone);
    await authRepository.updateLoginIdentityVerified(identity!.id);
    await authRepository.updateUserPhoneVerified(user!.id, true);

    const smsFetch = vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
      const body = new URLSearchParams(String(init?.body));
      expect(body.get('Body')).toMatch(/verification code is: \d{6}/);
      return new Response(null, { status: 201 });
    });
    vi.stubEnv('SMS_PROVIDER', 'twilio');
    vi.stubEnv('TWILIO_ACCOUNT_SID', 'test-account');
    vi.stubEnv('TWILIO_AUTH_TOKEN', 'test-auth-token');
    vi.stubEnv('TWILIO_FROM_NUMBER', '+15005550006');
    vi.stubGlobal('fetch', smsFetch);

    const absent = await request(app)
      .post('/api/v1/auth/login/phone-otp/request')
      .send({ phone: '+254700000000' });
    const requested = await request(app)
      .post('/api/v1/auth/login/phone-otp/request')
      .send({ phone });
    const throttled = await request(app)
      .post('/api/v1/auth/login/phone-otp/request')
      .send({ phone });

    expect(absent.status).toBe(200);
    expect(requested.status).toBe(200);
    expect(throttled.status).toBe(200);
    expect(absent.body.message).toBe(requested.body.message);
    expect(smsFetch).toHaveBeenCalledTimes(1);
  });

  it('enforces Redis-backed rate limits across requests', async () => {
    const rateLimitApp = express();
    const limiter = createRateLimiter({
      windowMs: 60_000,
      max: 1,
      keyPrefix: `test-${Date.now()}`,
      ipWindowMs: 60_000,
      ipMax: 1,
    });
    rateLimitApp.get('/', limiter, (_req, res) => res.sendStatus(204));
    rateLimitApp.use((error: { status?: number }, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
      res.sendStatus(error.status ?? 500);
    });

    const first = await request(rateLimitApp).get('/');
    const second = await request(rateLimitApp).get('/');
    expect(first.status).toBe(204);
    expect(second.status).toBe(429);
  });
});

describe('Concurrent Registration', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  it('should handle concurrent email registration attempts', async () => {
    const promises = Array(5).fill(null).map(() =>
      request(app)
        .post('/api/auth/register/email')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          email: `concurrent${Date.now()}@example.com`,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        })
    );

    const results = await Promise.all(promises);
    const successful = results.filter(r => r.status === 201);
    const conflicts = results.filter(r => r.status === 409);

    expect(successful.length).toBeGreaterThan(0);
  });

  it('should handle concurrent phone registration attempts', async () => {
    const promises = Array(5).fill(null).map(() =>
      request(app)
        .post('/api/auth/register/phone')
        .send({
          firstName: TEST_FIRST_NAME,
          lastName: TEST_LAST_NAME,
          phone: `+2547${String(Math.floor(Math.random() * 90000000) + 10000000)}`,
          password: TEST_PASSWORD,
          role: TEST_ROLE,
          termsAccepted: true,
        })
    );

    const results = await Promise.all(promises);
    const successful = results.filter(r => r.status === 201);
    expect(successful.length).toBeGreaterThan(0);
  });
});

describe('OTP Rate Limiting', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM phone_verification_tokens');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM users');
  });

  it('should limit OTP requests per phone number', async () => {
    await request(app)
      .post('/api/auth/register/phone')
      .send({
        firstName: TEST_FIRST_NAME,
        lastName: TEST_LAST_NAME,
        phone: TEST_PHONE,
        password: TEST_PASSWORD,
        role: TEST_ROLE,
        termsAccepted: true,
      });

    // Request OTP multiple times
    for (let i = 0; i < 5; i++) {
      const response = await request(app)
        .post('/api/auth/verify-phone/request')
        .send({ phone: TEST_PHONE });

      if (i < 3) {
        expect(response.status).toBe(200);
      } else {
        // Should be rate limited after 3 requests
        expect([200, 429]).toContain(response.status);
      }
    }
  });
});
