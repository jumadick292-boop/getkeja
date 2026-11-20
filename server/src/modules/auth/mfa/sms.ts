import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import * as authRepository from '../auth.repository.js';
import { createSmsProvider } from '../providers/sms.js';
import { loadEnv } from '../../../config/env.js';
import type { MfaMethod } from '../auth.types.js';

function getEnv() {
  return loadEnv();
}

function getSmsProvider() {
  const env = getEnv();
  return createSmsProvider({ fromNumber: env.SMS_FROM_NUMBER });
}

function getSmsMfaConfig() {
  const env = getEnv();
  return {
    expiryMinutes: env.MFA_SMS_EXPIRY_MINUTES || 5,
    otpLength: env.MFA_SMS_OTP_LENGTH || 6,
    maxAttempts: env.MFA_SMS_MAX_ATTEMPTS || 3,
    resendCooldownSeconds: env.MFA_SMS_RESEND_COOLDOWN_SECONDS || 60,
  };
}

function generateOtp(length: number): string {
  const digits = '0123456789';
  let otp = '';
  for (let i = 0; i < length; i++) {
    otp += digits[randomInt(digits.length)];
  }
  return otp;
}

function hashOtp(otp: string): string {
  return createHmac('sha256', getEnv().COOKIE_SECRET).update(otp).digest('hex');
}

function normalizeKenyanPhone(phone: string): string {
  const cleaned = phone.replace(/[\s\-\(\)]/g, '');
  if (cleaned.startsWith('+254')) return cleaned;
  if (cleaned.startsWith('254')) return `+${cleaned}`;
  if (cleaned.startsWith('0')) return `+254${cleaned.slice(1)}`;
  if (cleaned.startsWith('7') || cleaned.startsWith('1')) return `+254${cleaned}`;
  return cleaned;
}

export async function createSmsMfaMethod(
  userId: string,
  phoneNumber: string,
  methodName: string | null,
  isPrimary: boolean,
): Promise<MfaMethod> {
  const normalizedPhone = normalizeKenyanPhone(phoneNumber);

  const method = await authRepository.createMfaMethod(
    userId,
    'sms',
    methodName || `SMS to ${normalizedPhone.slice(-9)}`,
    isPrimary,
    { phoneNumber: normalizedPhone },
  );

  return method;
}

export async function sendSmsMfaOtp(userId: string, mfaMethodId: string): Promise<{ expiresAt: Date; resendAfter: number }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || method.methodType !== 'sms' || !method.isActive) {
    throw new Error('SMS MFA method not found or inactive');
  }

  const phoneNumber = method.metadata.phoneNumber as string;
  if (!phoneNumber) {
    throw new Error('Phone number not configured for SMS MFA');
  }

  const cooldown = await canResendSmsOtp(mfaMethodId);
  if (!cooldown.canResend) {
    throw new Error(`Please wait ${cooldown.waitSeconds ?? 60} seconds before requesting another code`);
  }

  const { expiryMinutes, otpLength, maxAttempts, resendCooldownSeconds } = getSmsMfaConfig();
  const otp = generateOtp(otpLength);
  const otpHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

  await authRepository.updateMfaMethod(mfaMethodId, {
    metadata: {
      ...method.metadata,
      otpHash,
      otpExpiresAt: expiresAt.toISOString(),
      otpAttempts: 0,
      otpMaxAttempts: maxAttempts,
      lastOtpSentAt: new Date().toISOString(),
      resendCooldownSeconds,
    },
  });

  try {
    const smsProvider = getSmsProvider();
    await smsProvider.sendOtp(phoneNumber, otp);
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
    { methodId: mfaMethodId, methodType: 'sms', phoneNumber: phoneNumber.slice(-9) },
  );

  return { expiresAt, resendAfter: resendCooldownSeconds };
}

export async function verifySmsMfaOtp(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<{ valid: boolean; error?: string }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || method.methodType !== 'sms' || !method.isActive) {
    return { valid: false, error: 'SMS MFA method not found or inactive' };
  }

  const metadata = method.metadata as Record<string, unknown>;
  const otpHash = metadata.otpHash as string | undefined;
  const otpExpiresAt = metadata.otpExpiresAt ? new Date(metadata.otpExpiresAt as string) : undefined;
  const otpAttempts = (metadata.otpAttempts as number) || 0;
  const otpMaxAttempts = (metadata.otpMaxAttempts as number) || 3;

  if (!otpHash || !otpExpiresAt) {
    return { valid: false, error: 'No active SMS challenge. Request a new code.' };
  }

  if (new Date() > otpExpiresAt) {
    await authRepository.updateMfaMethod(mfaMethodId, {
      metadata: { ...metadata, otpHash: undefined, otpExpiresAt: undefined },
    });
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'sms', reason: 'expired' },
    );
    return { valid: false, error: 'SMS code has expired. Request a new code.' };
  }

  if (otpAttempts >= otpMaxAttempts) {
    await authRepository.updateMfaMethod(mfaMethodId, {
      metadata: { ...metadata, otpHash: undefined, otpExpiresAt: undefined },
    });
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'sms', reason: 'max_attempts_exceeded' },
    );
    return { valid: false, error: 'Too many failed attempts. Request a new code.' };
  }

  const codeHash = hashOtp(code);
  if (!timingSafeEqual(Buffer.from(codeHash), Buffer.from(otpHash))) {
    const newAttempts = await authRepository.incrementMfaCodeAttempt(mfaMethodId, 'otp', otpHash, otpMaxAttempts);
    if (newAttempts === null) return { valid: false, error: 'SMS code is invalid or has already been used' };
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'sms', reason: 'invalid_code', attempts: newAttempts },
    );
    return { valid: false, error: 'Invalid SMS code' };
  }

  const consumed = await authRepository.consumeMfaOneTimeCode(mfaMethodId, 'otp', otpHash);
  if (!consumed) {
    return { valid: false, error: 'SMS code is invalid or has already been used' };
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_verified',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'sms' },
  );

  return { valid: true };
}

export async function disableSmsMfaMethod(userId: string, mfaMethodId: string): Promise<void> {
  await authRepository.updateMfaMethod(mfaMethodId, { isActive: false, isVerified: false });
  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_removed',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'sms' },
  );
}

export async function canResendSmsOtp(mfaMethodId: string): Promise<{ canResend: boolean; waitSeconds?: number }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.methodType !== 'sms') {
    return { canResend: false };
  }

  const metadata = method.metadata as Record<string, unknown>;
  const lastSentAt = metadata.lastOtpSentAt ? new Date(metadata.lastOtpSentAt as string) : null;
  const resendCooldown = (metadata.resendCooldownSeconds as number) || 60;

  if (!lastSentAt) return { canResend: true };

  const elapsed = (Date.now() - lastSentAt.getTime()) / 1000;
  if (elapsed >= resendCooldown) {
    return { canResend: true };
  }

  return { canResend: false, waitSeconds: Math.ceil(resendCooldown - elapsed) };
}
