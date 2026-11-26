import { randomBytes, randomInt, randomUUID, createHash, createHmac } from 'node:crypto';
import * as argon2 from 'argon2';
import { ConflictError, UnauthorizedError, HttpError, ForbiddenError } from '../../shared/errors.js';
import * as authRepository from './auth.repository.js';
import type { AuthUser, LoginResult, RegistrationResult, VerificationResult } from './auth.types.js';
import { createEmailProvider, type EmailProviderConfig } from './providers/email.js';
import { createSmsProvider, type SmsProviderConfig } from './providers/sms.js';
import { createGoogleOAuthProvider, type GoogleOAuthConfig } from './providers/google.js';
import { loadEnv } from '../../config/env.js';
import * as authLoginService from './auth.login.service.js';

const RESET_DURATION_MS = 60 * 60 * 1000;
const RECENT_AUTH_WINDOW_MS = 5 * 60 * 1000;

function isRecent(date: Date | null | undefined): boolean {
  return Boolean(date && date.getTime() >= Date.now() - RECENT_AUTH_WINDOW_MS);
}

async function verifyPasswordForStepUp(userId: string, password: string | undefined): Promise<boolean> {
  if (!password) return false;
  const identities = await authRepository.findLoginIdentitiesByUserId(userId);
  for (const identity of identities) {
    if (identity.passwordHash && await argon2.verify(identity.passwordHash, password)) return true;
  }
  throw new UnauthorizedError('Invalid credentials');
}

async function recordCredentialChange(
  userId: string,
  eventType: string,
  ipAddress: string | null,
  userAgent: string | null,
  detail: string,
): Promise<void> {
  try {
    await authRepository.createSecurityEvent(userId, eventType, 'account', 'warning', ipAddress, userAgent, {});
  } catch (error) {
    console.error(`Failed to record security event ${eventType}`, error);
  }
  try {
    const user = await authRepository.findUserById(userId);
    if (user?.email && user.emailVerified) {
      await getEmailProvider().sendEmail({
        to: user.email,
        subject: 'A sign-in method changed on your GetKeja account',
        text: `${detail} If you did not make this change, secure your account immediately by changing your password and reviewing active sessions.`,
        html: `<p>${detail}</p><p>If you did not make this change, secure your account immediately by changing your password and reviewing active sessions.</p>`,
      });
    } else {
      const verifiedPhone = (await authRepository.findLoginIdentitiesByUserId(userId))
        .find((identity) => identity.provider === 'phone' && identity.verifiedAt)?.identifier;
      if (verifiedPhone) {
        await getSmsProvider().sendSms({
          to: verifiedPhone,
          body: `${detail} If this wasn't you, secure your account and contact GetKeja support.`,
        });
      }
    }
  } catch (error) {
    console.error(`Failed to send credential-change alert for ${eventType}`, error);
  }
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function hashOtp(otp: string): string {
  return createHash('sha256').update(otp).digest('hex');
}

function hashEmailVerificationCode(code: string): string {
  return createHmac('sha256', loadEnv().COOKIE_SECRET).update(code).digest('hex');
}

function generateOtp(length: number): string {
  return randomInt(0, 10 ** length).toString().padStart(length, '0');
}

function normalizeKenyanPhone(phone: string): string {
  const cleaned = phone.replace(/[\s\-\(\)]/g, '');
  if (cleaned.startsWith('+254')) {
    return cleaned;
  }
  if (cleaned.startsWith('254')) {
    return `+${cleaned}`;
  }
  if (cleaned.startsWith('0')) {
    return `+254${cleaned.slice(1)}`;
  }
  if (cleaned.startsWith('7') || cleaned.startsWith('1')) {
    return `+254${cleaned}`;
  }
  return cleaned;
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
    phoneMinutes: env.PHONE_VERIFICATION_EXPIRY_MINUTES,
    otpLength: env.PHONE_VERIFICATION_OTP_LENGTH,
    maxAttempts: env.MAX_VERIFICATION_ATTEMPTS,
  };
}

async function createUserWithIdentity(
  client: any,
  email: string | null,
  phone: string | null,
  passwordHash: string | null,
  firstName: string,
  lastName: string,
  role: string,
): Promise<{ userId: string; emailIdentityId?: string; phoneIdentityId?: string }> {
  const userId = randomUUID();

  await client.query(
    `INSERT INTO users (id, email, password_hash, name, first_name, last_name, is_active, email_verified, phone_verified)
     VALUES ($1, $2, $3, $4, $5, $6, TRUE, $7, $8)`,
    [userId, email, passwordHash, `${firstName} ${lastName}`, firstName, lastName, !email, !phone],
  );

  await client.query(
    'INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)',
    [userId, role],
  );

  let emailIdentityId: string | undefined;
  let phoneIdentityId: string | undefined;

  if (email) {
    const emailIdentityResult = await client.query(
      `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary)
       VALUES ($1, $2, 'email', $3, $4, TRUE)
       RETURNING id`,
      [randomBytes(16).toString('hex'), userId, email.toLowerCase(), passwordHash],
    );
    emailIdentityId = emailIdentityResult.rows[0].id;
  }

  if (phone) {
    const phoneIdentityResult = await client.query(
      `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary)
       VALUES ($1, $2, 'phone', $3, $4, $5)
       RETURNING id`,
      [randomBytes(16).toString('hex'), userId, phone, passwordHash, !email],
    );
    phoneIdentityId = phoneIdentityResult.rows[0].id;
  }

  return { userId, emailIdentityId, phoneIdentityId };
}

export async function registerWithEmail(
  input: { firstName: string; lastName: string; email: string; password: string; role: string },
): Promise<RegistrationResult> {
  const normalizedEmail = input.email.toLowerCase().trim();

  const existingUser = await authRepository.findUserByEmail(normalizedEmail);
  if (existingUser) {
    throw new ConflictError('An account with this email already exists');
  }

  const existingEmailIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  if (existingEmailIdentity) {
    throw new ConflictError('An account with this email already exists');
  }

  const role = await authRepository.getRoleById(input.role);
  if (!role || !role.isPubliclyAssignable) {
    throw new HttpError('Invalid role selected', 400);
  }

  const passwordHash = await argon2.hash(input.password);

  const client = await (await import('../../db/pool.js')).pool.connect();
  try {
    await client.query('BEGIN');

    const { userId, emailIdentityId } = await createUserWithIdentity(
      client,
      normalizedEmail,
      null,
      passwordHash,
      input.firstName,
      input.lastName,
      input.role,
    );

    const { emailHours, maxAttempts } = getVerificationExpiry();
    const verificationToken = generateOtp(6);
    const tokenHash = hashEmailVerificationCode(verificationToken);
    const expiresAt = new Date(Date.now() + emailHours * 60 * 60 * 1000);

    await client.query(
      `INSERT INTO email_verification_tokens (id, user_id, login_identity_id, token_hash, expires_at, max_attempts)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomBytes(16).toString('hex'), userId, emailIdentityId, tokenHash, expiresAt, maxAttempts],
    );

    await client.query('COMMIT');

    const user = await authRepository.findUserWithRolesById(userId);
    if (!user) throw new HttpError('Failed to create user', 500);

    let verificationDeliveryFailed = false;
    try {
      const emailProvider = getEmailProvider();
      await emailProvider.sendVerificationEmail(normalizedEmail, verificationToken, input.firstName);
    } catch {
      // Keep the created account recoverable; the app can request a new code.
      verificationDeliveryFailed = true;
    }

    return {
      user,
      verificationRequired: true,
      verificationChannel: 'email',
      verificationId: emailIdentityId,
      verificationDeliveryFailed,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function registerWithPhone(
  input: { firstName: string; lastName: string; phone: string; password: string; role: string },
): Promise<RegistrationResult> {
  const normalizedPhone = normalizeKenyanPhone(input.phone);

  const existingPhoneIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (existingPhoneIdentity) {
    throw new ConflictError('An account with this phone number already exists');
  }

  const role = await authRepository.getRoleById(input.role);
  if (!role || !role.isPubliclyAssignable) {
    throw new HttpError('Invalid role selected', 400);
  }

  const passwordHash = await argon2.hash(input.password);

  const client = await (await import('../../db/pool.js')).pool.connect();
  try {
    await client.query('BEGIN');

    const { userId, phoneIdentityId } = await createUserWithIdentity(
      client,
      null,
      normalizedPhone,
      passwordHash,
      input.firstName,
      input.lastName,
      input.role,
    );

    const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
    const otp = generateOtp(otpLength);
    const otpHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

    await client.query(
      `INSERT INTO phone_verification_tokens (id, user_id, login_identity_id, otp_hash, expires_at, max_attempts)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomBytes(16).toString('hex'), userId, phoneIdentityId, otpHash, expiresAt, maxAttempts],
    );

    await client.query('COMMIT');

    const user = await authRepository.findUserWithRolesById(userId);
    if (!user) throw new HttpError('Failed to create user', 500);

    const smsProvider = getSmsProvider();
    await smsProvider.sendOtp(normalizedPhone, otp);

    return {
      user,
      verificationRequired: true,
      verificationChannel: 'sms',
      verificationId: phoneIdentityId,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function registerWithPhoneOtp(
  input: { firstName: string; lastName: string; phone: string; role: string },
): Promise<RegistrationResult> {
  const normalizedPhone = normalizeKenyanPhone(input.phone);

  const existingPhoneIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (existingPhoneIdentity) {
    const user = await authRepository.findUserWithRolesById(existingPhoneIdentity.userId);
    if (user) {
      const pendingToken = await authRepository.findPendingPhoneVerificationToken(existingPhoneIdentity.id);
      if (pendingToken) {
        const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
        const otp = generateOtp(otpLength);
        const otpHash = hashOtp(otp);
        const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

        await authRepository.invalidatePhoneVerificationTokens(existingPhoneIdentity.id);
        await authRepository.createPhoneVerificationToken(user.id, existingPhoneIdentity.id, otpHash, expiresAt, maxAttempts);

        const smsProvider = getSmsProvider();
        await smsProvider.sendOtp(normalizedPhone, otp);

        return {
          user,
          verificationRequired: true,
          verificationChannel: 'sms',
          verificationId: existingPhoneIdentity.id,
        };
      }
    }
    throw new ConflictError('An account with this phone number already exists');
  }

  const role = await authRepository.getRoleById(input.role);
  if (!role || !role.isPubliclyAssignable) {
    throw new HttpError('Invalid role selected', 400);
  }

  const client = await (await import('../../db/pool.js')).pool.connect();
  try {
    await client.query('BEGIN');

    const { userId, phoneIdentityId } = await createUserWithIdentity(
      client,
      null,
      normalizedPhone,
      null,
      input.firstName,
      input.lastName,
      input.role,
    );

    const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
    const otp = generateOtp(otpLength);
    const otpHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

    await client.query(
      `INSERT INTO phone_verification_tokens (id, user_id, login_identity_id, otp_hash, expires_at, max_attempts)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomBytes(16).toString('hex'), userId, phoneIdentityId, otpHash, expiresAt, maxAttempts],
    );

    await client.query('COMMIT');

    const user = await authRepository.findUserWithRolesById(userId);
    if (!user) throw new HttpError('Failed to create user', 500);

    const smsProvider = getSmsProvider();
    await smsProvider.sendOtp(normalizedPhone, otp);

    return {
      user,
      verificationRequired: true,
      verificationChannel: 'sms',
      verificationId: phoneIdentityId,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function requestEmailVerification(email: string): Promise<void> {
  const normalizedEmail = email.toLowerCase().trim();

  const loginIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  if (!loginIdentity) {
    return;
  }

  const pendingToken = await authRepository.findPendingEmailVerificationToken(loginIdentity.id);
  if (pendingToken) {
    await authRepository.invalidateEmailVerificationTokens(loginIdentity.id);
  }

  const { emailHours, maxAttempts } = getVerificationExpiry();
  const verificationToken = generateOtp(6);
  const tokenHash = hashEmailVerificationCode(verificationToken);
  const expiresAt = new Date(Date.now() + emailHours * 60 * 60 * 1000);

  await authRepository.createEmailVerificationToken(
    loginIdentity.userId,
    loginIdentity.id,
    tokenHash,
    expiresAt,
    maxAttempts,
  );

  const user = await authRepository.findUserById(loginIdentity.userId);
  const firstName = user?.firstName || undefined;

  const emailProvider = getEmailProvider();
  await emailProvider.sendVerificationEmail(normalizedEmail, verificationToken, firstName);
}

export async function confirmEmailVerification(email: string, code: string): Promise<VerificationResult> {
  const normalizedEmail = email.toLowerCase().trim();
  const loginIdentity = await authRepository.findLoginIdentity('email', normalizedEmail);
  if (!loginIdentity) {
    return { success: false, message: 'Invalid or expired verification code' };
  }

  const codeHash = hashEmailVerificationCode(code);
  const result = await authRepository.consumeEmailVerificationToken(loginIdentity.id, codeHash);

  if (!result) {
    const attempts = await authRepository.incrementEmailVerificationAttempt(loginIdentity.id);
    return {
      success: false,
      message: attempts && attempts.attemptCount >= attempts.maxAttempts
        ? 'Too many failed attempts. Please request a new code.'
        : 'Invalid or expired verification code',
    };
  }

  await authRepository.updateLoginIdentityVerified(result.loginIdentityId);
  await authRepository.updateUserEmailVerified(result.userId, true);

  const user = await authRepository.findUserWithRolesById(result.userId);
  if (!user) {
    return { success: false, message: 'User not found after verification' };
  }

  return { success: true, message: 'Email verified successfully', user };
}

export async function requestPhoneVerification(phone: string): Promise<void> {
  const normalizedPhone = normalizeKenyanPhone(phone);

  const loginIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (!loginIdentity) {
    return;
  }

  const pendingToken = await authRepository.findPendingPhoneVerificationToken(loginIdentity.id);
  if (pendingToken) {
    await authRepository.invalidatePhoneVerificationTokens(loginIdentity.id);
  }

  const { phoneMinutes, otpLength, maxAttempts } = getVerificationExpiry();
  const otp = generateOtp(otpLength);
  const otpHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + phoneMinutes * 60 * 1000);

  await authRepository.createPhoneVerificationToken(
    loginIdentity.userId,
    loginIdentity.id,
    otpHash,
    expiresAt,
    maxAttempts,
  );

  const smsProvider = getSmsProvider();
  await smsProvider.sendOtp(normalizedPhone, otp);
}

export async function confirmPhoneVerification(phone: string, otp: string): Promise<VerificationResult> {
  const normalizedPhone = normalizeKenyanPhone(phone);
  const otpHash = hashOtp(otp);

  const loginIdentity = await authRepository.findLoginIdentity('phone', normalizedPhone);
  if (!loginIdentity) {
    return { success: false, message: 'Invalid phone number' };
  }

  const result = await authRepository.consumePhoneVerificationToken(loginIdentity.id, otpHash);

  if (!result) {
    const attempts = await authRepository.incrementPhoneVerificationAttempt(loginIdentity.id);
    if (attempts && attempts.attemptCount >= attempts.maxAttempts) {
      return { success: false, message: 'Too many failed attempts. Please request a new code.' };
    }
    return { success: false, message: 'Invalid or expired verification code' };
  }

  await authRepository.updateLoginIdentityVerified(result.loginIdentityId);
  await authRepository.updateUserPhoneVerified(result.userId, true);

  const user = await authRepository.findUserWithRolesById(result.userId);
  if (!user) {
    return { success: false, message: 'User not found after verification' };
  }

  return { success: true, message: 'Phone verified successfully', user };
}

export async function registerWithGoogle(
  idToken: string,
  roleId = 'house_seeker',
): Promise<RegistrationResult> {
  const googleProvider = getGoogleOAuthProvider();
  const payload = await googleProvider.verifyIdToken(idToken);

  const existingGoogleIdentity = await authRepository.findGoogleIdentityBySubject(payload.sub);
  if (existingGoogleIdentity) {
    if (payload.email_verified) {
      await authRepository.activateVerifiedGoogleUser(
        existingGoogleIdentity.userId,
        payload.sub,
      );
    }
    const user = await authRepository.findUserWithRolesById(existingGoogleIdentity.userId);
    if (!user) throw new HttpError('Linked user not found', 500);
    return { user, verificationRequired: false, verificationChannel: 'none' };
  }

  const existingEmailIdentity = await authRepository.findLoginIdentity('email', payload.email.toLowerCase());
  if (existingEmailIdentity) {
    throw new ConflictError('An account with this email already exists. Please sign in and link your Google account.');
  }

  const role = await authRepository.getRoleById(roleId);
  if (!role) throw new HttpError('Selected role is not configured', 500);
  if (!role.isPubliclyAssignable) {
    throw new HttpError('Invalid role selected', 400);
  }

  const client = await (await import('../../db/pool.js')).pool.connect();
  try {
    await client.query('BEGIN');

    const userId = randomUUID();
    const firstName = payload.given_name || payload.name?.split(' ')[0] || 'User';
    const lastName = payload.family_name || payload.name?.split(' ').slice(1).join(' ') || '';

    await client.query(
      `INSERT INTO users (
         id, email, password_hash, name, first_name, last_name, is_active,
         email_verified, phone_verified, account_status
       )
       VALUES ($1, $2, $3, $4, $5, $6, TRUE, $7, FALSE, $8)`,
      [
        userId,
        payload.email.toLowerCase(),
        null,
        payload.name || `${firstName} ${lastName}`,
        firstName,
        lastName,
        payload.email_verified,
        payload.email_verified ? 'active' : 'pending_verification',
      ],
    );

    await client.query(
      'INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)',
      [userId, roleId],
    );

    const emailIdentityResult = await client.query(
      `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary, verified_at, metadata)
       VALUES ($1, $2, 'email', $3, NULL, TRUE, $4, $5)
       RETURNING id`,
      [randomBytes(16).toString('hex'), userId, payload.email.toLowerCase(),
       payload.email_verified ? new Date() : null,
       JSON.stringify({ googleLinked: true, googleSubject: payload.sub })],
    );
    const emailIdentityId = emailIdentityResult.rows[0].id;

    await client.query(
      `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary, metadata)
       VALUES ($1, $2, 'google', $3, NULL, FALSE, $4)
       RETURNING id`,
      [randomBytes(16).toString('hex'), userId, payload.sub, JSON.stringify({ email: payload.email })],
    );

    await client.query(
      `INSERT INTO google_identities (id, user_id, login_identity_id, google_subject, email, email_verified, name, given_name, family_name, picture, locale, raw_profile)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [randomBytes(16).toString('hex'), userId, emailIdentityId, payload.sub, payload.email, payload.email_verified,
       payload.name, payload.given_name, payload.family_name, payload.picture, payload.locale, JSON.stringify(payload)],
    );

    await client.query('COMMIT');

    const user = await authRepository.findUserWithRolesById(userId);
    if (!user) throw new HttpError('Failed to create user', 500);

    return {
      user,
      verificationRequired: !payload.email_verified,
      verificationChannel: payload.email_verified ? 'none' : 'email',
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function linkGoogleAccount(
  userId: string,
  idToken: string,
  options: { sessionCreatedAt?: Date; password?: string; ipAddress?: string | null; userAgent?: string | null } = {},
): Promise<void> {
  const googleProvider = getGoogleOAuthProvider();
  const payload = await googleProvider.verifyIdToken(idToken);
  if (!payload.email_verified) {
    throw new UnauthorizedError('Google email must be verified before linking');
  }

  const user = await authRepository.findUserById(userId);
  const passwordVerified = await verifyPasswordForStepUp(userId, options.password);
  const sameVerifiedEmail = Boolean(user?.emailVerified && user.email.toLowerCase() === payload.email.toLowerCase());
  if (!isRecent(options.sessionCreatedAt) && !isRecent(user?.lastMfaVerifiedAt) && !passwordVerified && !sameVerifiedEmail) {
    throw new ForbiddenError('Please sign in again, verify with MFA, or confirm your password before linking Google.');
  }

  const existingGoogleIdentity = await authRepository.findGoogleIdentityBySubject(payload.sub);
  if (existingGoogleIdentity && existingGoogleIdentity.userId !== userId) {
    throw new ConflictError('This Google account is already linked to another user');
  }

  const userGoogleIdentity = await authRepository.findGoogleIdentityByUserId(userId);
  if (userGoogleIdentity) {
    throw new ConflictError('This account already has a linked Google account');
  }

  const loginIdentities = await authRepository.findLoginIdentitiesByUserId(userId);
  const emailIdentity = loginIdentities.find((li) => li.provider === 'email');

  const client = await (await import('../../db/pool.js')).pool.connect();
  try {
    await client.query('BEGIN');

    let emailIdentityId = emailIdentity?.id;
    if (!emailIdentity) {
      const emailIdentityResult = await client.query(
        `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary, verified_at, metadata)
         VALUES ($1, $2, 'email', $3, NULL, TRUE, $4, $5)
         RETURNING id`,
        [randomBytes(16).toString('hex'), userId, payload.email.toLowerCase(),
         payload.email_verified ? new Date() : null,
         JSON.stringify({ googleLinked: true, googleSubject: payload.sub })],
      );
      emailIdentityId = emailIdentityResult.rows[0].id;
    } else if (emailIdentity.identifier.toLowerCase() === payload.email.toLowerCase()) {
      await client.query(
        `UPDATE user_login_identities SET verified_at = $1, metadata = $2, updated_at = NOW() WHERE id = $3`,
        [new Date(), JSON.stringify({ googleLinked: true, googleSubject: payload.sub }), emailIdentity.id],
      );
      await client.query(
        'UPDATE users SET email_verified = TRUE, updated_at = NOW() WHERE id = $1',
        [userId],
      );
    }

    const googleIdentityResult = await client.query(
      `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary, metadata)
       VALUES ($1, $2, 'google', $3, NULL, FALSE, $4)
       RETURNING id`,
      [randomBytes(16).toString('hex'), userId, payload.sub, JSON.stringify({ email: payload.email })],
    );
    const googleLoginIdentityId = googleIdentityResult.rows[0].id;

    await client.query(
      `INSERT INTO google_identities (id, user_id, login_identity_id, google_subject, email, email_verified, name, given_name, family_name, picture, locale, raw_profile)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [randomBytes(16).toString('hex'), userId, googleLoginIdentityId, payload.sub, payload.email, payload.email_verified,
       payload.name, payload.given_name, payload.family_name, payload.picture, payload.locale, JSON.stringify(payload)],
    );

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  await recordCredentialChange(userId, 'google_account_linked', options.ipAddress ?? null, options.userAgent ?? null,
    'A Google account was linked to your GetKeja account.');
}

export async function unlinkGoogleAccount(
  userId: string,
  password?: string,
  options: { ipAddress?: string | null; userAgent?: string | null } = {},
): Promise<void> {
  const loginIdentities = await authRepository.findLoginIdentitiesByUserId(userId);
  const emailIdentity = loginIdentities.find((li) => li.provider === 'email');
  const phoneIdentity = loginIdentities.find((li) => li.provider === 'phone');

  const hasPassword = emailIdentity?.passwordHash || phoneIdentity?.passwordHash;

  if (hasPassword) {
    if (!password) {
      throw new ForbiddenError('Password confirmation is required to unlink Google.');
    }
    let passwordMatches = false;
    for (const identity of [emailIdentity, phoneIdentity]) {
      if (identity?.passwordHash && await argon2.verify(identity.passwordHash, password)) {
        passwordMatches = true;
        break;
      }
    }
    if (!passwordMatches) throw new UnauthorizedError('Invalid credentials');
  } else {
    const user = await authRepository.findUserById(userId);
    const recentVerification = user?.lastMfaVerifiedAt
      && user.lastMfaVerifiedAt.getTime() >= Date.now() - 5 * 60 * 1000;
    if (!recentVerification) {
      throw new ForbiddenError('A recent MFA verification is required to unlink Google.');
    }
  }

  await authRepository.deleteGoogleIdentity(userId);
  await recordCredentialChange(userId, 'google_account_unlinked', options.ipAddress ?? null, options.userAgent ?? null,
    'A Google account was unlinked from your GetKeja account.');
}

export async function getGoogleAuthUrl(redirectUrl?: string): Promise<{ url: string; state: string }> {
  return authLoginService.getGoogleAuthUrl(redirectUrl);
}

export async function handleGoogleCallback(code: string, state: string): Promise<LoginResult> {
  return authLoginService.handleGoogleOAuthCallback(code, state);
}

export async function login(
  input: { email: string; password: string },
): Promise<LoginResult> {
  return authLoginService.loginWithEmail(input.email, input.password);
}

export async function loginWithPhone(
  input: { phone: string; password: string },
): Promise<LoginResult> {
  return authLoginService.loginWithPhone(input.phone, input.password);
}

export async function getUserForSession(sessionToken: string): Promise<AuthUser | undefined> {
  const user = await authRepository.findAuthSessionUser(hashToken(sessionToken));
  if (
    !user ||
    user.accountStatus !== 'active' ||
    user.deletedAt !== null ||
    !user.isActive ||
    user.isSuspended ||
    user.isLocked ||
    user.isDeactivated ||
    !user.mfaEnabled ||
    !user.mfaEnrolledAt ||
    user.mfaEnrollmentRequired ||
    !user.lastMfaVerifiedAt
  ) {
    return undefined;
  }
  return user;
}

export async function logout(sessionToken: string): Promise<void> {
  await authRepository.deleteAuthSession(hashToken(sessionToken));
}

export async function requestPasswordReset(email: string): Promise<{ resetToken?: string }> {
  const resetToken = randomBytes(32).toString('base64url');
  const created = await authRepository.createPasswordResetToken(
    email,
    hashToken(resetToken),
    new Date(Date.now() + RESET_DURATION_MS),
  );
  if (created) {
    const emailProvider = getEmailProvider();
    await emailProvider.sendPasswordResetEmail(email, resetToken);
  }
  return created ? { resetToken } : {};
}

export async function resetPassword(token: string, password: string): Promise<void> {
  const passwordHash = await argon2.hash(password);
  const consumed = await authRepository.consumePasswordResetToken(hashToken(token), passwordHash);
  if (!consumed) {
    throw new HttpError('Password reset token is invalid or expired', 400);
  }
  await recordCredentialChange(consumed, 'password_reset', null, null,
    'Your GetKeja password was reset.');
}

export async function setPassword(
  userId: string,
  password: string,
  options: { sessionId: string; sessionCreatedAt?: Date; idToken?: string; ipAddress?: string | null; userAgent?: string | null },
): Promise<void> {
  const identities = await authRepository.findLoginIdentitiesByUserId(userId);
  if (identities.some((identity) => Boolean(identity.passwordHash))) {
    throw new ConflictError('A password is already set. Use the change password flow instead.');
  }

  let googleReauthenticated = false;
  if (options.idToken) {
    const [payload, linkedGoogle] = await Promise.all([
      getGoogleOAuthProvider().verifyIdToken(options.idToken),
      authRepository.findGoogleIdentityByUserId(userId),
    ]);
    googleReauthenticated = Boolean(payload.email_verified && linkedGoogle && payload.sub === linkedGoogle.googleSubject);
  }
  const user = await authRepository.findUserById(userId);
  if (!isRecent(options.sessionCreatedAt) && !isRecent(user?.lastMfaVerifiedAt) && !googleReauthenticated) {
    throw new ForbiddenError('Please sign in again or verify with MFA before setting a password.');
  }

  const passwordHash = await argon2.hash(password);
  await authRepository.setPasswordAndRevokeOtherSessions(userId, passwordHash, options.sessionId, 'password_set');
  await recordCredentialChange(userId, 'password_set', options.ipAddress ?? null, options.userAgent ?? null,
    'A password was set for your GetKeja account.');
}
