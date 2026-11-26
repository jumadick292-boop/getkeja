import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().max(65535).default(4000),
  DATABASE_URL: z.url(),
  DB_POOL_MAX: z.coerce.number().int().positive().default(20),
  COOKIE_SECRET: z.string().min(32),
  CSRF_SECRET: z.string().min(32),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  TRUST_PROXY: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  CORS_ALLOWED_ORIGINS: z.string().default('http://localhost:3000'),

  // Redis configuration
  REDIS_URL: z.url().default('redis://localhost:6379'),

  // Email configuration
  EMAIL_PROVIDER: z.enum(['development', 'sendgrid', 'mailgun', 'ses']).default('development'),
  EMAIL_FROM_ADDRESS: z.email().default('noreply@getkeja.com'),
  EMAIL_FROM_NAME: z.string().default('GetKeja'),
  EMAIL_BASE_URL: z.url().default('http://localhost:3000'),
  CLOUDINARY_CLOUD_NAME: z.string().min(1).optional(),
  CLOUDINARY_API_KEY: z.string().min(1).optional(),
  CLOUDINARY_API_SECRET: z.string().min(1).optional(),
  GOOGLE_MAPS_SERVER_API_KEY: z.string().min(1).optional(),
  GOOGLE_ROUTES_API_KEY: z.string().min(1).optional(),
  SENDGRID_API_KEY: z.string().optional(),
  MAILGUN_API_KEY: z.string().optional(),
  MAILGUN_DOMAIN: z.string().optional(),
  AWS_REGION: z.string().optional(),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  AWS_S3_PRIVATE_BUCKET: z.string().min(3).optional(),

  // SMS configuration
  SMS_PROVIDER: z.enum(['development', 'twilio', 'africastalking', 'vonage']).default('development'),
  SMS_FROM_NUMBER: z.string().optional(),
  TWILIO_ACCOUNT_SID: z.string().optional(),
  TWILIO_AUTH_TOKEN: z.string().optional(),
  TWILIO_FROM_NUMBER: z.string().optional(),
  AFRICASTALKING_API_KEY: z.string().optional(),
  AFRICASTALKING_USERNAME: z.string().optional(),
  AFRICASTALKING_FROM_NUMBER: z.string().optional(),
  VONAGE_API_KEY: z.string().optional(),
  VONAGE_API_SECRET: z.string().optional(),
  VONAGE_FROM_NUMBER: z.string().optional(),

  // M-Pesa (Safaricom Daraja) — tenant rent payments via STK Push
  MPESA_ENV: z.enum(['sandbox', 'production']).optional(),
  MPESA_CONSUMER_KEY: z.string().optional(),
  MPESA_CONSUMER_SECRET: z.string().optional(),
  MPESA_PASSKEY: z.string().optional(),
  MPESA_SHORTCODE: z.string().optional(),
  MPESA_CALLBACK_URL: z.string().url().optional(),
  MPESA_CALLBACK_PATH: z.string().optional(),
  MPESA_ACCOUNT_REFERENCE: z.string().optional(),
  MPESA_TRANSACTION_DESC: z.string().optional(),
  MPESA_BASE_URL: z.string().url().optional(),

  // Pesapal — alternative payment gateway for tenant rent payments
  PESAPAL_ENV: z.enum(['sandbox', 'production']).optional(),
  PESAPAL_CONSUMER_KEY: z.string().optional(),
  PESAPAL_CONSUMER_SECRET: z.string().optional(),
  PESAPAL_CALLBACK_PATH: z.string().optional(),
  PESAPAL_IPN_PATH: z.string().optional(),
  PESAPAL_NOTIFICATION_ID: z.string().optional(),
  PESAPAL_BASE_URL: z.string().url().optional(),

  // Google OAuth configuration
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  GOOGLE_REDIRECT_URI: z.url().optional(),
  GOOGLE_ALLOWED_CLIENT_IDS: z.string().optional(),

  // Verification settings
  EMAIL_VERIFICATION_EXPIRY_HOURS: z.coerce.number().int().positive().default(24),
  PHONE_VERIFICATION_EXPIRY_MINUTES: z.coerce.number().int().positive().default(10),
  PHONE_VERIFICATION_OTP_LENGTH: z.coerce.number().int().min(4).max(8).default(6),
  MAX_VERIFICATION_ATTEMPTS: z.coerce.number().int().positive().default(5),

  // Registration rate limiting
  REGISTRATION_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(3600000),
  REGISTRATION_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(5),
  OTP_REQUEST_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(3600000),
  OTP_REQUEST_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(3),
  OTP_RESEND_COOLDOWN_SECONDS: z.coerce.number().int().positive().default(60),
  LOGIN_OTP_EXPIRY_MINUTES: z.coerce.number().int().positive().max(15).default(5),
  OTP_VERIFY_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  OTP_VERIFY_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(5),

  // Login rate limiting
  LOGIN_EMAIL_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_EMAIL_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(10),
  LOGIN_PHONE_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_PHONE_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(10),
  LOGIN_OTP_REQUEST_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_OTP_REQUEST_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(5),
  LOGIN_OTP_VERIFY_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_OTP_VERIFY_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(5),
  LOGIN_GOOGLE_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_GOOGLE_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(10),
  LOGIN_IP_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  LOGIN_IP_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(30),

  // MFA settings
  MFA_CHALLENGE_EXPIRY_MINUTES: z.coerce.number().int().positive().default(10),
  MFA_CHALLENGE_MAX_ATTEMPTS: z.coerce.number().int().positive().default(3),
  MFA_ENROLLMENT_TRANSACTION_MINUTES: z.coerce.number().int().positive().max(60).default(15),

  // TOTP MFA settings
  MFA_TOTP_ISSUER: z.string().default('GetKeja'),
  MFA_TOTP_WINDOW: z.coerce.number().int().min(0).max(5).default(1),
  MFA_TOTP_ALGORITHM: z.enum(['SHA1', 'SHA256', 'SHA512']).default('SHA1'),
  MFA_TOTP_DIGITS: z.coerce.number().int().min(6).max(8).default(6),
  MFA_TOTP_PERIOD: z.coerce.number().int().positive().default(30),

  // SMS MFA settings
  MFA_SMS_EXPIRY_MINUTES: z.coerce.number().int().positive().default(5),
  MFA_SMS_OTP_LENGTH: z.coerce.number().int().min(4).max(8).default(6),
  MFA_SMS_MAX_ATTEMPTS: z.coerce.number().int().positive().default(3),
  MFA_SMS_RESEND_COOLDOWN_SECONDS: z.coerce.number().int().positive().default(60),

  // Email MFA settings
  MFA_EMAIL_EXPIRY_MINUTES: z.coerce.number().int().positive().default(10),
  MFA_EMAIL_CODE_LENGTH: z.coerce.number().int().min(4).max(8).default(6),
  MFA_EMAIL_MAX_ATTEMPTS: z.coerce.number().int().positive().default(3),
  MFA_EMAIL_RESEND_COOLDOWN_SECONDS: z.coerce.number().int().positive().default(60),

  // Recovery codes settings
  MFA_RECOVERY_CODES_COUNT: z.coerce.number().int().positive().default(10),
  MFA_RECOVERY_CODE_LENGTH: z.coerce.number().int().positive().default(10),

  // Account Recovery settings
  ACCOUNT_RECOVERY_TOKEN_EXPIRY_HOURS: z.coerce.number().int().positive().default(24),
  ACCOUNT_RECOVERY_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),
  ACCOUNT_RECOVERY_REQUIRES_ADMIN_REVIEW: z.enum(['true', 'false']).default('false').transform(v => v === 'true'),

  // Session settings
  SESSION_IDLE_TIMEOUT_MINUTES: z.coerce.number().int().positive().default(30),
  SESSION_ABSOLUTE_TIMEOUT_HOURS: z.coerce.number().int().positive().default(168), // 7 days
  SESSION_EXTEND_ON_ACTIVITY: z.enum(['true', 'false']).default('true').transform(v => v === 'true'),

  // Refresh token settings
  REFRESH_TOKEN_EXPIRY_DAYS: z.coerce.number().int().positive().default(30),
  REFRESH_TOKEN_ROTATION_ENABLED: z.enum(['true', 'false']).default('true').transform(v => v === 'true'),

  // Device settings
  DEVICE_MAX_PER_USER: z.coerce.number().int().positive().default(10),
  DEVICE_PUSH_TOKEN_ENCRYPTION_KEY: z.string().min(32).optional(),

  // Push notification configuration
  PUSH_PROVIDER: z.enum(['development', 'fcm', 'apns', 'webpush']).default('development'),
  FCM_PROJECT_ID: z.string().optional(),
  FCM_SERVICE_ACCOUNT_KEY: z.string().optional(),
  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_KEY_PATH: z.string().optional(),
  APNS_PRODUCTION: z.enum(['true', 'false']).default('false').transform(v => v === 'true'),
  APNS_BUNDLE_ID: z.string().optional(),
  WEBPUSH_VAPID_PUBLIC_KEY: z.string().optional(),
  WEBPUSH_VAPID_PRIVATE_KEY: z.string().optional(),
  WEBPUSH_VAPID_SUBJECT: z.string().optional(),

  // Notification settings
  NOTIFICATION_OUTBOX_WORKER_ENABLED: z.enum(['true', 'false']).default('true').transform(v => v === 'true'),
  NOTIFICATION_OUTBOX_POLL_INTERVAL_MS: z.coerce.number().int().positive().default(5000),
  NOTIFICATION_MAX_RETRIES: z.coerce.number().int().positive().default(3),
  NOTIFICATION_RETRY_DELAYS_MS: z.string().default('60000,300000,900000'),

  // JWT settings
  JWT_ISSUER: z.string().default('getkeja'),
  JWT_AUDIENCE: z.string().default('getkeja-api'),
  JWT_ACCESS_TOKEN_EXPIRY_MINUTES: z.coerce.number().int().positive().default(15),
  JWT_PRIVATE_KEY: z.string().min(64).optional(), // PEM format private key
  JWT_PUBLIC_KEY: z.string().min(64).optional(), // PEM format public key
  JWT_KEY_ROTATION_ENABLED: z.enum(['true', 'false']).default('false').transform(v => v === 'true'),

  // CSRF settings
  CSRF_COOKIE_NAME: z.string().default('csrf_token'),
  CSRF_HEADER_NAME: z.string().default('x-csrf-token'),
});

export type Env = z.infer<typeof envSchema>;

export class EnvValidationError extends Error {
  readonly details: string;

  constructor(details: string) {
    super(`Invalid environment configuration:\n${details}`);
    this.name = 'EnvValidationError';
    this.details = details;
  }
}

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = envSchema.safeParse(source);

  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `  - ${issue.path.join('.') || 'env'}: ${issue.message}`)
      .join('\n');
    throw new EnvValidationError(details);
  }

  return parsed.data;
}
