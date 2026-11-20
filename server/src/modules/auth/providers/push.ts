export type PushProviderType = 'fcm' | 'apns' | 'webpush';

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
  sound?: string;
  imageUrl?: string;
  priority?: 'normal' | 'high';
  ttl?: number;
}

export interface PushResult {
  success: boolean;
  messageId?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface PushProvider {
  name: string;
  type: PushProviderType;
  send(message: PushMessage): Promise<PushResult>;
  sendBatch(messages: PushMessage[]): Promise<PushResult[]>;
  verifyToken(token: string): Promise<boolean>;
}

export interface FCMConfig {
  projectId: string;
  serviceAccountKey: string;
}

export interface APNSConfig {
  keyId: string;
  teamId: string;
  keyPath: string;
  production: boolean;
  bundleId: string;
}

export interface WebPushConfig {
  vapidPublicKey: string;
  vapidPrivateKey: string;
  vapidSubject: string;
}

class FCMProvider implements PushProvider {
  name = 'fcm';
  type = 'fcm' as const;
  private config: FCMConfig;
  private accessToken: string | null = null;
  private tokenExpiry = 0;

  constructor(config: FCMConfig) {
    this.config = config;
  }

  private async getAccessToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    try {
      const { google } = await import('googleapis');
      const auth = new google.auth.GoogleAuth({
        credentials: JSON.parse(this.config.serviceAccountKey),
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
      });
      const client = await auth.getClient();
      const token = await client.getAccessToken();
      this.accessToken = token.token || null;
      this.tokenExpiry = Date.now() + 3600 * 1000;
      return this.accessToken!;
    } catch {
      throw new Error('googleapis package not installed. Run: npm install googleapis');
    }
  }

  async send(message: PushMessage): Promise<PushResult> {
    try {
      const token = await this.getAccessToken();
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${this.config.projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: message.token,
              notification: { title: message.title, body: message.body, image: message.imageUrl },
              data: message.data,
              android: { priority: message.priority === 'high' ? 'high' : 'normal', ttl: message.ttl?.toString() },
              apns: { payload: { aps: { sound: message.sound, badge: message.badge } } },
              webpush: { headers: { TTL: message.ttl?.toString() || '86400' } },
            },
          }),
        }
      );

      if (!response.ok) {
        const error = await response.json() as { error?: { message?: string } };
        return { success: false, errorCode: 'FCM_ERROR', errorMessage: error.error?.message || 'FCM request failed' };
      }

      const result = await response.json() as { name?: string };
      return { success: true, messageId: result.name };
    } catch (error) {
      return { success: false, errorCode: 'FCM_EXCEPTION', errorMessage: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  async sendBatch(messages: PushMessage[]): Promise<PushResult[]> {
    const results: PushResult[] = [];
    for (const msg of messages) {
      results.push(await this.send(msg));
    }
    return results;
  }

  async verifyToken(token: string): Promise<boolean> {
    try {
      const result = await this.send({ token, title: 'Test', body: 'Token verification' });
      return result.success;
    } catch {
      return false;
    }
  }
}

class APNSProvider implements PushProvider {
  name = 'apns';
  type = 'apns' as const;
  private config: APNSConfig;

  constructor(config: APNSConfig) {
    this.config = config;
  }

  async send(message: PushMessage): Promise<PushResult> {
    try {
      const apn = await import('apn');
      const fs = await import('fs/promises');
      const provider = new apn.Provider({
        token: {
          key: await fs.readFile(this.config.keyPath),
          keyId: this.config.keyId,
          teamId: this.config.teamId,
        },
        production: this.config.production,
      });

      const notification = new apn.Notification();
      notification.expiry = Math.floor(Date.now() / 1000) + (message.ttl || 86400);
      notification.badge = message.badge || 0;
      notification.sound = message.sound || 'default';
      notification.alert = { title: message.title, body: message.body };
      notification.payload = message.data || {};
      notification.topic = this.config.bundleId;

      const result = await provider.send(notification, message.token);
      provider.shutdown();

      if (result.sent.length > 0 && result.sent[0]) {
        return { success: true, messageId: result.sent[0].device };
      }
      const failedError = result.failed[0]?.error;
      const errorMessage = failedError instanceof Error ? failedError.message : ((failedError as any)?.toString?.() || 'APNS send failed');
      return { success: false, errorCode: 'APNS_FAILED', errorMessage };
    } catch (error) {
      return { success: false, errorCode: 'APNS_EXCEPTION', errorMessage: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  async sendBatch(messages: PushMessage[]): Promise<PushResult[]> {
    const results: PushResult[] = [];
    for (const msg of messages) {
      results.push(await this.send(msg));
    }
    return results;
  }

  async verifyToken(token: string): Promise<boolean> {
    try {
      const result = await this.send({ token, title: 'Test', body: 'Token verification' });
      return result.success;
    } catch {
      return false;
    }
  }
}

class WebPushProvider implements PushProvider {
  name = 'webpush';
  type = 'webpush' as const;
  private config: WebPushConfig;

  constructor(config: WebPushConfig) {
    this.config = config;
  }

  async send(message: PushMessage): Promise<PushResult> {
    try {
      const webpush = await import('web-push');
      webpush.setVapidDetails(
        this.config.vapidSubject,
        this.config.vapidPublicKey,
        this.config.vapidPrivateKey
      );

      const payload = JSON.stringify({
        title: message.title,
        body: message.body,
        icon: message.imageUrl,
        data: message.data,
        badge: message.badge,
        tag: message.data?.tag,
        renotify: true,
        requireInteraction: message.priority === 'high',
      });

      const result = await webpush.sendNotification(
        JSON.parse(message.token),
        payload,
        { TTL: message.ttl || 86400 }
      );

      return { success: true, messageId: (result.headers as any)?.get?.('content-id') || 'sent' };
    } catch (error) {
      const err = error as { statusCode?: number; body?: string };
      if (err.statusCode === 410 || err.statusCode === 404) {
        return { success: false, errorCode: 'TOKEN_EXPIRED', errorMessage: 'Push subscription expired or invalid' };
      }
      return { success: false, errorCode: 'WEBPUSH_EXCEPTION', errorMessage: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  async sendBatch(messages: PushMessage[]): Promise<PushResult[]> {
    const results: PushResult[] = [];
    for (const msg of messages) {
      results.push(await this.send(msg));
    }
    return results;
  }

  async verifyToken(token: string): Promise<boolean> {
    try {
      const result = await this.send({ token, title: 'Test', body: 'Token verification' });
      return result.success;
    } catch {
      return false;
    }
  }
}

export function createPushProvider(type: PushProviderType, config: FCMConfig | APNSConfig | WebPushConfig): PushProvider {
  switch (type) {
    case 'fcm':
      return new FCMProvider(config as FCMConfig);
    case 'apns':
      return new APNSProvider(config as APNSConfig);
    case 'webpush':
      return new WebPushProvider(config as WebPushConfig);
    default:
      throw new Error(`Unknown push provider type: ${type}`);
  }
}

let pushProvider: PushProvider | null = null;

export function getPushProvider(): PushProvider | null {
  return pushProvider;
}

export function setPushProvider(provider: PushProvider | null): void {
  pushProvider = provider;
}

export function initializePushProvider(type: PushProviderType, config: FCMConfig | APNSConfig | WebPushConfig): PushProvider {
  const provider = createPushProvider(type, config);
  setPushProvider(provider);
  return provider;
}