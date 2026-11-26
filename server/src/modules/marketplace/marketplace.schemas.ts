// Service marketplace validation schemas (Task 13.5).
// Strict Zod: category-specific request details reject unknown keys so the
// `details` JSONB never becomes an arbitrary bag.
import { z } from 'zod';

const uuid = z.string().uuid();

export const serviceRequestDetailsSchema = z
  .object({
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    areaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    frequency: z.enum(['one_time', 'weekly', 'fortnightly', 'monthly']).optional(),
    urgency: z.enum(['standard', 'urgent']).optional(),
    brand: z.string().trim().max(120).optional(),
    model: z.string().trim().max(120).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
  })
  .strict();

const photosSchema = z.array(z.string().trim().max(200)).max(10).optional();

// Wi-Fi Installation & Configuration — strict category details.
export const wifiDetailsSchema = z
  .object({
    propertyUse: z.enum(['residential', 'commercial']).optional(),
    propertyType: z.string().trim().max(120).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    coverageAreaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    existingEquipment: z.string().trim().max(500).optional(),
    jobType: z.enum(['new_installation', 'troubleshooting']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Internet Installation & Connectivity — separate category, may share network
// capabilities but is independently searchable/requestable.
export const internetDetailsSchema = z
  .object({
    propertyUse: z.enum(['residential', 'commercial']).optional(),
    propertyType: z.string().trim().max(120).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    coverageAreaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    existingEquipment: z.string().trim().max(500).optional(),
    jobType: z.enum(['new_installation', 'troubleshooting']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Solar Installation & Maintenance — strict category details.
export const solarDetailsSchema = z
  .object({
    propertyUse: z.enum(['residential', 'commercial']).optional(),
    propertyType: z.string().trim().max(120).optional(),
    jobType: z.enum(['new_installation', 'maintenance']).optional(),
    existingSystem: z.string().trim().max(500).optional(),
    powerRequirementsKw: z.coerce.number().positive().max(100000).optional(),
    existingInverterBatteryPanel: z.string().trim().max(500).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Painting & Decoration — strict category details.
export const paintingDetailsSchema = z
  .object({
    surface: z.enum(['interior', 'exterior']).optional(),
    propertyType: z.string().trim().max(120).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    areaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    surfacePreparation: z.string().trim().max(500).optional(),
    finishType: z.enum(['painting', 'wallpaper', 'decorative']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Garbage collection — strict category details (Task 13.7).
export const garbageDetailsSchema = z
  .object({
    wasteCategory: z.enum(['general', 'recycling', 'organic', 'bulky', 'hazardous']).optional(),
    binCount: z.coerce.number().int().min(0).max(1000).optional(),
    estimatedQuantity: z.string().trim().max(120).optional(),
    frequency: z.enum(['one_time', 'weekly', 'fortnightly', 'monthly']).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Laundry — strict category details (Task 13.8).
export const laundryDetailsSchema = z
  .object({
    services: z.array(z.string().trim().max(80)).max(30).optional(),
    quantity: z.coerce.number().int().min(1).max(10000).optional(),
    weightKg: z.coerce.number().positive().max(100000).optional(),
    fabricCare: z.enum(['regular', 'delicate', 'dry_clean', 'mixed']).optional(),
    frequency: z.enum(['one_time', 'weekly', 'fortnightly', 'monthly']).optional(),
    collectionPreference: z.enum(['dropoff', 'pickup', 'both']).optional(),
    specialInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// ---------------------------------------------------------------------------
// Home Maintenance & Repairs — strict category details (Task 13.12).
// ---------------------------------------------------------------------------
export const plumbingDetailsSchema = z
  .object({
    problemType: z.enum(['leak', 'blockage', 'installation', 'repair', 'other']).optional(),
    jobType: z.enum(['repair', 'installation', 'diagnosis']).optional(),
    fixture: z.string().trim().max(120).optional(),
    severity: z.enum(['low', 'medium', 'high']).optional(),
    urgency: z.enum(['standard', 'urgent']).optional(),
    waterSupplyAvailable: z.boolean().optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const electricalDetailsSchema = z
  .object({
    jobType: z.enum(['installation', 'repair', 'fault_diagnosis']).optional(),
    affectedArea: z.string().trim().max(120).optional(),
    safetyConcerns: z.string().trim().max(1000).optional(),
    powerAvailable: z.boolean().optional(),
    urgency: z.enum(['standard', 'urgent']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const hvacDetailsSchema = z
  .object({
    jobType: z.enum(['installation', 'maintenance', 'repair']).optional(),
    equipmentType: z.string().trim().max(120).optional(),
    capacityModel: z.string().trim().max(120).optional(),
    faultDescription: z.string().trim().max(1000).optional(),
    installLocation: z.string().trim().max(200).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const carpentryDetailsSchema = z
  .object({
    jobType: z.enum(['repair', 'installation', 'fabrication', 'fitting']).optional(),
    itemType: z.string().trim().max(120).optional(),
    dimensions: z.string().trim().max(120).optional(),
    materialPreference: z.string().trim().max(120).optional(),
    finishing: z.string().trim().max(200).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const applianceDetailsSchema = z
  .object({
    applianceCategory: z.string().trim().max(120).optional(),
    manufacturer: z.string().trim().max(120).optional(),
    model: z.string().trim().max(120).optional(),
    faultDescription: z.string().trim().max(1000).optional(),
    warrantyStatus: z.enum(['unknown', 'in_warranty', 'out_of_warranty']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const handymanDetailsSchema = z
  .object({
    taskType: z.string().trim().max(120).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    urgency: z.enum(['standard', 'urgent']).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// ---------------------------------------------------------------------------
// Cleaning & Property Care — strict category details (Task 13.13).
// ---------------------------------------------------------------------------
export const cleaningDetailsSchema = z
  .object({
    propertyType: z.enum(['residential', 'commercial', 'office', 'industrial', 'other']).optional(),
    cleaningType: z.enum(['routine', 'deep', 'move_in', 'move_out', 'post_construction', 'sanitisation']).optional(),
    approximateSize: z.string().trim().max(120).optional(),
    rooms: z.coerce.number().int().min(0).max(500).optional(),
    areas: z.string().trim().max(500).optional(),
    condition: z.enum(['light', 'moderate', 'heavy']).optional(),
    frequency: z.enum(['one_time', 'weekly', 'fortnightly', 'monthly']).optional(),
    requestedTasks: z.array(z.string().trim().max(120)).max(40).optional(),
    suppliesProvided: z.boolean().optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const pestControlDetailsSchema = z
  .object({
    pestType: z.string().trim().max(120).optional(),
    affectedAreas: z.string().trim().max(500).optional(),
    infestationDescription: z.string().trim().max(2000).optional(),
    severity: z.enum(['low', 'medium', 'high']).optional(),
    propertyOccupied: z.boolean().optional(),
    treatmentType: z.enum(['spraying', 'baiting', 'fumigation', 'inspection', 'other']).optional(),
    safetyRequirements: z.string().trim().max(1000).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const landscapingDetailsSchema = z
  .object({
    workType: z.enum(['maintenance', 'mowing', 'trimming', 'planting', 'landscaping', 'cleanup', 'other']).optional(),
    areaSize: z.string().trim().max(120).optional(),
    vegetation: z.string().trim().max(500).optional(),
    frequency: z.enum(['one_time', 'weekly', 'fortnightly', 'monthly']).optional(),
    siteConditions: z.string().trim().max(1000).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// ---------------------------------------------------------------------------
// Finishing & Building Services — strict category details (Task 13.15).
// ---------------------------------------------------------------------------
export const roofingDetailsSchema = z
  .object({
    roofType: z.enum(['flat', 'pitched', 'gable', 'hip', 'shed', 'other']).optional(),
    material: z.string().trim().max(120).optional(),
    approximateAreaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    affectedSections: z.string().trim().max(500).optional(),
    jobType: z.enum(['repair', 'waterproofing', 'installation', 'inspection', 'replacement']).optional(),
    damageDescription: z.string().trim().max(2000).optional(),
    propertyType: z.string().trim().max(120).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const flooringDetailsSchema = z
  .object({
    floorType: z.enum(['tiles', 'wood', 'laminate', 'vinyl', 'concrete', 'carpet', 'other']).optional(),
    existingSurface: z.string().trim().max(500).optional(),
    areaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    roomBreakdown: z.string().trim().max(1000).optional(),
    proposedMaterial: z.string().trim().max(120).optional(),
    finish: z.string().trim().max(120).optional(),
    surfacePreparation: z.string().trim().max(1000).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

export const tilingDetailsSchema = z
  .object({
    surface: z.enum(['floor', 'wall', 'both']).optional(),
    areaSqM: z.coerce.number().positive().max(1_000_000).optional(),
    rooms: z.coerce.number().int().min(1).max(100).optional(),
    existingSurface: z.string().trim().max(500).optional(),
    tileType: z.string().trim().max(120).optional(),
    tileSize: z.string().trim().max(80).optional(),
    pattern: z.string().trim().max(120).optional(),
    finish: z.string().trim().max(120).optional(),
    surfacePreparation: z.string().trim().max(1000).optional(),
    preferredDate: z.string().trim().max(40).optional(),
    accessInstructions: z.string().trim().max(1000).optional(),
    notes: z.string().trim().max(1000).optional(),
    photos: photosSchema,
  })
  .strict();

// Map a category to its strict detail schema (falls back to the generic schema).
export function detailsSchemaForCategory(categoryId: string) {
  switch (categoryId) {
    case 'wifi_installation':
      return wifiDetailsSchema;
    case 'internet_installation':
      return internetDetailsSchema;
    case 'solar_installation':
      return solarDetailsSchema;
    case 'painting_decoration':
      return paintingDetailsSchema;
    case 'painting':
      return paintingDetailsSchema;
    case 'roofing':
      return roofingDetailsSchema;
    case 'flooring':
      return flooringDetailsSchema;
    case 'tiling':
      return tilingDetailsSchema;
    case 'plumbing_emergency':
    case 'plumbing_general':
      return plumbingDetailsSchema;
    case 'electrical_general':
    case 'electrical_wiring':
      return electricalDetailsSchema;
    case 'hvac_service':
      return hvacDetailsSchema;
    case 'appliance_repair':
      return applianceDetailsSchema;
    case 'carpentry':
      return carpentryDetailsSchema;
    case 'handyman':
      return handymanDetailsSchema;
    case 'clean_deep':
    case 'clean_home':
    case 'clean_office':
      return cleaningDetailsSchema;
    case 'pest_control_general':
      return pestControlDetailsSchema;
    case 'gardening':
    case 'landscaping_general':
      return landscapingDetailsSchema;
    default:
      if (categoryId.startsWith('garbage_')) return garbageDetailsSchema;
      if (categoryId.startsWith('laundry_')) return laundryDetailsSchema;
      return serviceRequestDetailsSchema;
  }
}

const anyDetailsSchema = z.union([
  wifiDetailsSchema,
  internetDetailsSchema,
  solarDetailsSchema,
  paintingDetailsSchema,
  garbageDetailsSchema,
  laundryDetailsSchema,
  plumbingDetailsSchema,
  electricalDetailsSchema,
  hvacDetailsSchema,
  carpentryDetailsSchema,
  applianceDetailsSchema,
  handymanDetailsSchema,
  cleaningDetailsSchema,
  pestControlDetailsSchema,
  landscapingDetailsSchema,
  roofingDetailsSchema,
  flooringDetailsSchema,
  tilingDetailsSchema,
  serviceRequestDetailsSchema,
]);

export const createServiceRequestSchema = z
  .object({
    categoryId: z.string().trim().min(1).max(80),
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().trim().min(10).max(5000),
    details: anyDetailsSchema.default({}),
    savedLocationId: uuid.optional().nullable(),
    serviceAddress: z.string().trim().max(500).optional().nullable(),
    serviceCounty: z.string().trim().max(120).optional().nullable(),
    serviceCity: z.string().trim().max(120).optional().nullable(),
    serviceLatitude: z.coerce.number().min(-90).max(90).optional().nullable(),
    serviceLongitude: z.coerce.number().min(-180).max(180).optional().nullable(),
    preferredDateTime: z.string().datetime().optional().nullable(),
    contactName: z.string().trim().max(200).optional().nullable(),
    contactPhone: z.string().trim().max(50).optional().nullable(),
    contactEmail: z.string().email().max(254).optional().nullable(),
  })
  .strict()
  .superRefine((value, ctx) => {
    // Enforce that details match the strict schema for the chosen category.
    const result = detailsSchemaForCategory(value.categoryId).safeParse(value.details);
    if (!result.success) {
      const message = result.error.issues
        .map((issue) => `${issue.path.join('.') || 'details'}: ${issue.message}`)
        .join(', ');
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['details'],
        message: `Invalid details for ${value.categoryId}: ${message}`,
      });
    }
  });

export const serviceRequestListQuerySchema = z.object({
  status: z
    .enum(['open', 'quoted', 'accepted', 'in_progress', 'completed', 'cancelled', 'expired'])
    .optional(),
  domain: z
    .enum([
      'moving', 'garbage', 'laundry', 'cleaning', 'plumbing', 'electrical', 'hvac',
      'pest_control', 'landscaping', 'carpentry', 'painting', 'roofing', 'flooring',
      'tiling', 'appliances', 'networking', 'solar', 'general',
    ])
    .optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const serviceRequestIdParamsSchema = z.object({ requestId: uuid });

export const cancelServiceRequestSchema = z
  .object({
    reason: z.string().trim().min(3).max(1000).optional(),
  })
  .strict();

// ---- Provider quotation ----
const quotationItemInputSchema = z
  .object({
    description: z.string().trim().min(1).max(200),
    quantity: z.coerce.number().positive().max(100000).default(1),
    unitPrice: z.coerce.number().min(0).max(100000000),
    amount: z.coerce.number().min(0).max(100000000),
  })
  .strict();

export const submitQuotationSchema = z
  .object({
    profileId: uuid,
    currency: z.string().trim().length(3).default('KES'),
    items: z.array(quotationItemInputSchema).min(1).max(50),
    subtotalAmount: z.coerce.number().min(0).max(100000000),
    totalAmount: z.coerce.number().min(0).max(100000000),
    estimatedStart: z.string().datetime().optional().nullable(),
    estimatedCompletion: z.string().datetime().optional().nullable(),
    validUntil: z.string().datetime(),
    terms: z.string().trim().min(5).max(5000).optional(),
    notes: z.string().trim().max(2000).optional().nullable(),
    expectedVersion: z.coerce.number().int().min(1).optional(),
  })
  .strict()
  .refine((v) => v.totalAmount >= v.subtotalAmount, {
    message: 'totalAmount must be greater than or equal to subtotalAmount',
    path: ['totalAmount'],
  });

export const quotationIdParamsSchema = z.object({ quotationId: uuid });

export const withdrawQuotationSchema = z
  .object({ reason: z.string().trim().max(1000).optional() })
  .strict();

export const acceptQuotationSchema = z
  .object({ expectedVersion: z.coerce.number().int().min(1).optional() })
  .strict();

export const providerInboxQuerySchema = z.object({
  domain: z
    .enum([
      'moving', 'garbage', 'laundry', 'cleaning', 'plumbing', 'electrical', 'hvac',
      'pest_control', 'landscaping', 'carpentry', 'painting', 'roofing', 'flooring',
      'tiling', 'appliances', 'networking', 'solar', 'general',
    ])
    .optional(),
  organizationId: uuid.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export type CreateServiceRequestInput = z.infer<typeof createServiceRequestSchema>;
export type ServiceRequestListQuery = z.infer<typeof serviceRequestListQuerySchema>;
export type SubmitQuotationInput = z.infer<typeof submitQuotationSchema>;
export type AcceptQuotationInput = z.infer<typeof acceptQuotationSchema>;