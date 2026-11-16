import express, { type Express } from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { pinoHttp } from 'pino-http';
import type { Logger } from 'pino';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';

export interface CreateAppOptions {
  logger?: Logger;
  cookieSecret?: string;
  trustProxy?: boolean | number | string;
  bodyLimit?: number | string;
}

export function createApp({
  logger,
  cookieSecret,
  trustProxy = false,
  bodyLimit = '1mb',
}: CreateAppOptions = {}): Express {
  const app = express();

  app.disable('x-powered-by');
  if (trustProxy !== false) {
    app.set('trust proxy', trustProxy);
  }

  app.use(helmet());
  if (logger) {
    app.use(pinoHttp({ logger }));
  }
  app.use(express.json({ limit: bodyLimit }));
  app.use(cookieParser(cookieSecret));

  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
