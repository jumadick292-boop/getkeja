import { Router } from 'express';
import { validateBody } from '../../middleware/validate.js';
import {
  deviceRegistrationSchema,
  deviceUpdateSchema,
} from './auth.schema.js';
import {
  refresh,
  getSessions,
  getCurrentSession,
  revokeSession,
  logoutAll,
  registerDevice,
  getDevices,
  updateDevice,
  revokeDevice,
} from './session.controller.js';
import { requireAuth } from './auth.middleware.js';

export function createSessionRouter(): Router {
  const router = Router();

  // Token refresh
  router.post('/refresh', refresh);

  // Session management
  router.get('/sessions', requireAuth, getSessions);
  router.get('/sessions/current', requireAuth, getCurrentSession);
  router.delete('/sessions/:sessionId', requireAuth, revokeSession);

  // Logout
  router.post('/logout-all', requireAuth, logoutAll);

  // Device management
  router.post('/devices/register', requireAuth, validateBody(deviceRegistrationSchema), registerDevice);
  router.get('/devices', requireAuth, getDevices);
  router.patch('/devices/:deviceId', requireAuth, validateBody(deviceUpdateSchema), updateDevice);
  router.delete('/devices/:deviceId', requireAuth, revokeDevice);

  return router;
}