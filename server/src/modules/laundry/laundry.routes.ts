// Laundry operations routes (Task 13.8) — mounted at /api/v1/laundry.
// Customer tracking + provider operational management share one engine with
// item-level intake, inspection/approval, processing (stage skipping),
// handovers and amendments.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  laundryOrderListQuerySchema,
  laundryOrderIdParamsSchema,
  laundryCancelSchema,
  laundryProgressSchema,
  laundryFailSchema,
  assignLaundryStaffSchema,
  laundryChecklistUpdateSchema,
  laundryItemSchema,
  laundryItemUpdateSchema,
  laundryInspectionSchema,
  resolveInspectionSchema,
  laundryCompletionSchema,
  laundryCustomerConfirmationSchema,
  reportLaundryExceptionSchema,
  createLaundryOrderSchema,
  scheduleHandoverSchema,
  confirmHandoverSchema,
  proposeLaundryAmendmentSchema,
  decideLaundryAmendmentSchema,
  laundryAmendmentIdParamsSchema,
  laundryInspectionIdParamsSchema,
} from './laundry.schemas.js';
import {
  listCustomerOrders,
  getCustomerOrder,
  cancelOrder,
  confirmCompletion,
  reportException,
  resolveInspection,
  decideAmendment,
  createOrder,
  listProviderOrders,
  getProviderOrder,
  updateProgress,
  failOrder,
  providerCancelOrder,
  addItem,
  updateItem,
  recordInspection,
  assignStaff,
  revokeStaff,
  updateChecklist,
  scheduleHandover,
  confirmHandover,
  proposeAmendment,
  submitCompletion,
} from './laundry.controller.js';

const orderItemParams = z.object({ orderId: z.string().uuid(), itemId: z.string().uuid() });
const orderHandoverParams = z.object({ orderId: z.string().uuid(), handoverId: z.string().uuid() });
const orderStaffParams = z.object({ orderId: z.string().uuid(), staffUserId: z.string().uuid() });

export function createLaundryRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Customer ----
  router.get('/orders', validate(laundryOrderListQuerySchema, 'query'), listCustomerOrders);
  router.get('/orders/:orderId', validate(laundryOrderIdParamsSchema, 'params'), getCustomerOrder);
  router.post('/orders/:orderId/cancel', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryCancelSchema, 'body'), cancelOrder);
  router.post('/orders/:orderId/confirm-completion', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryCustomerConfirmationSchema, 'body'), confirmCompletion);
  router.post('/orders/:orderId/exceptions', validate(laundryOrderIdParamsSchema, 'params'), validate(reportLaundryExceptionSchema, 'body'), reportException);
  router.post('/orders/:orderId/inspections/:inspectionId/resolve', validate(laundryInspectionIdParamsSchema, 'params'), validate(resolveInspectionSchema, 'body'), resolveInspection);
  router.post('/orders/:orderId/amendments/:amendmentId/decide', validate(laundryAmendmentIdParamsSchema, 'params'), validate(decideLaundryAmendmentSchema, 'body'), decideAmendment);

  // ---- Provider ----
  router.post('/provider/orders', validate(createLaundryOrderSchema, 'body'), createOrder);
  router.get('/provider/orders', validate(laundryOrderListQuerySchema, 'query'), listProviderOrders);
  router.get('/provider/orders/:orderId', validate(laundryOrderIdParamsSchema, 'params'), getProviderOrder);
  router.post('/provider/orders/:orderId/progress', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryProgressSchema, 'body'), updateProgress);
  router.post('/provider/orders/:orderId/fail', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryFailSchema, 'body'), failOrder);
  router.post('/provider/orders/:orderId/cancel', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryCancelSchema, 'body'), providerCancelOrder);
  router.post('/provider/orders/:orderId/items', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryItemSchema, 'body'), addItem);
  router.put('/provider/orders/:orderId/items/:itemId', validate(orderItemParams, 'params'), validate(laundryItemUpdateSchema, 'body'), updateItem);
  router.post('/provider/orders/:orderId/inspections', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryInspectionSchema, 'body'), recordInspection);
  router.post('/provider/orders/:orderId/staff', validate(laundryOrderIdParamsSchema, 'params'), validate(assignLaundryStaffSchema, 'body'), assignStaff);
  router.delete('/provider/orders/:orderId/staff/:staffUserId', validate(orderStaffParams, 'params'), revokeStaff);
  router.put('/provider/orders/:orderId/checklist', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryChecklistUpdateSchema, 'body'), updateChecklist);
  router.post('/provider/orders/:orderId/handovers', validate(laundryOrderIdParamsSchema, 'params'), validate(scheduleHandoverSchema, 'body'), scheduleHandover);
  router.post('/provider/orders/:orderId/handovers/:handoverId/confirm', validate(orderHandoverParams, 'params'), validate(confirmHandoverSchema, 'body'), confirmHandover);
  router.post('/provider/orders/:orderId/amendments', validate(laundryOrderIdParamsSchema, 'params'), validate(proposeLaundryAmendmentSchema, 'body'), proposeAmendment);
  router.post('/provider/orders/:orderId/completion', validate(laundryOrderIdParamsSchema, 'params'), validate(laundryCompletionSchema, 'body'), submitCompletion);

  return router;
}