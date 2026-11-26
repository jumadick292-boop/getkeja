import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import { requireAuth } from '../auth/auth.middleware.js';
import * as controller from './location-sharing.controller.js';
import {
  sharingSessionParamsSchema,
  startSharingSchema,
  updateLocationSchema,
} from './location-sharing.schema.js';
import { providerDiscoveryQuerySchema } from './provider-discovery.schema.js';

const router = Router();
router.use(requireAuth);
router.get(
  '/providers',
  createRateLimiter({
    windowMs: 60_000,
    max: 60,
    keyPrefix: 'location:provider-search',
    identifierField: 'userId',
  }),
  validate(providerDiscoveryQuerySchema, 'query'),
  controller.discoverProviders,
);
router.get('/sessions', controller.list);
router.get('/shared-with-me', controller.listSharedWithMe);
router.get('/eligible-visits', controller.listEligibleVisits);
router.post(
  '/sessions',
  createRateLimiter({
    windowMs: 60_000,
    max: 10,
    keyPrefix: 'location:share:start',
    identifierField: 'userId',
  }),
  validate(startSharingSchema),
  controller.start,
);
router.patch(
  '/sessions/:sessionId/location',
  validate(sharingSessionParamsSchema, 'params'),
  createRateLimiter({
    windowMs: 60_000,
    max: 5,
    keyPrefix: 'location:updates',
    identifierField: 'userId',
  }),
  validate(updateLocationSchema),
  controller.update,
);
router.get(
  '/sessions/:sessionId/location',
  validate(sharingSessionParamsSchema, 'params'),
  controller.sharedLocation,
);
router.post(
  '/sessions/:sessionId/stop',
  validate(sharingSessionParamsSchema, 'params'),
  controller.stop,
);

export function createLocationSharingRouter() {
  return router;
}
