import { v2 as cloudinary } from 'cloudinary';
import type { Logger } from 'pino';
import type { Env } from '../../config/env.js';

const CLOUDINARY_COMPONENT = { component: 'cloudinary' };
type CloudinaryLogger = Pick<Logger, 'info' | 'warn'>;

export async function verifyCloudinaryConnection(
  env: Env,
  logger: CloudinaryLogger,
): Promise<void> {
  const credentials = {
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
  };
  const missingConfiguration = Object.entries(credentials)
    .filter(([, value]) => !value)
    .map(([name]) => name.toUpperCase());

  if (missingConfiguration.length > 0) {
    logger.info(
      { ...CLOUDINARY_COMPONENT, status: 'not_configured', missingConfiguration },
      'Cloudinary uploads are not configured',
    );
    return;
  }

  cloudinary.config({ ...credentials, secure: true });

  try {
    await cloudinary.api.ping();
    logger.info(
      { ...CLOUDINARY_COMPONENT, status: 'connected' },
      'Cloudinary connection verified',
    );
  } catch (error) {
    logger.warn(
      {
        ...CLOUDINARY_COMPONENT,
        status: 'disconnected',
        error: error instanceof Error ? error.message : 'Unknown Cloudinary error',
      },
      'Cloudinary connection check failed; image uploads may not work',
    );
  }
}
