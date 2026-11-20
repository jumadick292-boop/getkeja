import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import * as authRepository from '../auth.repository.js';
import { createEmailProvider } from '../providers/email.js';
import { loadEnv } from '../../../config/env.js';
import type { MfaMethod } from '../auth.types.js';

function getEnv() {
  return loadEnv();
}

function getEmailProvider() {
  const env = getEnv();
  return createEmailProvider({
    fromAddress: env.EMAIL_FROM_ADDRESS,
    fromName: env.EMAIL_FROM_NAME,
    baseUrl: env.EMAIL_BASE_URL,
  });
}

function getEmailMfaConfig() {
  const env = getEnv();
  return {
    expiryMinutes: env.MFA_EMAIL_EXPIRY_MINUTES || 10,
    codeLength: env.MFA_EMAIL_CODE_LENGTH || 6,
    maxAttempts: env.MFA_EMAIL_MAX_ATTEMPTS || 3,
    resendCooldownSeconds: env.MFA_EMAIL_RESEND_COOLDOWN_SECONDS || 60,
  };
}

function generateCode(length: number): string {
  const digits = '0123456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += digits[randomInt(digits.length)];
  }
  return code;
}

function hashCode(code: string): string {
  return createHmac('sha256', getEnv().COOKIE_SECRET).update(code).digest('hex');
}

export async function createEmailMfaMethod(
  userId: string,
  methodName: string | null,
  isPrimary: boolean,
): Promise<MfaMethod> {
  const user = await authRepository.findUserById(userId);
  if (!user || !user.emailVerified) {
    throw new Error('Email MFA requires a verified email address');
  }

  const method = await authRepository.createMfaMethod(
    userId,
    'email',
    methodName || `Email to ${user.email}`,
    isPrimary,
    { email: user.email },
  );

  return method;
}

export async function sendEmailMfaCode(userId: string, mfaMethodId: string): Promise<{ expiresAt: Date }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || method.methodType !== 'email' || !method.isActive) {
    throw new Error('Email MFA method not found or inactive');
  }

  const email = method.metadata.email as string;
  if (!email) {
    throw new Error('Email not configured for Email MFA');
  }

  const { expiryMinutes, codeLength, maxAttempts, resendCooldownSeconds } = getEmailMfaConfig();
  const lastSentAt = method.metadata.lastCodeSentAt
    ? new Date(method.metadata.lastCodeSentAt as string).getTime()
    : 0;
  const waitSeconds = Math.ceil(resendCooldownSeconds - (Date.now() - lastSentAt) / 1000);
  if (lastSentAt && waitSeconds > 0) {
    throw new Error(`Please wait ${waitSeconds} seconds before requesting another code`);
  }
  const code = generateCode(codeLength);
  const codeHash = hashCode(code);
  const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

  await authRepository.updateMfaMethod(mfaMethodId, {
    metadata: {
      ...method.metadata,
      codeHash,
      codeExpiresAt: expiresAt.toISOString(),
      codeAttempts: 0,
      codeMaxAttempts: maxAttempts,
      lastCodeSentAt: new Date().toISOString(),
    },
  });

  try {
    const emailProvider = getEmailProvider();
    await emailProvider.sendLoginOtp(email, code);
  } catch (error) {
    await authRepository.updateMfaMethod(mfaMethodId, { metadata: method.metadata });
    throw error;
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_challenge_sent',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'email', email: email.split('@')[0] + '@***' },
  );

  return { expiresAt };
}

export async function verifyEmailMfaCode(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<{ valid: boolean; error?: string }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || method.methodType !== 'email' || !method.isActive) {
    return { valid: false, error: 'Email MFA method not found or inactive' };
  }

  const metadata = method.metadata as Record<string, unknown>;
  const codeHash = metadata.codeHash as string | undefined;
  const codeExpiresAt = metadata.codeExpiresAt ? new Date(metadata.codeExpiresAt as string) : undefined;
  const codeAttempts = (metadata.codeAttempts as number) || 0;
  const codeMaxAttempts = (metadata.codeMaxAttempts as number) || 3;

  if (!codeHash || !codeExpiresAt) {
    return { valid: false, error: 'No active email challenge. Request a new code.' };
  }

  if (new Date() > codeExpiresAt) {
    await authRepository.updateMfaMethod(mfaMethodId, {
      metadata: { ...metadata, codeHash: undefined, codeExpiresAt: undefined },
    });
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'email', reason: 'expired' },
    );
    return { valid: false, error: 'Email code has expired. Request a new code.' };
  }

  if (codeAttempts >= codeMaxAttempts) {
    await authRepository.updateMfaMethod(mfaMethodId, {
      metadata: { ...metadata, codeHash: undefined, codeExpiresAt: undefined },
    });
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'email', reason: 'max_attempts_exceeded' },
    );
    return { valid: false, error: 'Too many failed attempts. Request a new code.' };
  }

  const attemptHash = hashCode(code);
  if (!timingSafeEqual(Buffer.from(attemptHash), Buffer.from(codeHash))) {
    const newAttempts = await authRepository.incrementMfaCodeAttempt(mfaMethodId, 'email', codeHash, codeMaxAttempts);
    if (newAttempts === null) return { valid: false, error: 'Email code is invalid or has already been used' };
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'email', reason: 'invalid_code', attempts: newAttempts },
    );
    return { valid: false, error: 'Invalid email code' };
  }

  const consumed = await authRepository.consumeMfaOneTimeCode(mfaMethodId, 'email', codeHash);
  if (!consumed) {
    return { valid: false, error: 'Email code is invalid or has already been used' };
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_verified',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'email' },
  );

  return { valid: true };
}

export async function disableEmailMfaMethod(userId: string, mfaMethodId: string): Promise<void> {
  await authRepository.updateMfaMethod(mfaMethodId, { isActive: false, isVerified: false });
  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_removed',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'email' },
  );
}
