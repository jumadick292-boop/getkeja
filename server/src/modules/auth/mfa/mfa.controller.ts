import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError, ForbiddenError, HttpError } from '../../../shared/errors.js';
import * as mfaService from './index.js';
import { requireAuth } from '../auth.middleware.js';
import * as authLoginService from '../auth.login.service.js';
import type { AuthUser, MfaMethodType } from '../auth.types.js';
import { loadEnv } from '../../../config/env.js';

const SESSION_COOKIE = 'getkeja_session';
const SESSION_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

function setSessionCookie(res: Response, token: string, nodeEnv: string): void {
  res.cookie(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: nodeEnv === 'production',
    sameSite: 'strict',
    maxAge: SESSION_DURATION_MS,
    path: '/',
  });
}

function setAuthCookies(
  res: Response,
  accessToken: string,
  refreshToken: string,
  nodeEnv: string,
): void {
  const env = loadEnv();
  const secure = nodeEnv === 'production';
  res.setHeader('x-access-token', accessToken);
  res.cookie('getkeja_refresh', refreshToken, {
    httpOnly: true,
    secure,
    sameSite: secure ? 'strict' : 'lax',
    maxAge: env.REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
    path: '/api/v1/auth',
  });
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

function getClientInfo(req: Request) {
  return {
    ipAddress: req.ip || req.socket.remoteAddress || undefined,
    userAgent: req.get('user-agent') || undefined,
  };
}

export async function mfaEnrollmentStart(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { methodType, methodName, phoneNumber, makePrimary } = req.body;

    const result = await mfaService.startMfaEnrollment(user.id, methodType, {
      methodName,
      phoneNumber,
      makePrimary,
    });

    sendSuccessResponse(res, result, 'MFA enrollment started');
  } catch (error) {
    next(error);
  }
}

export async function mfaEnrollmentVerify(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { mfaMethodId, code } = req.body;

    const result = await mfaService.verifyMfaEnrollment(user.id, mfaMethodId, code);

    if (!result.success) {
      sendErrorResponse(res, result.message, 'ENROLLMENT_VERIFICATION_FAILED', 400);
      return;
    }

    const enrollmentToken = req.get('authorization')?.startsWith('MFA-Enrollment ')
      ? req.get('authorization')!.slice('MFA-Enrollment '.length)
      : undefined;
    if (enrollmentToken) {
      await authLoginService.consumeMfaEnrollmentTransaction(enrollmentToken);
    }
    sendSuccessResponse(res, { mfaStatus: result.mfaStatus }, result.message);
  } catch (error) {
    next(error);
  }
}

export async function mfaEnrollmentRequestCode(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();
    const result = await mfaService.requestMfaEnrollmentCode(user.id, req.body.mfaMethodId);
    sendSuccessResponse(res, result, 'Verification code sent');
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Please wait ')) {
      sendErrorResponse(res, error.message, 'MFA_RESEND_THROTTLED', 429);
      return;
    }
    if (error instanceof Error && /not found|not configured|not available|does not use|expired|inactive/i.test(error.message)) {
      sendErrorResponse(res, error.message, 'MFA_CODE_REQUEST_FAILED', 400);
      return;
    }
    next(error);
  }
}

export async function mfaMethodRequestCode(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();
    const result = await mfaService.requestMfaMethodCode(user.id, req.body.mfaMethodId);
    sendSuccessResponse(res, result, 'Verification code sent');
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Please wait ')) {
      sendErrorResponse(res, error.message, 'MFA_RESEND_THROTTLED', 429);
      return;
    }
    if (error instanceof Error && /not found|not configured|not available|does not use|expired|inactive/i.test(error.message)) {
      sendErrorResponse(res, error.message, 'MFA_CODE_REQUEST_FAILED', 400);
      return;
    }
    next(error);
  }
}

export async function mfaChallengeRequestCode(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await mfaService.requestMfaChallengeCode(req.body.challengeId, req.body.methodType);
    sendSuccessResponse(res, result, 'Verification code sent');
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Please wait ')) {
      sendErrorResponse(res, error.message, 'MFA_RESEND_THROTTLED', 429);
      return;
    }
    if (error instanceof Error && /not found|not configured|not available|does not use|expired|inactive/i.test(error.message)) {
      sendErrorResponse(res, error.message, 'MFA_CODE_REQUEST_FAILED', 400);
      return;
    }
    next(error);
  }
}

export async function mfaEnrollmentSkip(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    const authorization = req.get('authorization');
    const enrollmentToken = authorization?.startsWith('MFA-Enrollment ')
      ? authorization.slice('MFA-Enrollment '.length)
      : '';
    if (!user || !enrollmentToken) throw new UnauthorizedError();

    const result = await authLoginService.skipMfaEnrollment(
      enrollmentToken,
      user.id,
      {
        deviceId: null,
        userAgent: req.get('user-agent') || null,
        ipAddress: req.ip || req.socket.remoteAddress || null,
      },
    );
    setAuthCookies(
      res,
      result.accessToken,
      result.refreshToken,
      req.app.locals.nodeEnv,
    );
    sendSuccessResponse(res, {
      authenticationStatus: 'complete',
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      },
      sessionId: result.sessionId,
      expiresIn: result.expiresIn,
      ...(req.get('x-client-platform') === 'mobile'
        ? {
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          }
        : {}),
    }, 'MFA enrollment skipped for this account');
  } catch (error) {
    next(error);
  }
}

export async function mfaStatus(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const status = await mfaService.getMfaStatus(user.id);

    sendSuccessResponse(res, status, 'MFA status retrieved');
  } catch (error) {
    next(error);
  }
}

export async function mfaMethods(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const methods = await mfaService.getMfaMethods(user.id);

    sendSuccessResponse(res, { methods }, 'MFA methods retrieved');
  } catch (error) {
    next(error);
  }
}

export async function mfaChallengeCreate(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { ipAddress, userAgent } = getClientInfo(req);

    const result = await mfaService.createMfaLoginChallenge(user.id, ipAddress, userAgent);

    sendSuccessResponse(res, result, 'MFA challenge created');
  } catch (error) {
    if (error instanceof Error && error.message === 'No verified MFA methods available') {
      sendErrorResponse(res, 'No verified MFA methods available', 'NO_MFA_METHODS', 400);
      return;
    }
    next(error);
  }
}

export async function mfaChallengeVerify(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { challengeId, methodType, code } = req.body;
    const { ipAddress, userAgent } = getClientInfo(req);

    const result = await mfaService.verifyMfaChallenge(user.id, challengeId, methodType, code, ipAddress, userAgent);

    if (!result.success) {
      sendErrorResponse(res, result.message, 'MFA_VERIFICATION_FAILED', 400);
      return;
    }

    if (result.sessionToken) {
      setSessionCookie(res, result.sessionToken, req.app.locals.nodeEnv);
    }

    sendSuccessResponse(res, {
      authenticationStatus: result.authenticationStatus,
      user: result.user ? {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      } : undefined,
    }, result.message);
  } catch (error) {
    next(error);
  }
}

export async function mfaAddMethod(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { methodType, methodName, phoneNumber, makePrimary } = req.body;

    const result = await mfaService.addMfaMethod(user.id, methodType, {
      methodName,
      phoneNumber,
      makePrimary,
    });

    sendSuccessResponse(res, result, 'MFA method added');
  } catch (error) {
    if (error instanceof Error && error.message.includes('Recent MFA verification required')) {
      sendErrorResponse(res, error.message, 'RECENT_MFA_REQUIRED', 403);
      return;
    }
    next(error);
  }
}

export async function mfaVerifyMethod(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { mfaMethodId, code } = req.body;

    const result = await mfaService.verifyMfaMethod(user.id, mfaMethodId, code);

    if (!result.success) {
      sendErrorResponse(res, result.message, 'ENROLLMENT_VERIFICATION_FAILED', 400);
      return;
    }

    sendSuccessResponse(res, { mfaStatus: result.mfaStatus }, result.message);
  } catch (error) {
    if (error instanceof Error && error.message.includes('Recent MFA verification required')) {
      sendErrorResponse(res, error.message, 'RECENT_MFA_REQUIRED', 403);
      return;
    }
    next(error);
  }
}

export async function mfaDisableMethod(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { mfaMethodId, verificationCode } = req.body;

    const result = await mfaService.disableMfaMethod(user.id, mfaMethodId, verificationCode);

    sendSuccessResponse(res, result, result.message);
  } catch (error) {
    if (error instanceof Error && error.message.includes('Fresh MFA verification required')) {
      sendErrorResponse(res, error.message, 'FRESH_MFA_REQUIRED', 403);
      return;
    }
    if (error instanceof Error && error.message.includes('Cannot disable the last active MFA method')) {
      sendErrorResponse(res, error.message, 'LAST_MFA_METHOD', 400);
      return;
    }
    next(error);
  }
}

export async function mfaSetPrimaryMethod(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { mfaMethodId, verificationCode } = req.body;

    const result = await mfaService.setPrimaryMfaMethod(user.id, mfaMethodId, verificationCode);

    sendSuccessResponse(res, result, result.message);
  } catch (error) {
    if (error instanceof Error && error.message.includes('Fresh MFA verification required')) {
      sendErrorResponse(res, error.message, 'FRESH_MFA_REQUIRED', 403);
      return;
    }
    next(error);
  }
}

export async function mfaRegenerateRecoveryCodes(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const { verificationCode } = req.body;

    const result = await mfaService.regenerateRecoveryCodes(user.id, verificationCode);

    sendSuccessResponse(res, result, result.message);
  } catch (error) {
    if (error instanceof Error && error.message.includes('Fresh MFA verification required')) {
      sendErrorResponse(res, error.message, 'FRESH_MFA_REQUIRED', 403);
      return;
    }
    if (error instanceof Error && error.message.includes('Recovery codes not configured')) {
      sendErrorResponse(res, error.message, 'RECOVERY_CODES_NOT_CONFIGURED', 400);
      return;
    }
    next(error);
  }
}
