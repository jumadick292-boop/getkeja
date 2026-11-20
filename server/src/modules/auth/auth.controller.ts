import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError, ForbiddenError, HttpError } from '../../shared/errors.js';
import * as authService from './auth.login.service.js';
import * as authRegService from './auth.service.js';
import type { AuthUser, RegistrationResult, LoginResult, MfaHandoffResult } from './auth.types.js';
import { loadEnv } from '../../config/env.js';

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

export async function registerEmail(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.registerWithEmail(req.body);
    sendSuccessResponse(res, {
      verificationRequired: result.verificationRequired,
      verificationChannel: result.verificationChannel,
      verificationDeliveryFailed: result.verificationDeliveryFailed ?? false,
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      },
    }, 'Registration successful. Please verify your email.', 201);
  } catch (error) {
    next(error);
  }
}

export async function registerPhone(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.registerWithPhone(req.body);
    sendSuccessResponse(res, {
      verificationRequired: result.verificationRequired,
      verificationChannel: result.verificationChannel,
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      },
    }, 'Registration successful. Please verify your phone number.', 201);
  } catch (error) {
    next(error);
  }
}

export async function registerPhoneOtp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.registerWithPhoneOtp(req.body);
    sendSuccessResponse(res, {
      verificationRequired: result.verificationRequired,
      verificationChannel: result.verificationChannel,
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      },
    }, 'Registration initiated. Please verify your phone number.', 201);
  } catch (error) {
    next(error);
  }
}

export async function registerGoogle(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.registerWithGoogle(req.body.idToken, req.body.role);
    if (!result.verificationRequired) {
      const loginResult = await authService.loginWithGoogle(req.body.idToken);
      await handleLoginResult(
        req,
        res,
        loginResult,
        req.app.locals.nodeEnv,
        next,
        'google',
      );
      return;
    }

    sendSuccessResponse(res, {
      verificationRequired: result.verificationRequired,
      verificationChannel: result.verificationChannel,
      user: {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      },
    }, result.verificationRequired ? 'Registration successful. Verify your email to continue.' : 'Google account registered.', 201);
  } catch (error) {
    next(error);
  }
}

export async function login(req: Request, res: Response, next: NextFunction): Promise<void> {
  await loginWithEmail(req, res, next);
}

export async function logout(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const bodyToken = req.body?.refreshToken;
    const refreshToken = typeof bodyToken === 'string'
      ? bodyToken
      : req.cookies?.[REFRESH_COOKIE] as string | undefined;
    if (refreshToken) {
      try {
        const { verifyRefreshToken } = await import('./jwt.service.js');
        const jwtPayload = await verifyRefreshToken(refreshToken);
        if (jwtPayload) {
          const { logoutCurrentSession } = await import('./session.service.js');
          await logoutCurrentSession(jwtPayload.sid, jwtPayload.sub);
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

export async function getCurrentUser(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (!accessToken) throw new UnauthorizedError();

    const { validateAccessToken } = await import('./session.service.js');
    const result = await validateAccessToken(accessToken);
    if (!result) throw new UnauthorizedError();

    const user = result.user;
    req.user = user;
    sendSuccessResponse(res, {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        roles: user.roles,
        emailVerified: user.emailVerified,
        phoneVerified: user.phoneVerified,
        isActive: user.isActive,
        isSuspended: user.isSuspended,
        isLocked: user.isLocked,
        isDeactivated: user.isDeactivated,
      },
    }, 'Current user retrieved');
  } catch (error) {
    next(error);
  }
}

function clearAuthCookies(res: Response, nodeEnv: string): void {
  const secure = nodeEnv === 'production';
  res.clearCookie(REFRESH_COOKIE, { httpOnly: true, secure, sameSite: 'strict', path: '/api/v1/auth' });
}

export function forgotPassword(nodeEnv: 'development' | 'test' | 'production') {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const result = await authRegService.requestPasswordReset(req.body.email);
      const response: { message: string; resetToken?: string } = {
        message: 'If the email exists, a password reset link will be sent',
      };
      if (nodeEnv !== 'production' && result.resetToken) {
        response.resetToken = result.resetToken;
      }
      sendSuccessResponse(res, response, 'Password reset initiated');
    } catch (error) {
      next(error);
    }
  };
}

export async function resetPassword(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await authRegService.resetPassword(req.body.token, req.body.password);
    sendSuccessResponse(res, null, 'Password updated successfully');
  } catch (error) {
    next(error);
  }
}

export async function requestEmailVerification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await authRegService.requestEmailVerification(req.body.email);
    sendSuccessResponse(res, { verificationRequired: true, verificationChannel: 'email' }, 'Verification email sent');
  } catch (error) {
    next(error);
  }
}

export async function confirmEmailVerification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.confirmEmailVerification(req.body.email, req.body.code);
    if (!result.success || !result.user) {
      sendErrorResponse(res, result.message, 'VERIFICATION_FAILED', 400);
      return;
    }

    const loginResult = await authService.loginAfterEmailVerification(result.user.id);
    await handleLoginResult(
      req,
      res,
      loginResult,
      req.app.locals.nodeEnv,
      next,
      'email_otp',
    );
  } catch (error) {
    next(error);
  }
}

export async function requestPhoneVerification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await authRegService.requestPhoneVerification(req.body.phone);
    sendSuccessResponse(res, { verificationRequired: true, verificationChannel: 'sms' }, 'Verification code sent via SMS');
  } catch (error) {
    next(error);
  }
}

export async function confirmPhoneVerification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authRegService.confirmPhoneVerification(req.body.phone, req.body.otp);
    if (!result.success) {
      sendErrorResponse(res, result.message, 'VERIFICATION_FAILED', 400);
      return;
    }
    sendSuccessResponse(res, {
      user: result.user ? {
        id: result.user.id,
        email: result.user.email,
        firstName: result.user.firstName,
        lastName: result.user.lastName,
        roles: result.user.roles,
        emailVerified: result.user.emailVerified,
        phoneVerified: result.user.phoneVerified,
      } : null,
    }, result.message);
  } catch (error) {
    next(error);
  }
}

export async function googleAuth(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const redirectUrl = typeof req.query.redirectUrl === 'string' ? req.query.redirectUrl : undefined;
    const { url, state } = await authService.getGoogleAuthUrl(redirectUrl);
    res.cookie('oauth_state', state, { httpOnly: true, secure: req.app.locals.nodeEnv === 'production', sameSite: 'lax', maxAge: 10 * 60 * 1000, path: '/' });
    sendSuccessResponse(res, { url, state }, 'Google OAuth initiated');
  } catch (error) {
    next(error);
  }
}

export async function googleCallback(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const code = typeof req.query.code === 'string' ? req.query.code : undefined;
    const state = typeof req.query.state === 'string' ? req.query.state : undefined;

    if (!state) throw new UnauthorizedError();
    if (req.cookies?.oauth_state !== state) throw new UnauthorizedError();
    if (req.query.error || !code) {
      await authService.cancelGoogleOAuth(state);
      throw new UnauthorizedError();
    }
    const result = await authService.handleGoogleOAuthCallback(code, state);
    res.clearCookie('oauth_state', { httpOnly: true, sameSite: 'lax', path: '/' });
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'google');
  } catch (error) {
    res.clearCookie('oauth_state', { httpOnly: true, sameSite: 'lax', path: '/' });
    if (error instanceof UnauthorizedError || error instanceof ForbiddenError) {
      await recordLoginEvent(req, null, 'primary_authentication_failed', 'warning', 'google');
      sendInvalidCredentials(res);
      return;
    }
    next(error);
  }
}

export async function linkGoogle(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    await authRegService.linkGoogleAccount(user.id, req.body.idToken, {
      sessionCreatedAt: req.session?.createdAt,
      password: req.body.password,
      ipAddress: req.ip ?? null,
      userAgent: req.get('user-agent') ?? null,
    });
    sendSuccessResponse(res, null, 'Google account linked successfully');
  } catch (error) {
    next(error);
  }
}

export async function unlinkGoogle(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    await authRegService.unlinkGoogleAccount(user.id, req.body.password, {
      ipAddress: req.ip ?? null,
      userAgent: req.get('user-agent') ?? null,
    });
    sendSuccessResponse(res, null, 'Google account unlinked successfully');
  } catch (error) {
    next(error);
  }
}

export async function setPassword(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user as AuthUser;
    if (!user) throw new UnauthorizedError();

    const session = req.session;
    if (!session) throw new UnauthorizedError();
    await authRegService.setPassword(user.id, req.body.password, {
      sessionId: session.id,
      sessionCreatedAt: session.createdAt,
      idToken: req.body.idToken,
      ipAddress: req.ip ?? null,
      userAgent: req.get('user-agent') ?? null,
    });
    sendSuccessResponse(res, null, 'Password set successfully');
  } catch (error) {
    next(error);
  }
}

export async function loginWithEmail(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.loginWithEmail(req.body.email, req.body.password);
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'email');
  } catch (error) {
    await handleLoginError(req, error, res, next, 'email');
  }
}

export async function loginWithPhone(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.loginWithPhone(req.body.phone, req.body.password);
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'phone');
  } catch (error) {
    await handleLoginError(req, error, res, next, 'phone');
  }
}

export async function requestEmailLoginOtp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await authService.requestEmailLoginOtp(req.body.email);
    sendSuccessResponse(res, { verificationRequired: true, verificationChannel: 'email' }, 'If the account is eligible, a verification code will be sent');
  } catch (error) {
    next(error);
  }
}

export async function verifyEmailLoginOtp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.verifyEmailLoginOtp(req.body.email, req.body.otp);
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'email_otp');
  } catch (error) {
    await handleLoginError(req, error, res, next, 'email_otp');
  }
}

export async function requestPhoneLoginOtp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await authService.requestPhoneLoginOtp(req.body.phone);
    sendSuccessResponse(res, { verificationRequired: true, verificationChannel: 'sms' }, 'If the account is eligible, a verification code will be sent');
  } catch (error) {
    next(error);
  }
}

export async function verifyPhoneLoginOtp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.verifyPhoneLoginOtp(req.body.phone, req.body.otp);
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'phone_otp');
  } catch (error) {
    await handleLoginError(req, error, res, next, 'phone_otp');
  }
}

export async function googleAuthLogin(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.loginWithGoogle(req.body.idToken);
    await handleLoginResult(req, res, result, req.app.locals.nodeEnv, next, 'google');
  } catch (error) {
    await handleLoginError(req, error, res, next, 'google');
  }
}

export async function getMfaChallenge(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const challenge = await authService.getMfaChallenge(req.body.challengeId);
    if (!challenge || challenge.status !== 'pending' || challenge.expiresAt <= new Date()) {
      sendErrorResponse(res, 'MFA challenge not found or expired', 'CHALLENGE_NOT_FOUND', 404);
      return;
    }
    sendSuccessResponse(res, {
      challengeId: challenge.id,
      availableMethods: (challenge.challengeData.methods as string[]) || [],
      expiresAt: challenge.expiresAt,
    }, 'MFA challenge retrieved');
  } catch (error) {
    next(error);
  }
}

export async function verifyMfa(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const ipAddress = Array.isArray(req.ip) ? req.ip[0] : (req.ip || req.socket?.remoteAddress || null);
    const { user, accessToken, refreshToken, sessionId, expiresIn } = await authService.completeMfaChallenge(
      req.body.challengeId,
      req.body.code ?? req.body.recoveryCode ?? req.body.totpCode,
      {
        deviceId: null, // Will be set if device registration happens
        userAgent: req.get('user-agent') || null,
        ipAddress,
      },
      req.body.methodType ?? (req.body.recoveryCode ? 'recovery_codes' : 'totp'),
    );
    setAuthCookies(res, accessToken, refreshToken, req.app.locals.nodeEnv);
    sendSuccessResponse(res, {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        roles: user.roles,
        emailVerified: user.emailVerified,
        phoneVerified: user.phoneVerified,
      },
      sessionId,
      expiresIn,
      ...(req.get('x-client-platform') === 'mobile' ? { accessToken, refreshToken } : {}),
    }, 'MFA verification successful');
  } catch (error) {
    next(error);
  }
}

async function handleLoginResult(
  req: Request,
  res: Response,
  result: LoginResult | MfaHandoffResult,
  nodeEnv: string,
  next?: NextFunction,
  method: 'email' | 'phone' | 'email_otp' | 'phone_otp' | 'google' = 'email',
): Promise<void> {
  if ('authenticationStatus' in result && result.authenticationStatus === 'complete') {
    if (
      !result.accessToken ||
      !result.refreshToken ||
      !result.sessionId ||
      result.expiresIn === undefined
    ) {
      next?.(new HttpError('Authentication session is incomplete', 500));
      return;
    }

    setAuthCookies(res, result.accessToken, result.refreshToken, nodeEnv);
    await recordLoginEvent(req, result.user.id, 'primary_authentication_succeeded', 'info', method);
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
    }, 'Authentication successful');
  } else if ('authenticationStatus' in result && result.authenticationStatus === 'mfa_required') {
    await recordLoginEvent(req, result.user.id, 'primary_authentication_succeeded', 'info', method);
    sendSuccessResponse(res, {
      authenticationStatus: 'mfa_required',
      challengeId: result.challengeId,
      availableMethods: result.availableMethods,
    }, 'Primary authentication successful. MFA required.');
  } else if ('authenticationStatus' in result && result.authenticationStatus === 'mfa_enrollment_required') {
    await recordLoginEvent(req, result.user.id, 'primary_authentication_succeeded', 'info', method);
    sendSuccessResponse(res, {
      authenticationStatus: 'mfa_enrollment_required',
      enrollmentToken: result.enrollmentToken,
    }, 'MFA enrollment is required.');
  } else if (next) {
    next(new HttpError('Authentication handoff is unavailable', 500));
  }
}

async function handleLoginError(
  req: Request,
  error: unknown,
  res: Response,
  next: NextFunction,
  method: 'email' | 'phone' | 'email_otp' | 'phone_otp' | 'google',
): Promise<void> {
  if (
    error instanceof UnauthorizedError ||
    error instanceof ForbiddenError ||
    (error instanceof HttpError && (error.status === 401 || error.status === 403))
  ) {
    await recordLoginEvent(req, null, 'primary_authentication_failed', 'warning', method);
    sendInvalidCredentials(res);
    return;
  }
  next(error);
}

async function recordLoginEvent(
  req: Request,
  userId: string | null,
  eventType: 'primary_authentication_succeeded' | 'primary_authentication_failed',
  severity: 'info' | 'warning',
  method: 'email' | 'phone' | 'email_otp' | 'phone_otp' | 'google',
): Promise<void> {
  const ipAddress = Array.isArray(req.ip) ? req.ip[0] : (req.ip || req.socket?.remoteAddress || null);
  await authService.recordAuthenticationEvent(
    userId,
    eventType,
    severity,
    method,
    ipAddress,
    req.get('user-agent') || null,
  );
}

function sendInvalidCredentials(res: Response): void {
  sendErrorResponse(res, 'Invalid credentials.', 'INVALID_CREDENTIALS', 401);
}
