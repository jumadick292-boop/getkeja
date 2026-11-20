import type { Request, Response, NextFunction } from 'express';
import { NotificationService } from './notification.service.js';
import { NotificationPreferenceService } from './notification.service.js';
import { NotificationTemplateService } from './notification.service.js';
import type { AuthenticatedRequest } from './auth.middleware.js';

const notificationService = new NotificationService();
const preferenceService = new NotificationPreferenceService();
const templateService = new NotificationTemplateService();

export class NotificationController {
  async createNotification(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const data = req.body;

      const result = await notificationService.createAndSend({
        userId,
        organisationId: data.organisationId || null,
        eventType: data.eventType,
        category: data.category,
        title: data.title,
        body: data.body,
        metadata: data.metadata || {},
        priority: data.priority || 'normal',
        expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
        channels: data.channels,
        recipientUserIds: data.recipientUserIds,
      });

      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async createOutboxEvent(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const data = req.body;

      const idempotencyKey = req.headers['idempotency-key'] as string || `${userId}:${data.eventType}:${Date.now()}`;

      const event = await notificationService.createOutboxEvent({
        idempotencyKey,
        eventType: data.eventType,
        category: data.category,
        priority: data.priority || 'normal',
        recipientUserIds: data.recipientUserIds || [userId],
        organisationId: data.organisationId || null,
        resourceType: data.resourceType || null,
        resourceId: data.resourceId || null,
        payload: data.metadata || {},
        channels: data.channels,
        maxRetries: data.maxRetries,
      });

      res.status(201).json({
        success: true,
        data: event,
      });
    } catch (error) {
      next(error);
    }
  }

  async getNotifications(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const { category, isRead, limit, offset } = req.query;

      const notifications = await notificationService.getNotifications(userId, {
        category: category as string,
        isRead: isRead !== undefined ? isRead === 'true' : undefined,
        limit: limit ? parseInt(limit as string, 10) : 50,
        offset: offset ? parseInt(offset as string, 10) : 0,
      });

      res.json({
        success: true,
        data: notifications,
      });
    } catch (error) {
      next(error);
    }
  }

  async getUnreadCount(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const count = await notificationService.getUnreadCount(userId);

      res.json({
        success: true,
        data: { count },
      });
    } catch (error) {
      next(error);
    }
  }

  async markAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const { notificationIds } = req.body;

      const count = await notificationService.markMultipleAsRead(notificationIds, userId);

      res.json({
        success: true,
        data: { markedCount: count },
      });
    } catch (error) {
      next(error);
    }
  }

  async markAllAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const count = await notificationService.markAllAsRead(userId);

      res.json({
        success: true,
        data: { markedCount: count },
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteNotification(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;

      if (!id) {
        res.status(400).json({ success: false, error: 'Notification ID is required' });
        return;
      }

      const deleted = await notificationService.delete(id, userId);

      if (!deleted) {
        res.status(404).json({ success: false, error: 'Notification not found' });
        return;
      }

      res.json({
        success: true,
        data: { deleted: true },
      });
    } catch (error) {
      next(error);
    }
  }

  async getPreferences(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const prefs = await preferenceService.getOrCreate(userId);

      res.json({
        success: true,
        data: prefs,
      });
    } catch (error) {
      next(error);
    }
  }

  async updatePreferences(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const prefs = await preferenceService.update(userId, req.body);

      res.json({
        success: true,
        data: prefs,
      });
    } catch (error) {
      next(error);
    }
  }

  async createTemplate(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.id;
      const data = req.body;

      const template = await templateService.create({
        templateKey: data.templateKey,
        eventType: data.eventType,
        channel: data.channel,
        locale: data.locale || 'en',
        subject: data.subject || null,
        body: data.body,
        isActive: data.isActive ?? true,
        version: data.version || 1,
        metadata: data.metadata || {},
        createdBy: userId,
      });

      res.status(201).json({
        success: true,
        data: template,
      });
    } catch (error) {
      next(error);
    }
  }

  async getTemplates(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { eventType, channel } = req.query;

      const templates = await templateService.findAll(
        eventType as string,
        channel as 'email' | 'sms' | 'push' | 'in_app'
      );

      res.json({
        success: true,
        data: templates,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const notificationController = new NotificationController();