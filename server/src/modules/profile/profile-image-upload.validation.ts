import { fileTypeFromBuffer } from 'file-type';
import { HttpError, ValidationError } from '../../shared/errors.js';

export const MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

export async function validateProfileImageFile(file: {
  buffer: Buffer;
  mimetype: string;
  size: number;
}): Promise<void> {
  if (file.size > MAX_PROFILE_IMAGE_BYTES) {
    throw new HttpError('Image must be 5 MB or smaller', 413);
  }

  const detectedType = await fileTypeFromBuffer(file.buffer);
  if (
    !detectedType ||
    !ALLOWED_MIME_TYPES.has(detectedType.mime) ||
    detectedType.mime !== file.mimetype
  ) {
    throw new ValidationError('Only JPEG, PNG, and WebP images are supported');
  }
}
