import { describe, expect, it } from 'vitest';
import { validateVerificationDocument } from './verification-document-upload.validation.js';

describe('verification document validation', () => {
  it('accepts a PDF with a matching signature and records a SHA-256 hash', async () => {
    const buffer = Buffer.from('%PDF-1.7\nverification document');
    const result = await validateVerificationDocument({
      buffer,
      mimetype: 'application/pdf',
      size: buffer.length,
    });
    expect(result.sha256).toMatch(/^[a-f0-9]{64}$/);
  });

  it('rejects spoofed MIME types and empty files', async () => {
    const buffer = Buffer.from('not a real pdf');
    await expect(validateVerificationDocument({
      buffer, mimetype: 'application/pdf', size: buffer.length,
    })).rejects.toThrow('valid PDF');
    await expect(validateVerificationDocument({
      buffer: Buffer.alloc(0), mimetype: 'application/pdf', size: 0,
    })).rejects.toThrow('empty');
  });
});
