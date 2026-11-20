import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from './pool.js';
import type { MigrationFile, MigrationRecord, MigrationStatus } from './migrationTypes.js';

const __dirname = join(fileURLToPath(import.meta.url), '..');

const MIGRATIONS_DIR = join(__dirname, 'migrations');

function computeChecksum(sql: string): string {
  return createHash('sha256').update(sql).digest('hex');
}

async function loadMigrationFiles(): Promise<MigrationFile[]> {
  const entries = await readdir(MIGRATIONS_DIR);
  const sqlFiles = entries.filter((f) => f.endsWith('.sql')).sort();

  const migrations: MigrationFile[] = [];
  for (const filename of sqlFiles) {
    const match = filename.match(/^(\d+)_(.+)\.sql$/);
    if (!match || !match[1] || !match[2]) {
      throw new Error(`Invalid migration filename: ${filename}`);
    }
    const number = Number.parseInt(match[1], 10);
    const name = match[2];
    const sql = await readFile(join(MIGRATIONS_DIR, filename), 'utf-8');
    const checksum = computeChecksum(sql);
    migrations.push({ filename, number, name, sql, checksum });
  }
  return migrations;
}

async function getAppliedMigrations(): Promise<MigrationRecord[]> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) NOT NULL UNIQUE,
      checksum VARCHAR(64) NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  const result = await pool.query<MigrationRecord>(
    'SELECT id, name, checksum, applied_at::text AS "appliedAt" FROM _migrations ORDER BY id'
  );
  return result.rows;
}

export async function getMigrationStatus(): Promise<MigrationStatus> {
  const files = await loadMigrationFiles();
  const applied = await getAppliedMigrations();

  const appliedMap = new Map(applied.map((m) => [m.name, m]));
  const pending: MigrationFile[] = [];
  let drift = false;

  for (const file of files) {
    const record = appliedMap.get(file.name);
    if (!record) {
      pending.push(file);
    } else if (record.checksum !== file.checksum) {
      drift = true;
    }
  }

  return { total: files.length, applied, pending, drift };
}

export async function runMigrations(): Promise<MigrationRecord[]> {
  const status = await getMigrationStatus();

  if (status.drift) {
    throw new Error('Migration drift detected: applied migrations have different checksums');
  }

  const appliedRecords: MigrationRecord[] = [];

  for (const migration of status.pending) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(migration.sql);
      const result = await client.query<MigrationRecord>(
        `INSERT INTO _migrations (name, checksum) VALUES ($1, $2)
         RETURNING id, name, checksum, applied_at::text AS "appliedAt"`,
        [migration.name, migration.checksum]
      );
      await client.query('COMMIT');
      appliedRecords.push(result.rows[0]!);
    } catch (error) {
      await client.query('ROLLBACK');
      throw new Error(`Failed to apply migration ${migration.filename}: ${error}`);
    } finally {
      client.release();
    }
  }

  return appliedRecords;
}

export async function createMigration(name: string): Promise<string> {
  const files = await loadMigrationFiles();
  const nextNumber = files.length > 0 ? Math.max(...files.map((f) => f.number)) + 1 : 1;
  const filename = `${String(nextNumber).padStart(3, '0')}_${name}.sql`;
  const filepath = join(MIGRATIONS_DIR, filename);

  const template = `-- Migration: ${filename}
-- Description: ${name}

-- Write your migration SQL here

`;

  await writeFile(filepath, template);
  return filepath;
}

async function writeFile(path: string, content: string): Promise<void> {
  const { writeFile } = await import('node:fs/promises');
  await writeFile(path, content);
}