import { z } from 'zod';

const optionalText = (max: number) => z.string().trim().max(max).nullable().optional();
const optionalUrl = z.string().url().max(500).nullable().optional().refine(
  (value) => value === undefined || value === null || value.startsWith('https://'),
  'Image and website URLs must use HTTPS',
);

export const profileCategorySchema = z.enum([
  'house_seeker',
  'tenant',
  'landlord',
  'real_estate_agent',
  'agency',
  'property_manager',
  'caretaker',
  'moving_service_provider',
  'garbage_collection_provider',
  'laundry_service_provider',
]);

const specializedProfileFields = z.object({
  profileCategory: profileCategorySchema,
  fullName: optionalText(200),
  displayName: optionalText(100),
  profilePhotoUrl: optionalUrl,
  businessName: optionalText(200),
  businessLogoUrl: optionalUrl,
  description: optionalText(2000),
  contactEmail: z.string().email().max(255).nullable().optional(),
  contactPhone: optionalText(20),
  websiteUrl: optionalUrl,
  organisationId: z.string().uuid().nullable().optional(),
}).strict();

export const createSpecializedProfileSchema = specializedProfileFields.superRefine((value, ctx) => {
  if (value.profileCategory === 'agency' && !value.organisationId) {
    ctx.addIssue({
      code: 'custom',
      path: ['organisationId'],
      message: 'Agency profiles must be linked to an organization',
    });
  }
});

export const updateSpecializedProfileSchema = specializedProfileFields
  .omit({ profileCategory: true })
  .partial()
  .strict();

export const createPersonalProfileSchema = z.object({
  displayName: optionalText(100),
  profilePhotoUrl: optionalUrl,
  bio: optionalText(2000),
  phoneNumber: optionalText(20),
  websiteUrl: optionalUrl,
}).strict();

export const profileImageUploadSchema = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('personal_photo') }).strict(),
  z.object({
    kind: z.enum(['profile_photo', 'business_logo']),
    profileId: z.string().uuid(),
  }).strict(),
  z.object({
    kind: z.literal('organization_logo'),
    organizationId: z.string().uuid(),
  }).strict(),
]);

export const saveLocationSchema = z.object({
  locationType: z.enum(['personal_residential', 'business_office', 'provider_operating']),
  specializedProfileId: z.string().uuid().nullable().optional(),
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  formattedAddress: z.string().trim().max(500).nullable().optional(),
  placeId: z.string().trim().max(255).nullable().optional(),
  country: optionalText(100),
  county: optionalText(100),
  city: optionalText(100),
  neighborhood: optionalText(100),
  street: optionalText(200),
  buildingName: optionalText(200),
  locationSource: z.enum(['device_gps', 'manual_map_pin', 'address_search', 'text_entry'])
    .default('manual_map_pin'),
  accuracy: z.number().finite().min(0).max(100_000).nullable().optional(),
}).strict().superRefine((value, ctx) => {
  if (value.locationType === 'personal_residential' && value.specializedProfileId) {
    ctx.addIssue({
      code: 'custom',
      path: ['specializedProfileId'],
      message: 'Personal residential locations cannot be attached to a specialized profile',
    });
  }
  if (value.locationType !== 'personal_residential' && !value.specializedProfileId) {
    ctx.addIssue({
      code: 'custom',
      path: ['specializedProfileId'],
      message: 'Business and provider locations must belong to a specialized profile',
    });
  }
});

const serviceAreaFields = z.object({
  profileId: z.string().uuid(),
  country: optionalText(100),
  county: optionalText(100),
  city: optionalText(100),
  neighborhood: optionalText(100),
  areaDescription: optionalText(1000),
  latitude: z.number().finite().min(-90).max(90).nullable().optional(),
  longitude: z.number().finite().min(-180).max(180).nullable().optional(),
  radiusKm: z.number().finite().positive().max(20_000).nullable().optional(),
  status: z.enum(['active', 'inactive']).default('active'),
}).strict();

export const serviceAreaSchema = serviceAreaFields.superRefine((value, ctx) => {
  if ((value.latitude === null || value.latitude === undefined) !==
      (value.longitude === null || value.longitude === undefined)) {
    ctx.addIssue({
      code: 'custom',
      path: ['longitude'],
      message: 'Latitude and longitude must be provided together',
    });
  }
  if (value.radiusKm !== undefined && value.radiusKm !== null &&
      (value.latitude === null || value.latitude === undefined)) {
    ctx.addIssue({
      code: 'custom',
      path: ['radiusKm'],
      message: 'A radius requires a center latitude and longitude',
    });
  }
});

export const updateServiceAreaSchema = serviceAreaFields
  .omit({ profileId: true })
  .partial()
  .strict()
  .superRefine((value, ctx) => {
    if ((value.latitude === null || value.latitude === undefined) !==
        (value.longitude === null || value.longitude === undefined)) {
      ctx.addIssue({
        code: 'custom',
        path: ['longitude'],
        message: 'Latitude and longitude must be provided together',
      });
    }
    if (value.radiusKm !== null && value.radiusKm !== undefined &&
        (value.latitude === null || value.latitude === undefined)) {
      ctx.addIssue({
        code: 'custom',
        path: ['radiusKm'],
        message: 'A radius requires a center latitude and longitude',
      });
    }
  });

export const providerExtensionSchema = z.object({
  serviceTypes: z.array(z.string().trim().min(1).max(100)).max(50).optional(),
  serviceDescription: optionalText(2000),
  operatingStatus: z.enum(['active', 'inactive', 'temporarily_unavailable']).optional(),
  registrationNumber: optionalText(100),
  taxId: optionalText(100),
  businessHours: z.record(z.string(), z.unknown()).nullable().optional(),
  available247: z.boolean().optional(),
  emergencyService: z.boolean().optional(),
  insuranceInfo: z.record(z.string(), z.unknown()).nullable().optional(),
  certifications: z.array(z.record(z.string(), z.unknown())).max(50).optional(),
  bookingContactEmail: z.string().email().max(255).nullable().optional(),
  bookingContactPhone: optionalText(20),
}).strict();

export const laundryServicesSchema = z.object({
  offersWashing: z.boolean().optional(),
  offersDryCleaning: z.boolean().optional(),
  offersIroning: z.boolean().optional(),
  offersFolding: z.boolean().optional(),
  offersBeddingCleaning: z.boolean().optional(),
  offersHouseholdTextileCleaning: z.boolean().optional(),
  offersOtherServices: z.boolean().optional(),
  otherServicesDescription: optionalText(1000),
  specialHandlingInfo: optionalText(2000),
  offersPickup: z.boolean().optional(),
  offersDelivery: z.boolean().optional(),
  customerVisitRequired: z.boolean().optional(),
  pickupDeliveryAreas: z.array(z.string().trim().min(1).max(200)).max(100).optional(),
}).strict();

export const organizationProfileSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  description: optionalText(2000),
  contactEmail: z.string().email().max(255).nullable().optional(),
  contactPhone: optionalText(50),
  address: optionalText(500),
  city: optionalText(100),
  county: optionalText(100),
  country: z.string().trim().length(2).optional(),
  registrationNumber: optionalText(100),
  taxId: optionalText(100),
  logoUrl: optionalUrl,
  websiteUrl: optionalUrl,
  latitude: z.number().finite().min(-90).max(90).nullable().optional(),
  longitude: z.number().finite().min(-180).max(180).nullable().optional(),
  placeId: z.string().trim().max(255).nullable().optional(),
  neighborhood: optionalText(100),
  locationSource: z.enum(['device_gps', 'manual_map_pin', 'address_search', 'text_entry']).optional(),
}).strict().superRefine((value, ctx) => {
  if ((value.latitude === null || value.latitude === undefined) !==
      (value.longitude === null || value.longitude === undefined)) {
    ctx.addIssue({
      code: 'custom',
      path: ['longitude'],
      message: 'Latitude and longitude must be provided together',
    });
  }
});

const profileReviewFields = z.object({
  decision: z.enum(['approved', 'rejected', 'request_changes', 'suspended']),
  reviewNotes: optionalText(2000),
  rejectionReason: optionalText(1000),
  requestedChanges: optionalText(2000),
}).strict();

function requireRejectionReason(
  value: { decision: string; rejectionReason?: string | null },
  ctx: z.RefinementCtx,
) {
  if (value.decision === 'rejected' && !value.rejectionReason?.trim()) {
    ctx.addIssue({
      code: 'custom',
      path: ['rejectionReason'],
      message: 'A rejection reason is required',
    });
  }
}

export const profileReviewSchema = profileReviewFields.superRefine(requireRejectionReason);

export const organizationReviewSchema = profileReviewFields.extend({
  decision: z.enum(['approved', 'rejected', 'request_changes']),
}).superRefine(requireRejectionReason);

export const profileIdParamsSchema = z.object({ id: z.string().uuid() }).strict();
export const organizationIdParamsSchema = z.object({
  organizationId: z.string().uuid(),
}).strict();
export const serviceAreaIdParamsSchema = z.object({
  areaId: z.string().uuid(),
}).strict();
export const serviceAreasProfileParamsSchema = z.object({
  profileId: z.string().uuid(),
}).strict();
export const providerExtensionIdParamsSchema = z.object({
  providerProfileId: z.string().uuid(),
}).strict();
export const profileIdQuerySchema = z.object({
  profileId: z.string().uuid().optional(),
}).strict();

export const placeSearchQuerySchema = z.object({
  input: z.string().trim().min(2).max(200),
}).strict();
export const placeIdParamsSchema = z.object({
  placeId: z.string().trim().min(1).max(255),
}).strict();
export const verificationDocumentSchema = z.object({
  documentType: z.string().trim().min(1).max(80).default('supporting_document'),
}).strict();
export const verificationDocumentIdParamsSchema = z.object({
  documentId: z.string().uuid(),
}).strict();

export type ProfileCategory = z.infer<typeof profileCategorySchema>;
export type CreateSpecializedProfileInput = z.infer<typeof createSpecializedProfileSchema>;
export type UpdateSpecializedProfileInput = z.infer<typeof updateSpecializedProfileSchema>;
export type PersonalProfileInput = z.infer<typeof createPersonalProfileSchema>;
export type SavedLocationInput = z.infer<typeof saveLocationSchema>;
export type ServiceAreaInput = z.infer<typeof serviceAreaSchema>;
export type UpdateServiceAreaInput = z.infer<typeof updateServiceAreaSchema>;
export type ProviderExtensionInput = z.infer<typeof providerExtensionSchema>;
export type LaundryServicesInput = z.infer<typeof laundryServicesSchema>;
export type OrganizationProfileInput = z.infer<typeof organizationProfileSchema>;
export type ProfileReviewInput = z.infer<typeof profileReviewSchema>;
export type OrganizationReviewInput = z.infer<typeof organizationReviewSchema>;
