import { randomBytes } from 'node:crypto';
import * as authRepository from '../auth.repository.js';
import { loadEnv } from '../../../config/env.js';
import { generateRecoveryCodes, hashRecoveryCode } from '../crypto.js';
import type { MfaMethod, MfaRecoveryCode } from '../auth.types.js';

function getEnv() {
  return loadEnv();
}

function getRecoveryCodesConfig() {
  const env = getEnv();
  return {
    count: env.MFA_RECOVERY_CODES_COUNT || 10,
    length: env.MFA_RECOVERY_CODE_LENGTH || 10,
  };
}

export async function createRecoveryCodesMethod(
  userId: string,
  isPrimary: boolean,
): Promise<{ method: MfaMethod; codes: string[] }> {
  const codes = generateRecoveryCodes(getRecoveryCodesConfig().count);
  const codeHashes = codes.map(hashRecoveryCode);

  const method = await authRepository.createMfaMethod(
    userId,
    'recovery_codes',
    'Recovery Codes',
    isPrimary,
    { codesGeneratedAt: new Date().toISOString() },
  );

  // Mark recovery codes as verified immediately since they're usable on creation
  await authRepository.updateMfaMethod(method.id, { isVerified: true });

  await authRepository.createMfaRecoveryCodes(userId, method.id, codeHashes);

  await authRepository.createSecurityEvent(
    userId,
    'recovery_codes_generated',
    'mfa',
    'info',
    null,
    null,
    { methodId: method.id, count: codes.length },
  );

  return { method, codes };
}

export async function regenerateRecoveryCodes(
  userId: string,
  mfaMethodId: string,
): Promise<{ codes: string[] }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.methodType !== 'recovery_codes') {
    throw new Error('Recovery codes method not found');
  }

  await authRepository.invalidateAllRecoveryCodes(userId);

  const codes = generateRecoveryCodes(getRecoveryCodesConfig().count);
  const codeHashes = codes.map(hashRecoveryCode);

  await authRepository.createMfaRecoveryCodes(userId, mfaMethodId, codeHashes);

  await authRepository.updateMfaMethod(mfaMethodId, {
    metadata: { ...method.metadata, codesRegeneratedAt: new Date().toISOString() },
  });

  await authRepository.createSecurityEvent(
    userId,
    'recovery_codes_regenerated',
    'mfa',
    'warning',
    null,
    null,
    { methodId: mfaMethodId, count: codes.length },
  );

  return { codes };
}

export async function verifyRecoveryCode(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<{ valid: boolean; error?: string; remainingCodes?: number }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.methodType !== 'recovery_codes' || !method.isActive) {
    return { valid: false, error: 'Recovery codes method not found or inactive' };
  }

  const codeHash = hashRecoveryCode(code.toUpperCase().replace(/-/g, ''));
  const consumedCode = await authRepository.consumeRecoveryCode(userId, codeHash);

  if (!consumedCode) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: 'recovery_codes', reason: 'invalid_or_used_code' },
    );
    return { valid: false, error: 'Invalid or already used recovery code' };
  }

  const remaining = await authRepository.countUnusedRecoveryCodes(userId);

  await authRepository.createSecurityEvent(
    userId,
    'recovery_code_used',
    'mfa',
    'warning',
    null,
    null,
    { methodId: mfaMethodId, remainingCodes: remaining },
  );

  return { valid: true, remainingCodes: remaining };
}

export async function getRecoveryCodesStatus(userId: string): Promise<{ method: MfaMethod | null; remainingCodes: number }> {
  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const recoveryMethod = methods.find(m => m.methodType === 'recovery_codes' && m.deletedAt === null);
  const remainingCodes = await authRepository.countUnusedRecoveryCodes(userId);
  return { method: recoveryMethod || null, remainingCodes };
}

export async function disableRecoveryCodesMethod(userId: string, mfaMethodId: string): Promise<void> {
  await authRepository.updateMfaMethod(mfaMethodId, { isActive: false, isVerified: false });
  await authRepository.invalidateAllRecoveryCodes(userId);
  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_removed',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: 'recovery_codes' },
  );
}