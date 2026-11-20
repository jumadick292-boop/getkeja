import { randomBytes, randomInt, createHash, createHmac } from 'node:crypto';
import * as argon2 from 'argon2';
import { ConflictError, UnauthorizedError, HttpError, ForbiddenError } from '../../shared/errors.js';
import * as authRepository from './auth.repository.js';
import * as mfaService from './mfa/index.js';
import * as sessionService from './session.service.js';
import type {
  AuthUser,
  LoginResult,
  MfaHandoffResult,
  EmailLoginOtp,
  PhoneLoginOtp,
  MfaChallenge,
} from './auth.types.js';
import { createEmailProvider, type EmailProviderConfig } from './providers/email.js';
import { createSmsProvider, type SmsProviderConfig } from './providers/sms.js';
import { createGoogleOAuthProvider, type GoogleOAuthConfig } from './providers/google.js';
import { loadEnv } from '../../config/env.js';
import {
  incrementLoginFailure,
  getLoginFailureCount,
  resetLoginFailure,
  reserveOtpResend,
  delayRepeatedLoginFailures,
} from '../../middleware/rate-limit.js';
import { getRedisClient } from '../../db/redis.js';

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function hashOtp(otp: string): string {
  return createHmac('sha256', loadEnv().COOKIE_SECRET).update(otp).digest('hex');
}

function generateOtp(length: number): string {
  return randomInt(0, 10 ** length).toString().padStart(length, '0');
}

function normalizeKenyanPhone(phone: string): string {
  const cleaned = phone.replace(/[\s()+-]/g, '');
  const local = cleaned.replace(/^254/, '').replace(/^0/, '');
  return `+254${local}`;
}

function getEnv() {
  return loadEnv();
}

function getEmailProvider(): ReturnType<typeof createEmailProvider> {
  const env = getEnv();
  return createEmailProvider({
    fromAddress: env.EMAIL_FROM_ADDRESS,
    fromName: env.EMAIL_FROM_NAME,
    baseUrl: env.EMAIL_BASE_URL,
  });
}

function getSmsProvider(): ReturnType<typeof createSmsProvider> {
  const env = getEnv();
  return createSmsProvider({ fromNumber: env.SMS_FROM_NUMBER });
}

function getGoogleOAuthProvider(): ReturnType<typeof createGoogleOAuthProvider> {
  const env = getEnv();
  return createGoogleOAuthProvider({
    clientId: env.GOOGLE_CLIENT_ID || '',
    clientSecret: env.GOOGLE_CLIENT_SECRET || '',
    redirectUri: env.GOOGLE_REDIRECT_URI || '',
    allowedClientIds: env.GOOGLE_ALLOWED_CLIENT_IDS?.split(',').filter(Boolean),
  });
}

function getVerificationExpiry(): { emailHours: number; phoneMinutes: number; otpLength: number; maxAttempts: number } {
  const env = getEnv();
  return {
    emailHours: env.EMAIL_VERIFICATION_EXPIRY_HOURS,
    phoneMinutes: env.LOGIN_OTP_EXPIRY_MINUTES,
    otpLength: env.PHONE_VERIFICATION_OTP_LENGTH,
    maxAttempts: env.MAX_VERIFICATION_ATTEMPTS,
  };
}

function getMfaExpiry(): { challengeMinutes: number; maxAttempts: number } {
  const env = getEnv();
  return {
    challengeMinutes: env.MFA_CHALLENGE_EXPIRY_MINUTES,
    maxAttempts: env.MFA_CHALLENGE_MAX_ATTEMPTS,
  };
}

async function checkAccountState(user: AuthUser): Promise<void> {
  if (
    user.accountStatus !== 'active' ||
    user.deletedAt !== null ||
    user.isDeactivated ||
    user.isSuspended ||
    user.isLocked ||
    !user.isActive
  ) {
    throw new UnauthorizedError('Invalid credentials');
  }
}

function isAccountEligible(user: AuthUser): boolean {
  return (
    user.accountStatus === 'active' &&
    user.deletedAt === null &&
    user.isActive &&
    !user.isSuspended &&
    !user.isLocked &&
    !user.isDeactivated
  );
}

async function checkMfaRequirement(
  user: AuthUser,
): Promise<{ required: boolean; enrollmentRequired: boolean; availableMethods: string[] }> {
  if (!user.mfaEnrollmentRequired && !user.mfaEnabled && !user.mfaEnrolledAt) {
    return { required: false, enrollmentRequired: false, availableMethods: [] };
  }

  if (!user.mfaEnabled || !user.mfaEnrolledAt || user.mfaEnrollmentRequired) {
    return { required: false, enrollmentRequired: true, availableMethods: [] };
  }

  const methods = await authRepository.findMfaMethodsByUserId(user.id);
  const availableMethods: string[] = [];
  for (const method of methods) {
    if (!method.isActive || !method.isVerified || method.deletedAt) continue;
    if (method.methodType === 'sms' && !availableMethods.includes('sms')) {
      availableMethods.push('sms');
    }
    if (
      method.methodType === 'email' &&
      user.emailVerified &&
      method.metadata.email === user.email &&
      !availableMethods.includes('email')
    ) {
      availableMethods.push('email');
    }
    if (method.methodType !== 'totp') continue;
    if (await authRepository.findMfaTotpSecretByMethodId(method.id)) {
      if (!availableMethods.includes('totp')) availableMethods.push('totp');
    }
  }

  const recoveryMethodAvailable = methods.some(
    method => method.methodType === 'recovery_codes' && method.isActive && method.isVerified && !method.deletedAt,
  );
  if (recoveryMethodAvailable && await authRepository.countUnusedRecoveryCodes(user.id) > 0) {
    availableMethods.push('recovery_codes');
  }

  if (availableMethods.length > 0) {
    return { required: true, enrollmentRequired: false, availableMethods };
  }
  return { required: false, enrollmentRequired: true, availableMethods: [] };
}

async function createMfaChallengeForUser(
  userId: string,
  availableMethods: string[],
): Promise<MfaHandoffResult> {
  const { challengeMinutes, maxAttempts } = getMfaExpiry();
  const expiresAt = new Date(Date.now() + challengeMinutes * 60 * 1000);

  const challenge = await authRepository.createMfaHandoffChallenge(
    userId,
    expiresAt,
    availableMethods,
    maxAttempts,
  );

  return {
    challengeId: challenge.id,
    availableMethods,
    expiresAt: challenge.expiresAt,
  };
}

const dummyPasswordHash = argon2.hash(randomBytes(32).toString('hex'));

async function verifyPassword(
  passwordHash: string | null | undefined,
  password: string,
): Promise<boolean> {
  const hash = passwordHash ?? (await dummyPasswordHash);
  const valid = await argon2.verify(hash, password).catch(() => false);
  return passwordHash !== null && passwordHash !== undefined && valid;
}

async function finishPrimaryAuthentication(user: AuthUser): Promise<LoginResult> {
  const { required, enrollmentRequired, availableMethods } = await checkMfaRequirement(user);
  if (enrollmentRequired) {
    return {
      user,
      authenticationStatus: 'mfa_enrollment_required',
      enrollmentToken: await createMfaEnrollmentTransaction(user.id),
    };
  }
  if (!required) {
    const session = await sessionService.createSessionForUser(user, {
      deviceId: null,
      userAgent: null,
      ipAddress: null,
    });
    return {
      ...session,
      authenticationStatus: 'complete',
    };
  }

  const handoff = await createMfaChallengeForUser(user.id, availableMethods);
  return {
    user,
    authenticationStatus: 'mfa_required',
    challengeId: handoff.challengeId,
    availableMethods: handoff.availableMethods,
  };
}

async function createMfaEnrollmentTransaction(userId: string): Promise<string> {
  const token = randomBytes(32).toString('base64url');
  const result = await getRedisClient().set(
    `auth:mfa-enrollment:${hashToken(token)}`,
    userId,
    'EX',
    getEnv().MFA_ENROLLMENT_TRANSACTION_MINUTES * 60,
    'NX',
  );
  if (result !== 'OK') {
    throw new HttpError('Unable to create MFA enrollment transaction', 503);
  }
  return token;
}

export async function resolveMfaEnrollmentTransaction(token: string): Promise<AuthUser | undefined> {
  const userId = await getRedisClient().get(`auth:mfa-enrollment:${hashToken(token)}`);
  return userId ? authRepository.findUserWithRolesById(userId) : undefined;
}

export async function consumeMfaEnrollmentTransaction(token: string): Promise<void> {
  await getRedisClient().del(`auth:mfa-enrollment:${hashToken(token)}`);
}

export async function skipMfaEnrollment(
  token: string,
  userId: string,
  deviceInfo: {
    deviceId: string | null;
    userAgent: string | null;
    ipAddress: string | null;
  },
): Promise<Awaited<ReturnType<typeof sessionService.createSessionForUser>>> {
  const transactionKey = `auth:mfa-enrollment:${hashToken(token)}`;
  const transactionUserId = await getRedisClient().eval(
    "local userId = redis.call('GET', KEYS[1]); if userId then redis.call('DEL', KEYS[1]); end; return userId",
    1,
    transactionKey,
  ) as string | null;

  if (transactionUserId !== userId) {
    throw new UnauthorizedError('MFA enrollment is not available');
  }

  const user = await authRepository.findUserWithRolesById(userId);
  if (!user) {
    throw new UnauthorizedError();
  }
  await checkAccountState(user);

  const skipped = await authRepository.skipUserMfaEnrollment(userId);
  if (!skipped) {
    throw new UnauthorizedError('MFA enrollment is not available');
  }

  return sessionService.createSessionForUser(user, deviceInfo);
}

export async function loginWithEmail(
  email: string,
  password: string,
): Promise<LoginResult> {
  const normalizedEmail = email.toLowerCase().trim();
  await delayRepeatedLoginFailures(normalizedEmail, 'email');
  const loginIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  const passwordValid = await verifyPassword(loginIdentity?.passwordHash, password);
  if (!loginIdentity || !loginIdentity.verifiedAt || !passwordValid) {
    await incrementLoginFailure(normalizedEmail, 'email');
    throw new UnauthorizedError('Invalid credentials');
  }

  const user = await authRepository.findUserWithRolesById(loginIdentity.userId);
  if (!user) {
    await incrementLoginFailure(normalizedEmail, 'email');
    throw new UnauthorizedError('Invalid credentials');
  }
  await checkAccountState(user);
  await resetLoginFailure(normalizedEmail, 'email');
  return finishPrimaryAuthentication(user);
}

export async function loginAfterEmailVerification(userId: string): Promise<LoginResult> {
  const user = await authRepository.findUserWithRolesById(userId);
  if (!user) {
    throw new UnauthorizedError('Invalid credentials');
  }

  await checkAccountState(user);
  return finishPrimaryAuthentication(user);
}

export async function loginWithPhone(
  phone: string,
  password: string,
): Promise<LoginResult> {
  const normalizedPhone = normalizeKenyanPhone(phone);
  await delayRepeatedLoginFailures(normalizedPhone, 'phone');
  const loginIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  const passwordValid = await verifyPassword(loginIdentity?.passwordHash, password);
  if (!loginIdentity || !loginIdentity.verifiedAt || !passwordValid) {
    await incrementLoginFailure(normalizedPhone, 'phone');
    throw new UnauthorizedError('Invalid credentials');
  }

  const user = await authRepository.findUserWithRolesById(loginIdentity.userId);
  if (!user) {
    await incrementLoginFailure(normalizedPhone, 'phone');
    throw new UnauthorizedError('Invalid credentials');
  }
  await checkAccountState(user);
  await resetLoginFailure(normalizedPhone, 'phone');
  return finishPrimaryAuthentication(user);
}

export async function requestEmailLoginOtp(email: string): Promise<void> {
  const normalizedEmail = email.toLowerCase().trim();
  if (!(await reserveOtpResend(normalizedEmail, 'email'))) return;
  const loginIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  if (!loginIdentity?.verifiedAt) return;
  const user = await authRepository.findUserWithRolesById(loginIdentity.userId);
  if (!user || !isAccountEligible(user)) return;

  const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
  const otp = generateOtp(otpLength);
  const otpHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

  await authRepository.createEmailLoginOtp(
    loginIdentity.userId,
    loginIdentity.id,
    otpHash,
    expiresAt,
    maxAttempts,
  );

  try {
    await getEmailProvider().sendLoginOtp(normalizedEmail, otp, user.firstName ?? undefined);
  } catch {
    await authRepository.invalidateEmailLoginOtpTokens(loginIdentity.id);
    await authRepository.createSecurityEvent(
      null,
      'login_otp_delivery_failed',
      'authentication',
      'warning',
      null,
      null,
      { method: 'email_otp' },
    );
  }
}

export async function verifyEmailLoginOtp(email: string, otp: string): Promise<LoginResult> {
  const normalizedEmail = email.toLowerCase().trim();
  const otpHash = hashOtp(otp);

  const loginIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  if (!loginIdentity?.verifiedAt) throw new UnauthorizedError('Invalid credentials');

  const result = await authRepository.consumeEmailLoginOtp(loginIdentity.id, otpHash);
  if (!result) throw new UnauthorizedError('Invalid credentials');

  const user = await authRepository.findUserWithRolesById(result.userId);
  if (!user) throw new UnauthorizedError('Invalid credentials');
  await checkAccountState(user);
  return finishPrimaryAuthentication(user);
}

export async function requestPhoneLoginOtp(phone: string): Promise<void> {
  const normalizedPhone = normalizeKenyanPhone(phone);
  if (!(await reserveOtpResend(normalizedPhone, 'phone'))) return;
  const loginIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (!loginIdentity?.verifiedAt) return;
  const user = await authRepository.findUserWithRolesById(loginIdentity.userId);
  if (!user || !isAccountEligible(user)) return;

  const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
  const otp = generateOtp(otpLength);
  const otpHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

  await authRepository.createPhoneLoginOtp(
    loginIdentity.userId,
    loginIdentity.id,
    otpHash,
    expiresAt,
    maxAttempts,
  );

  try {
    await getSmsProvider().sendLoginOtp(normalizedPhone, otp);
  } catch {
    await authRepository.invalidatePhoneLoginOtpTokens(loginIdentity.id);
    await authRepository.createSecurityEvent(
      null,
      'login_otp_delivery_failed',
      'authentication',
      'warning',
      null,
      null,
      { method: 'phone_otp' },
    );
  }
}

export async function verifyPhoneLoginOtp(phone: string, otp: string): Promise<LoginResult> {
  const normalizedPhone = normalizeKenyanPhone(phone);
  const otpHash = hashOtp(otp);

  const loginIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (!loginIdentity?.verifiedAt) throw new UnauthorizedError('Invalid credentials');

  const result = await authRepository.consumePhoneLoginOtp(loginIdentity.id, otpHash);
  if (!result) throw new UnauthorizedError('Invalid credentials');

  const user = await authRepository.findUserWithRolesById(result.userId);
  if (!user) throw new UnauthorizedError('Invalid credentials');
  await checkAccountState(user);
  return finishPrimaryAuthentication(user);
}

export async function loginWithGoogle(idToken: string): Promise<LoginResult> {
  const googleProvider = getGoogleOAuthProvider();
  let payload;
  try {
    payload = await googleProvider.verifyIdToken(idToken);
  } catch {
    throw new UnauthorizedError('Invalid credentials');
  }
  if (!payload.email_verified || !payload.sub) {
    throw new UnauthorizedError('Invalid credentials');
  }

  const existingGoogleIdentity = await authRepository.findGoogleIdentityBySubject(payload.sub);
  if (!existingGoogleIdentity) {
    throw new UnauthorizedError('Invalid credentials');
  }

  const user = await authRepository.findUserWithRolesById(existingGoogleIdentity.userId);
  if (!user) {
    throw new UnauthorizedError('Invalid credentials');
  }

  if (payload.email_verified) {
    await authRepository.activateVerifiedGoogleUser(user.id, payload.sub);
  }
  const activeUser = await authRepository.findUserWithRolesById(user.id);
  if (!activeUser) {
    throw new UnauthorizedError('Invalid credentials');
  }

  await checkAccountState(activeUser);
  return finishPrimaryAuthentication(activeUser);
}

export async function getGoogleAuthUrl(
  redirectUrl?: string,
): Promise<{ url: string; state: string }> {
  const env = getEnv();
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET || !env.GOOGLE_REDIRECT_URI) {
    throw new HttpError('Google OAuth is not configured', 503);
  }
  const provider = getGoogleOAuthProvider();
  const authorization = provider.getAuthorizationUrl({
    redirectUrl,
    codeChallengeMethod: 'S256',
  });
  if (!authorization.codeVerifier) {
    throw new HttpError('Unable to create secure Google sign-in request', 500);
  }
  const result = await getRedisClient().set(
    `auth:google:state:${hashToken(authorization.state)}`,
    JSON.stringify({
      codeVerifier: authorization.codeVerifier,
      redirectUrl,
    }),
    'EX',
    600,
    'NX',
  );
  if (result !== 'OK') {
    throw new HttpError('Unable to create secure Google sign-in request', 500);
  }
  return { url: authorization.url, state: authorization.state };
}

export async function handleGoogleOAuthCallback(
  code: string,
  state: string,
): Promise<LoginResult> {
  const stateKey = `auth:google:state:${hashToken(state)}`;
  const serializedState = await getRedisClient().eval(
    "local value = redis.call('GET', KEYS[1]); if value then redis.call('DEL', KEYS[1]); end; return value",
    1,
    stateKey,
  ) as string | null;
  if (!serializedState) throw new UnauthorizedError('Invalid credentials');

  let stateData: { codeVerifier?: string };
  try {
    stateData = JSON.parse(serializedState) as { codeVerifier?: string };
  } catch {
    throw new UnauthorizedError('Invalid credentials');
  }
  if (!stateData.codeVerifier) throw new UnauthorizedError('Invalid credentials');

  const provider = getGoogleOAuthProvider();
  let tokens: { idToken: string };
  try {
    tokens = await provider.exchangeCodeForTokens(code, stateData.codeVerifier);
  } catch {
    throw new UnauthorizedError('Invalid credentials');
  }
  return loginWithGoogle(tokens.idToken);
}

export async function cancelGoogleOAuth(state: string): Promise<void> {
  await getRedisClient().del(`auth:google:state:${hashToken(state)}`);
}

export async function getMfaChallenge(challengeId: string): Promise<MfaChallenge | undefined> {
  return authRepository.findMfaChallenge(challengeId);
}

export async function completeMfaChallenge(
  challengeId: string,
  code: string,
  deviceInfo: {
    deviceId: string | null;
    userAgent: string | null;
    ipAddress: string | null;
  },
  methodType: 'totp' | 'sms' | 'email' | 'recovery_codes' = 'totp',
): Promise<{ user: AuthUser; accessToken: string; refreshToken: string; sessionId: string; expiresIn: number }> {
  // Get the challenge to find the user
  const challenge = await authRepository.findMfaChallenge(challengeId);
  if (!challenge) {
    throw new UnauthorizedError('Invalid or expired MFA challenge');
  }

  // Use the MFA service to verify the challenge
  const result = await mfaService.verifyMfaChallenge(
    challenge.userId,
    challengeId,
    methodType,
    code,
  );

  if (!result.success) {
    throw new UnauthorizedError(result.message);
  }

  // Update last MFA verified timestamp BEFORE creating session
  // This ensures the session's created_at is >= last_mfa_verified_at
  await authRepository.updateUserLastMfaVerified(challenge.userId);

  const user = await authRepository.findUserWithRolesById(challenge.userId);
  if (!user) {
    throw new HttpError('User not found after MFA verification', 500);
  }

  // Create a new session with access and refresh tokens
  const sessionResult = await sessionService.createSessionForUser(user, deviceInfo);

  return sessionResult;
}

export async function failMfaChallenge(challengeId: string): Promise<void> {
  const challenge = await authRepository.findMfaChallenge(challengeId);
  if (!challenge) {
    throw new UnauthorizedError('Invalid MFA challenge');
  }

  if (challenge.failedAttempts + 1 >= challenge.maxAttempts) {
    await authRepository.failMfaChallenge(challengeId);
    throw new UnauthorizedError('Too many failed MFA attempts. Please start login again.');
  }

  await authRepository.failMfaChallenge(challengeId);
}

export async function recordAuthenticationEvent(
  userId: string | null,
  eventType: 'primary_authentication_succeeded' | 'primary_authentication_failed',
  severity: 'info' | 'warning',
  method: 'email' | 'phone' | 'email_otp' | 'phone_otp' | 'google',
  ipAddress: string | null,
  userAgent: string | null,
): Promise<void> {
  if (ipAddress) {
    if (eventType === 'primary_authentication_failed') {
      await incrementLoginFailure(ipAddress, 'ip');
    } else {
      await resetLoginFailure(ipAddress, 'ip');
    }
  }
  await authRepository.createSecurityEvent(
    userId,
    eventType,
    'authentication',
    severity,
    ipAddress,
    userAgent,
    { method },
  );
}
