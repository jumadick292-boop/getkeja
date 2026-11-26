// Provider reviews validation schemas (Task 13.16) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();
const rating = z.coerce.number().int().min(1).max(5);

export const reviewResourceParamsSchema = z.object({
  domain: z.string().trim().min(1).max(40),
  resourceId: uuid,
});

export const createReviewSchema = z
  .object({
    overallRating: rating,
    comment: z.string().trim().max(2000).optional(),
    qualityRating: rating.optional(),
    professionalismRating: rating.optional(),
    timelinessRating: rating.optional(),
    valueRating: rating.optional(),
  })
  .strict();

export const reviewIdParamsSchema = z.object({ reviewId: uuid });

export const respondReviewSchema = z
  .object({ response: z.string().trim().min(1).max(2000) })
  .strict();

export const reportReviewSchema = z
  .object({
    reason: z.string().trim().min(1).max(200),
    details: z.string().trim().max(2000).optional(),
  })
  .strict();

export const moderateReviewSchema = z
  .object({
    status: z.enum(['published', 'pending_moderation', 'hidden', 'removed']),
    reason: z.string().trim().max(1000).optional(),
  })
  .strict();

export const reviewListQuerySchema = z.object({
  providerProfileId: uuid.optional(),
  status: z.enum(['published', 'pending_moderation', 'hidden', 'removed']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export type CreateReviewInput = z.infer<typeof createReviewSchema>;
export type RespondReviewInput = z.infer<typeof respondReviewSchema>;
export type ReportReviewInput = z.infer<typeof reportReviewSchema>;
export type ModerateReviewInput = z.infer<typeof moderateReviewSchema>;