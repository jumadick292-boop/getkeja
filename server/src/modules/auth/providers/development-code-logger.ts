type CodeChannel = 'email' | 'sms';

export function logDevelopmentCode(
  channel: CodeChannel,
  purpose: string,
  recipient: string,
  code: string,
): void {
  const providerVariable = channel === 'email' ? 'EMAIL_PROVIDER' : 'SMS_PROVIDER';
  const provider = process.env[providerVariable]?.toLowerCase() || 'development';
  const nodeEnv = process.env.NODE_ENV?.toLowerCase() || 'development';

  if (nodeEnv !== 'development' || provider !== 'development') {
    return;
  }

  console.info(`[DEV ${channel.toUpperCase()}] ${purpose} code for ${recipient}: ${code}`);
}
