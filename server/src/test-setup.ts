import { resetPool } from './db/pool.js';

const testEnv = {
  NODE_ENV: 'test',
  PORT: '3000',
  DATABASE_URL: 'postgresql://getkeja:Juma%402002@localhost:5433/getkeja',
  DB_POOL_MAX: '20',
  COOKIE_SECRET: 'test-cookie-secret-that-is-at-least-32-characters-long',
  CSRF_SECRET: 'test-csrf-secret-that-is-at-least-32-characters-long',
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