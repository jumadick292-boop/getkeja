import { describe, expect, it } from 'vitest';
import { ValidationError } from '../../shared/errors.js';
import {
  MAX_PROFILE_IMAGE_BYTES,
  validateProfileImageFile,
} from './profile-image-upload.validation.js';

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlU3KwAAAAASUVORK5CYII=',
  'base64',
);

describe('profile image upload validation', () => {
  it('accepts a supported image with matching file signature and MIME type', async () => {
    await expect(validateProfileImageFile({
      buffer: png,
      mimetype: 'image/png',
      size: png.length,
    })).resolves.toBeUndefined();
  });

  it('rejects spoofed MIME types based on the actual file signature', async () => {
    await expect(validateProfileImageFile({
      buffer: png,
      mimetype: 'image/jpeg',
      size: png.length,
    })).rejects.toBeInstanceOf(ValidationError);
  });

  it('rejects files larger than the upload limit', async () => {
    await expect(validateProfileImageFile({
      buffer: png,
      mimetype: 'image/png',
      size: MAX_PROFILE_IMAGE_BYTES + 1,
    })).rejects.toMatchObject({ status: 413 });
  });
});
