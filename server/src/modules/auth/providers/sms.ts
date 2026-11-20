import { randomUUID } from 'node:crypto';
import { logDevelopmentCode } from './development-code-logger.js';

export interface SmsProvider {
  name: string;
  sendOtp(phone: string, otp: string): Promise<void>;
  sendLoginOtp(phone: string, otp: string): Promise<void>;
  sendMessage(phone: string, message: string): Promise<void>;
  sendSms(params: { to: string; body: string }): Promise<{ messageId: string }>;
}

export interface SmsProviderConfig {
  fromNumber?: string;
}

export function createSmsProvider(config: SmsProviderConfig = {}): SmsProvider {
  const providerType = process.env.SMS_PROVIDER?.toLowerCase() || 'development';

  switch (providerType) {
    case 'twilio':
      return createTwilioProvider(config);
    case 'africastalking':
      return createAfricaTalkingProvider(config);
    case 'vonage':
      return createVonageProvider(config);
    case 'development':
    default:
      return createDevelopmentSmsProvider(config);
  }
}

function createDevelopmentSmsProvider(config: SmsProviderConfig): SmsProvider {
  return {
    name: 'development',
    async sendOtp(phone: string, otp: string): Promise<void> {
      logDevelopmentCode('sms', 'Verification', phone, otp);
    },
    async sendLoginOtp(phone: string, otp: string): Promise<void> {
      logDevelopmentCode('sms', 'Login OTP', phone, otp);
    },
    async sendMessage(phone: string, message: string): Promise<void> {
      console.log(`[DEV SMS] To: ${phone}`);
      console.log(`[DEV SMS] Body: ${message}`);
    },
    async sendSms(params: { to: string; body: string }): Promise<{ messageId: string }> {
      console.log(`[DEV SMS] To: ${params.to}`);
      console.log(`[DEV SMS] Body: ${params.body}`);
      return { messageId: `dev-${randomUUID()}` };
    },
  };
}

function createTwilioProvider(config: SmsProviderConfig): SmsProvider {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = config.fromNumber || process.env.TWILIO_FROM_NUMBER;
  if (!accountSid || !authToken || !fromNumber) {
    throw new Error('TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_NUMBER must be configured');
  }

  return {
    name: 'twilio',
    async sendOtp(phone: string, otp: string): Promise<void> {
      await sendTwilioMessage(accountSid, authToken, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendLoginOtp(phone: string, otp: string): Promise<void> {
      await sendTwilioMessage(accountSid, authToken, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendMessage(phone: string, message: string): Promise<void> {
      await sendTwilioMessage(accountSid, authToken, fromNumber, phone, message);
    },
    async sendSms(params: { to: string; body: string }): Promise<{ messageId: string }> {
      await sendTwilioMessage(accountSid, authToken, fromNumber, params.to, params.body);
      return { messageId: `tw-${randomUUID()}` };
    },
  };
}

function createAfricaTalkingProvider(config: SmsProviderConfig): SmsProvider {
  const apiKey = process.env.AFRICASTALKING_API_KEY;
  const username = process.env.AFRICASTALKING_USERNAME || 'sandbox';
  const fromNumber = config.fromNumber || process.env.AFRICASTALKING_FROM_NUMBER;
  if (!apiKey) {
    throw new Error('AFRICASTALKING_API_KEY must be configured');
  }

  return {
    name: 'africastalking',
    async sendOtp(phone: string, otp: string): Promise<void> {
      await sendAfricaTalkingMessage(apiKey, username, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendLoginOtp(phone: string, otp: string): Promise<void> {
      await sendAfricaTalkingMessage(apiKey, username, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendMessage(phone: string, message: string): Promise<void> {
      await sendAfricaTalkingMessage(apiKey, username, fromNumber, phone, message);
    },
    async sendSms(params: { to: string; body: string }): Promise<{ messageId: string }> {
      await sendAfricaTalkingMessage(apiKey, username, fromNumber, params.to, params.body);
      return { messageId: `at-${randomUUID()}` };
    },
  };
}

function createVonageProvider(config: SmsProviderConfig): SmsProvider {
  const apiKey = process.env.VONAGE_API_KEY;
  const apiSecret = process.env.VONAGE_API_SECRET;
  const fromNumber = config.fromNumber || process.env.VONAGE_FROM_NUMBER;
  if (!apiKey || !apiSecret || !fromNumber) {
    throw new Error('VONAGE_API_KEY, VONAGE_API_SECRET, and VONAGE_FROM_NUMBER must be configured');
  }

  return {
    name: 'vonage',
    async sendOtp(phone: string, otp: string): Promise<void> {
      await sendVonageMessage(apiKey, apiSecret, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendLoginOtp(phone: string, otp: string): Promise<void> {
      await sendVonageMessage(apiKey, apiSecret, fromNumber, phone, `Your verification code is: ${otp}`);
    },
    async sendMessage(phone: string, message: string): Promise<void> {
      await sendVonageMessage(apiKey, apiSecret, fromNumber, phone, message);
    },
    async sendSms(params: { to: string; body: string }): Promise<{ messageId: string }> {
      await sendVonageMessage(apiKey, apiSecret, fromNumber, params.to, params.body);
      return { messageId: `vn-${randomUUID()}` };
    },
  };
}

async function sendTwilioMessage(
  accountSid: string,
  authToken: string,
  from: string,
  to: string,
  body: string,
): Promise<void> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const formData = new URLSearchParams();
  formData.append('From', from);
  formData.append('To', to);
  formData.append('Body', body);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`${accountSid}:${authToken}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error('Twilio message delivery failed');
  }
}

async function sendAfricaTalkingMessage(
  apiKey: string,
  username: string,
  from: string | undefined,
  to: string,
  message: string,
): Promise<void> {
  const formData = new FormData();
  formData.append('username', username);
  formData.append('to', to);
  formData.append('message', message);
  if (from) {
    formData.append('from', from);
  }

  const response = await fetch('https://api.africastalking.com/version1/messaging', {
    method: 'POST',
    headers: {
      'apiKey': apiKey,
      'Accept': 'application/json',
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error("Africa's Talking message delivery failed");
  }
}

async function sendVonageMessage(
  apiKey: string,
  apiSecret: string,
  from: string,
  to: string,
  text: string,
): Promise<void> {
  const formData = new URLSearchParams();
  formData.append('api_key', apiKey);
  formData.append('api_secret', apiSecret);
  formData.append('from', from);
  formData.append('to', to);
  formData.append('text', text);

  const response = await fetch('https://rest.nexmo.com/sms/json', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error('Vonage message delivery failed');
  }
}

let smsProviderInstance: SmsProvider | null = null;

export function getSmsProvider(): SmsProvider {
  if (!smsProviderInstance) {
    smsProviderInstance = createSmsProvider({ fromNumber: process.env.SMS_FROM_NUMBER });
  }
  return smsProviderInstance;
}

export function setSmsProvider(provider: SmsProvider): void {
  smsProviderInstance = provider;
}

export async function sendSms(
  provider: SmsProvider,
  params: { to: string; body: string }
): Promise<{ messageId: string }> {
  return provider.sendSms(params);
}