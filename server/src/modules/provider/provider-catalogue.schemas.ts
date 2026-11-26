// Provider service-catalogue validation schemas (Task 13.4).
import { z } from 'zod';

const domainEnum = z.enum([
  'moving', 'garbage', 'laundry', 'cleaning', 'plumbing', 'electrical', 'hvac',
  'pest_control', 'landscaping', 'carpentry', 'painting', 'roofing', 'flooring',
  'tiling', 'appliances', 'networking', 'solar', 'general',
]);
const offeringStatusEnum = z.enum(['draft', 'active', 'paused', 'unavailable', 'archived']);
const pricingModelEnum = z.enum([
  'fixed',
  'starting',
  'per_item',
  'per_unit',
  'per_km',
  'hourly',
  'weight',
  'volume',
  'custom_quote',
]);

const timeString = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/, 'Time must be HH:MM');

export const catalogueQuerySchema = z.object({
  domain: domainEnum.optional(),
});

export const catalogueDomainParamsSchema = z.object({
  serviceType: domainEnum,
});

export const offeringListQuerySchema = z.object({
  organizationId: z.string().uuid().optional(),
  domain: domainEnum.optional(),
  status: offeringStatusEnum.optional(),
});

export const offeringIdParamsSchema = z.object({
  serviceId: z.string().uuid(),
});

// Domain-specific configuration is intentionally permissive (JSONB) but bounded.
export const createOfferingSchema = z
  .object({
    profileId: z.string().uuid(),
    domain: domainEnum,
    categoryId: z.string().trim().min(1).max(80),
    title: z.string().trim().min(1).max(200),
    description: z.string().trim().max(4000).optional().nullable(),
    serviceType: z.string().trim().max(80).optional().nullable(),
    status: offeringStatusEnum.default('draft'),
    config: z.record(z.string(), z.unknown()).default({}),
    capabilities: z
      .array(
        z.object({
          capabilityId: z.string().trim().min(1).max(80),
          enabled: z.boolean().default(true),
          detail: z.string().trim().max(1000).optional().nullable(),
        }),
      )
      .optional(),
    pricing: z
      .object({
        pricingModel: pricingModelEnum.default('custom_quote'),
        currency: z.string().length(3).default('KES'),
        baseAmount: z.number().nonnegative().optional().nullable(),
        minimumCharge: z.number().nonnegative().optional().nullable(),
        unitLabel: z.string().trim().max(50).optional().nullable(),
        quotationRequired: z.boolean().default(false),
        isIndicative: z.boolean().default(true),
        priceNotes: z.string().trim().max(2000).optional().nullable(),
      })
      .optional(),
  })
  .superRefine((v, ctx) => {
    if (v.status === 'active' && v.pricing && v.pricing.quotationRequired === false) {
      // Active offerings may still be quote-only; no hard block. Intentionally
      // permissive: pricing validity is enforced in the service layer.
    }
  });

export const updateOfferingSchema = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().trim().max(4000).optional().nullable(),
    serviceType: z.string().trim().max(80).optional().nullable(),
    categoryId: z.string().trim().min(1).max(80).optional(),
    config: z.record(z.string(), z.unknown()).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'No fields to update' });

export const offeringCapabilitiesSchema = z.object({
  capabilities: z.array(
    z.object({
      capabilityId: z.string().trim().min(1).max(80),
      enabled: z.boolean().default(true),
      detail: z.string().trim().max(1000).optional().nullable(),
    }),
  ),
});

export const offeringPricingSchema = z.object({
  pricingModel: pricingModelEnum.default('custom_quote'),
  currency: z.string().length(3).default('KES'),
  baseAmount: z.number().nonnegative().optional().nullable(),
  minimumCharge: z.number().nonnegative().optional().nullable(),
  unitLabel: z.string().trim().max(50).optional().nullable(),
  quotationRequired: z.boolean().default(false),
  isIndicative: z.boolean().default(true),
  priceNotes: z.string().trim().max(2000).optional().nullable(),
});

// ---- Locations ----
export const locationListQuerySchema = z.object({
  organizationId: z.string().uuid().optional(),
});

export const locationIdParamsSchema = z.object({
  locationId: z.string().uuid(),
});

const locationFields = z.object({
  locationType: z
    .enum(['personal_residential', 'business_office', 'provider_operating', 'service_area', 'property_location'])
    .default('provider_operating'),
  label: z.string().trim().max(100).optional().nullable(),
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  formattedAddress: z.string().trim().max(1000).optional().nullable(),
  placeId: z.string().trim().max(255).optional().nullable(),
  country: z.string().trim().max(100).optional().nullable(),
  county: z.string().trim().max(100).optional().nullable(),
  city: z.string().trim().max(100).optional().nullable(),
  neighbourhood: z.string().trim().max(100).optional().nullable(),
  street: z.string().trim().max(200).optional().nullable(),
  buildingName: z.string().trim().max(200).optional().nullable(),
  locationSource: z
    .enum(['device_gps', 'manual_map_pin', 'address_search', 'text_entry'])
    .default('manual_map_pin'),
  isPublic: z.boolean().default(false),
  visibility: z.enum(['private', 'public']).default('private'),
  isPrimary: z.boolean().default(false),
  specializedProfileId: z.string().uuid().optional().nullable(),
  organisationId: z.string().uuid().optional().nullable(),
});

export const createLocationSchema = locationFields;
export const updateLocationSchema = locationFields.partial();

// ---- Service areas ----
export const serviceAreaListQuerySchema = z.object({
  profileId: z.string().uuid().optional(),
  offeringId: z.string().uuid().optional(),
});

export const serviceAreaIdParamsSchema = z.object({
  areaId: z.string().uuid(),
});

const serviceAreaFields = z.object({
  specializedProfileId: z.string().uuid(),
  offeringId: z.string().uuid().optional().nullable(),
  country: z.string().trim().max(100).optional().nullable(),
  county: z.string().trim().max(100).optional().nullable(),
  city: z.string().trim().max(100).optional().nullable(),
  neighbourhood: z.string().trim().max(100).optional().nullable(),
  areaDescription: z.string().trim().max(1000).optional().nullable(),
  latitude: z.number().finite().min(-90).max(90).optional().nullable(),
  longitude: z.number().finite().min(-180).max(180).optional().nullable(),
  radiusKm: z.number().positive().max(20000).optional().nullable(),
  isActive: z.boolean().default(true),
});

export const createServiceAreaSchema = serviceAreaFields.superRefine((v, ctx) => {
  const hasLat = v.latitude !== undefined && v.latitude !== null;
  const hasLng = v.longitude !== undefined && v.longitude !== null;
  if (hasLat !== hasLng) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'latitude and longitude must be provided together' });
  }
  if (v.radiusKm !== undefined && v.radiusKm !== null && !hasLat) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'radiusKm requires coordinates' });
  }
});

export const updateServiceAreaSchema = serviceAreaFields.partial();

// ---- Operating hours ----
export const availabilityQuerySchema = z.object({
  profileId: z.string().uuid().optional(),
  offeringId: z.string().uuid().optional(),
});

export const operatingHoursReplaceSchema = z.object({
  specializedProfileId: z.string().uuid().optional(),
  offeringId: z.string().uuid().optional(),
  timeZone: z.string().trim().max(60).default('Africa/Nairobi'),
  hours: z
    .array(
      z.object({
        dayOfWeek: z.number().int().min(0).max(6),
        openTime: timeString,
        closeTime: timeString,
        isClosed: z.boolean().default(false),
      }),
    )
    .min(1)
    .max(42),
});

export const exceptionIdParamsSchema = z.object({
  exceptionId: z.string().uuid(),
});

export const createExceptionSchema = z.object({
  specializedProfileId: z.string().uuid(),
  offeringId: z.string().uuid().optional().nullable(),
  exceptionDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
  isUnavailable: z.boolean().default(true),
  startTime: timeString.optional().nullable(),
  endTime: timeString.optional().nullable(),
  reason: z.string().trim().max(1000).optional().nullable(),
  timeZone: z.string().trim().max(60).default('Africa/Nairobi'),
});

export const updateExceptionSchema = createExceptionSchema.partial();

export type CreateOfferingInput = z.infer<typeof createOfferingSchema>;
export type UpdateOfferingInput = z.infer<typeof updateOfferingSchema>;
export type OfferingCapabilitiesInput = z.infer<typeof offeringCapabilitiesSchema>;
export type OfferingPricingInput = z.infer<typeof offeringPricingSchema>;
export type CreateLocationInput = z.infer<typeof createLocationSchema>;
export type UpdateLocationInput = z.infer<typeof updateLocationSchema>;
export type CreateServiceAreaInput = z.infer<typeof createServiceAreaSchema>;
export type UpdateServiceAreaInput = z.infer<typeof updateServiceAreaSchema>;
export type OperatingHoursReplaceInput = z.infer<typeof operatingHoursReplaceSchema>;
export type CreateExceptionInput = z.infer<typeof createExceptionSchema>;
export type UpdateExceptionInput = z.infer<typeof updateExceptionSchema>;