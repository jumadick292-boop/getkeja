import {
  createNotificationTemplate,
  findNotificationTemplateByKey,
  findNotificationTemplates,
  createNotification,
  createNotificationWithRecipients,
  createNotificationRecipient,
  findNotificationsByUserId,
  findNotificationById,
  markNotificationAsRead,
  markNotificationsAsRead,
  markAllNotificationsAsRead,
  getUnreadNotificationCount,
  deleteNotification,
  createNotificationPreferences,
  findNotificationPreferencesByUserId,
  updateNotificationPreferences,
  ensureNotificationPreferences,
  createDeliveryAttempt,
  updateDeliveryAttempt,
  findDeliveryAttemptById,
  findPendingDeliveryAttempts,
  findDeliveryAttemptsByNotification,
  createDeadLetter,
  findDeadLetters,
  resolveDeadLetter,
  createOutboxEvent,
  findOutboxEventByIdempotencyKey,
  findPendingOutboxEvents,
  updateOutboxEvent,
  findOutboxEventById,
} from './auth.repository.js';
import type {
  NotificationTemplate,
  Notification,
  NotificationRecipient,
  NotificationPreferences,
  NotificationDeliveryAttempt,
  NotificationDeadLetter,
  NotificationOutbox,
  NotificationCategory,
  NotificationPriority,
  NotificationChannel,
  DeliveryStatus,
  OutboxStatus,
} from './auth.types.js';
import { sendEmail, getEmailProvider, type EmailProvider } from './providers/email.js';
import { sendSms, getSmsProvider, type SmsProvider } from './providers/sms.js';
import { encrypt, decrypt } from './crypto.js';
import { pool } from '../../db/pool.js';

const MAX_RETRIES = 3;
const RETRY_DELAYS = [60_000, 300_000, 900_000];

function isQuietHours(prefs: NotificationPreferences): boolean {
  if (!prefs.quietHoursStart || !prefs.quietHoursEnd) return false;
  const now = new Date();
  const userTime = new Date(now.toLocaleString('en-US', { timeZone: prefs.timezone }));
  const currentMinutes = userTime.getHours() * 60 + userTime.getMinutes();
  const startParts = prefs.quietHoursStart.split(':').map(Number);
  const endParts = prefs.quietHoursEnd.split(':').map(Number);
  const startH = startParts[0] ?? 0;
  const startM = startParts[1] ?? 0;
  const endH = endParts[0] ?? 0;
  const endM = endParts[1] ?? 0;
  const startMinutes = startH * 60 + startM;
  const endMinutes = endH * 60 + endM;
  if (startMinutes <= endMinutes) {
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }
  return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
}

function shouldSendViaChannel(
  prefs: NotificationPreferences,
  category: NotificationCategory,
  channel: NotificationChannel
): boolean {
  if (isQuietHours(prefs) && channel !== 'in_app') return false;

  switch (channel) {
    case 'email':
      if (!prefs.emailEnabled) return false;
      break;
    case 'sms':
      if (!prefs.smsEnabled) return false;
      break;
    case 'push':
      if (!prefs.pushEnabled) return false;
      break;
    case 'in_app':
      if (!prefs.inAppEnabled) return false;
      break;
  }

  const categoryChannelKey = `${category}${channel.charAt(0).toUpperCase() + channel.slice(1)}` as keyof NotificationPreferences;
  return prefs[categoryChannelKey] === true;
}

async function getTemplate(eventType: string, channel: NotificationChannel, locale = 'en'): Promise<NotificationTemplate | undefined> {
  return findNotificationTemplateByKey(eventType, channel, locale);
}

function renderTemplate(template: NotificationTemplate, data: Record<string, unknown>): { subject: string | null; body: string } {
  let subject = template.subject;
  let body = template.body;

  for (const [key, value] of Object.entries(data)) {
    const placeholder = `{{${key}}}`;
    const stringValue = String(value);
    if (subject) subject = subject.replaceAll(placeholder, stringValue);
    body = body.replaceAll(placeholder, stringValue);
  }

  return { subject, body };
}

export class NotificationTemplateService {
  async create(data: {
    templateKey: string;
    eventType: string;
    channel: NotificationChannel;
    locale: string;
    subject: string | null;
    body: string;
    isActive: boolean;
    version: number;
    metadata: Record<string, unknown>;
    createdBy: string;
  }): Promise<NotificationTemplate> {
    return createNotificationTemplate(data);
  }

  async findByKey(templateKey: string, channel: NotificationChannel, locale = 'en'): Promise<NotificationTemplate | undefined> {
    return findNotificationTemplateByKey(templateKey, channel, locale);
  }

  async findAll(eventType?: string, channel?: NotificationChannel): Promise<NotificationTemplate[]> {
    return findNotificationTemplates(eventType, channel);
  }
}

export class NotificationPreferenceService {
  async getOrCreate(userId: string): Promise<NotificationPreferences> {
    return ensureNotificationPreferences(userId);
  }

  async update(userId: string, updates: Partial<Omit<NotificationPreferences, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>): Promise<NotificationPreferences | undefined> {
    return updateNotificationPreferences(userId, updates);
  }
}

export class NotificationDeliveryService {
  public emailProvider: EmailProvider;
  public smsProvider: SmsProvider;

  constructor() {
    this.emailProvider = getEmailProvider();
    this.smsProvider = getSmsProvider();
  }

  async send(
    attempt: NotificationDeliveryAttempt,
    recipient: { email?: string; phone?: string; pushToken?: string },
    rendered: { subject: string | null; body: string }
  ): Promise<{ success: boolean; providerMessageId?: string; errorCode?: string; errorMessage?: string }> {
    const { channel, provider } = attempt;

    try {
      switch (channel) {
        case 'email': {
          if (!recipient.email) throw new Error('No email address for recipient');
          const result = await sendEmail(this.emailProvider, {
            to: recipient.email,
            subject: rendered.subject || 'Notification',
            html: rendered.body,
            text: rendered.body.replace(/<[^>]*>/g, ''),
          });
          return { success: true, providerMessageId: result.messageId };
        }
        case 'sms': {
          if (!recipient.phone) throw new Error('No phone number for recipient');
          const result = await sendSms(this.smsProvider, {
            to: recipient.phone,
            body: rendered.body,
          });
          return { success: true, providerMessageId: result.messageId };
        }
        case 'push': {
          if (!recipient.pushToken) throw new Error('No push token for recipient');
          return { success: false, errorCode: 'PUSH_NOT_IMPLEMENTED', errorMessage: 'Push notifications not yet implemented' };
        }
        case 'in_app': {
          return { success: true };
        }
        default:
          throw new Error(`Unknown channel: ${channel}`);
      }
    } catch (error) {
      return {
        success: false,
        errorCode: error instanceof Error ? error.name : 'UNKNOWN_ERROR',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  async processAttempt(attemptId: string): Promise<void> {
    const attempt = await findDeliveryAttemptById(attemptId);
    if (!attempt) return;

    const notification = await findNotificationById(attempt.notificationId);
    if (!notification) return;

    const template = await getTemplate(notification.eventType, attempt.channel as NotificationChannel);
    if (!template) {
      await updateDeliveryAttempt(attemptId, {
        status: 'failed',
        errorCode: 'TEMPLATE_NOT_FOUND',
        errorMessage: `No template for ${notification.eventType} on ${attempt.channel}`,
        failedAt: new Date(),
      });
      return;
    }

    const recipientData = await this.getRecipientData(attempt.recipientId);
    const rendered = renderTemplate(template, { ...notification.metadata, title: notification.title, body: notification.body });

    await updateDeliveryAttempt(attemptId, { status: 'sent', sentAt: new Date() });

    const result = await this.send(attempt, recipientData, rendered);

    if (result.success) {
      await updateDeliveryAttempt(attemptId, {
        status: 'delivered',
        providerMessageId: result.providerMessageId,
        deliveredAt: new Date(),
      });

      if (attempt.recipientId) {
        await pool.query(
          `UPDATE notification_recipients SET delivered_channels = array_append(delivered_channels, $1) WHERE id = $2`,
          [attempt.channel, attempt.recipientId],
        );
      }
    } else {
      await this.handleFailure(attempt, result.errorCode, result.errorMessage);
    }
  }

  private async getRecipientData(recipientId: string | null): Promise<{ email?: string; phone?: string; pushToken?: string }> {
    if (!recipientId) return {};
    const result = await pool.query(
      `SELECT u.email, u.phone, d.push_token_encrypted
       FROM notification_recipients nr
       JOIN users u ON u.id = nr.user_id
       LEFT JOIN devices d ON d.user_id = u.id AND d.push_token_encrypted IS NOT NULL AND d.is_active = TRUE
       WHERE nr.id = $1
       LIMIT 1`,
      [recipientId],
    );
    if (result.rows.length === 0) return {};

    const row = result.rows[0];
    let pushToken: string | undefined;
    if (row.push_token_encrypted) {
      try {
        pushToken = decrypt(row.push_token_encrypted);
      } catch {
        pushToken = undefined;
      }
    }
    return { email: row.email, phone: row.phone, pushToken };
  }

  private async handleFailure(
    attempt: NotificationDeliveryAttempt,
    errorCode: string | undefined,
    errorMessage: string | undefined
  ): Promise<void> {
    const nextAttempt = attempt.attemptNumber + 1;
    const maxRetries = MAX_RETRIES;

    if (nextAttempt > maxRetries) {
      await updateDeliveryAttempt(attempt.id, {
        status: 'failed',
        errorCode,
        errorMessage,
        failedAt: new Date(),
        attemptNumber: nextAttempt,
      });

      await createDeadLetter({
        deliveryAttemptId: attempt.id,
        notificationId: attempt.notificationId,
        recipientId: attempt.recipientId,
        channel: attempt.channel,
        provider: attempt.provider,
        failureReason: errorMessage || errorCode || 'Unknown error',
        payload: { attemptNumber: nextAttempt },
        retryCount: nextAttempt,
      });
      return;
    }

    const delayIndex = Math.min(nextAttempt - 1, RETRY_DELAYS.length - 1);
    const delay = RETRY_DELAYS[delayIndex]!;
    const nextRetryAt = new Date(Date.now() + delay);

    await updateDeliveryAttempt(attempt.id, {
      status: 'pending',
      errorCode,
      errorMessage,
      attemptNumber: nextAttempt,
      nextRetryAt,
    });
  }
}

export class NotificationService {
  private deliveryService: NotificationDeliveryService;
  private preferenceService: NotificationPreferenceService;

  constructor() {
    this.deliveryService = new NotificationDeliveryService();
    this.preferenceService = new NotificationPreferenceService();
  }

  async createAndSend(data: {
    userId: string;
    organisationId: string | null;
    eventType: string;
    category: NotificationCategory;
    title: string;
    body: string;
    metadata: Record<string, unknown>;
    priority: NotificationPriority;
    expiresAt: Date | null;
    channels: NotificationChannel[];
    recipientUserIds?: string[];
  }): Promise<{ notification: Notification; recipients: NotificationRecipient[] }> {
    const recipientIds = data.recipientUserIds ?? [data.userId];

    const { notification, recipients } = await createNotificationWithRecipients({
      notification: {
        userId: data.userId,
        organisationId: data.organisationId,
        eventType: data.eventType,
        category: data.category,
        title: data.title,
        body: data.body,
        metadata: data.metadata,
        priority: data.priority,
        expiresAt: data.expiresAt,
      },
      recipientUserIds: recipientIds,
    });

    for (const recipient of recipients) {
      const prefs = await this.preferenceService.getOrCreate(recipient.userId);

      for (const channel of data.channels) {
        if (!shouldSendViaChannel(prefs, data.category, channel)) continue;

        const attempt = await createDeliveryAttempt({
          notificationId: notification.id,
          recipientId: recipient.id,
          channel,
          provider: this.getProviderForChannel(channel),
        });

        setImmediate(() => this.deliveryService.processAttempt(attempt.id));
      }
    }

    return { notification, recipients };
  }

  async createOutboxEvent(data: {
    idempotencyKey: string;
    eventType: string;
    category: string;
    priority: NotificationPriority;
    recipientUserIds: string[];
    organisationId: string | null;
    resourceType: string | null;
    resourceId: string | null;
    payload: Record<string, unknown>;
    channels: NotificationChannel[];
    maxRetries?: number;
  }): Promise<NotificationOutbox> {
    const existing = await findOutboxEventByIdempotencyKey(data.idempotencyKey);
    if (existing) return existing;

    return createOutboxEvent(data);
  }

  async processOutboxEvent(outboxId: string): Promise<void> {
    const event = await findOutboxEventById(outboxId);
    if (!event) return;

    await updateOutboxEvent(outboxId, { status: 'processing', processingStartedAt: new Date() });

    try {
      for (const userId of event.recipientUserIds) {
        const prefs = await this.preferenceService.getOrCreate(userId);

        for (const channel of event.channels) {
          if (!shouldSendViaChannel(prefs, event.category as NotificationCategory, channel)) continue;

          await createDeliveryAttempt({
            notificationId: event.id,
            recipientId: null,
            channel,
            provider: this.getProviderForChannel(channel),
          });
        }
      }

      await updateOutboxEvent(outboxId, {
        status: 'completed',
        processingCompletedAt: new Date(),
      });
    } catch (error) {
      await updateOutboxEvent(outboxId, {
        status: 'failed',
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
        processingCompletedAt: new Date(),
      });
    }
  }

  async getNotifications(userId: string, options: {
    category?: string;
    isRead?: boolean;
    limit?: number;
    offset?: number;
  } = {}): Promise<Notification[]> {
    return findNotificationsByUserId(userId, options);
  }

  async getUnreadCount(userId: string): Promise<number> {
    return getUnreadNotificationCount(userId);
  }

  async markAsRead(notificationId: string, userId: string): Promise<Notification | undefined> {
    return markNotificationAsRead(notificationId, userId);
  }

  async markMultipleAsRead(notificationIds: string[], userId: string): Promise<number> {
    return markNotificationsAsRead(notificationIds, userId);
  }

  async markAllAsRead(userId: string): Promise<number> {
    return markAllNotificationsAsRead(userId);
  }

  async delete(notificationId: string, userId: string): Promise<boolean> {
    return deleteNotification(notificationId, userId);
  }

  private getProviderForChannel(channel: NotificationChannel): string {
    switch (channel) {
      case 'email':
        return this.deliveryService.emailProvider.name;
      case 'sms':
        return this.deliveryService.smsProvider.name;
      case 'push':
        return 'fcm';
      case 'in_app':
        return 'internal';
      default:
        return 'unknown';
    }
  }
}

export class NotificationOutboxWorker {
  private notificationService: NotificationService;
  private isRunning = false;
  private interval: NodeJS.Timeout | null = null;

  constructor() {
    this.notificationService = new NotificationService();
  }

  async start(pollInterval = 5000): Promise<void> {
    if (this.isRunning) return;
    this.isRunning = true;

    this.interval = setInterval(async () => {
      try {
        const events = await findPendingOutboxEvents(50);
        for (const event of events) {
          await this.notificationService.processOutboxEvent(event.id);
        }
      } catch (error) {
        console.error('Outbox worker error:', error);
      }
    }, pollInterval);
  }

  stop(): void {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.isRunning = false;
  }
}