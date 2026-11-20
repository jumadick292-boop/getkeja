import { createHash } from 'node:crypto';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { getRedisClient } from '../db/redis.js';
import { loadEnv } from '../config/env.js';
import { HttpError } from '../shared/errors.js';

interface RateLimitConfig {
  windowMs: number;
  max: number;
  keyPrefix: string;
  identifierField?: 'email' | 'phone' | 'newEmail' | 'newPhone' | 'userId';
  ipWindowMs?: number;
  ipMax?: number;
}

const incrementWindowScript = `
  local count = redis.call('INCR', KEYS[1])
  if count == 1 then
    redis.call('PEXPIRE', KEYS[1], ARGV[1])
  end
  return count
`;

function digest(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function normalizeIdentifier(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim().toLowerCase();
  return trimmed || undefined;
}

function normalizeKenyanPhoneIdentifier(value: string): string {
  const stripped = value.replace(/[\s()+-]/g, '');
  let nationalNumber = stripped.replace(/^254/, '').replace(/^0/, '');
  if (/^[17]\d{8}$/.test(nationalNumber)) {
    return `+254${nationalNumber}`;
  }
  return stripped;
}

function requestIdentifier(req: Request, field: RateLimitConfig['identifierField']): string | undefined {
  if (!field) return undefined;
  if (field === 'userId') return normalizeIdentifier(req.user?.id);
  const value = normalizeIdentifier(req.body?.[field]);
  if (!value) return undefined;
  return field === 'phone' || field === 'newPhone'
    ? normalizeKenyanPhoneIdentifier(value)
    : value;
}

async function incrementLimit(key: string, windowMs: number): Promise<number> {
  const count = await getRedisClient().eval(
    incrementWindowScript,
    1,
    key,
    String(windowMs),
  );
  return Number(count);
}

export function createRateLimiter(config: RateLimitConfig): RequestHandler {
  const env = loadEnv();

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const identifier = requestIdentifier(req, config.identifierField);
      const clientIp = req.ip || req.socket.remoteAddress || 'unknown';
      const limits = [
        {
          key: `auth:rate:${config.keyPrefix}:ip:${digest(clientIp)}`,
          windowMs: config.ipWindowMs ?? env.LOGIN_IP_RATE_LIMIT_WINDOW_MS,
          max: config.ipMax ?? env.LOGIN_IP_RATE_LIMIT_MAX,
        },
      ];

      if (identifier) {
        limits.push({
          key: `auth:rate:${config.keyPrefix}:identity:${digest(identifier)}`,
          windowMs: config.windowMs,
          max: config.max,
        });
      }

      let blockedUntil = 0;
      for (const limit of limits) {
        const count = await incrementLimit(limit.key, limit.windowMs);
        const remaining = Math.max(0, limit.max - count);
        res.setHeader('X-RateLimit-Limit', String(limit.max));
        res.setHeader('X-RateLimit-Remaining', String(remaining));
        if (count > limit.max) {
          blockedUntil = Math.max(
            blockedUntil,
            Math.ceil(limit.windowMs / 1000),
          );
        }
      }

      if (blockedUntil > 0) {
        res.setHeader('Retry-After', String(blockedUntil));
        next(new HttpError('Too many requests. Please try again later.', 429));
        return;
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}

export function loginEmailRateLimiter(): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_EMAIL_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_EMAIL_RATE_LIMIT_MAX,
    keyPrefix: 'login:email',
    identifierField: 'email',
  });
}

export function loginPhoneRateLimiter(): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_PHONE_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_PHONE_RATE_LIMIT_MAX,
    keyPrefix: 'login:phone',
    identifierField: 'phone',
  });
}

export function loginOtpRequestRateLimiter(field: 'email' | 'phone'): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_OTP_REQUEST_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX,
    keyPrefix: `login:otp:request:${field}`,
    identifierField: field,
  });
}

export function loginOtpVerifyRateLimiter(field: 'email' | 'phone'): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_OTP_VERIFY_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_OTP_VERIFY_RATE_LIMIT_MAX,
    keyPrefix: `login:otp:verify:${field}`,
    identifierField: field,
  });
}

export function loginGoogleRateLimiter(): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_GOOGLE_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_GOOGLE_RATE_LIMIT_MAX,
    keyPrefix: 'login:google',
  });
}

export function loginIpRateLimiter(): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_IP_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_IP_RATE_LIMIT_MAX,
    keyPrefix: 'login:ip',
    ipWindowMs: env.LOGIN_IP_RATE_LIMIT_WINDOW_MS,
    ipMax: env.LOGIN_IP_RATE_LIMIT_MAX,
  });
}

export function registrationRateLimiter(identifierField: 'email' | 'phone'): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.REGISTRATION_RATE_LIMIT_WINDOW_MS,
    max: env.REGISTRATION_RATE_LIMIT_MAX,
    keyPrefix: `registration:${identifierField}`,
    identifierField,
  });
}

export function accountContactChangeRateLimiter(channel: 'email' | 'phone'): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: env.LOGIN_OTP_REQUEST_RATE_LIMIT_WINDOW_MS,
    max: env.LOGIN_OTP_REQUEST_RATE_LIMIT_MAX,
    keyPrefix: `account:contact-change:${channel}`,
    identifierField: channel === 'email' ? 'newEmail' : 'newPhone',
    ipWindowMs: env.LOGIN_IP_RATE_LIMIT_WINDOW_MS,
    ipMax: env.LOGIN_IP_RATE_LIMIT_MAX,
  });
}

export function accountDataExportRateLimiter(): RequestHandler {
  const env = loadEnv();
  return createRateLimiter({
    windowMs: 60 * 60 * 1000,
    max: 5,
    keyPrefix: 'account:data-export',
    identifierField: 'userId',
    ipWindowMs: env.LOGIN_IP_RATE_LIMIT_WINDOW_MS,
    ipMax: env.LOGIN_IP_RATE_LIMIT_MAX,
  });
}

function failureKey(identifier: string, type: 'email' | 'phone' | 'ip'): string {
  return `auth:failure:${type}:${digest(identifier)}`;
}

export async function incrementLoginFailure(
  identifier: string,
  type: 'email' | 'phone' | 'ip',
): Promise<void> {
  const env = loadEnv();
  const redis = getRedisClient();
  const key = failureKey(identifier, type);
  await redis.multi().incr(key).pexpire(key, env.LOGIN_IP_RATE_LIMIT_WINDOW_MS).exec();
}

export async function getLoginFailureCount(
  identifier: string,
  type: 'email' | 'phone' | 'ip',
): Promise<number> {
  const count = await getRedisClient().get(failureKey(identifier, type));
  return count ? Number.parseInt(count, 10) : 0;
}

export async function resetLoginFailure(
  identifier: string,
  type: 'email' | 'phone' | 'ip',
): Promise<void> {
  await getRedisClient().del(failureKey(identifier, type));
}

export async function reserveOtpResend(
  identifier: string,
  channel: 'email' | 'phone',
): Promise<boolean> {
  const env = loadEnv();
  const key = `auth:otp:resend:${channel}:${digest(identifier)}`;
  const result = await getRedisClient().set(
    key,
    '1',
    'EX',
    env.OTP_RESEND_COOLDOWN_SECONDS,
    'NX',
  );
  return result === 'OK';
}

export async function delayRepeatedLoginFailures(
  identifier: string,
  type: 'email' | 'phone',
): Promise<void> {
  const failures = await getLoginFailureCount(identifier, type);
  if (failures > 0) {
    await new Promise((resolve) =>
      setTimeout(resolve, Math.min(failures * 100, 1_000)),
    );
  }
}
