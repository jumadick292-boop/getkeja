import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { logDevelopmentCode } from './development-code-logger.js';
import { createEmailProvider } from './email.js';
import { createSmsProvider } from './sms.js';

describe('logDevelopmentCode', () => {
  const log = vi.fn();
  const emailConfig = {
    fromAddress: 'noreply@example.com',
    fromName: 'GetKeja',
    baseUrl: 'http://localhost:3000',
  };

  beforeEach(() => {
    vi.spyOn(console, 'info').mockImplementation(log);
    vi.stubEnv('NODE_ENV', 'development');
    vi.stubEnv('EMAIL_PROVIDER', 'development');
    vi.stubEnv('SMS_PROVIDER', 'development');
    log.mockClear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it('logs codes only for the development delivery provider', () => {
    logDevelopmentCode('email', 'Login OTP', 'user@example.com', '012345');
    logDevelopmentCode('sms', 'Verification', '+254700000000', '654321');

    expect(log).toHaveBeenNthCalledWith(
      1,
      '[DEV EMAIL] Login OTP code for user@example.com: 012345',
    );
    expect(log).toHaveBeenNthCalledWith(
      2,
      '[DEV SMS] Verification code for +254700000000: 654321',
    );
  });

  it('does not log codes outside development', () => {
    vi.stubEnv('NODE_ENV', 'production');

    logDevelopmentCode('email', 'Login OTP', 'user@example.com', '012345');

    expect(log).not.toHaveBeenCalled();
  });

  it('does not log codes when a real delivery provider is selected', () => {
    vi.stubEnv('SMS_PROVIDER', 'twilio');

    logDevelopmentCode('sms', 'Login OTP', '+254700000000', '654321');

    expect(log).not.toHaveBeenCalled();
  });

  it('uses the development default when NODE_ENV is empty', () => {
    vi.stubEnv('NODE_ENV', '');

    logDevelopmentCode('sms', 'Login OTP', '+254700000000', '654321');

    expect(log).toHaveBeenCalledWith(
      '[DEV SMS] Login OTP code for +254700000000: 654321',
    );
  });

  it('logs password reset, phone login, and phone signup codes through dev providers', async () => {
    vi.stubEnv('NODE_ENV', 'development');
    vi.stubEnv('EMAIL_PROVIDER', 'development');
    vi.stubEnv('SMS_PROVIDER', 'development');

    const email = createEmailProvider(emailConfig);
    const sms = createSmsProvider();

    await email.sendPasswordResetEmail('user@example.com', 'reset-token');
    await sms.sendLoginOtp('+254700000000', '112233');
    await sms.sendOtp('+254711111111', '445566');

    expect(log).toHaveBeenNthCalledWith(
      1,
      '[DEV EMAIL] Password reset code for user@example.com: reset-token',
    );
    expect(log).toHaveBeenNthCalledWith(
      2,
      '[DEV SMS] Login OTP code for +254700000000: 112233',
    );
    expect(log).toHaveBeenNthCalledWith(
      3,
      '[DEV SMS] Verification code for +254711111111: 445566',
    );
  });
});
