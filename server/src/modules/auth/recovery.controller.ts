import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError, HttpError } from '../../shared/errors.js';
import * as recoveryService from './recovery.js';
import { validateBody } from '../../middleware/validate.js';
import {
  accountRecoveryRequestSchema,
  accountRecoveryPhoneSchema,
  accountRecoveryVerifySchema,
} from './auth.schema.js';

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

export async function accountRecoveryRequest(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await recoveryService.requestAccountRecoveryEmail(req.body.email);
    sendSuccessResponse(res, null, 'If the email exists, an account recovery link will be sent');
  } catch (error) {
    next(error);
  }
}

export async function accountRecoveryPhone(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await recoveryService.requestAccountRecoverySms(req.body.phone);
    sendSuccessResponse(res, null, 'If the phone number exists, an account recovery code will be sent via SMS');
  } catch (error) {
    next(error);
  }
}

export async function accountRecoveryVerify(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { token, password, mfaMethod, phoneNumber } = req.body;

    const verification = await recoveryService.verifyAccountRecoveryToken(token);
    if (!verification) {
      sendErrorResponse(res, 'Invalid or expired recovery token', 'INVALID_RECOVERY_TOKEN', 400);
      return;
    }

    const result = await recoveryService.completeAccountRecovery(
      verification.userId,
      token,
      password,
      mfaMethod ? { type: mfaMethod, phoneNumber } : undefined,
    );

    sendSuccessResponse(res, result, result.message);
  } catch (error) {
    next(error);
  }
}

export async function getSecurityEvents(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = req.user;
    if (!user) throw new UnauthorizedError();

    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;
    const category = req.query.category as string | undefined;
    const categories = category === 'authentication'
      ? ['auth']
      : category === 'security'
        ? ['mfa', 'account', 'admin']
        : undefined;

    const events = await recoveryService.getUserSecurityEvents(user.id, limit, offset, categories);

    sendSuccessResponse(res, { events }, 'Security events retrieved');
  } catch (error) {
    next(error);
  }
}