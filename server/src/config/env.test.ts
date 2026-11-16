import { describe, expect, it } from 'vitest';
import { EnvValidationError, loadEnv } from './env.js';

const validEnv = {
  NODE_ENV: 'test',
  PORT: '4000',
  DATABASE_URL: 'postgres://getkeja:secret@localhost:5432/getkeja',
  DB_POOL_MAX: '10',
  COOKIE_SECRET: 'a'.repeat(32),
  CSRF_SECRET: 'b'.repeat(32),
  LOG_LEVEL: 'debug',
};

describe('loadEnv', () => {
  it('parses and coerces valid values', () => {
    const env = loadEnv(validEnv);

    expect(env.PORT).toBe(4000);
    expect(env.DB_POOL_MAX).toBe(10);
    expect(env.NODE_ENV).toBe('test');
    expect(env.TRUST_PROXY).toBe(false);
  });

  it('applies defaults for optional values', () => {
    const env = loadEnv({
      DATABASE_URL: validEnv.DATABASE_URL,
      COOKIE_SECRET: validEnv.COOKIE_SECRET,
      CSRF_SECRET: validEnv.CSRF_SECRET,
    });

    expect(env.NODE_ENV).toBe('development');
    expect(env.PORT).toBe(4000);
    expect(env.DB_POOL_MAX).toBe(20);
    expect(env.LOG_LEVEL).toBe('info');
  });

  it('enables trust proxy only when asked', () => {
    expect(loadEnv({ ...validEnv, TRUST_PROXY: 'true' }).TRUST_PROXY).toBe(true);
    expect(loadEnv({ ...validEnv, TRUST_PROXY: 'false' }).TRUST_PROXY).toBe(false);
  });

  it('rejects a missing database url', () => {
    expect(() => loadEnv({ ...validEnv, DATABASE_URL: '' })).toThrow(
      EnvValidationError,
    );
  });

  it('rejects secrets shorter than 32 characters', () => {
    expect(() => loadEnv({ ...validEnv, COOKIE_SECRET: 'too-short' })).toThrow(
      /COOKIE_SECRET/,
    );
  });

  it('rejects an invalid port', () => {
    expect(() => loadEnv({ ...validEnv, PORT: '70000' })).toThrow(/PORT/);
  });
});
