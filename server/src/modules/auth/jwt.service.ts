import { SignJWT, jwtVerify, importSPKI, importPKCS8, type JWTPayload, type CryptoKey, generateKeyPair } from 'jose';
import { randomBytes } from 'node:crypto';
import { loadEnv } from '../../config/env.js';
import type { JwtPayload, RefreshTokenPayload, TokenPair } from './auth.types.js';

let privateKey: CryptoKey | null = null;
let publicKey: CryptoKey | null = null;
let env: ReturnType<typeof loadEnv> | null = null;
let keysPromise: Promise<void> | null = null;

function getEnv() {
  if (!env) {
    env = loadEnv();
  }
  return env;
}

async function loadKeys(): Promise<void> {
  if (privateKey && publicKey) return;
  if (!keysPromise) {
    keysPromise = (async () => {
      const e = getEnv();

      if (e.JWT_PRIVATE_KEY && e.JWT_PUBLIC_KEY) {
        privateKey = await importPKCS8(e.JWT_PRIVATE_KEY, 'RS256');
        publicKey = await importSPKI(e.JWT_PUBLIC_KEY, 'RS256');
      } else {
        // Generate test keys for development/test environments
        const { privateKey: generatedPrivateKey, publicKey: generatedPublicKey } = await generateKeyPair('RS256', {
          extractable: true,
        });
        privateKey = generatedPrivateKey;
        publicKey = generatedPublicKey;
      }
    })();
  }
  await keysPromise;
}

export async function createAccessToken(
  userId: string,
  sessionId: string,
): Promise<{ token: string; payload: JwtPayload }> {
  await loadKeys();

  const e = getEnv();
  const now = Math.floor(Date.now() / 1000);
  const exp = now + e.JWT_ACCESS_TOKEN_EXPIRY_MINUTES * 60;
  const jti = randomBytes(16).toString('hex');

  const payload: JwtPayload = {
    sub: userId,
    sid: sessionId,
    jti,
    iss: e.JWT_ISSUER,
    aud: e.JWT_AUDIENCE,
    iat: now,
    exp,
    type: 'access',
  };

  const token = await new SignJWT(payload as unknown as JWTPayload)
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .setNotBefore(now)
    .sign(privateKey!);

  return { token, payload };
}

export async function verifyAccessToken(token: string): Promise<JwtPayload | null> {
  await loadKeys();

  const e = getEnv();

  try {
    const { payload } = await jwtVerify(token, publicKey!, {
      issuer: e.JWT_ISSUER,
      audience: e.JWT_AUDIENCE,
      algorithms: ['RS256'],
      clockTolerance: 30,
    });

    if (payload.type !== 'access') {
      return null;
    }

    return payload as unknown as JwtPayload;
  } catch {
    return null;
  }
}

export async function createRefreshToken(
  userId: string,
  sessionId: string,
  familyId: string,
): Promise<{ token: string; payload: RefreshTokenPayload }> {
  await loadKeys();

  const e = getEnv();
  const now = Math.floor(Date.now() / 1000);
  const exp = now + e.REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60;
  const jti = randomBytes(16).toString('hex');

  const payload: RefreshTokenPayload = {
    sub: userId,
    sid: sessionId,
    jti,
    fid: familyId,
    iss: e.JWT_ISSUER,
    aud: e.JWT_AUDIENCE,
    iat: now,
    exp,
    type: 'refresh',
  };

  const token = await new SignJWT(payload as unknown as JWTPayload)
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .setNotBefore(now)
    .sign(privateKey!);

  return { token, payload };
}

export async function verifyRefreshToken(token: string): Promise<RefreshTokenPayload | null> {
  await loadKeys();

  const e = getEnv();

  try {
    const { payload } = await jwtVerify(token, publicKey!, {
      issuer: e.JWT_ISSUER,
      audience: e.JWT_AUDIENCE,
      algorithms: ['RS256'],
      clockTolerance: 30,
    });

    if (payload.type !== 'refresh') {
      return null;
    }

    return payload as unknown as RefreshTokenPayload;
  } catch {
    return null;
  }
}

export async function createTokenPair(
  userId: string,
  sessionId: string,
  familyId: string,
): Promise<TokenPair> {
  const [accessResult, refreshResult] = await Promise.all([
    createAccessToken(userId, sessionId),
    createRefreshToken(userId, sessionId, familyId),
  ]);

  return {
    accessToken: accessResult.token,
    refreshToken: refreshResult.token,
    expiresIn: getEnv().JWT_ACCESS_TOKEN_EXPIRY_MINUTES * 60,
  };
}

export function getAccessTokenExpiry(): number {
  return getEnv().JWT_ACCESS_TOKEN_EXPIRY_MINUTES * 60;
}

export function getRefreshTokenExpiry(): number {
  return getEnv().REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60;
}