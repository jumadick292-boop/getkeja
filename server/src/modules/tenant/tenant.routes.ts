// Tenant routes — tenant-facing API under /api/v1/tenant.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  tenantDashboardQuerySchema,
  tenancyQuerySchema,
  tenantMaintenanceReportSchema,
  tenantGarbageRequestSchema,
  tenantMovingRequestSchema,
  tenantLaundryRequestSchema,
  tenantRequestListQuerySchema,
  notificationMarkReadSchema,
  signedUrlRequestSchema,
} from './tenant.schema.js';
import {
  getTenantDashboard,
  getTenantTenancies,
  getTenantTenancyDetail,
  getTenantInvoices,
  getTenantPayments,
  getTenantInvoiceDetail,
  getTenantMaintenanceRequests,
  getTenantGarbageRequests,
  getTenantMovingRequests,
  getTenantLaundryRequests,
  getDocumentSignedUrl,
  createTenantMaintenanceRequest,
  createTenantGarbageRequest,
  createTenantMovingRequest,
  createTenantLaundryRequest,
  cancelTenantMaintenanceRequest,
  cancelTenantGarbageRequest,
  cancelTenantMovingRequest,
  cancelTenantLaundryRequest,
} from './tenant.controller.js';

export function createTenantRouter(): Router {
  const router = Router();

  router.use(requireAuth);

  // Dashboard
  router.get(
    '/dashboard',
    validate(tenantDashboardQuerySchema, 'query'),
    getTenantDashboard,
  );

  // Tenancies
  router.get(
    '/tenancies',
    validate(tenancyQuerySchema, 'query'),
    getTenantTenancies,
  );
  router.get(
    '/tenancies/:tenancyId',
    getTenantTenancyDetail,
  );

  // Financial — invoices
  router.get('/invoices', getTenantInvoices);
  router.get('/invoices/:invoiceId', getTenantInvoiceDetail);

  // Financial — payments
  router.get('/payments', getTenantPayments);

  // Maintenance requests
  router.get(
    '/maintenance-requests',
    getTenantMaintenanceRequests,
  );
  router.post(
    '/maintenance-requests',
    validate(tenantMaintenanceReportSchema),
    createTenantMaintenanceRequest,
  );
  router.delete(
    '/maintenance-requests/:requestId',
    cancelTenantMaintenanceRequest,
  );

  // Garbage collection requests
  router.get(
    '/garbage-requests',
    validate(tenantRequestListQuerySchema, 'query'),
    getTenantGarbageRequests,
  );
  router.post(
    '/garbage-requests',
    validate(tenantGarbageRequestSchema),
    createTenantGarbageRequest,
  );
  router.delete(
    '/garbage-requests/:requestId',
    cancelTenantGarbageRequest,
  );

  // Moving service requests
  router.get(
    '/moving-requests',
    validate(tenantRequestListQuerySchema, 'query'),
    getTenantMovingRequests,
  );
  router.post(
    '/moving-requests',
    validate(tenantMovingRequestSchema),
    createTenantMovingRequest,
  );
  router.delete(
    '/moving-requests/:requestId',
    cancelTenantMovingRequest,
  );

  // Laundry service requests
  router.get(
    '/laundry-requests',
    validate(tenantRequestListQuerySchema, 'query'),
    getTenantLaundryRequests,
  );
  router.post(
    '/laundry-requests',
    validate(tenantLaundryRequestSchema),
    createTenantLaundryRequest,
  );
  router.delete(
    '/laundry-requests/:requestId',
    cancelTenantLaundryRequest,
  );

  // Document signed URLs
  router.post(
    '/documents/signed-url',
    validate(signedUrlRequestSchema),
    getDocumentSignedUrl,
  );

  return router;
}
