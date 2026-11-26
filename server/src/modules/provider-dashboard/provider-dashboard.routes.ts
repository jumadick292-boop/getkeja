// Provider dashboard routes (Task 13.16) — mounted at /api/v1/provider/dashboard.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { getDashboard, getStaffWorkload } from './provider-dashboard.controller.js';

export function createProviderDashboardRouter(): Router {
  const router = Router();
  router.use(requireAuth);
  router.get('/', getDashboard);
  router.get('/staff-workload', getStaffWorkload);
  return router;
}