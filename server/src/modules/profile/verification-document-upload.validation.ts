import { createHash } from 'node:crypto';
import { fileTypeFromBuffer } from 'file-type';
import { HttpError, ValidationError } from '../../shared/errors.js';

export const MAX_VERIFICATION_DOCUMENT_BYTES = 10 * 1024 * 1024;
const allowedMimeTypes = new Set(['application/pdf', 'image/jpeg', 'image/png', 'image/webp']);

export async function validateVerificationDocument(file: {
  buffer: Buffer;
  mimetype: string;
  size: number;
}): Promise<{ sha256: string }> {
  if (file.size <= 0) throw new ValidationError('The uploaded document is empty');
  if (file.size > MAX_VERIFICATION_DOCUMENT_BYTES) {
    throw new HttpError('Verification document must be 10 MB or smaller', 413);
  }
  const detected = await fileTypeFromBuffer(file.buffer);
  if (!detected || !allowedMimeTypes.has(detected.mime) || detected.mime !== file.mimetype) {
    throw new ValidationError('Use a valid PDF, JPEG, PNG, or WebP document');
  }
  return { sha256: createHash('sha256').update(file.buffer).digest('hex') };
}
