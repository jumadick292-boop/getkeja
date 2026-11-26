// Service marketplace routes (Task 13.5) — mounted at /api/v1/marketplace.
// Customer request lifecycle + provider quotation inbox share one engine.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  createServiceRequestSchema,
  serviceRequestListQuerySchema,
  serviceRequestIdParamsSchema,
  cancelServiceRequestSchema,
  submitQuotationSchema,
  quotationIdParamsSchema,
  withdrawQuotationSchema,
  acceptQuotationSchema,
  providerInboxQuerySchema,
} from './marketplace.schemas.js';
import { z } from 'zod';
import {
  browseCategories,
  createRequest,
  listMyRequests,
  getMyRequest,
  cancelRequest,
  acceptQuotation,
  providerInbox,
  providerRequestDetail,
  submitQuotation,
  withdrawQuotation,
  advanceJob,
} from './marketplace.controller.js';

const requestQuotationParamsSchema = z.object({
  requestId: z.string().uuid(),
  quotationId: z.string().uuid(),
});
const advanceParamsSchema = z.object({
  requestId: z.string().uuid(),
  action: z.enum(['start', 'complete']),
});
const categoryQuerySchema = z.object({ domain: z.string().trim().max(40).optional() });

export function createMarketplaceRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // ---- Catalogue ----
  router.get('/categories', validate(categoryQuerySchema, 'query'), browseCategories);

  // ---- Customer requests ----
  router.post('/requests', validate(createServiceRequestSchema, 'body'), createRequest);
  router.get('/requests', validate(serviceRequestListQuerySchema, 'query'), listMyRequests);
  router.get('/requests/:requestId', validate(serviceRequestIdParamsSchema, 'params'), getMyRequest);
  router.post('/requests/:requestId/cancel', validate(serviceRequestIdParamsSchema, 'params'), validate(cancelServiceRequestSchema, 'body'), cancelRequest);
  router.post(
    '/requests/:requestId/quotations/:quotationId/accept',
    validate(requestQuotationParamsSchema, 'params'),
    validate(acceptQuotationSchema, 'body'),
    acceptQuotation,
  );

  // ---- Provider quotation inbox ----
  router.get('/provider/inbox', validate(providerInboxQuerySchema, 'query'), providerInbox);
  router.get('/provider/requests/:requestId', validate(serviceRequestIdParamsSchema, 'params'), providerRequestDetail);
  router.post('/provider/requests/:requestId/quotations', validate(serviceRequestIdParamsSchema, 'params'), validate(submitQuotationSchema, 'body'), submitQuotation);
  router.post('/provider/quotations/:quotationId/withdraw', validate(quotationIdParamsSchema, 'params'), validate(withdrawQuotationSchema, 'body'), withdrawQuotation);
  router.post('/provider/requests/:requestId/advance/:action', validate(advanceParamsSchema, 'params'), advanceJob);

  return router;
}