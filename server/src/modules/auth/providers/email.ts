import { randomUUID } from 'node:crypto';
import { logDevelopmentCode } from './development-code-logger.js';

export interface EmailProvider {
  name: string;
  sendVerificationEmail(email: string, token: string, firstName?: string): Promise<void>;
  sendLoginOtp(email: string, otp: string, firstName?: string): Promise<void>;
  sendPasswordResetEmail(email: string, token: string, firstName?: string): Promise<void>;
  sendAccountRecoveryEmail(email: string, token: string, firstName?: string): Promise<void>;
  sendAccountRestorationEmail(email: string, token: string, firstName?: string): Promise<void>;
  sendWelcomeEmail(email: string, firstName?: string): Promise<void>;
  sendEmail(params: { to: string; subject: string; html: string; text?: string }): Promise<{ messageId: string }>;
}

export interface EmailProviderConfig {
  fromAddress: string;
  fromName: string;
  baseUrl: string;
}

export function createEmailProvider(config: EmailProviderConfig): EmailProvider {
  const providerType = process.env.EMAIL_PROVIDER?.toLowerCase() || 'development';

  switch (providerType) {
    case 'sendgrid':
      return createSendGridProvider(config);
    case 'mailgun':
      return createMailgunProvider(config);
    case 'ses':
      return createSesProvider(config);
    case 'development':
    default:
      return createDevelopmentEmailProvider(config);
  }
}

function createDevelopmentEmailProvider(config: EmailProviderConfig): EmailProvider {
  return {
    name: 'development',
    async sendVerificationEmail(email: string, token: string, _firstName?: string): Promise<void> {
      logDevelopmentCode('email', 'Verification', email, token);
    },
    async sendLoginOtp(email: string, otp: string, _firstName?: string): Promise<void> {
      logDevelopmentCode('email', 'Login OTP', email, otp);
    },
    async sendPasswordResetEmail(email: string, token: string, _firstName?: string): Promise<void> {
      logDevelopmentCode('email', 'Password reset', email, token);
    },
    async sendAccountRecoveryEmail(email: string, token: string, _firstName?: string): Promise<void> {
      logDevelopmentCode('email', 'Account recovery', email, token);
    },
    async sendAccountRestorationEmail(email: string, token: string, _firstName?: string): Promise<void> {
      logDevelopmentCode('email', 'Account restoration', email, token);
    },
    async sendWelcomeEmail(email: string, _firstName?: string): Promise<void> {
      console.log('[DEV EMAIL] Welcome email not delivered');
    },
    async sendEmail(params: { to: string; subject: string; html: string; text?: string }): Promise<{ messageId: string }> {
      console.log('[DEV EMAIL] Sending email to:', params.to, 'Subject:', params.subject);
      if (params.subject === 'Confirm your GetKeja email change') {
        const code = params.text?.match(/verification code .*?:\s*(\S+)/i)?.[1];
        if (code) logDevelopmentCode('email', 'Email change', params.to, code);
      }
      return { messageId: `dev-${randomUUID()}` };
    },
  };
}

function createSendGridProvider(config: EmailProviderConfig): EmailProvider {
  const apiKey = process.env.SENDGRID_API_KEY;
  if (!apiKey) {
    throw new Error('SENDGRID_API_KEY not configured');
  }

  return {
    name: 'sendgrid',
    async sendVerificationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `${config.baseUrl}/verify-email?email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}`;
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Verify your email address', `
        Hi ${firstName || 'there'},<br>
        Your 6-digit email verification code is <strong>${token}</strong>.<br>
        Enter this code in the app or <a href="${url}">return to verification</a>.<br>
        This link expires in 24 hours.
      `);
    },
    async sendLoginOtp(email: string, otp: string, firstName?: string): Promise<void> {
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Your GetKeja sign-in code', `
        Hi ${firstName || 'there'},<br>
        Your GetKeja sign-in code is <strong>${otp}</strong>. It expires shortly.
      `);
    },
    async sendPasswordResetEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://reset-password?token=${encodeURIComponent(token)}`;
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Reset your password', `
        Hi ${firstName || 'there'},<br>
        Open <a href="${url}">GetKeja to reset your password</a>. If the link does not open the app, enter this reset token in the app:<br>
        <strong>${token}</strong><br>
        This token expires in 1 hour.
      `);
    },
    async sendAccountRecoveryEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://account-recovery?token=${encodeURIComponent(token)}`;
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Recover your GetKeja account', `
        Hi ${firstName || 'there'},<br>
        Open <a href="${url}">GetKeja account recovery</a>. If the link does not open the app, enter this recovery token in the app:<br>
        <strong>${token}</strong><br>
        This token expires in 24 hours.
      `);
    },
    async sendAccountRestorationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://restore-account?token=${encodeURIComponent(token)}`;
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Restore your GetKeja account', `
        Hi ${firstName || 'there'},<br>
        Open <a href="${url}">GetKeja account restoration</a>. If the link does not open the app, enter this restoration code in the app:<br>
        <strong>${token}</strong><br>
        This code expires in 1 hour.
      `);
    },
    async sendWelcomeEmail(email: string, firstName?: string): Promise<void> {
      await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, email, 'Welcome to GetKeja!', `
        Hi ${firstName || 'there'},<br>
        Welcome to GetKeja! We're excited to have you.
      `);
    },
    async sendEmail(params: { to: string; subject: string; html: string; text?: string }): Promise<{ messageId: string }> {
      const result = await sendSendGridEmail(apiKey, config.fromAddress, config.fromName, params.to, params.subject, params.html);
      return { messageId: result.messageId || `sg-${randomUUID()}` };
    },
  };
}

function createMailgunProvider(config: EmailProviderConfig): EmailProvider {
  const apiKey = process.env.MAILGUN_API_KEY;
  const domain = process.env.MAILGUN_DOMAIN;
  if (!apiKey || !domain) {
    throw new Error('MAILGUN_API_KEY and MAILGUN_DOMAIN must be configured');
  }

  return {
    name: 'mailgun',
    async sendVerificationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `${config.baseUrl}/verify-email?email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}`;
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Verify your email address', `
        Hi ${firstName || 'there'},
        Your 6-digit email verification code is ${token}.
        Enter the code in the app or return to verification: ${url}
      `);
    },
    async sendLoginOtp(email: string, otp: string, firstName?: string): Promise<void> {
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Your GetKeja sign-in code', `
        Hi ${firstName || 'there'}, your GetKeja sign-in code is ${otp}. It expires shortly.
      `);
    },
    async sendPasswordResetEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://reset-password?token=${encodeURIComponent(token)}`;
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Reset your password', `
        Hi ${firstName || 'there'},
        Open GetKeja to reset your password: ${url}
        If the link does not open the app, enter this reset token in the app: ${token}
        This token expires in 1 hour.
      `);
    },
    async sendAccountRecoveryEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://account-recovery?token=${encodeURIComponent(token)}`;
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Recover your GetKeja account', `
        Hi ${firstName || 'there'},
        Open GetKeja account recovery: ${url}
        If the link does not open the app, enter this recovery token in the app: ${token}
        This token expires in 24 hours.
      `);
    },
    async sendAccountRestorationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://restore-account?token=${encodeURIComponent(token)}`;
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Restore your GetKeja account', `
        Hi ${firstName || 'there'},
        Open GetKeja account restoration: ${url}
        If the link does not open the app, enter this restoration code in the app: ${token}
        This code expires in 1 hour.
      `);
    },
    async sendWelcomeEmail(email: string, firstName?: string): Promise<void> {
      await sendMailgunEmail(apiKey, domain, config.fromAddress, email, 'Welcome to GetKeja!', `
        Hi ${firstName || 'there'},
        Welcome to GetKeja!
      `);
    },
    async sendEmail(params: { to: string; subject: string; html: string; text?: string }): Promise<{ messageId: string }> {
      await sendMailgunEmail(apiKey, domain, config.fromAddress, params.to, params.subject, params.text || params.html);
      return { messageId: `mg-${randomUUID()}` };
    },
  };
}

function createSesProvider(config: EmailProviderConfig): EmailProvider {
  const region = process.env.AWS_REGION || 'us-east-1';
  const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
  const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;
  if (!accessKeyId || !secretAccessKey) {
    throw new Error('AWS credentials not configured');
  }

  return {
    name: 'ses',
    async sendVerificationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `${config.baseUrl}/verify-email?email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}`;
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Verify your email address', `
        Hi ${firstName || 'there'},
        Your 6-digit email verification code is ${token}.
        Enter the code in the app or return to verification: ${url}
      `);
    },
    async sendLoginOtp(email: string, otp: string, firstName?: string): Promise<void> {
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Your GetKeja sign-in code', `
        Hi ${firstName || 'there'}, your GetKeja sign-in code is ${otp}. It expires shortly.
      `);
    },
    async sendPasswordResetEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://reset-password?token=${encodeURIComponent(token)}`;
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Reset your password', `
        Hi ${firstName || 'there'},
        Open GetKeja to reset your password: ${url}
        If the link does not open the app, enter this reset token in the app: ${token}
        This token expires in 1 hour.
      `);
    },
    async sendAccountRecoveryEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://account-recovery?token=${encodeURIComponent(token)}`;
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Recover your GetKeja account', `
        Hi ${firstName || 'there'},
        Open GetKeja account recovery: ${url}
        If the link does not open the app, enter this recovery token in the app: ${token}
        This token expires in 24 hours.
      `);
    },
    async sendAccountRestorationEmail(email: string, token: string, firstName?: string): Promise<void> {
      const url = `getkeja://restore-account?token=${encodeURIComponent(token)}`;
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Restore your GetKeja account', `
        Hi ${firstName || 'there'},
        Open GetKeja account restoration: ${url}
        If the link does not open the app, enter this restoration code in the app: ${token}
        This code expires in 1 hour.
      `);
    },
    async sendWelcomeEmail(email: string, firstName?: string): Promise<void> {
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, email, 'Welcome to GetKeja!', `
        Hi ${firstName || 'there'},
        Welcome to GetKeja!
      `);
    },
    async sendEmail(params: { to: string; subject: string; html: string; text?: string }): Promise<{ messageId: string }> {
      await sendSesEmail(region, accessKeyId, secretAccessKey, config.fromAddress, params.to, params.subject, params.text || params.html);
      return { messageId: `ses-${randomUUID()}` };
    },
  };
}

async function sendSendGridEmail(
  apiKey: string,
  fromAddress: string,
  fromName: string,
  to: string,
  subject: string,
  html: string,
): Promise<{ messageId: string }> {
  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to }], subject }],
      from: { email: fromAddress, name: fromName },
      content: [{ type: 'text/html', value: html }],
    }),
  });

  if (!response.ok) {
    throw new Error('SendGrid email delivery failed');
  }

  // SendGrid returns message ID in the X-Message-Id header
  const messageId = response.headers.get('X-Message-Id') || `sg-${randomUUID()}`;
  return { messageId };
}

async function sendMailgunEmail(
  apiKey: string,
  domain: string,
  from: string,
  to: string,
  subject: string,
  text: string,
): Promise<{ messageId: string }> {
  const formData = new FormData();
  formData.append('from', from);
  formData.append('to', to);
  formData.append('subject', subject);
  formData.append('text', text);

  const response = await fetch(`https://api.mailgun.net/v3/${domain}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`api:${apiKey}`)}`,
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error('Mailgun email delivery failed');
  }

  const messageId = response.headers.get('X-Message-Id') || `mg-${randomUUID()}`;
  return { messageId };
}

async function sendSesEmail(
  region: string,
  accessKeyId: string,
  secretAccessKey: string,
  from: string,
  to: string,
  subject: string,
  bodyText: string,
): Promise<{ messageId: string }> {
  throw new Error('AWS SES implementation requires AWS SDK - not implemented in this version');
}

let emailProviderInstance: EmailProvider | null = null;

export function getEmailProvider(): EmailProvider {
  if (!emailProviderInstance) {
    emailProviderInstance = createEmailProvider({
      fromAddress: process.env.EMAIL_FROM_ADDRESS || 'noreply@getkeja.com',
      fromName: process.env.EMAIL_FROM_NAME || 'GetKeja',
      baseUrl: process.env.EMAIL_BASE_URL || 'http://localhost:3000',
    });
  }
  return emailProviderInstance;
}

export function setEmailProvider(provider: EmailProvider): void {
  emailProviderInstance = provider;
}

export async function sendEmail(
  provider: EmailProvider,
  params: { to: string; subject: string; html: string; text?: string }
): Promise<{ messageId: string }> {
  return provider.sendEmail(params);
}
