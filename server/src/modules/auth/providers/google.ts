import { createHash, randomBytes } from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';

export interface GoogleOAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  allowedClientIds?: string[];
}

export interface GoogleTokenPayload {
  iss: string;
  sub: string;
  azp: string;
  aud: string;
  iat: number;
  exp: number;
  email: string;
  email_verified: boolean;
  name?: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
  locale?: string;
  hd?: string;
}

export function createGoogleOAuthProvider(config: GoogleOAuthConfig) {
  const oauthClient = new OAuth2Client(config.clientId);

  function generateState(): string {
    return randomBytes(32).toString('base64url');
  }

  function generateCodeVerifier(): string {
    return randomBytes(32).toString('base64url');
  }

  function generateCodeChallenge(codeVerifier: string): string {
    return createHash('sha256').update(codeVerifier).digest('base64url');
  }

  function getAuthorizationUrl(
    options: {
      scope?: string[];
      redirectUrl?: string;
      codeChallengeMethod?: 'S256';
    } = {}
  ): { url: string; state: string; codeVerifier?: string } {
    const state = generateState();
    const codeVerifier = options.codeChallengeMethod ? generateCodeVerifier() : undefined;
    const codeChallenge = codeVerifier ? generateCodeChallenge(codeVerifier) : undefined;

    const params = new URLSearchParams({
      client_id: config.clientId,
      redirect_uri: config.redirectUri,
      response_type: 'code',
      scope: (options.scope || ['openid', 'email', 'profile']).join(' '),
      state,
      access_type: 'offline',
      prompt: 'consent',
    });

    if (codeChallenge) {
      params.set('code_challenge', codeChallenge);
      params.set('code_challenge_method', 'S256');
    }

    return {
      url: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`,
      state,
      codeVerifier,
    };
  }

  async function exchangeCodeForTokens(
    code: string,
    codeVerifier?: string
  ): Promise<{ accessToken: string; idToken: string; refreshToken?: string }> {
    const params = new URLSearchParams({
      client_id: config.clientId,
      client_secret: config.clientSecret,
      code,
      grant_type: 'authorization_code',
      redirect_uri: config.redirectUri,
    });

    if (codeVerifier) {
      params.set('code_verifier', codeVerifier);
    }

    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params,
    });

    if (!response.ok) throw new Error('Google authorization code exchange failed');

    const data = await response.json() as { access_token: string; id_token: string; refresh_token?: string };
    if (typeof data.id_token !== 'string' || data.id_token.length === 0) {
      throw new Error('Google did not return an ID token');
    }
    return {
      accessToken: data.access_token,
      idToken: data.id_token,
      refreshToken: data.refresh_token,
    };
  }

  async function verifyIdToken(idToken: string): Promise<GoogleTokenPayload> {
    const allowedAudiences = config.allowedClientIds || [config.clientId];
    const ticket = await oauthClient.verifyIdToken({
      idToken,
      audience: allowedAudiences,
    });
    const verified = ticket.getPayload();
    if (
      !verified?.sub ||
      !verified.email ||
      !verified.iss ||
      !verified.exp ||
      !allowedAudiences.includes(verified.aud) ||
      (verified.azp !== undefined && !allowedAudiences.includes(verified.azp)) ||
      (Array.isArray(verified.aud) && verified.aud.length > 1 && !verified.azp) ||
      (verified.iss !== 'accounts.google.com' &&
        verified.iss !== 'https://accounts.google.com')
    ) {
      throw new Error('Invalid Google ID token');
    }
    return {
      iss: verified.iss,
      sub: verified.sub,
      azp: verified.azp ?? verified.aud,
      aud: verified.aud,
      iat: verified.iat ?? 0,
      exp: verified.exp,
      email: verified.email,
      email_verified: verified.email_verified === true,
      name: verified.name,
      given_name: verified.given_name,
      family_name: verified.family_name,
      picture: verified.picture,
      locale: verified.locale,
      hd: verified.hd,
    };
  }

  async function refreshAccessToken(refreshToken: string): Promise<{ accessToken: string; idToken?: string }> {
    const params = new URLSearchParams({
      client_id: config.clientId,
      client_secret: config.clientSecret,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });

    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Token refresh failed: ${error}`);
    }

    const data = await response.json() as { access_token: string; id_token?: string };
    return {
      accessToken: data.access_token,
      idToken: data.id_token,
    };
  }

  return {
    getAuthorizationUrl,
    exchangeCodeForTokens,
    verifyIdToken,
    refreshAccessToken,
  };
}

export type GoogleOAuthProvider = ReturnType<typeof createGoogleOAuthProvider>;