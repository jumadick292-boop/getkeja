import { z } from 'zod';

const latitude = z.coerce.number().finite().min(-90).max(90);
const longitude = z.coerce.number().finite().min(-180).max(180);

export const nearbyListingsQuerySchema = z
  .object({
    latitude: latitude.optional(),
    longitude: longitude.optional(),
    radiusKm: z.coerce.number().finite().positive().max(100).default(10),
    north: latitude.optional(),
    south: latitude.optional(),
    east: longitude.optional(),
    west: longitude.optional(),
    q: z.string().trim().max(120).optional(),
    city: z.string().trim().max(100).optional(),
    county: z.string().trim().max(100).optional(),
    propertyType: z.string().trim().max(50).optional(),
    rentMin: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    rentMax: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    bedrooms: z.coerce.number().int().min(0).max(20).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict()
  .superRefine((value, ctx) => {
    const hasCenter =
      value.latitude !== undefined || value.longitude !== undefined;
    if ((value.latitude === undefined) !== (value.longitude === undefined)) {
      ctx.addIssue({
        code: 'custom',
        path: ['longitude'],
        message: 'Latitude and longitude must be provided together',
      });
    }
    const bounds = [value.north, value.south, value.east, value.west];
    if (
      bounds.some((part) => part !== undefined) &&
      bounds.some((part) => part === undefined)
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['north'],
        message: 'Viewport bounds require north, south, east, and west',
      });
    }
    if (bounds.every((part) => part !== undefined)) {
      if (value.north! <= value.south!) {
        ctx.addIssue({
          code: 'custom',
          path: ['north'],
          message: 'North must be greater than south',
        });
      }
      if (value.east === value.west) {
        ctx.addIssue({
          code: 'custom',
          path: ['east'],
          message: 'Viewport width must be greater than zero',
        });
      }
    }
    if (
      !hasCenter &&
      bounds.every((part) => part === undefined) &&
      !value.q &&
      !value.city &&
      !value.county
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['latitude'],
        message:
          'Provide a center point, complete viewport bounds, or location search text',
      });
    }
    if (
      value.rentMin !== undefined &&
      value.rentMax !== undefined &&
      value.rentMin > value.rentMax
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['rentMax'],
        message: 'Maximum rent must be greater than or equal to minimum rent',
      });
    }
  })
  .transform((value) => ({
    ...value,
    wrapsAntimeridian:
      value.east !== undefined &&
      value.west !== undefined &&
      value.east < value.west,
  }));

export type NearbyListingsQuery = z.infer<typeof nearbyListingsQuerySchema>;

export const directionsRequestSchema = z
  .object({
    origin: z.object({ latitude, longitude }).strict(),
    destination: z.object({ latitude, longitude }).strict(),
    travelMode: z
      .enum(['DRIVE', 'WALK', 'BICYCLE', 'TRANSIT', 'TWO_WHEELER'])
      .default('DRIVE'),
  })
  .strict();

export type DirectionsRequest = z.infer<typeof directionsRequestSchema>;
