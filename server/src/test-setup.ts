import { resetPool } from './db/pool.js';
import { beforeEach } from 'vitest';
import { Redis } from 'ioredis';

const testEnv = {
  NODE_ENV: 'test',
  PORT: '3000',
  DATABASE_URL: 'postgresql://getkeja:Juma%402002@localhost:5433/getkeja',
  DB_POOL_MAX: '20',
  COOKIE_SECRET: 'test-cookie-secret-that-is-at-least-32-characters-long',
  CSRF_SECRET: 'test-csrf-secret-that-is-at-least-32-characters-long',
  // PEM-format placeholder (64+ chars) so document signed-URL signing works in tests.
  JWT_PRIVATE_KEY:
    'test-jwt-private-key-placeholder-value-that-is-at-least-sixty-four-characters-long-0000',
  LOG_LEVEL: 'debug',
  TRUST_PROXY: 'false',
  EMAIL_PROVIDER: 'development',
  EMAIL_FROM_ADDRESS: 'noreply@getkeja.com',
  EMAIL_FROM_NAME: 'GetKeja',
  EMAIL_BASE_URL: 'http://localhost:3000',
  SMS_PROVIDER: 'development',
  GOOGLE_CLIENT_ID: 'test-client-id',
  GOOGLE_CLIENT_SECRET: 'test-client-secret',
  GOOGLE_REDIRECT_URI: 'http://localhost:4000/api/auth/google/callback',

  // M-Pesa (Daraja) sandbox test credentials — placeholder values only, never
  // real credentials. Enables the payments module to load in the test env.
  MPESA_ENV: 'sandbox',
  MPESA_CONSUMER_KEY: 'test-consumer-key',
  MPESA_CONSUMER_SECRET: 'test-consumer-secret',
  MPESA_PASSKEY: 'test-passkey',
  MPESA_SHORTCODE: '123456',
  MPESA_CALLBACK_URL: 'http://localhost:4000/api/v1/payments/mpesa/callback',
  MPESA_CALLBACK_PATH: '/api/v1/payments/mpesa/callback',
  MPESA_BASE_URL: 'https://sandbox.safaricom.co.ke',

  // Pesapal sandbox test credentials — placeholder values only, never
  // real credentials. Enables the Pesapal payments module to load in the test env.
  PESAPAL_ENV: 'sandbox',
  PESAPAL_CONSUMER_KEY: 'test-consumer-key',
  PESAPAL_CONSUMER_SECRET: 'test-consumer-secret',
  PESAPAL_BASE_URL: 'https://cybqa.pesapal.com/pesapalpva',
  PESAPAL_CALLBACK_PATH: '/api/v1/payments/pesapal/callback',
  PESAPAL_IPN_PATH: '/api/v1/payments/pesapal/ipn',

  EMAIL_VERIFICATION_EXPIRY_HOURS: '24',
  PHONE_VERIFICATION_EXPIRY_MINUTES: '10',
  PHONE_VERIFICATION_OTP_LENGTH: '6',
  MAX_VERIFICATION_ATTEMPTS: '5',
  REGISTRATION_RATE_LIMIT_WINDOW_MS: '3600000',
  REGISTRATION_RATE_LIMIT_MAX: '1000',
  OTP_REQUEST_RATE_LIMIT_WINDOW_MS: '3600000',
  OTP_REQUEST_RATE_LIMIT_MAX: '3',
  LOGIN_EMAIL_RATE_LIMIT_MAX: '1000',
  LOGIN_PHONE_RATE_LIMIT_MAX: '1000',
  LOGIN_OTP_REQUEST_RATE_LIMIT_MAX: '1000',
  LOGIN_OTP_VERIFY_RATE_LIMIT_MAX: '1000',
  LOGIN_GOOGLE_RATE_LIMIT_MAX: '1000',
  LOGIN_IP_RATE_LIMIT_MAX: '1000',
};

for (const [key, value] of Object.entries(testEnv)) {
  process.env[key] = value;
}

resetPool();

// Flush Redis rate-limit counters before each test to ensure test isolation
// across files when running multiple suites together. This does not weaken
// production rate limiting — it only clears test-state counters.
const redis = new Redis('redis://localhost:6379', { lazyConnect: false });

beforeEach(async () => {
  await redis.flushall();
});