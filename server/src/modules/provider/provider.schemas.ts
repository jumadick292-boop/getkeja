// Provider-facing validation schemas.
import { z } from 'zod';

export const providerInboxQuerySchema = z.object({
  serviceType: z.enum(['moving', 'garbage', 'laundry']).optional(),
  status: z.string().trim().max(40).optional(),
  organizationId: z.string().uuid().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const providerRequestIdParamsSchema = z.object({
  requestId: z.string().uuid(),
});

export const providerRespondSchema = z.object({
  // The domain is inferred from the request, but the client states intent.
  action: z.enum(['accept', 'decline']),
  reason: z.string().trim().max(1000).optional().nullable(),
});

// Discovery: either coordinates (Haversine) or a textual county/city fallback.
export const providerDiscoveryQuerySchema = z
  .object({
    category: z
      .enum([
        'moving_service_provider',
        'garbage_collection_provider',
        'laundry_service_provider',
      ])
      .optional(),
    latitude: z.coerce.number().finite().min(-90).max(90).optional(),
    longitude: z.coerce.number().finite().min(-180).max(180).optional(),
    county: z.string().trim().max(100).optional(),
    city: z.string().trim().max(100).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .refine(
    (v) =>
      (v.latitude !== undefined && v.longitude !== undefined) ||
      v.county !== undefined ||
      v.city !== undefined,
    { message: 'Provide coordinates (latitude+longitude) or a county/city' },
  )
  .refine(
    (v) =>
      !(
        (v.latitude !== undefined && v.longitude === undefined) ||
        (v.longitude !== undefined && v.latitude === undefined)
      ),
    { message: 'latitude and longitude must be provided together' },
  );