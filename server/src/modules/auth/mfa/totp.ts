import { generateSecret, generateURI, verify } from 'otplib';
import QRCode from 'qrcode';
import { randomBytes } from 'node:crypto';
import * as authRepository from '../auth.repository.js';
import { loadEnv } from '../../../config/env.js';
import { encryptSecret, decryptSecret } from '../crypto.js';
import type { MfaMethod, MfaTotpSecret } from '../auth.types.js';

function getEnv() {
  return loadEnv();
}

function getTotpConfig() {
  const env = getEnv();
  return {
    issuer: env.MFA_TOTP_ISSUER || 'GetKeja',
    window: env.MFA_TOTP_WINDOW || 1,
    algorithm: (env.MFA_TOTP_ALGORITHM || 'SHA1').toLowerCase() as 'sha1' | 'sha256' | 'sha512',
    digits: env.MFA_TOTP_DIGITS || 6,
    period: env.MFA_TOTP_PERIOD || 30,
  };
}

export function generateTotpSecret(): string {
  return generateSecret();
}

export function generateProvisioningUri(email: string, secret: string): string {
  const config = getTotpConfig();
  return generateURI({
    strategy: 'totp',
    issuer: config.issuer,
    label: email,
    secret,
    algorithm: config.algorithm,
    digits: config.digits,
    period: config.period,
  });
}

export async function generateQrCodeDataUrl(uri: string): Promise<string> {
  return QRCode.toDataURL(uri, {
    errorCorrectionLevel: 'M',
    margin: 2,
    width: 300,
  });
}

export async function createTotpMethod(
  userId: string,
  methodName: string | null,
  isPrimary: boolean,
): Promise<{ method: MfaMethod; secret: string; provisioningUri: string; qrCodeDataUrl: string }> {
  const secret = generateTotpSecret();
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const provisioningUri = generateProvisioningUri(user.email, secret);
  const qrCodeDataUrl = await generateQrCodeDataUrl(provisioningUri);

  const encryptedSecret = encryptSecret(secret);

  const method = await authRepository.createMfaMethod(
    userId,
    'totp',
    methodName || 'Authenticator App',
    isPrimary,
    { issuer: getTotpConfig().issuer },
  );

  const config = getTotpConfig();
  await authRepository.createMfaTotpSecret(
    userId,
    method.id,
    encryptedSecret,
    config.algorithm.toUpperCase(),
    config.digits,
    config.period,
  );

  return { method, secret, provisioningUri, qrCodeDataUrl };
}

export async function verifyTotpCode(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<{ valid: boolean; error?: string }> {
  const totpSecret = await authRepository.findMfaTotpSecretByMethodId(mfaMethodId);
  if (!totpSecret) {
    return { valid: false, error: 'TOTP secret not found' };
  }

  const secret = decryptSecret(totpSecret.encryptedSecret);
  const currentStep = Math.floor(Date.now() / 1000 / totpSecret.period);
  const lastUsedStep = Number(totpSecret.lastUsedStep);

  const config = getTotpConfig();
  const verifyOptions = {
    strategy: 'totp',
    token: code,
    secret,
    algorithm: config.algorithm,
    digits: config.digits,
    period: config.period,
    epochTolerance: config.window,
  } as any;
  if (lastUsedStep >= 0) {
    verifyOptions.afterTimeStep = lastUsedStep;
  }
  const { valid: isValid } = await verify(verifyOptions);

  if (!isValid) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'totp', reason: 'invalid_code' },
    );
    return { valid: false, error: 'Invalid TOTP code' };
  }

  if (currentStep <= lastUsedStep) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'totp', reason: 'replay_attack', currentStep, lastUsedStep },
    );
    return { valid: false, error: 'TOTP code already used (replay detected)' };
  }

  const claimed = await authRepository.updateMfaTotpSecretLastUsedStep(mfaMethodId, currentStep);
  if (!claimed) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'totp', reason: 'replay_attack', currentStep },
    );
    return { valid: false, error: 'TOTP code already used (replay detected)' };
  }

  return { valid: true };
}

export async function getTotpMethodSecret(userId: string, mfaMethodId: string): Promise<string | null> {
  const totpSecret = await authRepository.findMfaTotpSecretByMethodId(mfaMethodId);
  if (!totpSecret) {
    return null;
  }
  return decryptSecret(totpSecret.encryptedSecret);
}

export async function disableTotpMethod(userId: string, mfaMethodId: string): Promise<void> {
  await authRepository.updateMfaMethod(mfaMethodId, { isActive: false, isVerified: false });
  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_removed',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'totp' },
  );
}
