// Provider reporting routes (Task 13.16) — mounted at /api/v1/provider/reports.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { getOperationalReport, getServicePerformance, getCustomerExperience } from './provider-reporting.controller.js';

export function createProviderReportingRouter(): Router {
  const router = Router();
  router.use(requireAuth);
  router.get('/operational', getOperationalReport);
  router.get('/service-performance', getServicePerformance);
  router.get('/customer-experience', getCustomerExperience);
  return router;
}