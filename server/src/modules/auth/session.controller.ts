import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError, ForbiddenError, HttpError } from '../../shared/errors.js';
import * as sessionService from './session.service.js';
import * as authRepository from './auth.repository.js';
import type { AuthUser, DeviceRegistrationInput, DeviceUpdateInput } from './auth.types.js';
import { deviceRegistrationSchema, deviceUpdateSchema } from './auth.schema.js';
import { loadEnv } from '../../config/env.js';

const SESSION_COOKIE = 'getkeja_session';
const REFRESH_COOKIE = 'getkeja_refresh';
function getEnv() {
  return loadEnv();
}

function setAuthCookies(res: Response, accessToken: string, refreshToken: string, nodeEnv: string): void {
  const secure = nodeEnv === 'production';
  const sameSite = secure ? 'strict' : 'lax';

  // Access token in Authorization header (Bearer) or short-lived cookie
  res.setHeader('x-access-token', accessToken);

  // Refresh token in HttpOnly cookie
  res.cookie(REFRESH_COOKIE, refreshToken, {
    httpOnly: true,
    secure,
    sameSite,
    maxAge: getEnv().REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
    path: '/api/v1/auth',
  });
}

function clearAuthCookies(res: Response, nodeEnv: string): void {
  const secure = nodeEnv === 'production';
  res.clearCookie(REFRESH_COOKIE, { httpOnly: true, secure, sameSite: 'strict', path: '/api/v1/auth' });
}

function sendSuccessResponse<T>(
  res: Response,
  data: T,
  message: string,
  status = 200,
): void {
  res.status(status).json({ success: true, message, data });
}

function sendErrorResponse(res: Response, message: string, code: string, status = 400): void {
  res.status(status).json({ success: false, message, code });
}

export async function refresh(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const bodyToken = req.body?.refreshToken;
    const refreshToken = typeof bodyToken === 'string'
      ? bodyToken
      : req.cookies?.[REFRESH_COOKIE] as string | undefined;
    if (!refreshToken) {
      throw new UnauthorizedError('Refresh token not provided');
    }

    const nodeEnv = req.app.locals.nodeEnv;
    const ipAddress = Array.isArray(req.ip) ? req.ip[0] : (req.ip || req.socket?.remoteAddress || null);
    const tokenPair = await sessionService.refreshAccessToken(refreshToken, {
      userAgent: req.get('user-agent') || null,
      ipAddress,
    });

    if (typeof bodyToken === 'string') {
      res.setHeader('x-access-token', tokenPair.accessToken);
      sendSuccessResponse(res, tokenPair, 'Token refreshed successfully');
      return;
    }

    setAuthCookies(res, tokenPair.accessToken, tokenPair.refreshToken, nodeEnv);
    sendSuccessResponse(res, { expiresIn: tokenPair.expiresIn }, 'Token refreshed successfully');
  } catch (error) {
    if (error instanceof UnauthorizedError) {
      clearAuthCookies(res, req.app.locals.nodeEnv);
      sendErrorResponse(res, error.message, 'UNAUTHORIZED', 401);
      return;
    }
    next(error);
  }
}

export async function getSessions(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const sessions = await sessionService.getUserSessions(user.id);

    const sanitized = sessions.map((s) => ({
      id: s.id,
      deviceId: s.deviceId,
      userAgent: s.userAgent,
      ipAddress: s.ipAddress,
      countryCode: s.countryCode,
      city: s.city,
      isCurrent: s.isCurrent,
      idleExpiresAt: s.idleExpiresAt,
      absoluteExpiresAt: s.absoluteExpiresAt,
      revokedAt: s.revokedAt,
      revokedReason: s.revokedReason,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    }));

    sendSuccessResponse(res, { sessions: sanitized }, 'Sessions retrieved');
  } catch (error) {
    next(error);
  }
}

export async function getCurrentSession(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const session = await sessionService.getCurrentSession(user.id);
    if (!session) {
      sendErrorResponse(res, 'No active session found', 'SESSION_NOT_FOUND', 404);
      return;
    }

    const sanitized = {
      id: session.id,
      deviceId: session.deviceId,
      userAgent: session.userAgent,
      ipAddress: session.ipAddress,
      countryCode: session.countryCode,
      city: session.city,
      isCurrent: session.isCurrent,
      idleExpiresAt: session.idleExpiresAt,
      absoluteExpiresAt: session.absoluteExpiresAt,
      revokedAt: session.revokedAt,
      revokedReason: session.revokedReason,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    };

    sendSuccessResponse(res, { session: sanitized }, 'Current session retrieved');
  } catch (error) {
    next(error);
  }
}

export async function revokeSession(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const sessionId = Array.isArray(req.params.sessionId) ? req.params.sessionId[0] : req.params.sessionId;
    if (!sessionId) {
      sendErrorResponse(res, 'Session ID required', 'SESSION_ID_REQUIRED', 400);
      return;
    }

    const result = await sessionService.revokeSession(sessionId, user.id, 'user_revoked');
    if (!result) {
      sendErrorResponse(res, 'Session not found or already revoked', 'SESSION_NOT_FOUND', 404);
      return;
    }

    sendSuccessResponse(res, null, 'Session revoked successfully');
  } catch (error) {
    next(error);
  }
}

export async function logout(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) {
      // Idempotent logout - clear cookies even if no user
      clearAuthCookies(res, req.app.locals.nodeEnv);
      sendSuccessResponse(res, null, 'Logged out successfully');
      return;
    }

    // Get current session from cookies
    const refreshToken = req.cookies?.[REFRESH_COOKIE] as string | undefined;
    if (refreshToken) {
      try {
        const jwtPayload = await (await import('./jwt.service.js')).verifyRefreshToken(refreshToken);
        if (jwtPayload) {
          await sessionService.logoutCurrentSession(jwtPayload.sid, user.id);
        }
      } catch {
        // Ignore verification errors, just clear cookies
      }
    }

    clearAuthCookies(res, req.app.locals.nodeEnv);
    sendSuccessResponse(res, null, 'Logged out successfully');
  } catch (error) {
    next(error);
  }
}

export async function logoutAll(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    await sessionService.logoutAllSessions(user.id);
    clearAuthCookies(res, req.app.locals.nodeEnv);
    sendSuccessResponse(res, null, 'Logged out from all devices');
  } catch (error) {
    next(error);
  }
}

// Device management endpoints
export async function registerDevice(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const ipAddress = Array.isArray(req.ip) ? req.ip[0] : (req.ip || req.socket?.remoteAddress || null);

    const result = await sessionService.registerDevice(user.id, req.body, ipAddress);
    sendSuccessResponse(res, {
      device: {
        id: result.id,
        deviceIdentifier: result.deviceIdentifier,
        platform: result.platform,
        deviceName: result.deviceName,
        deviceModel: result.deviceModel,
        osVersion: result.osVersion,
        appVersion: result.appVersion,
        pushProvider: result.pushProvider,
        status: result.status,
        lastActivityAt: result.lastActivityAt,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      },
    }, 'Device registered successfully', 201);
  } catch (error) {
    if (error instanceof ForbiddenError) {
      sendErrorResponse(res, error.message, 'FORBIDDEN', 403);
      return;
    }
    next(error);
  }
}

export async function getDevices(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const devices = await sessionService.getUserDevices(user.id);

    const sanitized = devices.map((d) => ({
      id: d.id,
      deviceIdentifier: d.deviceIdentifier,
      platform: d.platform,
      deviceName: d.deviceName,
      deviceModel: d.deviceModel,
      osVersion: d.osVersion,
      appVersion: d.appVersion,
      pushProvider: d.pushProvider,
      lastIp: d.lastIp,
      lastCountryCode: d.lastCountryCode,
      lastCity: d.lastCity,
      status: d.status,
      revokedAt: d.revokedAt,
      revokedReason: d.revokedReason,
      lastActivityAt: d.lastActivityAt,
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
    }));

    sendSuccessResponse(res, { devices: sanitized }, 'Devices retrieved');
  } catch (error) {
    next(error);
  }
}

export async function updateDevice(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const deviceId = Array.isArray(req.params.deviceId) ? req.params.deviceId[0] : req.params.deviceId;
    if (!deviceId) {
      sendErrorResponse(res, 'Device ID required', 'DEVICE_ID_REQUIRED', 400);
      return;
    }

    const device = await sessionService.updateDevice(deviceId, user.id, req.body);
    if (!device) {
      sendErrorResponse(res, 'Device not found', 'DEVICE_NOT_FOUND', 404);
      return;
    }

    sendSuccessResponse(res, {
      device: {
        id: device.id,
        deviceIdentifier: device.deviceIdentifier,
        platform: device.platform,
        deviceName: device.deviceName,
        deviceModel: device.deviceModel,
        osVersion: device.osVersion,
        appVersion: device.appVersion,
        pushProvider: device.pushProvider,
        status: device.status,
        lastActivityAt: device.lastActivityAt,
        updatedAt: device.updatedAt,
      },
    }, 'Device updated successfully');
  } catch (error) {
    next(error);
  }
}

export async function revokeDevice(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const deviceId = Array.isArray(req.params.deviceId) ? req.params.deviceId[0] : req.params.deviceId;
    if (!deviceId) {
      sendErrorResponse(res, 'Device ID required', 'DEVICE_ID_REQUIRED', 400);
      return;
    }

    const result = await sessionService.revokeDevice(deviceId, user.id, 'user_revoked');
    if (!result) {
      sendErrorResponse(res, 'Device not found or already revoked', 'DEVICE_NOT_FOUND', 404);
      return;
    }

    sendSuccessResponse(res, null, 'Device revoked successfully');
  } catch (error) {
    next(error);
  }
}