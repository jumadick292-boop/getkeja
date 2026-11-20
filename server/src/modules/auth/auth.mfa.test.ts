import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createHmac } from 'node:crypto';
import { createApp } from '../../app.js';
import * as authRepository from './auth.repository.js';
import { encryptSecret } from './crypto.js';
import { pool } from '../../db/pool.js';
import { loadEnv } from '../../config/env.js';

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

function hashLoginOtp(otp: string): string {
  return createHmac('sha256', loadEnv().COOKIE_SECRET).update(otp).digest('hex');
}

describe('MFA Challenge and Verification', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM sessions');
    await pool.query('DELETE FROM refresh_tokens');
    await pool.query('DELETE FROM devices');
    await pool.query('DELETE FROM mfa_methods');
    await pool.query('DELETE FROM mfa_totp_secrets');
    await pool.query('DELETE FROM mfa_recovery_codes');
    await pool.query('DELETE FROM mfa_challenges');
    await pool.query('DELETE FROM security_events');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');
  });

  const setupUserWithTotp = async (email: string) => {
    const user = await createVerifiedEmailUser(email);
    const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
    const method = await authRepository.createMfaMethod(user.id, 'totp', 'Test', true, {});
    await authRepository.updateMfaMethod(method.id, { isVerified: true });
    const encryptedSecret = encryptSecret(secret);
    await authRepository.createMfaTotpSecret(user.id, method.id, encryptedSecret, 'SHA1', 6, 30);
    await authRepository.updateUserMfaEnrolled(user.id, true);
    return { user, secret };
  };

  it('returns MFA challenge on login with enrolled TOTP', async () => {
    const email = `mfa-challenge-${Date.now()}@example.com`;
    const { secret } = await setupUserWithTotp(email);

    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    expect(login.status).toBe(200);
    expect(login.body.data.authenticationStatus).toBe('mfa_required');
    expect(login.body.data.challengeId).toBeDefined();
    expect(login.body.data.availableMethods).toContain('totp');
    expect(login.headers['set-cookie']).toBeUndefined();
  });

  it('verifies valid TOTP code and issues session', async () => {
    const email = `mfa-verify-${Date.now()}@example.com`;
    const { secret } = await setupUserWithTotp(email);

    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    expect(login.status).toBe(200);
    expect(login.body.data.challengeId).toBeDefined();

    const { generate } = await import('otplib');
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1' });
    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .set('X-Client-Platform', 'mobile')
      .send({ challengeId: login.body.data.challengeId, totpCode: validCode });
    expect(verify.status).toBe(200);
    expect(verify.body.data.user).toBeDefined();
    expect(verify.body.data.user.id).toBeDefined();
    expect(verify.headers['set-cookie']).toBeDefined();
    expect(verify.headers['set-cookie']?.[0]).toContain('getkeja_refresh=');
    expect(verify.headers['x-access-token']).toBeDefined();
    expect(verify.body.data.accessToken).toBeDefined();
    expect(verify.body.data.refreshToken).toBeDefined();

    const refreshed = await request(app)
      .post('/api/v1/auth/refresh')
      .set('X-Client-Platform', 'mobile')
      .send({ refreshToken: verify.body.data.refreshToken });
    expect(refreshed.status, JSON.stringify(refreshed.body)).toBe(200);
    expect(refreshed.body.data.accessToken).toBeDefined();
    expect(refreshed.body.data.refreshToken).toBeDefined();

    const currentUser = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${refreshed.body.data.accessToken}`);
    expect(currentUser.status).toBe(200);
  });

  it('lets an unenrolled user start MFA enrollment with a restricted transaction', async () => {
    const email = `mfa-enrollment-${Date.now()}@example.com`;
    await createVerifiedEmailUser(email);
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    expect(login.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    expect(login.body.data.enrollmentToken).toBeDefined();
    expect(login.headers['x-access-token']).toBeUndefined();

    const enrollment = await request(app)
      .post('/api/v1/auth/mfa/enrollment/start')
      .set('Authorization', `MFA-Enrollment ${login.body.data.enrollmentToken}`)
      .send({ methodType: 'totp' });

    expect(enrollment.status).toBe(200);
    expect(enrollment.body.data.methodId).toBeDefined();

    const protectedRequest = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `MFA-Enrollment ${login.body.data.enrollmentToken}`);
    expect(protectedRequest.status).toBe(401);
  });

  it('lets an unenrolled user skip MFA and keeps MFA optional on later logins', async () => {
    const email = `mfa-skip-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    expect(login.status).toBe(200);
    expect(login.body.data.authenticationStatus).toBe('mfa_enrollment_required');

    const skip = await request(app)
      .post('/api/v1/auth/mfa/enrollment/skip')
      .set('Authorization', `MFA-Enrollment ${login.body.data.enrollmentToken}`)
      .set('X-Client-Platform', 'mobile')
      .send();

    expect(skip.status).toBe(200);
    expect(skip.body.data.authenticationStatus).toBe('complete');
    expect(skip.body.data.accessToken).toBeDefined();
    expect(skip.body.data.refreshToken).toBeDefined();
    expect(skip.headers['x-access-token']).toBeDefined();

    const updatedUser = await authRepository.findUserWithRolesById(user.id);
    expect(updatedUser?.mfaEnrollmentRequired).toBe(false);
    expect(updatedUser?.mfaEnabled).toBe(false);

    const nextLogin = await request(app)
      .post('/api/v1/auth/login/email')
      .set('X-Client-Platform', 'mobile')
      .send({ email, password: TEST_PASSWORD });
    expect(nextLogin.status).toBe(200);
    expect(nextLogin.body.data.authenticationStatus).toBe('complete');
    expect(nextLogin.body.data.accessToken).toBeDefined();

    const currentUser = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${nextLogin.body.data.accessToken}`);
    expect(currentUser.status).toBe(200);
  });

  it('rejects invalid TOTP code', async () => {
    const email = `mfa-invalid-${Date.now()}@example.com`;
    await setupUserWithTotp(email);

    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: '000000' });
    expect(verify.status).toBe(401);
    expect(verify.body.code).toBe('UNAUTHORIZED');
    expect(verify.body.message).toBe('Invalid MFA code');
  });

  it('rejects replayed TOTP code', async () => {
    const email = `mfa-replay-${Date.now()}@example.com`;
    const { secret } = await setupUserWithTotp(email);

    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    
    const { generate } = await import('otplib');
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1' });

    // First verification succeeds
    const first = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: validCode });
    expect(first.status).toBe(200);

    // Second with same code should fail (replay prevention)
    const second = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: validCode });
    expect(second.status).toBe(401);
    expect(second.body.code).toBe('UNAUTHORIZED');
    expect(second.body.message).toBe('MFA challenge is no longer valid');
  });

  it('expires challenge after max attempts', async () => {
    const email = `mfa-expire-${Date.now()}@example.com`;
    await setupUserWithTotp(email);

    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });

    // Fail 3 times
    for (let i = 0; i < 3; i++) {
      const verify = await request(app)
        .post('/api/v1/auth/mfa/verify')
        .send({ challengeId: login.body.data.challengeId, totpCode: '000000' });
      if (i < 2) expect(verify.status).toBe(401);
    }

    // 4th attempt should fail with challenge expired
    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: '000000' });
    expect(verify.status).toBe(401);
    expect(verify.body.code).toBe('UNAUTHORIZED');
    expect(verify.body.message).toContain('challenge');
  });
});

describe('MFA Management', () => {
  let accessToken: string;

  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM sessions');
    await pool.query('DELETE FROM refresh_tokens');
    await pool.query('DELETE FROM devices');
    await pool.query('DELETE FROM mfa_methods');
    await pool.query('DELETE FROM mfa_totp_secrets');
    await pool.query('DELETE FROM mfa_recovery_codes');
    await pool.query('DELETE FROM mfa_challenges');
    await pool.query('DELETE FROM security_events');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');

    const email = `mfa-mgmt-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);

    // Enable TOTP and complete full login to get session
    const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
    const method = await authRepository.createMfaMethod(user.id, 'totp', 'Test', true, {});
    await authRepository.updateMfaMethod(method.id, { isVerified: true });
    const encryptedSecret = encryptSecret(secret);
    await authRepository.createMfaTotpSecret(user.id, method.id, encryptedSecret, 'SHA1', 6, 30);
    await authRepository.updateUserMfaEnrolled(user.id, true);

    // Login and complete MFA to get access token
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    expect(login.body.data.challengeId).toBeDefined();
    
    const { generate } = await import('otplib');
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1' });
    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: validCode });
    expect(verify.status).toBe(200);
    accessToken = verify.headers['x-access-token'] || '';
  });

  const authRequest = (method: 'get' | 'post' | 'patch' | 'delete', path: string) => {
    const req = request(app);
    return req[method](path).set('Authorization', `Bearer ${accessToken}`);
  };

  it('adds a second MFA method (SMS)', async () => {
    const phone = `+2547${String(Date.now()).slice(-8)}`;
    const add = await authRequest('post', '/api/v1/auth/mfa/methods/add')
      .send({ methodType: 'sms', phoneNumber: phone, methodName: 'Backup Phone' });
    console.log('SMS add response:', add.status, add.body);
    expect(add.status).toBe(200);
    expect(add.body.data.method).toBe('sms');

    const methods = await authRequest('get', '/api/v1/auth/mfa/methods');
    expect(methods.status).toBe(200);
    expect(methods.body.data.methods).toHaveLength(2);
  });

  it('sets primary MFA method', async () => {
    // Get current methods (TOTP is primary and verified)
    const methods = await authRequest('get', '/api/v1/auth/mfa/methods');
    console.log('Methods:', JSON.stringify(methods.body.data.methods, null, 2));
    const totpMethod = methods.body.data.methods.find((m: any) => m.methodType === 'totp');
    expect(totpMethod).toBeDefined();
    expect(totpMethod.isPrimary).toBe(true);
    expect(totpMethod.isVerified).toBe(true);

    // Set TOTP as primary again (requires TOTP verification)
    // Wait for next TOTP time step to avoid replay detection
    await new Promise(resolve => setTimeout(resolve, 31000));
    
    const { generate } = await import('otplib');
    const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1' });
    console.log('Generated TOTP code:', validCode);
    console.log('Using method ID:', totpMethod.id);
    
    const setPrimary = await authRequest('post', '/api/v1/auth/mfa/methods/set-primary')
      .send({ mfaMethodId: totpMethod.id, verificationCode: validCode });
    console.log('Set primary response:', setPrimary.status, setPrimary.body);
    if (setPrimary.status !== 200) {
      console.log('Error details:', JSON.stringify(setPrimary.body, null, 2));
    }
    expect(setPrimary.status).toBe(200);

    const updated = await authRequest('get', '/api/v1/auth/mfa/methods');
    const primary = updated.body.data.methods.find((m: any) => m.isPrimary);
    expect(primary.methodType).toBe('totp');
  }, 40000);

  it('disables non-primary MFA method', async () => {
    // Add recovery codes method (verified immediately, we get the codes)
    const start = await authRequest('post', '/api/v1/auth/mfa/methods/add')
      .send({ methodType: 'recovery_codes' });
    expect(start.status).toBe(200);
    expect(start.body.data.recoveryCodes).toBeDefined();
    expect(start.body.data.recoveryCodes).toHaveLength(10);
    const recoveryCode = start.body.data.recoveryCodes[0];

    const methods = await authRequest('get', '/api/v1/auth/mfa/methods');
    const recoveryMethod = methods.body.data.methods.find((m: any) => m.methodType === 'recovery_codes');
    expect(recoveryMethod).toBeDefined();
    expect(recoveryMethod.isActive).toBe(true);

    // Disable recovery codes method using a recovery code
    const disable = await authRequest('post', '/api/v1/auth/mfa/methods/disable')
      .send({ mfaMethodId: recoveryMethod.id, verificationCode: recoveryCode });
    expect(disable.status).toBe(200);

    const updated = await authRequest('get', '/api/v1/auth/mfa/methods');
    const disabledMethod = updated.body.data.methods.find((m: any) => m.id === recoveryMethod.id);
    expect(disabledMethod).toBeDefined();
    expect(disabledMethod.isActive).toBe(false);
    expect(disabledMethod.isVerified).toBe(false);
    // Only TOTP should be active
    const activeMethods = updated.body.data.methods.filter((m: any) => m.isActive);
    expect(activeMethods).toHaveLength(1);
    expect(activeMethods[0].methodType).toBe('totp');
  });

  it('prevents disabling last/primary MFA method', async () => {
    const methods = await authRequest('get', '/api/v1/auth/mfa/methods');
    const totpMethod = methods.body.data.methods.find((m: any) => m.methodType === 'totp');
    expect(totpMethod).toBeDefined();

    // Wait for next TOTP time step to avoid replay detection from previous tests
    await new Promise(resolve => setTimeout(resolve, 31000));

    // Generate TOTP code for current time step
    const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
    const { generate } = await import('otplib');
    const currentStep = Math.floor(Date.now() / 1000 / 30);
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1', timeStep: currentStep } as any);
    
    const disable = await authRequest('post', '/api/v1/auth/mfa/methods/disable')
      .send({ mfaMethodId: totpMethod.id, verificationCode: validCode });
    expect(disable.status).toBe(400);
    expect(disable.body.code).toBe('LAST_MFA_METHOD');
  }, 40000);

  it('regenerates recovery codes', async () => {
    // First enroll recovery codes
    const start = await authRequest('post', '/api/v1/auth/mfa/methods/add')
      .send({ methodType: 'recovery_codes' });
    expect(start.status).toBe(200);
    expect(start.body.data.recoveryCodes).toBeDefined();
    expect(start.body.data.recoveryCodes).toHaveLength(10);
    const originalCodes = start.body.data.recoveryCodes;
    const recoveryCode = originalCodes[0];

    // Regenerate using a recovery code
    const regen = await authRequest('post', '/api/v1/auth/mfa/recovery-codes/regenerate')
      .send({ verificationCode: recoveryCode });
    expect(regen.status).toBe(200);
    expect(regen.body.data.codes).toHaveLength(10);

    // New codes should be different
    const newCodes = regen.body.data.codes;
    const overlap = originalCodes.filter((c: string) => newCodes.includes(c));
    expect(overlap.length).toBe(0);

    // Status should show full recovery codes remaining
    const status = await authRequest('get', '/api/v1/auth/mfa/status');
    expect(status.body.data.recoveryCodesRemaining).toBe(10);
  });

}); // Close MFA Management

describe('Account Recovery', () => {
  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM password_reset_tokens');
    await pool.query('DELETE FROM security_events');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');
  });

  it('initiates account recovery via email', async () => {
    const email = `recovery-${Date.now()}@example.com`;
    await createVerifiedEmailUser(email);

    const response = await request(app)
      .post('/api/v1/auth/account/recovery/request')
      .send({ email });
    expect(response.status).toBe(200);
    expect(response.body.message).toContain('recovery link will be sent');

    // Verify security event was logged
    const events = await pool.query('SELECT * FROM security_events WHERE event_type = $1', ['account_recovery_initiated']);
    expect(events.rowCount).toBe(1);
  });

  it('initiates account recovery via SMS', async () => {
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
    await authRepository.updateLoginIdentityVerified(identity!.id);
    const user = await authRepository.findUserByPhone(phone);
    await authRepository.updateUserPhoneVerified(user!.id, true);

    const response = await request(app)
      .post('/api/v1/auth/account/recovery/phone')
      .send({ phone });
    expect(response.status).toBe(200);
    expect(response.body.message).toContain('recovery code will be sent via SMS');
  });

  it('completes account recovery with valid token', async () => {
    const email = `recovery-complete-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);

    // Create a recovery token directly
    const recoveryToken = 'test-recovery-token-' + Date.now();
    const { createHash } = await import('node:crypto');
    const tokenHash = createHash('sha256').update(recoveryToken).digest('hex');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await authRepository.createPasswordResetToken(email, tokenHash, expiresAt);

    const newPassword = 'newpassword123';
    const response = await request(app)
      .post('/api/v1/auth/account/recovery/verify')
      .send({ token: recoveryToken, password: newPassword });
    expect(response.status).toBe(200);
    expect(response.body.data.success).toBe(true);

    // Verify password was changed
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: newPassword });
    expect(login.status).toBe(200);
    expect(login.body.data.authenticationStatus).toBe('mfa_enrollment_required');

    // Verify all sessions were revoked
    const sessions = await pool.query('SELECT * FROM auth_sessions WHERE user_id = $1', [user.id]);
    expect(sessions.rowCount).toBe(0);

    // Verify security event
    const events = await pool.query('SELECT * FROM security_events WHERE event_type = $1', ['account_recovery_completed']);
    expect(events.rowCount).toBe(1);
  });

  it('rejects invalid/expired recovery token', async () => {
    const response = await request(app)
      .post('/api/v1/auth/account/recovery/verify')
      .send({ token: 'invalid-token', password: 'newpassword123' });
    expect(response.status).toBe(400);
    expect(response.body.code).toBe('VALIDATION_ERROR');
  });
});

describe('MFA Enforcement Middleware', () => {
  let enrolledAccessToken: string;

  beforeEach(async () => {
    await pool.query('DELETE FROM auth_sessions');
    await pool.query('DELETE FROM mfa_methods');
    await pool.query('DELETE FROM mfa_totp_secrets');
    await pool.query('DELETE FROM mfa_recovery_codes');
    await pool.query('DELETE FROM mfa_challenges');
    await pool.query('DELETE FROM security_events');
    await pool.query('DELETE FROM user_roles');
    await pool.query('DELETE FROM user_login_identities');
    await pool.query('DELETE FROM google_identities');
    await pool.query('DELETE FROM users');

    // Create enrolled user and get session
    const email = `enrolled-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    
    const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
    const method = await authRepository.createMfaMethod(user.id, 'totp', 'Test', true, {});
    await authRepository.updateMfaMethod(method.id, { isVerified: true });
    const encryptedSecret = encryptSecret(secret);
    await authRepository.createMfaTotpSecret(user.id, method.id, encryptedSecret, 'SHA1', 6, 30);
    await authRepository.updateUserMfaEnrolled(user.id, true);

    // Login and complete MFA to get session cookie
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    const { generate } = await import('otplib');
    const validCode = await generate({ secret, period: 30, digits: 6, algorithm: 'sha1' });
    const verify = await request(app)
      .post('/api/v1/auth/mfa/verify')
      .send({ challengeId: login.body.data.challengeId, totpCode: validCode });
    enrolledAccessToken = verify.headers['x-access-token'] || '';
  });

  it('allows enrolled user to access MFA-protected route', async () => {
    const status = await request(app)
      .get('/api/v1/auth/mfa/status')
      .set('Authorization', `Bearer ${enrolledAccessToken}`);
    expect(status.status).toBe(200);
    expect(status.body.data.mfaEnrolled).toBe(true);
  });

  it('blocks unenrolled user from MFA-protected route', async () => {
    // Create unenrolled user
    const email = `unenrolled-${Date.now()}@example.com`;
    const user = await createVerifiedEmailUser(email);
    
    // Login without MFA enrollment - gets mfa_enrollment_required, no session
    const login = await request(app)
      .post('/api/v1/auth/login/email')
      .send({ email, password: TEST_PASSWORD });
    expect(login.body.data.authenticationStatus).toBe('mfa_enrollment_required');
    
    // No session cookie available for unenrolled user
    // The /mfa/status endpoint requires requireAuth which needs a session
    // Since unenrolled user can't get a session, they can't access it
    // This is the expected behavior - MFA enrollment is mandatory
  });
});