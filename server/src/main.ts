import { pino } from 'pino';
import type { Server } from 'node:http';
import { createApp } from './app.js';
import { loadEnv, type Env } from './config/env.js';
import { closeDatabase, initializeDatabase, pool } from './db/pool.js';
import { closeRedis, configureRedisLogger, connectRedis, getRedisClient } from './db/redis.js';
import { initializePushProvider } from './modules/auth/providers/push.js';
import { startOutboxWorker, stopOutboxWorker } from './modules/auth/notification.worker.js';
import { startAccountPurgeWorker, stopAccountPurgeWorker } from './modules/auth/account-purge.worker.js';
import { verifyCloudinaryConnection } from './modules/profile/cloudinary.service.js';

let env: Env;
try {
  env = loadEnv();
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}

const logger =
  env.NODE_ENV === 'development'
    ? pino(
        { level: env.LOG_LEVEL },
        (await import('pino-pretty')).default({
          colorize: true,
          translateTime: 'SYS:standard',
          ignore: 'pid,hostname,req,res,reqId,responseTime',
          messageFormat(log, messageKey, _levelLabel, { colors }) {
            const request = log.req;
            const response = log.res;
            if (
              request === null ||
              typeof request !== 'object' ||
              response === null ||
              typeof response !== 'object' ||
              !('method' in request) ||
              typeof request.method !== 'string' ||
              !('url' in request) ||
              typeof request.url !== 'string' ||
              !('statusCode' in response) ||
              typeof response.statusCode !== 'number' ||
              typeof log.responseTime !== 'number'
            ) {
              return String(log[messageKey] ?? '');
            }

            const requestId =
              'id' in request &&
              (typeof request.id === 'string' || typeof request.id === 'number')
                ? `[${request.id}] `
                : '';
            const statusColor =
              response.statusCode >= 500
                ? colors.red
                : response.statusCode >= 400
                  ? colors.yellow
                  : colors.green;
            const requestSummary = statusColor(
              `${requestId}${request.method} ${request.url} -> ${response.statusCode} ${log.responseTime.toFixed(1)}ms`,
            );
            const message = log[messageKey];
            return message ? `${requestSummary} ${String(message)}` : requestSummary;
          },
        }),
      )
    : pino({ level: env.LOG_LEVEL });
let shuttingDown = false;

async function start(): Promise<void> {
  try {
    await initializeDatabase(logger);
    configureRedisLogger(logger);
    await connectRedis();
    await verifyCloudinaryConnection(env, logger);

    if (env.PUSH_PROVIDER !== 'development') {
      let pushConfig: any = {};

      switch (env.PUSH_PROVIDER) {
        case 'fcm':
          pushConfig = {
            projectId: env.FCM_PROJECT_ID,
            serviceAccountKey: env.FCM_SERVICE_ACCOUNT_KEY,
          };
          break;
        case 'apns':
          pushConfig = {
            keyId: env.APNS_KEY_ID,
            teamId: env.APNS_TEAM_ID,
            keyPath: env.APNS_KEY_PATH,
            production: env.APNS_PRODUCTION,
            bundleId: env.APNS_BUNDLE_ID,
          };
          break;
        case 'webpush':
          pushConfig = {
            vapidPublicKey: env.WEBPUSH_VAPID_PUBLIC_KEY,
            vapidPrivateKey: env.WEBPUSH_VAPID_PRIVATE_KEY,
            vapidSubject: env.WEBPUSH_VAPID_SUBJECT,
          };
          break;
      }

      initializePushProvider(env.PUSH_PROVIDER, pushConfig);
    }

    const app = createApp({
      logger,
      cookieSecret: env.COOKIE_SECRET,
      trustProxy: env.TRUST_PROXY,
      nodeEnv: env.NODE_ENV,
      allowedOrigins: env.CORS_ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean),
      readinessCheck: async () => {
        await Promise.all([pool.query('SELECT 1'), getRedisClient().ping()]);
      },
    });

    const server = app.listen(env.PORT, () => {
      logger.info({ port: env.PORT }, 'server listening');
    });

    if (env.NOTIFICATION_OUTBOX_WORKER_ENABLED) {
      await startOutboxWorker();
    }
    await startAccountPurgeWorker();

    process.once('SIGTERM', () => shutdown(server, 'SIGTERM'));
    process.once('SIGINT', () => shutdown(server, 'SIGINT'));
  } catch (error) {
    logger.fatal({ err: error }, 'failed to start server');
    process.exit(1);
  }
}

function shutdown(server: Server, signal: NodeJS.Signals): void {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');

  const forceExit = setTimeout(() => {
    logger.error('forced shutdown after 10s');
    process.exit(1);
  }, 10_000);
  forceExit.unref();

  server.close(async (error) => {
    if (error) {
      logger.error({ err: error }, 'failed to close server');
    } else {
      logger.info('server closed');
    }
    await stopOutboxWorker();
    await stopAccountPurgeWorker();
    await closeDatabase();
    await closeRedis();
    process.exit(error ? 1 : 0);
  });
}

process.on('uncaughtException', (error) => {
  logger.fatal({ err: error }, 'uncaught exception');
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.fatal({ err: reason }, 'unhandled rejection');
  process.exit(1);
});

void start();
