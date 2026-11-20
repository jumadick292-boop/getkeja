import type { RequestHandler } from 'express';
import { HttpError } from '../shared/errors.js';

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

export function createCorsAndCsrfMiddleware(allowedOrigins: string[]): RequestHandler {
  const origins = new Set(allowedOrigins.map((origin) => new URL(origin).origin));

  return (req, res, next) => {
    const origin = req.get('origin');
    if (origin) {
      let normalizedOrigin: string;
      try {
        normalizedOrigin = new URL(origin).origin;
      } catch {
        next(new HttpError('Invalid request origin', 403));
        return;
      }
      if (!origins.has(normalizedOrigin)) {
        next(new HttpError('Origin not allowed', 403));
        return;
      }
      res.setHeader('Access-Control-Allow-Origin', normalizedOrigin);
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      res.setHeader('Vary', 'Origin');
    }

    if (req.method === 'OPTIONS') {
      res.setHeader('Access-Control-Allow-Methods', 'GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type,X-CSRF-Token,X-Client-Platform');
      res.sendStatus(204);
      return;
    }

    const authCookiePresent = /(?:^|;\s*)(?:getkeja_refresh|getkeja_session)=/.test(req.get('cookie') || '');
    if (!SAFE_METHODS.has(req.method) && authCookiePresent) {
      const requestOrigin = origin || req.get('referer');
      let normalizedOrigin: string | undefined;
      try {
        normalizedOrigin = requestOrigin ? new URL(requestOrigin).origin : undefined;
      } catch {
        normalizedOrigin = undefined;
      }
      if (!normalizedOrigin || !origins.has(normalizedOrigin)) {
        next(new HttpError('A trusted origin is required for cookie-authenticated requests', 403));
        return;
      }
    }

    next();
  };
}