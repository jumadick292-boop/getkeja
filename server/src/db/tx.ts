// Shared database transaction infrastructure.
// All multi-statement unit-of-work work must flow through this helper so
// controllers never manage transactions or raw connections directly.
import { pool } from './pool.js';
import type { PoolClient } from 'pg';

export async function transaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {
      // Rollback failure masks the original error intentionally.
    });
    throw error;
  } finally {
    client.release();
  }
}
