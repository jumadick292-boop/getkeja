import express, { type Express } from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { pinoHttp } from 'pino-http';
import type { Logger } from 'pino';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { createCorsAndCsrfMiddleware } from './middleware/security.js';
import { createAuthRouter } from './modules/auth/auth.routes.js';
import { createProfileRouter } from './modules/profile/profile.routes.js';

export interface CreateAppOptions {
  logger?: Logger;
  cookieSecret?: string;
  trustProxy?: boolean | number | string;
  bodyLimit?: number | string;
  nodeEnv?: 'development' | 'test' | 'production';
  allowedOrigins?: string[];
  readinessCheck?: () => Promise<void>;
}

export function createApp({
  logger,
  cookieSecret,
  trustProxy = false,
  bodyLimit = '1mb',
  nodeEnv = 'development',
  allowedOrigins = ['http://localhost:3000'],
  readinessCheck,
}: CreateAppOptions = {}): Express {
  const app = express();
  app.locals.nodeEnv = nodeEnv;

  app.disable('x-powered-by');
  if (trustProxy !== false) {
    app.set('trust proxy', trustProxy);
  }

  app.use(helmet());
  app.use(createCorsAndCsrfMiddleware(allowedOrigins));
  if (logger) {
    app.use(
      pinoHttp({
        logger,
        serializers: {
          req: (req) => ({
            id: req.id,
            method: req.method,
            url: (req.url ?? '/').split('?')[0],
          }),
          res: (res) => ({ statusCode: res.statusCode }),
        },
        customLogLevel: (_req, res, error) => {
          if (error || res.statusCode >= 500) return 'error';
          if (res.statusCode >= 400) return 'warn';
          return 'info';
        },
      }),
    );
  }
  app.use(express.json({ limit: bodyLimit }));
  app.use(cookieParser(cookieSecret));
  const authRouter = createAuthRouter(nodeEnv);
  app.use('/api/auth', authRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/profile', createProfileRouter());
  app.use('/api/profile', createProfileRouter());

  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok' });
  });
  app.get('/ready', async (_req, res) => {
    try {
      await readinessCheck?.();
      res.status(200).json({ status: 'ready' });
    } catch (error) {
      logger?.error({ err: error }, 'readiness check failed');
      res.status(503).json({ status: 'not_ready' });
    }
  });

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
