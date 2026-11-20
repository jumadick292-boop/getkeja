import { Redis } from 'ioredis';
import type { Logger } from 'pino';
import { loadEnv } from '../config/env.js';

let redisClient: Redis | null = null;
let redisLogger: Logger | undefined;

export function configureRedisLogger(logger: Logger): void {
  redisLogger = logger.child({ component: 'redis' });
}

export function getRedisClient(): Redis {
  if (!redisClient) {
    const env = loadEnv();
    redisClient = new Redis(env.REDIS_URL || 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      retryStrategy: (times) => {
        if (times > 3) return null;
        return Math.min(times * 100, 3000);
      },
      lazyConnect: true,
    });

    redisClient.on('error', (err) => {
      if (redisLogger) {
        redisLogger.error({ err }, 'Redis connection error');
      } else {
        console.error('[redis] connection error', err);
      }
    });

    redisClient.on('connect', () => {
      if (redisLogger) {
        redisLogger.info('Redis connected');
      } else {
        console.log('[redis] connected');
      }
    });
  }
  return redisClient;
}

export async function connectRedis(): Promise<void> {
  const client = getRedisClient();
  if (client.status === 'wait') {
    await client.connect();
  }
}

export async function closeRedis(): Promise<void> {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
}

export function getRedis(): Redis {
  return getRedisClient();
}