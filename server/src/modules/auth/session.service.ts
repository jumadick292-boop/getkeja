import { randomUUID, createHash } from 'node:crypto';
import { getRedisClient } from '../../db/redis.js';
import { loadEnv } from '../../config/env.js';
import * as authRepository from './auth.repository.js';
import * as jwtService from './jwt.service.js';
import type {
  AuthUser,
  Session,
  RefreshToken,
  Device,
  SessionResult,
  TokenPair,
  DeviceRegistrationInput,
  DeviceUpdateInput,
} from './auth.types.js';
import { UnauthorizedError, ForbiddenError, HttpError } from '../../shared/errors.js';

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function getEnv() {
  return loadEnv();
}

export async function createSessionForUser(
  user: AuthUser,
  deviceInfo: {
    deviceId: string | null;
    userAgent: string | null;
    ipAddress: string | null;
  },
): Promise<SessionResult> {
  const e = getEnv();

  const familyId = randomUUID();
  const sessionId = randomUUID();

  // Create tokens first
  const tokenPair = await jwtService.createTokenPair(user.id, sessionId, familyId);

  const sessionTokenHash = hashToken(tokenPair.accessToken);
  const refreshTokenHash = hashToken(tokenPair.refreshToken);

  const idleTimeoutMinutes = e.SESSION_IDLE_TIMEOUT_MINUTES;
  const absoluteTimeoutHours = e.SESSION_ABSOLUTE_TIMEOUT_HOURS;

  // Create session in database
  const refreshExpiresAt = new Date(Date.now() + e.REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
  const session = await authRepository.createManagedSession({
    userId: user.id,
    sessionId,
    tokenHash: sessionTokenHash,
    refreshTokenHash,
    familyId,
    deviceId: deviceInfo.deviceId,
    userAgent: deviceInfo.userAgent,
    ipAddress: deviceInfo.ipAddress,
    idleTimeoutMinutes,
    absoluteTimeoutHours,
    refreshExpiresAt,
  });

  // Update device activity if device provided
  if (deviceInfo.deviceId) {
    await authRepository.updateDeviceActivity(deviceInfo.deviceId, deviceInfo.ipAddress);
  }

  return {
    user,
    accessToken: tokenPair.accessToken,
    refreshToken: tokenPair.refreshToken,
    sessionId: session.id,
    expiresIn: tokenPair.expiresIn,
  };
}

export async function refreshAccessToken(
  refreshToken: string,
  deviceInfo: {
    userAgent: string | null;
    ipAddress: string | null;
  },
): Promise<TokenPair> {
  const e = getEnv();
  const refreshTokenHash = hashToken(refreshToken);

  // Verify the JWT
  const jwtPayload = await jwtService.verifyRefreshToken(refreshToken);
  if (!jwtPayload) {
    throw new UnauthorizedError('Invalid or expired refresh token');
  }

  // Find the refresh token in database
  const storedToken = await authRepository.findRefreshTokenByHash(refreshTokenHash);
  if (!storedToken) {
    throw new UnauthorizedError('Invalid or expired refresh token');
  }

  if (storedToken.consumedAt || storedToken.isRevoked) {
    await authRepository.revokeRefreshTokenFamily(storedToken.familyId, 'token_reuse_detected');
    await authRepository.revokeSession(storedToken.sessionId, storedToken.userId, 'token_reuse_detected');
    throw new UnauthorizedError('Token reuse detected. Session revoked for security.');
  }

  // Verify token belongs to the same session
  if (
    storedToken.sessionId !== jwtPayload.sid ||
    storedToken.userId !== jwtPayload.sub ||
    storedToken.familyId !== jwtPayload.fid ||
    storedToken.expiresAt <= new Date()
  ) {
    throw new UnauthorizedError('Invalid refresh token');
  }

  // Check if session is still valid
  const currentSession = await authRepository.findSessionById(jwtPayload.sid);
  if (!currentSession || currentSession.userId !== jwtPayload.sub) {
    throw new UnauthorizedError('Session no longer valid');
  }

  // Check if session is revoked or expired
  if (currentSession.revokedAt || currentSession.idleExpiresAt < new Date() || currentSession.absoluteExpiresAt < new Date()) {
    throw new UnauthorizedError('Session expired or revoked');
  }

  // Rotate the refresh token
  const newFamilyId = jwtPayload.fid; // Keep same family for rotation
  const newTokenPair = await jwtService.createTokenPair(jwtPayload.sub, jwtPayload.sid, newFamilyId);

  const newRefreshTokenHash = hashToken(newTokenPair.refreshToken);
  const newAccessTokenHash = hashToken(newTokenPair.accessToken);
  const newRefreshExpiresAt = new Date(Date.now() + e.REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  // Consume old token and create new one transactionally
  const newStoredToken = await authRepository.consumeRefreshToken(
    storedToken.id,
    newAccessTokenHash,
    newRefreshTokenHash,
    newFamilyId,
    newRefreshExpiresAt,
  );

  if (!newStoredToken) {
    await authRepository.revokeRefreshTokenFamily(storedToken.familyId, 'token_reuse_detected');
    await authRepository.revokeSession(storedToken.sessionId, storedToken.userId, 'token_reuse_detected');
    throw new UnauthorizedError('Refresh token is no longer valid');
  }

  // Update session's refresh token hash
  // Note: We don't update session.token_hash as access tokens are stateless

  // Update device activity
  if (currentSession.deviceId) {
    await authRepository.updateDeviceActivity(currentSession.deviceId, deviceInfo.ipAddress);
  }

  // Extend session idle timeout if configured
  if (e.SESSION_EXTEND_ON_ACTIVITY) {
    await authRepository.updateSessionActivity(currentSession.id, e.SESSION_IDLE_TIMEOUT_MINUTES);
  }

  return {
    accessToken: newTokenPair.accessToken,
    refreshToken: newTokenPair.refreshToken,
    expiresIn: newTokenPair.expiresIn,
  };
}

export async function validateAccessToken(accessToken: string): Promise<{ user: AuthUser; session: Session } | null> {
  const jwtPayload = await jwtService.verifyAccessToken(accessToken);
  if (!jwtPayload) {
    return null;
  }

  const tokenHash = hashToken(accessToken);
  const session = await authRepository.findSessionByTokenHash(tokenHash);
  if (!session) {
    return null;
  }

  // Check if session is revoked or expired
  if (session.revokedAt || session.idleExpiresAt < new Date() || session.absoluteExpiresAt < new Date()) {
    return null;
  }

  // Get user with roles
  const user = await authRepository.findUserWithRolesById(jwtPayload.sub);
  if (!user) {
    return null;
  }

  // Check account status
  if (
    user.accountStatus !== 'active' ||
    user.deletedAt !== null ||
    !user.isActive ||
    user.isSuspended ||
    user.isLocked ||
    user.isDeactivated ||
    (user.mfaEnrollmentRequired && !user.mfaEnrolledAt)
  ) {
    return null;
  }

  return { user, session };
}

export async function revokeSession(sessionId: string, userId: string, reason: string): Promise<boolean> {
  // Get session to find refresh tokens
  const sessions = await authRepository.findSessionsByUserId(userId);
  const session = sessions.find(s => s.id === sessionId);
  if (!session) return false;

  // Revoke session
  const result = await authRepository.revokeSession(sessionId, userId, reason);
  if (!result) return false;

  // Revoke associated refresh tokens
  const refreshTokens = await authRepository.findRefreshTokensBySessionId(sessionId);
  for (const rt of refreshTokens) {
    await authRepository.revokeRefreshTokenById(rt.id, reason);
  }

  // Log security event
  await authRepository.createSecurityEvent(
    userId,
    'session_revoked',
    'session',
    'info',
    null,
    null,
    { sessionId, reason },
  );

  return true;
}

export async function revokeAllUserSessions(userId: string, reason: string): Promise<number> {
  const count = await authRepository.revokeAllUserSessions(userId, reason);
  if (count > 0) {
    await authRepository.revokeAllUserRefreshTokens(userId, reason);
    await authRepository.createSecurityEvent(
      userId,
      'all_sessions_revoked',
      'session',
      'warning',
      null,
      null,
      { count, reason },
    );
  }
  return count;
}

export async function getUserSessions(userId: string): Promise<Session[]> {
  return authRepository.findSessionsByUserId(userId);
}

export async function getCurrentSession(userId: string): Promise<Session | undefined> {
  return authRepository.findCurrentSessionByUserId(userId);
}

// Device management
export async function registerDevice(
  userId: string,
  input: DeviceRegistrationInput,
  ipAddress: string | null,
): Promise<Device> {
  const e = getEnv();
  if (input.pushToken && !e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY) {
    throw new HttpError('Device push token encryption is not configured', 503);
  }

  // Check device limit
  const activeCount = await authRepository.countActiveDevices(userId);
  if (activeCount >= e.DEVICE_MAX_PER_USER) {
    throw new ForbiddenError(`Maximum number of devices (${e.DEVICE_MAX_PER_USER}) reached`);
  }

  // Check if device already exists
  const existing = await authRepository.findDeviceByIdentifier(userId, input.deviceIdentifier);
  if (existing) {
    // Update existing device
    const updates: DeviceUpdateInput = {
      deviceName: input.deviceName,
      deviceModel: input.deviceModel,
      osVersion: input.osVersion,
      appVersion: input.appVersion,
      pushProvider: input.pushProvider,
    };

    // Encrypt push token if provided
    let pushTokenEncrypted: Buffer | null = null;
    let pushTokenIv: Buffer | null = null;
    let pushTokenAuthTag: Buffer | null = null;

    if (input.pushToken && e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY) {
      // Use the encryption service
      const { encryptPushToken } = await import('./crypto.js');
      const encrypted = encryptPushToken(input.pushToken, e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY);
      pushTokenEncrypted = encrypted.encrypted;
      pushTokenIv = encrypted.iv;
      pushTokenAuthTag = encrypted.authTag;
      updates.pushProvider = input.pushProvider;
    }

    return authRepository.updateDevice(existing.id, userId, {
      ...updates,
      pushTokenEncrypted,
      pushTokenIv,
      pushTokenAuthTag,
    }) as Promise<Device>;
  }

  // Encrypt push token if provided
  let pushTokenEncrypted: Buffer | null = null;
  let pushTokenIv: Buffer | null = null;
  let pushTokenAuthTag: Buffer | null = null;

  if (input.pushToken && e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY) {
    const { encryptPushToken } = await import('./crypto.js');
    const encrypted = encryptPushToken(input.pushToken, e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY);
    pushTokenEncrypted = encrypted.encrypted;
    pushTokenIv = encrypted.iv;
    pushTokenAuthTag = encrypted.authTag;
  }

  const device = await authRepository.createDevice(
    userId,
    input.deviceIdentifier,
    input.platform,
    input.deviceName ?? null,
    input.deviceModel ?? null,
    input.osVersion ?? null,
    input.appVersion ?? null,
    input.pushProvider ?? null,
    pushTokenEncrypted,
    pushTokenIv,
    pushTokenAuthTag,
  );

  await authRepository.createSecurityEvent(
    userId,
    'device_registered',
    'device',
    'info',
    ipAddress,
    null,
    { deviceId: device.id, platform: device.platform, deviceName: device.deviceName },
  );

  return device;
}

export async function getUserDevices(userId: string): Promise<Device[]> {
  return authRepository.findDevicesByUserId(userId);
}

export async function updateDevice(
  deviceId: string,
  userId: string,
  input: DeviceUpdateInput,
): Promise<Device | undefined> {
  const e = getEnv();
  if (input.pushToken && !e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY) {
    throw new HttpError('Device push token encryption is not configured', 503);
  }

  // Encrypt push token if provided
  let pushTokenEncrypted: Buffer | null = null;
  let pushTokenIv: Buffer | null = null;
  let pushTokenAuthTag: Buffer | null = null;

  if (input.pushToken && e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY) {
    const { encryptPushToken } = await import('./crypto.js');
    const encrypted = encryptPushToken(input.pushToken, e.DEVICE_PUSH_TOKEN_ENCRYPTION_KEY);
    pushTokenEncrypted = encrypted.encrypted;
    pushTokenIv = encrypted.iv;
    pushTokenAuthTag = encrypted.authTag;
  }

  return authRepository.updateDevice(deviceId, userId, {
    deviceName: input.deviceName,
    deviceModel: input.deviceModel,
    osVersion: input.osVersion,
    appVersion: input.appVersion,
    pushProvider: input.pushProvider,
    pushTokenEncrypted,
    pushTokenIv,
    pushTokenAuthTag,
  });
}

export async function revokeDevice(deviceId: string, userId: string, reason: string): Promise<boolean> {
  const device = await authRepository.findDeviceById(deviceId);
  if (!device || device.userId !== userId) {
    return false;
  }

  const result = await authRepository.revokeDevice(deviceId, userId, reason);
  if (!result) return false;

  // Revoke all sessions for this device
  const sessions = await authRepository.findSessionsByUserId(userId);
  const deviceSessions = sessions.filter(s => s.deviceId === deviceId);
  for (const session of deviceSessions) {
    await authRepository.revokeSession(session.id, userId, `device_revoked: ${reason}`);
    const refreshTokens = await authRepository.findRefreshTokensBySessionId(session.id);
    for (const rt of refreshTokens) {
      await authRepository.revokeRefreshTokenById(rt.id, `device_revoked: ${reason}`);
    }
  }

  await authRepository.createSecurityEvent(
    userId,
    'device_revoked',
    'device',
    'warning',
    null,
    null,
    { deviceId, reason, revokedSessions: deviceSessions.length },
  );

  return true;
}

export async function revokeAllUserDevices(userId: string, reason: string): Promise<number> {
  const count = await authRepository.revokeAllUserDevices(userId, reason);
  if (count > 0) {
    // Also revoke all sessions
    await revokeAllUserSessions(userId, `all_devices_revoked: ${reason}`);
    await authRepository.createSecurityEvent(
      userId,
      'all_devices_revoked',
      'device',
      'warning',
      null,
      null,
      { count, reason },
    );
  }
  return count;
}

export async function logoutCurrentSession(
  sessionId: string,
  userId: string,
): Promise<void> {
  await revokeSession(sessionId, userId, 'logout');
}

export async function logoutAllSessions(
  userId: string,
): Promise<void> {
  await revokeAllUserSessions(userId, 'logout_all');
}

// Password change integration
export async function handlePasswordChange(userId: string): Promise<void> {
  await revokeAllUserSessions(userId, 'password_changed');
  await authRepository.createSecurityEvent(
    userId,
    'password_changed_sessions_revoked',
    'authentication',
    'info',
    null,
    null,
    { reason: 'password_changed' },
  );
}

// Account suspension/deactivation integration
export async function handleAccountSuspension(userId: string): Promise<void> {
  await revokeAllUserSessions(userId, 'account_suspended');
  await authRepository.createSecurityEvent(
    userId,
    'account_suspended_sessions_revoked',
    'authentication',
    'critical',
    null,
    null,
    { reason: 'account_suspended' },
  );
}

export async function handleAccountDeactivation(userId: string): Promise<void> {
  await revokeAllUserSessions(userId, 'account_deactivated');
  await authRepository.createSecurityEvent(
    userId,
    'account_deactivated_sessions_revoked',
    'authentication',
    'critical',
    null,
    null,
    { reason: 'account_deactivated' },
  );
}

// MFA compromise integration
export async function handleMfaCompromise(userId: string): Promise<void> {
  await revokeAllUserSessions(userId, 'mfa_compromise');
  await authRepository.revokeAllUserRefreshTokens(userId, 'mfa_compromise');
  await authRepository.createSecurityEvent(
    userId,
    'mfa_compromise_sessions_revoked',
    'authentication',
    'critical',
    null,
    null,
    { reason: 'mfa_compromise' },
  );
}

// Cleanup functions
export async function cleanupExpiredSessions(): Promise<number> {
  return authRepository.deleteExpiredSessions();
}

export async function cleanupInactiveDevices(maxInactiveDays: number): Promise<number> {
  return authRepository.deleteExpiredDevices(maxInactiveDays);
}