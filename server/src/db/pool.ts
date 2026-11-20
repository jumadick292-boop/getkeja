import { Pool, type PoolConfig, type ClientBase } from 'pg';
import type { Logger } from 'pino';

let poolInstance: Pool | null = null;
let poolConfig: PoolConfig | null = null;
let databaseLogger: Logger | undefined;

function createPoolConfig(): PoolConfig {
  return {
    connectionString: process.env.DATABASE_URL,
    max: Number(process.env.DB_POOL_MAX ?? 20),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  };
}

export function getPool(): Pool {
  if (!poolInstance) {
    poolConfig = createPoolConfig();
    poolInstance = new Pool(poolConfig);
    poolInstance.on('error', (err) => {
      if (databaseLogger) {
        databaseLogger.error({ err }, 'unexpected database pool error');
      } else {
        console.error('[db] unexpected pool error', err);
      }
    });
  }
  return poolInstance;
}

export function resetPool(newConfig?: Partial<PoolConfig>): void {
  if (poolInstance) {
    poolInstance.end();
    poolInstance = null;
  }
  if (newConfig) {
    poolConfig = { ...createPoolConfig(), ...newConfig };
  } else {
    poolConfig = createPoolConfig();
  }
  poolInstance = new Pool(poolConfig);
  poolInstance.on('error', (err) => {
    if (databaseLogger) {
      databaseLogger.error({ err }, 'unexpected database pool error');
    } else {
      console.error('[db] unexpected pool error', err);
    }
  });
}

export const pool = new Proxy({} as Pool, {
  get(_target, prop) {
    const instance = getPool();
    const value = instance[prop as keyof Pool];
    return typeof value === 'function' ? value.bind(instance) : value;
  },
});

export async function initializeDatabase(logger?: Logger): Promise<void> {
  databaseLogger = logger?.child({ component: 'database' });
  const instance = getPool();
  const client = await instance.connect();
  try {
    await client.query('SELECT 1');
    databaseLogger?.info('database connected');
  } finally {
    client.release();
  }
}

export async function closeDatabase(): Promise<void> {
  if (poolInstance) {
    await poolInstance.end();
    poolInstance = null;
  }
}

export type { ClientBase };