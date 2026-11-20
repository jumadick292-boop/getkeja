import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import { v2 as cloudinary } from 'cloudinary';
import { loadEnv } from '../../config/env.js';
import { HttpError } from '../../shared/errors.js';
import type { profileImageUploadSchema } from './profile.schema.js';
import type { z } from 'zod';
import { validateProfileImageFile } from './profile-image-upload.validation.js';

export interface UploadedProfileImage {
  secureUrl: string;
  assetId: string;
  format: string;
  width: number;
  height: number;
}

type UploadInput = z.infer<typeof profileImageUploadSchema>;

export async function uploadProfileImage(
  userId: string,
  input: UploadInput,
  file: { buffer: Buffer; mimetype: string; size: number },
): Promise<UploadedProfileImage> {
  const env = loadEnv();
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new HttpError('Image uploads are not configured on this server', 503);
  }
  await validateProfileImageFile(file);

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });

  const folder = getFolder(userId, input);
  const result = await new Promise<{
    secure_url?: string;
    asset_id?: string;
    format?: string;
    width?: number;
    height?: number;
  }>((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        public_id: randomUUID(),
        resource_type: 'image',
        overwrite: false,
        allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        transformation: [{ width: 2048, height: 2048, crop: 'limit', quality: 'auto' }],
      },
      (error, uploaded) => {
        if (error) {
          reject(error);
          return;
        }
        if (!uploaded) {
          reject(new Error('Cloudinary returned no upload result'));
          return;
        }
        resolve(uploaded);
      },
    );
    Readable.from([file.buffer]).pipe(stream);
    stream.on('error', reject);
  }).catch((error: unknown) => {
    const uploadError = new HttpError('Image upload failed', 502);
    uploadError.cause = error;
    throw uploadError;
  });

  if (!result.secure_url || !result.asset_id || !result.format || !result.width || !result.height) {
    throw new HttpError('Image upload returned incomplete metadata', 502);
  }

  return {
    secureUrl: result.secure_url,
    assetId: result.asset_id,
    format: result.format,
    width: result.width,
    height: result.height,
  };
}

export async function deleteUserProfileAssets(
  userId: string,
  specializedProfileIds: string[],
): Promise<void> {
  const env = loadEnv();
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    return;
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });

  const prefixes = [
    `getkeja/profiles/${userId}/`,
    ...specializedProfileIds.map((profileId) => `getkeja/profiles/${profileId}/`),
  ];
  for (const prefix of prefixes) {
    await cloudinary.api.delete_resources_by_prefix(prefix, {
      resource_type: 'image',
      type: 'upload',
    });
  }
}

function getFolder(userId: string, input: UploadInput): string {
  if (input.kind === 'personal_photo') return `getkeja/profiles/${userId}/personal`;
  if (input.kind === 'organization_logo') {
    return `getkeja/organizations/${input.organizationId}/logos`;
  }
  return `getkeja/profiles/${input.profileId}/${input.kind === 'profile_photo' ? 'photos' : 'logos'}`;
}
