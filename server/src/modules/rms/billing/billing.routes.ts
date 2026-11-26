// Recurring billing routes — mounted at /api/v1/rms/billing (Task 14.1).
import { Router } from 'express';
import { requireAuth } from '../../auth/auth.middleware.js';
import { validate } from '../../../middleware/validate.js';
import {
  createScheduleSchema,
  updateScheduleSchema,
  scheduleIdParamSchema,
  scheduleQuerySchema,
  previewInvoiceSchema,
  invoiceQuerySchema,
  invoiceIdParamSchema,
  voidInvoiceSchema,
} from './billing.schema.js';
import {
  createSchedule,
  listSchedules,
  getSchedule,
  updateSchedule,
  activateSchedule,
  suspendSchedule,
  resumeSchedule,
  cancelSchedule,
  previewSchedule,
  listRentTerms,
  listInvoices,
  getInvoice,
  voidInvoice,
} from './billing.controller.js';

export function createBillingRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // Billing schedules
  router.post('/schedules', validate(createScheduleSchema), createSchedule);
  router.get('/schedules', validate(scheduleQuerySchema, 'query'), listSchedules);
  router.get('/schedules/:scheduleId', validate(scheduleIdParamSchema, 'params'), getSchedule);
  router.patch('/schedules/:scheduleId', validate(scheduleIdParamSchema, 'params'), validate(updateScheduleSchema), updateSchedule);
  router.post('/schedules/:scheduleId/activate', validate(scheduleIdParamSchema, 'params'), activateSchedule);
  router.post('/schedules/:scheduleId/suspend', validate(scheduleIdParamSchema, 'params'), suspendSchedule);
  router.post('/schedules/:scheduleId/resume', validate(scheduleIdParamSchema, 'params'), resumeSchedule);
  router.post('/schedules/:scheduleId/cancel', validate(scheduleIdParamSchema, 'params'), cancelSchedule);
  router.get('/schedules/:scheduleId/preview', validate(scheduleIdParamSchema, 'params'), validate(previewInvoiceSchema, 'query'), previewSchedule);
  router.get('/schedules/:scheduleId/rent-terms', validate(scheduleIdParamSchema, 'params'), listRentTerms);

  // Invoices
  router.get('/invoices', validate(invoiceQuerySchema, 'query'), listInvoices);
  router.get('/invoices/:invoiceId', validate(invoiceIdParamSchema, 'params'), getInvoice);
  router.post('/invoices/:invoiceId/void', validate(invoiceIdParamSchema, 'params'), validate(voidInvoiceSchema), voidInvoice);

  return router;
}