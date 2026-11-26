import { z } from 'zod';

export const providerDiscoveryQuerySchema = z
  .object({
    latitude: z.coerce.number().finite().min(-90).max(90),
    longitude: z.coerce.number().finite().min(-180).max(180),
    category: z
      .enum([
        'moving_service_provider',
        'garbage_collection_provider',
        'laundry_service_provider',
      ])
      .optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();

export type ProviderDiscoveryQuery = z.infer<
  typeof providerDiscoveryQuerySchema
>;
