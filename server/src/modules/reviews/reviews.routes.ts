// Provider reviews routes (Task 13.16) — mounted at /api/v1/reviews.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  reviewResourceParamsSchema, createReviewSchema, reviewIdParamsSchema,
  respondReviewSchema, reportReviewSchema, moderateReviewSchema, reviewListQuerySchema,
} from './reviews.schemas.js';
import {
  submitReview, listProviderReviews, listCustomerReviews, getReview,
  respondToReview, reportReview, moderateReview, getRatingSummary,
} from './reviews.controller.js';

const profileParams = z.object({ providerProfileId: z.string().uuid() });

export function createReviewsRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // Customer
  router.post('/resources/:domain/:resourceId', validate(reviewResourceParamsSchema, 'params'), validate(createReviewSchema, 'body'), submitReview);
  router.get('/mine', listCustomerReviews);

  // Provider
  router.get('/provider', validate(reviewListQuerySchema, 'query'), listProviderReviews);
  router.post('/:reviewId/respond', validate(reviewIdParamsSchema, 'params'), validate(respondReviewSchema, 'body'), respondToReview);

  // Shared
  router.get('/:reviewId', validate(reviewIdParamsSchema, 'params'), getReview);
  router.post('/:reviewId/report', validate(reviewIdParamsSchema, 'params'), validate(reportReviewSchema, 'body'), reportReview);

  // Public rating summary + moderation
  router.get('/profiles/:providerProfileId/rating', validate(profileParams, 'params'), getRatingSummary);
  router.post('/:reviewId/moderate', validate(reviewIdParamsSchema, 'params'), validate(moderateReviewSchema, 'body'), moderateReview);

  return router;
}