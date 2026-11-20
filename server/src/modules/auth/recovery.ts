import { randomBytes, createHash } from 'node:crypto';
import * as authRepository from './auth.repository.js';
import { loadEnv } from '../../config/env.js';
import { createEmailProvider } from './providers/email.js';
import { createSmsProvider } from './providers/sms.js';
import type { AuthUser, SecurityEvent } from './auth.types.js';

function getEnv() {
  return loadEnv();
}

function getAccountRecoveryConfig() {
  const env = getEnv();
  return {
    tokenExpiryHours: env.ACCOUNT_RECOVERY_TOKEN_EXPIRY_HOURS || 24,
    maxAttempts: env.ACCOUNT_RECOVERY_MAX_ATTEMPTS || 5,
    requiresAdminReview: env.ACCOUNT_RECOVERY_REQUIRES_ADMIN_REVIEW === true,
  };
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export async function initiateAccountRecovery(
  userId: string,
  recoveryMethod: 'email' | 'phone' | 'recovery_codes',
  ipAddress?: string,
  userAgent?: string,
): Promise<{ token: string; expiresAt: Date }> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const { tokenExpiryHours, maxAttempts } = getAccountRecoveryConfig();
  const recoveryToken = randomBytes(32).toString('base64url');
  const tokenHash = hashToken(recoveryToken);
  const expiresAt = new Date(Date.now() + tokenExpiryHours * 60 * 60 * 1000);

  await authRepository.createSecurityEvent(
    userId,
    'account_recovery_initiated',
    'account',
    'warning',
    ipAddress || null,
    userAgent || null,
    { recoveryMethod, expiresAt: expiresAt.toISOString() },
  );

  // Store the recovery token (we'll use the password reset tokens table with a special type)
  await authRepository.createPasswordResetToken(
    user.email,
    tokenHash,
    expiresAt,
  );

  return { token: recoveryToken, expiresAt };
}

export async function verifyAccountRecoveryToken(
  token: string,
): Promise<{ userId: string; email: string } | null> {
  const tokenHash = hashToken(token);
  return authRepository.findPasswordResetToken(tokenHash);
}

export async function completeAccountRecovery(
  userId: string,
  recoveryToken: string,
  newPassword: string,
  newMfaMethod?: { type: string; phoneNumber?: string },
  ipAddress?: string,
  userAgent?: string,
): Promise<{ success: boolean; message: string }> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Hash the new password
  const argon2 = await import('argon2');
  const passwordHash = await argon2.default.hash(newPassword);

  const consumed = await authRepository.consumePasswordResetToken(hashToken(recoveryToken), passwordHash);
  if (!consumed) {
    throw new Error('Invalid or expired recovery token');
  }

  // If new MFA method provided, start enrollment
  if (newMfaMethod) {
    // This would be handled by the caller
  }

  await authRepository.createSecurityEvent(
    userId,
    'account_recovery_completed',
    'account',
    'critical',
    ipAddress || null,
    userAgent || null,
    { passwordChanged: true, mfaMethodAdded: !!newMfaMethod },
  );

  return { success: true, message: 'Account recovery completed successfully' };
}

export async function requestAccountRecoveryEmail(email: string): Promise<void> {
  const user = await authRepository.findUserByEmail(email);
  if (
    !user ||
    user.account_status !== 'active' ||
    !user.is_active ||
    user.is_deactivated ||
    user.deleted_at !== null
  ) {
    return; // Enumeration resistance
  }

  const { token, expiresAt } = await initiateAccountRecovery(
    user.id,
    'email',
  );

  const emailProvider = createEmailProvider({
    fromAddress: getEnv().EMAIL_FROM_ADDRESS,
    fromName: getEnv().EMAIL_FROM_NAME,
    baseUrl: getEnv().EMAIL_BASE_URL,
  });

  await emailProvider.sendAccountRecoveryEmail(email, token);
}

export async function requestAccountRecoverySms(phone: string): Promise<void> {
  const normalizedPhone = phone.replace(/[\s\-\(\)]/g, '');
  if (!normalizedPhone.startsWith('+254')) {
    throw new Error('Invalid phone format');
  }

  const user = await authRepository.findUserByPhone(normalizedPhone);
  if (
    !user ||
    user.account_status !== 'active' ||
    !user.is_active ||
    user.is_deactivated ||
    user.deleted_at !== null
  ) {
    return; // Enumeration resistance
  }

  const { token, expiresAt } = await initiateAccountRecovery(
    user.id,
    'phone',
  );

  const smsProvider = createSmsProvider({ fromNumber: getEnv().SMS_FROM_NUMBER });
  await smsProvider.sendOtp(normalizedPhone, `Your account recovery code: ${token}`);
}

export async function hasSystemRole(userId: string): Promise<boolean> {
  return authRepository.hasSystemRole(userId);
}

export async function getUserSecurityEvents(
  userId: string,
  limit = 50,
  offset = 0,
  categories?: string[],
): Promise<SecurityEvent[]> {
  return authRepository.findSecurityEventsByUserId(userId, limit, offset, categories);
}

export async function notifyMfaChange(
  userId: string,
  eventType: string,
  metadata: Record<string, unknown>,
  ipAddress?: string,
  userAgent?: string,
): Promise<void> {
  await authRepository.createSecurityEvent(
    userId,
    eventType,
    'mfa',
    'warning',
    ipAddress || null,
    userAgent || null,
    metadata,
  );
}
