import * as authRepository from '../auth.repository.js';
import { loadEnv } from '../../../config/env.js';
import * as totpService from './totp.js';
import * as smsService from './sms.js';
import * as emailService from './email.js';
import * as recoveryService from './recovery.js';
import type {
  AuthUser,
  MfaMethod,
  MfaEnrollmentStartResult,
  MfaEnrollmentVerifyResult,
  MfaStatusResult,
  MfaChallengeResult,
  MfaVerifyResult,
  MfaMethodType,
} from '../auth.types.js';

function getEnv() {
  return loadEnv();
}

function getMfaConfig() {
  const env = getEnv();
  return {
    challengeExpiryMinutes: env.MFA_CHALLENGE_EXPIRY_MINUTES || 10,
    challengeMaxAttempts: env.MFA_CHALLENGE_MAX_ATTEMPTS || 3,
  };
}

export async function startMfaEnrollment(
  userId: string,
  methodType: MfaMethodType,
  options: { methodName?: string; phoneNumber?: string; makePrimary?: boolean } = {},
): Promise<MfaEnrollmentStartResult> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const existingMethods = await authRepository.findMfaMethodsByUserId(userId);
  const hasPrimary = existingMethods.some(m => m.isPrimary && m.isActive && !m.deletedAt);
  const makePrimary = options.makePrimary ?? !hasPrimary;

  let result: MfaEnrollmentStartResult;

  switch (methodType) {
    case 'totp': {
      const { method, secret, provisioningUri, qrCodeDataUrl } = await totpService.createTotpMethod(
        userId,
        options.methodName || null,
        makePrimary,
      );
      result = {
        method: 'totp',
        methodId: method.id,
        provisioningUri,
        qrCodeDataUrl,
        secret, // Only returned once during enrollment
      };
      break;
    }
    case 'sms': {
      if (!options.phoneNumber) {
        throw new Error('Phone number required for SMS MFA');
      }
      const normalizedPhone = options.phoneNumber.replace(/[\s\-\(\)]/g, '');
      if (!normalizedPhone.startsWith('+254')) {
        throw new Error('Invalid Kenyan phone number format');
      }
      const method = await smsService.createSmsMfaMethod(userId, normalizedPhone, options.methodName || null, makePrimary);
      result = { method: 'sms', methodId: method.id };
      break;
    }
    case 'email': {
      if (!user.emailVerified) {
        throw new Error('Email must be verified before enabling email MFA');
      }
      const method = await emailService.createEmailMfaMethod(userId, options.methodName || null, makePrimary);
      result = { method: 'email', methodId: method.id };
      break;
    }
    case 'recovery_codes': {
      const { method, codes } = await recoveryService.createRecoveryCodesMethod(userId, makePrimary);
      result = { method: 'recovery_codes', methodId: method.id, recoveryCodes: codes };
      break;
    }
    default:
      throw new Error(`Unsupported MFA method type: ${methodType}`);
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_enrollment_started',
    'mfa',
    'info',
    null,
    null,
    { methodType, methodName: options.methodName },
  );

  return result;
}

export async function verifyMfaEnrollment(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<MfaEnrollmentVerifyResult> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId) {
    return { success: false, message: 'MFA method not found' };
  }

  let valid = false;

  switch (method.methodType) {
    case 'totp': {
      const { valid: isValid } = await totpService.verifyTotpCode(userId, mfaMethodId, code);
      valid = isValid;
      break;
    }
    case 'sms': {
      const { valid: isValid } = await smsService.verifySmsMfaOtp(userId, mfaMethodId, code);
      valid = isValid;
      break;
    }
    case 'email': {
      const { valid: isValid } = await emailService.verifyEmailMfaCode(userId, mfaMethodId, code);
      valid = isValid;
      break;
    }
    case 'recovery_codes': {
      // Recovery codes don't need enrollment verification - they're verified on use
      valid = true;
      break;
    }
    default:
      return { success: false, message: 'Unsupported MFA method type' };
  }

  if (!valid) {
    return { success: false, message: 'Invalid verification code' };
  }

  await authRepository.updateMfaMethod(mfaMethodId, { isVerified: true });

  if (method.methodType !== 'recovery_codes') {
    await authRepository.updateUserMfaEnrolled(userId, true);
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_enrolled',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: method.methodType },
  );

  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const hasVerifiedMethod = methods.some(m => m.isVerified && m.isActive && !m.deletedAt);
  const mfaStatus = hasVerifiedMethod ? 'enrolled' : 'pending';

  return { success: true, message: 'MFA method verified and activated', mfaStatus };
}

export async function getMfaStatus(userId: string): Promise<MfaStatusResult> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const recoveryStatus = await recoveryService.getRecoveryCodesStatus(userId);

  const hasVerifiedMethod = methods.some(m => m.isVerified && m.isActive && !m.deletedAt);
  const mfaEnabled = user.mfaEnabled && hasVerifiedMethod;
  const enrollmentRequired = user.mfaEnrollmentRequired && !hasVerifiedMethod;

  return {
    mfaEnabled,
    mfaEnrolled: hasVerifiedMethod,
    enrollmentRequired,
    methods: methods.filter(m => !m.deletedAt),
    recoveryCodesRemaining: recoveryStatus.remainingCodes,
  };
}

export async function getMfaMethods(userId: string): Promise<MfaMethod[]> {
  const methods = await authRepository.findMfaMethodsByUserId(userId);
  return methods.filter(m => !m.deletedAt);
}

export async function requestMfaEnrollmentCode(
  userId: string,
  mfaMethodId: string,
): Promise<{ methodType: 'sms' | 'email'; expiresAt: Date }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || !method.isActive || method.isVerified) {
    throw new Error('Pending MFA method not found');
  }
  return requestMfaMethodCode(userId, mfaMethodId);
}

export async function requestMfaMethodCode(
  userId: string,
  mfaMethodId: string,
): Promise<{ methodType: 'sms' | 'email'; expiresAt: Date }> {
  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId || !method.isActive) {
    throw new Error('MFA method not found or inactive');
  }
  if (method.methodType === 'sms') {
    const result = await smsService.sendSmsMfaOtp(userId, method.id);
    return { methodType: 'sms', expiresAt: result.expiresAt };
  }
  if (method.methodType === 'email') {
    const result = await emailService.sendEmailMfaCode(userId, method.id);
    return { methodType: 'email', expiresAt: result.expiresAt };
  }
  throw new Error('This MFA method does not use a verification code');
}

export async function requestMfaChallengeCode(
  challengeId: string,
  methodType: 'sms' | 'email',
): Promise<{ expiresAt: Date }> {
  const challenge = await authRepository.findMfaChallenge(challengeId);
  if (!challenge || challenge.status !== 'pending' || challenge.expiresAt <= new Date()) {
    throw new Error('MFA challenge not found or expired');
  }
  const data = challenge.challengeData as Record<string, unknown>;
  const availableMethods = (data.methods as MfaMethodType[] | undefined) ?? [];
  if (!availableMethods.includes(methodType)) {
    throw new Error('This MFA method is not available for this challenge');
  }
  const methods = await authRepository.findMfaMethodsByUserId(challenge.userId);
  const method = methods.find(m => m.methodType === methodType && m.isVerified && m.isActive && !m.deletedAt);
  if (!method) throw new Error('MFA method not configured');

  const result = methodType === 'sms'
    ? await smsService.sendSmsMfaOtp(challenge.userId, method.id)
    : await emailService.sendEmailMfaCode(challenge.userId, method.id);
  return { expiresAt: result.expiresAt };
}

export async function createMfaLoginChallenge(
  userId: string,
  ipAddress?: string,
  userAgent?: string,
): Promise<MfaChallengeResult> {
  const { challengeExpiryMinutes, challengeMaxAttempts } = getMfaConfig();
  const expiresAt = new Date(Date.now() + challengeExpiryMinutes * 60 * 1000);

  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const activeVerifiedMethods = methods.filter(m => m.isVerified && m.isActive && !m.deletedAt);

  if (activeVerifiedMethods.length === 0) {
    throw new Error('No verified MFA methods available');
  }

  const availableMethods = Array.from(new Set(
    await Promise.all(activeVerifiedMethods.map(async method => {
      if (method.methodType === 'totp' && !(await authRepository.findMfaTotpSecretByMethodId(method.id))) {
        return null;
      }
      return method.methodType;
    })),
  )).filter((method): method is MfaMethodType => method !== null);
  const recoveryMethod = methods.find(
    m => m.methodType === 'recovery_codes' && m.isVerified && m.isActive && !m.deletedAt,
  );
  if (recoveryMethod && await authRepository.countUnusedRecoveryCodes(userId) > 0) {
    availableMethods.push('recovery_codes');
  }

  const challengeData = {
    methods: availableMethods,
    ipAddress,
    userAgent,
  };

  const challenge = await authRepository.createMfaChallenge(
    userId,
    'multi',
    challengeData,
    expiresAt,
    challengeMaxAttempts,
  );

  await authRepository.createSecurityEvent(
    userId,
    'mfa_challenge_created',
    'mfa',
    'info',
    ipAddress || null,
    userAgent || null,
    { challengeId: challenge.id, availableMethods },
  );

  return {
    challengeId: challenge.id,
    availableMethods,
    expiresAt: challenge.expiresAt,
  };
}

export async function verifyMfaChallenge(
  userId: string,
  challengeId: string,
  methodType: MfaMethodType,
  code: string,
  ipAddress?: string,
  userAgent?: string,
): Promise<MfaVerifyResult> {
  const challenge = await authRepository.findMfaChallenge(challengeId);
  if (!challenge) {
    return { success: false, message: 'Invalid or expired MFA challenge' };
  }

  if (challenge.userId !== userId) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      ipAddress || null,
      userAgent || null,
      { challengeId, reason: 'challenge_user_mismatch' },
    );
    return { success: false, message: 'Invalid MFA challenge' };
  }

  if (challenge.status !== 'pending') {
    return { success: false, message: 'MFA challenge is no longer valid' };
  }

  if (challenge.expiresAt < new Date()) {
    await authRepository.expireMfaChallenge(challengeId);
    return { success: false, message: 'MFA challenge has expired' };
  }

  if (challenge.failedAttempts >= challenge.maxAttempts) {
    await authRepository.failMfaChallenge(challengeId);
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      ipAddress || null,
      userAgent || null,
      { challengeId, methodType, reason: 'max_attempts_exceeded' },
    );
    return { success: false, message: 'Too many failed MFA attempts. Please start login again.' };
  }

  const challengeData = challenge.challengeData as Record<string, unknown>;
  const availableMethods = (challengeData.methods as MfaMethodType[]) || [];

  if (!availableMethods.includes(methodType)) {
    await authRepository.failMfaChallenge(challengeId);
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'critical',
      ipAddress || null,
      userAgent || null,
      { challengeId, methodType, reason: 'method_not_allowed' },
    );
    return { success: false, message: 'This MFA method is not available for this challenge' };
  }

  let valid = false;

  switch (methodType) {
    case 'totp': {
      const totpMethod = (await authRepository.findMfaMethodsByUserId(userId)).find(
        m => m.methodType === 'totp' && m.isVerified && m.isActive && !m.deletedAt,
      );
      if (!totpMethod) {
        return { success: false, message: 'TOTP method not configured' };
      }
      const { valid: isValid } = await totpService.verifyTotpCode(userId, totpMethod.id, code);
      valid = isValid;
      break;
    }
    case 'sms': {
      const smsMethod = (await authRepository.findMfaMethodsByUserId(userId)).find(m => m.methodType === 'sms' && m.isVerified && m.isActive && !m.deletedAt);
      if (!smsMethod) {
        return { success: false, message: 'SMS MFA method not configured' };
      }
      const { valid: isValid } = await smsService.verifySmsMfaOtp(userId, smsMethod.id, code);
      valid = isValid;
      break;
    }
    case 'email': {
      const emailMethod = (await authRepository.findMfaMethodsByUserId(userId)).find(m => m.methodType === 'email' && m.isVerified && m.isActive && !m.deletedAt);
      if (!emailMethod) {
        return { success: false, message: 'Email MFA method not configured' };
      }
      const { valid: isValid } = await emailService.verifyEmailMfaCode(userId, emailMethod.id, code);
      valid = isValid;
      break;
    }
    case 'recovery_codes': {
      const recoveryMethod = (await authRepository.findMfaMethodsByUserId(userId)).find(m => m.methodType === 'recovery_codes' && m.isActive && !m.deletedAt);
      if (!recoveryMethod) {
        return { success: false, message: 'Recovery codes not configured' };
      }
      const { valid: isValid } = await recoveryService.verifyRecoveryCode(userId, recoveryMethod.id, code);
      valid = isValid;
      break;
    }
    default:
      await authRepository.failMfaChallenge(challengeId);
      return { success: false, message: 'Unsupported MFA method type' };
  }

  if (!valid) {
    await authRepository.failMfaChallenge(challengeId);
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      ipAddress || null,
      userAgent || null,
      { challengeId, methodType, reason: 'invalid_code', failedAttempts: challenge.failedAttempts + 1 },
    );
    return { success: false, message: 'Invalid MFA code' };
  }

  const completed = await authRepository.completeMfaChallenge(challengeId);
  if (!completed) {
    return { success: false, message: 'MFA challenge is no longer valid' };
  }
  await authRepository.updateUserLastMfaVerified(userId);

  const user = await authRepository.findUserWithRolesById(userId);
  if (!user) {
    throw new Error('User not found after MFA verification');
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_verified',
    'mfa',
    'info',
    ipAddress || null,
    userAgent || null,
    { challengeId, methodType },
  );

  return {
    success: true,
    message: 'MFA verification successful',
    authenticationStatus: 'complete',
    user,
  };
}

export async function addMfaMethod(
  userId: string,
  methodType: MfaMethodType,
  options: { methodName?: string; phoneNumber?: string; makePrimary?: boolean } = {},
): Promise<MfaEnrollmentStartResult> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  const existingMethods = await authRepository.findMfaMethodsByUserId(userId);
  const hasPrimary = existingMethods.some(m => m.isPrimary && m.isActive && !m.deletedAt);
  const makePrimary = options.makePrimary ?? !hasPrimary;

  // Require recent MFA verification for sensitive changes
  const hoursSinceLastMfa = user.lastMfaVerifiedAt
    ? (Date.now() - user.lastMfaVerifiedAt.getTime()) / (1000 * 60 * 60)
    : Infinity;
  if (user.mfaEnabled && hoursSinceLastMfa > 24) {
    throw new Error('Recent MFA verification required. Please complete MFA challenge first.');
  }

  return startMfaEnrollment(userId, methodType, { ...options, makePrimary });
}

export async function verifyMfaMethod(
  userId: string,
  mfaMethodId: string,
  code: string,
): Promise<MfaEnrollmentVerifyResult> {
  // Require recent MFA verification for sensitive changes
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }
  const hoursSinceLastMfa = user.lastMfaVerifiedAt
    ? (Date.now() - user.lastMfaVerifiedAt.getTime()) / (1000 * 60 * 60)
    : Infinity;
  if (user.mfaEnabled && hoursSinceLastMfa > 24) {
    throw new Error('Recent MFA verification required. Please complete MFA challenge first.');
  }

  return verifyMfaEnrollment(userId, mfaMethodId, code);
}

export async function disableMfaMethod(
  userId: string,
  mfaMethodId: string,
  verificationCode: string,
): Promise<{ success: boolean; message: string }> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Require fresh MFA verification before disabling
  const hoursSinceLastMfa = user.lastMfaVerifiedAt
    ? (Date.now() - user.lastMfaVerifiedAt.getTime()) / (1000 * 60 * 60)
    : Infinity;

  if (hoursSinceLastMfa > 1) {
    throw new Error('Fresh MFA verification required. Please complete MFA challenge first.');
  }

  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId) {
    throw new Error('MFA method not found');
  }

  // Verify the provided code using the method being disabled (or any active method)
  let verified = false;
  if (method.methodType === 'totp') {
    const { valid } = await totpService.verifyTotpCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'sms') {
    const { valid } = await smsService.verifySmsMfaOtp(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'email') {
    const { valid } = await emailService.verifyEmailMfaCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'recovery_codes') {
    const { valid } = await recoveryService.verifyRecoveryCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  }

  if (!verified) {
    await authRepository.createSecurityEvent(
      userId,
      'mfa_failed',
      'mfa',
      'warning',
      null,
      null,
      { methodId: mfaMethodId, methodType: method.methodType, reason: 'disable_verification_failed' },
    );
    throw new Error('Invalid verification code');
  }

  // Check if this is the last active verified method
  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const activeVerifiedMethods = methods.filter(m => m.isVerified && m.isActive && !m.deletedAt);
  if (activeVerifiedMethods.length <= 1 && activeVerifiedMethods[0]?.id === mfaMethodId) {
    throw new Error('Cannot disable the last active MFA method. Add another method first.');
  }

  switch (method.methodType) {
    case 'totp':
      await totpService.disableTotpMethod(userId, mfaMethodId);
      break;
    case 'sms':
      await smsService.disableSmsMfaMethod(userId, mfaMethodId);
      break;
    case 'email':
      await emailService.disableEmailMfaMethod(userId, mfaMethodId);
      break;
    case 'recovery_codes':
      await recoveryService.disableRecoveryCodesMethod(userId, mfaMethodId);
      break;
  }

  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_removed',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: method.methodType },
  );

  // Check if user still has any verified methods
  const remainingMethods = await authRepository.findMfaMethodsByUserId(userId);
  const hasVerifiedMethod = remainingMethods.some(m => m.isVerified && m.isActive && !m.deletedAt);
  if (!hasVerifiedMethod) {
    await authRepository.updateUserMfaEnrolled(userId, false);
  }

  return { success: true, message: 'MFA method disabled successfully' };
}

export async function setPrimaryMfaMethod(
  userId: string,
  mfaMethodId: string,
  verificationCode: string,
): Promise<{ success: boolean; message: string }> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Require fresh MFA verification
  const hoursSinceLastMfa = user.lastMfaVerifiedAt
    ? (Date.now() - user.lastMfaVerifiedAt.getTime()) / (1000 * 60 * 60)
    : Infinity;

  if (hoursSinceLastMfa > 1) {
    throw new Error('Fresh MFA verification required. Please complete MFA challenge first.');
  }

  const method = await authRepository.findMfaMethodById(mfaMethodId);
  if (!method || method.userId !== userId) {
    throw new Error('MFA method not found');
  }

  if (!method.isVerified || !method.isActive) {
    throw new Error('Cannot set unverified or inactive method as primary');
  }

  // Verify the provided code
  let verified = false;
  if (method.methodType === 'totp') {
    const { valid } = await totpService.verifyTotpCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'sms') {
    const { valid } = await smsService.verifySmsMfaOtp(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'email') {
    const { valid } = await emailService.verifyEmailMfaCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  } else if (method.methodType === 'recovery_codes') {
    const { valid } = await recoveryService.verifyRecoveryCode(userId, mfaMethodId, verificationCode);
    verified = valid;
  }

  if (!verified) {
    throw new Error('Invalid verification code');
  }

  await authRepository.setPrimaryMfaMethod(userId, mfaMethodId);

  await authRepository.createSecurityEvent(
    userId,
    'mfa_method_set_primary',
    'mfa',
    'info',
    null,
    null,
    { methodId: mfaMethodId, methodType: method.methodType },
  );

  return { success: true, message: 'Primary MFA method updated' };
}

export async function regenerateRecoveryCodes(
  userId: string,
  verificationCode: string,
): Promise<{ success: boolean; message: string; codes: string[] }> {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Require fresh MFA verification
  const hoursSinceLastMfa = user.lastMfaVerifiedAt
    ? (Date.now() - user.lastMfaVerifiedAt.getTime()) / (1000 * 60 * 60)
    : Infinity;

  if (hoursSinceLastMfa > 1) {
    throw new Error('Fresh MFA verification required. Please complete MFA challenge first.');
  }

  const methods = await authRepository.findMfaMethodsByUserId(userId);
  const recoveryMethod = methods.find(m => m.methodType === 'recovery_codes' && m.isActive && !m.deletedAt);
  if (!recoveryMethod) {
    throw new Error('Recovery codes not configured');
  }

  // Verify using the recovery code
  const { valid } = await recoveryService.verifyRecoveryCode(userId, recoveryMethod.id, verificationCode);
  if (!valid) {
    throw new Error('Invalid recovery code');
  }

  const { codes } = await recoveryService.regenerateRecoveryCodes(userId, recoveryMethod.id);

  return { success: true, message: 'Recovery codes regenerated', codes };
}
