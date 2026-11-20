import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

const originalEnv = {
  AWS_REGION: process.env.AWS_REGION,
  AWS_S3_PRIVATE_BUCKET: process.env.AWS_S3_PRIVATE_BUCKET,
  AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,
};

import {
  putPrivateDocument,
  signedPrivateDocumentUrl,
} from './private-document-storage.service.js';

describe('private document storage', () => {
  beforeEach(() => {
    process.env.AWS_REGION = 'us-east-1';
    process.env.AWS_S3_PRIVATE_BUCKET = 'private-verification-documents';
    process.env.AWS_ACCESS_KEY_ID = 'test-access-key';
    process.env.AWS_SECRET_ACCESS_KEY = 'test-secret-key';
  });

  afterEach(() => {
    for (const [key, value] of Object.entries(originalEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    vi.restoreAllMocks();
  });

  it('uploads only to the configured private bucket with server-side encryption', async () => {
    const send = vi.spyOn(S3Client.prototype, 'send').mockResolvedValue({} as never);
    await putPrivateDocument('verification/profiles/p1/random-id', Buffer.from('%PDF'), 'application/pdf');

    const command = send.mock.calls[0]?.[0];
    expect(command).toBeInstanceOf(PutObjectCommand);
    expect((command as PutObjectCommand).input).toMatchObject({
      Bucket: 'private-verification-documents',
      ServerSideEncryption: 'AES256',
      ContentType: 'application/pdf',
    });
  });

  it('creates a five-minute signed URL without making the object public', async () => {
    const url = await signedPrivateDocumentUrl('verification/p/r', 'proof.pdf', 'application/pdf');
    expect(url).toContain('X-Amz-Expires=300');
    expect(url).toContain('private-verification-documents');
  });

  it('fails closed when private storage is not configured', async () => {
    delete process.env.AWS_S3_PRIVATE_BUCKET;
    await expect(putPrivateDocument('verification/p/r', Buffer.from('%PDF'), 'application/pdf'))
      .rejects.toMatchObject({ status: 503 });
  });
});
