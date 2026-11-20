import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  findLoginIdentity: vi.fn(),
  consumePhoneVerificationToken: vi.fn(),
  incrementPhoneVerificationAttempt: vi.fn(),
}));

vi.mock('./auth.repository.js', () => ({
  findLoginIdentity: mocks.findLoginIdentity,
  consumePhoneVerificationToken: mocks.consumePhoneVerificationToken,
  incrementPhoneVerificationAttempt: mocks.incrementPhoneVerificationAttempt,
}));

import { confirmPhoneVerification } from './auth.service.js';

describe('phone verification attempt lockout', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.findLoginIdentity.mockResolvedValue({ id: 'phone-identity-1' });
    mocks.consumePhoneVerificationToken.mockResolvedValue(null);
  });

  it('increments the active code attempt count for a wrong OTP and reports lockout at the limit', async () => {
    mocks.incrementPhoneVerificationAttempt.mockResolvedValue({
      attemptCount: 5,
      maxAttempts: 5,
    });

    const result = await confirmPhoneVerification('+254712345678', '000000');

    expect(mocks.incrementPhoneVerificationAttempt).toHaveBeenCalledWith(
      'phone-identity-1',
    );
    expect(result).toEqual({
      success: false,
      message: 'Too many failed attempts. Please request a new code.',
    });
  });

  it('keeps the active code usable until its maximum failed attempts', async () => {
    mocks.incrementPhoneVerificationAttempt.mockResolvedValue({
      attemptCount: 4,
      maxAttempts: 5,
    });

    const result = await confirmPhoneVerification('+254712345678', '000000');

    expect(result).toEqual({
      success: false,
      message: 'Invalid or expired verification code',
    });
  });
});
