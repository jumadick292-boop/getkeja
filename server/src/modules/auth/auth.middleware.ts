import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { createHash } from 'node:crypto';
import { UnauthorizedError, ForbiddenError } from '../../shared/errors.js';
import * as sessionService from './session.service.js';
import type { AuthUser, Session } from './auth.types.js';

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  session?: Session;
}

export const requireAuth: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    // Try to get access token from Authorization header first
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      // Fallback to x-access-token header (set by refresh endpoint)
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (!accessToken) {
      throw new UnauthorizedError();
    }

    const result = await sessionService.validateAccessToken(accessToken);
    if (!result) {
      throw new UnauthorizedError();
    }

    req.user = result.user;
    req.session = result.session;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireMfaEnrollment: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (!accessToken) {
      throw new UnauthorizedError();
    }

    const result = await sessionService.validateAccessToken(accessToken);
    if (!result) {
      throw new UnauthorizedError();
    }

    if (!result.user.mfaEnrolledAt) {
      throw new ForbiddenError('MFA enrollment is required to access this resource');
    }

    req.user = result.user;
    req.session = result.session;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireMfaEnrollmentOrAuth: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.get('authorization');
    if (authHeader?.startsWith('Bearer ')) {
      const result = await sessionService.validateAccessToken(authHeader.slice(7));
      if (result) {
        req.user = result.user;
        req.session = result.session;
        next();
        return;
      }
    }

    const enrollmentToken = authHeader?.startsWith('MFA-Enrollment ')
      ? authHeader.slice('MFA-Enrollment '.length)
      : '';
    if (!enrollmentToken) throw new UnauthorizedError();

    const user = await (await import('./auth.login.service.js'))
      .resolveMfaEnrollmentTransaction(enrollmentToken);
    if (!user || user.mfaEnrolledAt) throw new UnauthorizedError();
    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireFreshMfaVerification: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (!accessToken) {
      throw new UnauthorizedError();
    }

    const result = await sessionService.validateAccessToken(accessToken);
    if (!result) {
      throw new UnauthorizedError();
    }

    if (!result.user.mfaEnrolledAt) {
      throw new ForbiddenError('MFA enrollment is required');
    }

    // Check if last MFA verification was recent (within 5 minutes for sensitive operations)
    if (result.user.lastMfaVerifiedAt) {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      if (result.user.lastMfaVerifiedAt < fiveMinutesAgo) {
        throw new ForbiddenError('Fresh MFA verification required for this operation');
      }
    } else {
      throw new ForbiddenError('MFA verification required for this operation');
    }

    req.user = result.user;
    req.session = result.session;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireAdminRole: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (!accessToken) {
      throw new UnauthorizedError();
    }

    const result = await sessionService.validateAccessToken(accessToken);
    if (!result) {
      throw new UnauthorizedError();
    }

    const hasAdminRole = await (await import('./auth.repository.js')).hasSystemRole(result.user.id);
    if (!hasAdminRole) {
      throw new ForbiddenError('Administrator access required');
    }

    req.user = result.user;
    req.session = result.session;
    next();
  } catch (error) {
    next(error);
  }
};

// Optional: Extract token for endpoints that need it
export const extractAuthToken: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.get('authorization');
    let accessToken: string | undefined;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.slice(7);
    } else {
      accessToken = req.get('x-access-token') as string | undefined;
    }

    if (accessToken) {
      const result = await sessionService.validateAccessToken(accessToken);
      if (result) {
        req.user = result.user;
        req.session = result.session;
      }
    }
    next();
  } catch {
    // Ignore errors, just continue without auth
    next();
  }
};