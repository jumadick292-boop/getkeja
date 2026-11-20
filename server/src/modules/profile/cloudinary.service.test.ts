import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  configure: vi.fn(),
  ping: vi.fn(),
}));

vi.mock('cloudinary', () => ({
  v2: {
    config: mocks.configure,
    api: { ping: mocks.ping },
  },
}));

import { loadEnv } from '../../config/env.js';
import { verifyCloudinaryConnection } from './cloudinary.service.js';

const logger = {
  info: vi.fn(),
  warn: vi.fn(),
};

const baseEnv = {
  DATABASE_URL: 'postgres://localhost:5432/getkeja',
  COOKIE_SECRET: 'a'.repeat(32),
  CSRF_SECRET: 'b'.repeat(32),
};

describe('verifyCloudinaryConnection', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('logs when Cloudinary is not configured without failing startup', async () => {
    await expect(
      verifyCloudinaryConnection(loadEnv(baseEnv), logger),
    ).resolves.toBeUndefined();

    expect(logger.info).toHaveBeenCalledWith(
      expect.objectContaining({
        component: 'cloudinary',
        status: 'not_configured',
      }),
      'Cloudinary uploads are not configured',
    );
    expect(mocks.ping).not.toHaveBeenCalled();
  });

  it('logs a verified connection when the configured account responds', async () => {
    mocks.ping.mockResolvedValue({ status: 'ok' });
    const env = loadEnv({
      ...baseEnv,
      CLOUDINARY_CLOUD_NAME: 'getkeja',
      CLOUDINARY_API_KEY: 'test-key',
      CLOUDINARY_API_SECRET: 'test-secret',
    });

    await verifyCloudinaryConnection(env, logger);

    expect(mocks.configure).toHaveBeenCalledWith({
      cloud_name: 'getkeja',
      api_key: 'test-key',
      api_secret: 'test-secret',
      secure: true,
    });
    expect(logger.info).toHaveBeenCalledWith(
      expect.objectContaining({
        component: 'cloudinary',
        status: 'connected',
      }),
      'Cloudinary connection verified',
    );
  });

  it('logs failed credentials without preventing startup', async () => {
    mocks.ping.mockRejectedValue(new Error('Invalid credentials'));
    const env = loadEnv({
      ...baseEnv,
      CLOUDINARY_CLOUD_NAME: 'getkeja',
      CLOUDINARY_API_KEY: 'test-key',
      CLOUDINARY_API_SECRET: 'test-secret',
    });

    await expect(verifyCloudinaryConnection(env, logger)).resolves.toBeUndefined();

    expect(logger.warn).toHaveBeenCalledWith(
      expect.objectContaining({
        component: 'cloudinary',
        status: 'disconnected',
        error: 'Invalid credentials',
      }),
      'Cloudinary connection check failed; image uploads may not work',
    );
  });
});
