import { z } from 'zod';

export const startSharingSchema = z.object({
  siteVisitId: z.string().uuid(),
  recipientUserId: z.string().uuid(),
  durationMinutes: z.union([z.literal(15), z.literal(30), z.literal(60), z.literal(480)]),
}).strict();

export const updateLocationSchema = z.object({
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  accuracyMeters: z.number().finite().min(0).max(100_000).optional(),
}).strict();

export const sharingSessionParamsSchema = z.object({
  sessionId: z.string().uuid(),
}).strict();
