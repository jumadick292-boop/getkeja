import { Router } from 'express';
import { requireAuth } from './auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import { notificationController } from './notification.controller.js';
import { z } from 'zod';

const router = Router();

router.use(requireAuth);

const createNotificationSchema = z.object({
  eventType: z.string().min(1),
  category: z.enum(['security', 'account', 'property', 'tenancy', 'service', 'financial', 'operational', 'marketing']),
  title: z.string().min(1).max(255),
  body: z.string().min(1),
  metadata: z.record(z.string(), z.unknown()).optional(),
  priority: z.enum(['low', 'normal', 'high', 'critical']).optional(),
  expiresAt: z.string().datetime().optional().nullable(),
  channels: z.array(z.enum(['email', 'sms', 'push', 'in_app'])).min(1),
  recipientUserIds: z.array(z.string().uuid()).optional(),
  organisationId: z.string().uuid().optional().nullable(),
  resourceType: z.string().optional().nullable(),
  resourceId: z.string().uuid().optional().nullable(),
});

const updatePreferencesSchema = z.object({
  emailEnabled: z.boolean().optional(),
  smsEnabled: z.boolean().optional(),
  pushEnabled: z.boolean().optional(),
  inAppEnabled: z.boolean().optional(),
  securityEmail: z.boolean().optional(),
  securitySms: z.boolean().optional(),
  securityPush: z.boolean().optional(),
  securityInApp: z.boolean().optional(),
  accountEmail: z.boolean().optional(),
  accountSms: z.boolean().optional(),
  accountPush: z.boolean().optional(),
  accountInApp: z.boolean().optional(),
  propertyEmail: z.boolean().optional(),
  propertySms: z.boolean().optional(),
  propertyPush: z.boolean().optional(),
  propertyInApp: z.boolean().optional(),
  tenancyEmail: z.boolean().optional(),
  tenancySms: z.boolean().optional(),
  tenancyPush: z.boolean().optional(),
  tenancyInApp: z.boolean().optional(),
  serviceEmail: z.boolean().optional(),
  serviceSms: z.boolean().optional(),
  servicePush: z.boolean().optional(),
  serviceInApp: z.boolean().optional(),
  financialEmail: z.boolean().optional(),
  financialSms: z.boolean().optional(),
  financialPush: z.boolean().optional(),
  financialInApp: z.boolean().optional(),
  operationalEmail: z.boolean().optional(),
  operationalSms: z.boolean().optional(),
  operationalPush: z.boolean().optional(),
  operationalInApp: z.boolean().optional(),
  marketingEmail: z.boolean().optional(),
  marketingSms: z.boolean().optional(),
  marketingPush: z.boolean().optional(),
  marketingInApp: z.boolean().optional(),
  quietHoursStart: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).optional().nullable(),
  quietHoursEnd: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).optional().nullable(),
  timezone: z.string().optional(),
});

const markReadSchema = z.object({
  notificationIds: z.array(z.string().uuid()).min(1),
});

const createTemplateSchema = z.object({
  templateKey: z.string().min(1),
  eventType: z.string().min(1),
  channel: z.enum(['email', 'sms', 'push', 'in_app']),
  locale: z.string().min(2).max(10).optional(),
  subject: z.string().optional().nullable(),
  body: z.string().min(1),
  isActive: z.boolean().optional(),
  version: z.number().int().positive().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

router.post('/', validate(createNotificationSchema), notificationController.createNotification.bind(notificationController));
router.post('/outbox', validate(createNotificationSchema), notificationController.createOutboxEvent.bind(notificationController));

router.get('/', notificationController.getNotifications.bind(notificationController));
router.get('/unread-count', notificationController.getUnreadCount.bind(notificationController));

router.post('/mark-read', validate(markReadSchema), notificationController.markAsRead.bind(notificationController));
router.post('/mark-all-read', notificationController.markAllAsRead.bind(notificationController));
router.delete('/:id', notificationController.deleteNotification.bind(notificationController));

router.get('/preferences', notificationController.getPreferences.bind(notificationController));
router.patch('/preferences', validate(updatePreferencesSchema), notificationController.updatePreferences.bind(notificationController));

router.post('/templates', validate(createTemplateSchema), notificationController.createTemplate.bind(notificationController));
router.get('/templates', notificationController.getTemplates.bind(notificationController));

export default router;