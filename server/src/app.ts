import express, { type Express } from 'express';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { pinoHttp } from 'pino-http';
import type { Logger } from 'pino';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { createCorsAndCsrfMiddleware } from './middleware/security.js';
import { createAuthRouter } from './modules/auth/auth.routes.js';
import { createProfileRouter } from './modules/profile/profile.routes.js';
import { createListingsRouter } from './modules/listings/listings.routes.js';
import { createLocationSharingRouter } from './modules/location/location-sharing.routes.js';
import { createLandlordRouter } from './modules/landlord/landlord.routes.js';
import { createHouseSeekerRouter } from './modules/house-seeker/house-seeker.routes.js';
import { createMessagingRouter } from './modules/messaging/messaging.routes.js';
import { createRentalApplicationRouter } from './modules/rental-applications/rental-application.routes.js';
import { createTenantRouter } from './modules/tenant/tenant.routes.js';
import { createProviderRouter } from './modules/provider/provider.routes.js';
import { createMarketplaceRouter } from './modules/marketplace/marketplace.routes.js';
import { createMovingRouter } from './modules/moving/moving.routes.js';
import { createGarbageRouter } from './modules/garbage/garbage.routes.js';
import { createLaundryRouter } from './modules/laundry/laundry.routes.js';
import { createHomeMaintenanceRouter } from './modules/home-maintenance/home-maintenance.routes.js';
import { createCleaningOperationsRouter } from './modules/cleaning-operations/cleaning-operations.routes.js';
import { createInstallationOperationsRouter } from './modules/installation-operations/installation-operations.routes.js';
import { createSchedulingRouter } from './modules/scheduling/scheduling.routes.js';
import { createPaymentsRouter } from './modules/payments/payments.routes.js';

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
  app.use('/api/v1/listings', createListingsRouter());
  app.use('/api/v1/location-sharing', createLocationSharingRouter());
  app.use('/api/v1/landlord', createLandlordRouter());
  app.use('/api/v1/house-seeker', createHouseSeekerRouter());
  app.use('/api/v1/messaging', createMessagingRouter());
  app.use('/api/v1/rental-applications', createRentalApplicationRouter());
  app.use('/api/v1/tenant', createTenantRouter());
  app.use('/api/v1/provider', createProviderRouter());
  app.use('/api/v1/marketplace', createMarketplaceRouter());
  app.use('/api/v1/moving', createMovingRouter());
  app.use('/api/v1/garbage', createGarbageRouter());
  app.use('/api/v1/laundry', createLaundryRouter());
  app.use('/api/v1/home-maintenance', createHomeMaintenanceRouter());
  app.use('/api/v1/cleaning-operations', createCleaningOperationsRouter());
  app.use('/api/v1/installation-operations', createInstallationOperationsRouter());
  app.use('/api/v1/scheduling', createSchedulingRouter());
  app.use('/api/v1/payments', createPaymentsRouter());

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
