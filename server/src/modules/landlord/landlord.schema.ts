import { z } from 'zod';

// Lenient UUID: accepts any canonical 8-4-4-4-12 hex string.
// The platform generates non-RFC variant nibbles, so uuid (RFC-strict) rejects valid IDs.
const uuid = z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, 'Invalid UUID');

const listingStatusSchema = z.enum(['draft', 'published', 'paused', 'withdrawn', 'archived']);
const unitTypeSchema = z.enum(['bedsitter', 'one_bedroom', 'two_bedroom', 'three_bedroom', 'four_plus_bedroom', 'commercial', 'parking', 'storage', 'other']);
const propertyTypeSchema = z.enum(['apartment', 'house', 'commercial', 'land', 'mixed_use', 'other']);
const visitStatusSchema = z.enum(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show', 'rescheduled']);
const tenantStatusSchema = z.enum(['active', 'inactive', 'archived', 'blacklisted']);
const garbageProviderStatusSchema = z.enum(['active', 'inactive', 'suspended', 'terminated']);
const assignmentTypeSchema = z.enum(['scheduled', 'on_demand']);
const collectionFrequencySchema = z.enum(['daily', 'weekly', 'biweekly', 'monthly', 'on_call']);
const collectionRequestStatusSchema = z.enum(['pending', 'assigned', 'in_progress', 'completed', 'cancelled']);
const collectionRequestTypeSchema = z.enum(['regular_collection', 'special_pickup', 'bulky_waste', 'recycling']);

// ============================================================================
// LISTING SCHEMAS
// ============================================================================

export const createListingSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  title: z.string().trim().min(1).max(255),
  description: z.string().max(5000).optional().nullable(),
  rentAmount: z.number().positive(),
  depositAmount: z.number().nonnegative().default(0),
  availableFrom: z.string().date().optional().nullable(),
  availableTo: z.string().date().optional().nullable(),
  furnished: z.boolean().default(false),
  petPolicy: z.enum(['allowed', 'not_allowed', 'negotiable']).optional().nullable(),
  smokingAllowed: z.boolean().default(false),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  floorPlanUrl: z.url().max(500).optional().nullable(),
  virtualTourUrl: z.url().max(500).optional().nullable(),
});

export const updateListingSchema = z.object({
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(5000).optional().nullable(),
  rentAmount: z.number().positive().optional(),
  depositAmount: z.number().nonnegative().optional(),
  availableFrom: z.string().date().optional().nullable(),
  availableTo: z.string().date().optional().nullable(),
  furnished: z.boolean().optional(),
  petPolicy: z.enum(['allowed', 'not_allowed', 'negotiable']).optional().nullable(),
  smokingAllowed: z.boolean().optional(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  floorPlanUrl: z.url().max(500).optional().nullable(),
  virtualTourUrl: z.url().max(500).optional().nullable(),
});

export const publishListingSchema = z.object({
  listingId: uuid.optional(),
});

export const pauseListingSchema = z.object({
  listingId: uuid.optional(),
});

export const resumeListingSchema = z.object({
  listingId: uuid.optional(),
});

export const withdrawListingSchema = z.object({
  listingId: uuid.optional(),
  reason: z.string().trim().min(1).max(1000).optional(),
});

export const archiveListingSchema = z.object({
  listingId: uuid.optional(),
});

export const listingQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  status: listingStatusSchema.optional(),
  propertyType: propertyTypeSchema.optional(),
  city: z.string().max(100).optional(),
  county: z.string().max(100).optional(),
  rentMin: z.coerce.number().nonnegative().optional(),
  rentMax: z.coerce.number().nonnegative().optional(),
  bedrooms: z.coerce.number().int().min(0).max(20).optional(),
  furnished: z.boolean().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// SITE VISIT MANAGEMENT SCHEMAS
// ============================================================================

export const confirmSiteVisitSchema = z.object({
  visitId: uuid.optional(),
  hostNotes: z.string().max(2000).optional().nullable(),
});

export const declineSiteVisitSchema = z.object({
  visitId: uuid.optional(),
  reason: z.string().trim().min(1).max(1000),
});

export const rescheduleSiteVisitSchema = z.object({
  visitId: uuid.optional(),
  scheduledAt: z.string().datetime(),
  durationMinutes: z.coerce.number().int().min(15).max(480).optional(),
  reason: z.string().trim().min(1).max(1000).optional(),
});

export const cancelSiteVisitSchema = z.object({
  visitId: uuid.optional(),
  reason: z.string().trim().min(1).max(1000).optional(),
});

export const completeSiteVisitSchema = z.object({
  visitId: uuid.optional(),
  outcome: z.string().trim().max(50).optional().nullable(),
  hostNotes: z.string().max(2000).optional().nullable(),
});

export const markNoShowSchema = z.object({
  visitId: uuid.optional(),
  reason: z.string().trim().min(1).max(1000).optional(),
});

export const siteVisitListQuerySchema = z
  .object({
    status: z.string().trim().max(40).optional(),
    propertyId: z.string().uuid().optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

export const siteVisitIdParamSchema = z.object({ visitId: z.string().uuid() });

export const propertyIdParamSchema = z.object({ propertyId: uuid });

const dayOfWeekSchema = z.enum([
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
]);

const timeSchema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'time must be HH:MM');

export const upsertAvailabilityRuleSchema = z
  .object({
    dayOfWeek: dayOfWeekSchema,
    startTime: timeSchema,
    endTime: timeSchema,
    slotDurationMinutes: z.coerce.number().int().min(15).max(240).default(30),
    bufferMinutes: z.coerce.number().int().min(0).max(120).default(0),
    maxBookingsPerSlot: z.coerce.number().int().min(1).max(50).default(1),
    isActive: z.boolean().default(true),
  })
  .strict()
  .refine((value) => value.startTime < value.endTime, {
    message: 'startTime must be before endTime',
    path: ['endTime'],
  });

export const availabilityRuleIdParamSchema = z.object({ propertyId: uuid, ruleId: uuid });

export const availabilityExceptionIdParamSchema = z.object({ propertyId: uuid, exceptionId: uuid });

export const upsertAvailabilityExceptionSchema = z
  .object({
    exceptionDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'exceptionDate must be YYYY-MM-DD'),
    reason: z.string().trim().max(1000).optional().nullable(),
    isUnavailable: z.boolean().default(true),
    startTime: timeSchema.optional().nullable(),
    endTime: timeSchema.optional().nullable(),
  })
  .strict();

export const availabilityQuerySchema = z
  .object({
    propertyId: uuid.optional(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD').optional(),
  })
  .strict();

// ============================================================================
// TENANT SCHEMAS
// ============================================================================

export const createTenantSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  userId: uuid.optional().nullable(),
  fullName: z.string().trim().min(1).max(255),
  email: z.email().trim().toLowerCase().optional().nullable(),
  phone: z.string().trim().min(1).max(50),
  idNumber: z.string().max(50).optional().nullable(),
  idType: z.enum(['national_id', 'passport', 'alien_id']).optional().nullable(),
  emergencyContactName: z.string().trim().max(255).optional().nullable(),
  emergencyContactPhone: z.string().max(50).optional().nullable(),
  employerName: z.string().max(255).optional().nullable(),
  employerContact: z.string().max(255).optional().nullable(),
  monthlyIncome: z.number().positive().optional().nullable(),
  previousLandlordName: z.string().max(255).optional().nullable(),
  previousLandlordContact: z.string().max(255).optional().nullable(),
  moveInDate: z.string().date().optional().nullable(),
  moveOutDate: z.string().date().optional().nullable(),
  status: tenantStatusSchema.default('active'),
  notes: z.string().max(5000).optional().nullable(),
});

export const updateTenantSchema = z.object({
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  fullName: z.string().trim().min(1).max(255).optional(),
  email: z.email().trim().toLowerCase().optional().nullable(),
  phone: z.string().trim().min(1).max(50).optional(),
  idNumber: z.string().max(50).optional().nullable(),
  idType: z.enum(['national_id', 'passport', 'alien_id']).optional().nullable(),
  emergencyContactName: z.string().trim().max(255).optional().nullable(),
  emergencyContactPhone: z.string().max(50).optional().nullable(),
  employerName: z.string().max(255).optional().nullable(),
  employerContact: z.string().max(255).optional().nullable(),
  monthlyIncome: z.number().positive().optional().nullable(),
  previousLandlordName: z.string().max(255).optional().nullable(),
  previousLandlordContact: z.string().max(255).optional().nullable(),
  moveInDate: z.string().date().optional().nullable(),
  moveOutDate: z.string().date().optional().nullable(),
  status: tenantStatusSchema.optional(),
  notes: z.string().max(5000).optional().nullable(),
});

export const tenantQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  tenancyId: uuid.optional(),
  status: tenantStatusSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// GARBAGE PROVIDER SCHEMAS
// ============================================================================

export const createGarbageProviderSchema = z.object({
  organisationId: uuid.optional().nullable(),
  name: z.string().trim().min(1).max(255),
  contactPerson: z.string().trim().max(255).optional().nullable(),
  contactPhone: z.string().trim().min(1).max(50),
  contactEmail: z.email().trim().toLowerCase().optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  serviceAreas: z.array(z.record(z.string(), z.unknown())).default([]),
  status: garbageProviderStatusSchema.default('active'),
  rating: z.number().min(0).max(5).optional().nullable(),
});

export const updateGarbageProviderSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  contactPerson: z.string().trim().max(255).optional().nullable(),
  contactPhone: z.string().trim().min(1).max(50).optional(),
  contactEmail: z.email().trim().toLowerCase().optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  serviceAreas: z.array(z.record(z.string(), z.unknown())).optional(),
  status: garbageProviderStatusSchema.optional(),
  rating: z.number().min(0).max(5).optional().nullable(),
});

export const garbageProviderQuerySchema = z.object({
  status: garbageProviderStatusSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// GARBAGE ASSIGNMENT SCHEMAS
// ============================================================================

export const createGarbageAssignmentSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  garbageProviderId: uuid,
  assignmentType: assignmentTypeSchema.default('scheduled'),
  frequency: collectionFrequencySchema.default('weekly'),
  dayOfWeek: z.coerce.number().int().min(0).max(6).optional().nullable(),
  timeSlot: z.string().max(50).optional().nullable(),
  effectiveFrom: z.string().date(),
  effectiveTo: z.string().date().optional().nullable(),
  notes: z.string().max(2000).optional().nullable(),
});

export const updateGarbageAssignmentSchema = z.object({
  unitId: uuid.optional().nullable(),
  garbageProviderId: uuid.optional(),
  assignmentType: assignmentTypeSchema.optional(),
  frequency: collectionFrequencySchema.optional(),
  dayOfWeek: z.coerce.number().int().min(0).max(6).optional().nullable(),
  timeSlot: z.string().max(50).optional().nullable(),
  status: garbageProviderStatusSchema.optional(),
  effectiveFrom: z.string().date().optional(),
  effectiveTo: z.string().date().optional().nullable(),
  notes: z.string().max(2000).optional().nullable(),
});

export const garbageAssignmentQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  garbageProviderId: uuid.optional(),
  status: garbageProviderStatusSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// GARBAGE COLLECTION REQUEST SCHEMAS
// ============================================================================

export const createGarbageCollectionRequestSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  garbageProviderId: uuid.optional().nullable(),
  requestType: collectionRequestTypeSchema.default('regular_collection'),
  scheduledAt: z.string().datetime().optional().nullable(),
  notes: z.string().max(2000).optional().nullable(),
});

export const updateGarbageCollectionRequestSchema = z.object({
  garbageProviderId: uuid.optional().nullable(),
  requestType: collectionRequestTypeSchema.optional(),
  status: collectionRequestStatusSchema.optional(),
  scheduledAt: z.string().datetime().optional().nullable(),
  completedAt: z.string().datetime().optional().nullable(),
  notes: z.string().max(2000).optional().nullable(),
});

export const garbageCollectionRequestQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  garbageProviderId: uuid.optional(),
  status: collectionRequestStatusSchema.optional(),
  requestType: collectionRequestTypeSchema.optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// DASHBOARD SCHEMAS
// ============================================================================

export const dashboardQuerySchema = z.object({
  propertyId: uuid.optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
});

// ============================================================================
// TYPE EXPORTS
// ============================================================================

export type CreateListingInput = z.infer<typeof createListingSchema>;
export type UpdateListingInput = z.infer<typeof updateListingSchema>;
export type PublishListingInput = z.infer<typeof publishListingSchema>;
export type PauseListingInput = z.infer<typeof pauseListingSchema>;
export type ResumeListingInput = z.infer<typeof resumeListingSchema>;
export type WithdrawListingInput = z.infer<typeof withdrawListingSchema>;
export type ArchiveListingInput = z.infer<typeof archiveListingSchema>;
export type ListingQueryInput = z.infer<typeof listingQuerySchema>;

export type ConfirmSiteVisitInput = z.infer<typeof confirmSiteVisitSchema>;
export type DeclineSiteVisitInput = z.infer<typeof declineSiteVisitSchema>;
export type RescheduleSiteVisitInput = z.infer<typeof rescheduleSiteVisitSchema>;
export type CancelSiteVisitInput = z.infer<typeof cancelSiteVisitSchema>;
export type CompleteSiteVisitInput = z.infer<typeof completeSiteVisitSchema>;
export type MarkNoShowInput = z.infer<typeof markNoShowSchema>;

export type CreateTenantInput = z.infer<typeof createTenantSchema>;
export type UpdateTenantInput = z.infer<typeof updateTenantSchema>;
export type TenantQueryInput = z.infer<typeof tenantQuerySchema>;

export type CreateGarbageProviderInput = z.infer<typeof createGarbageProviderSchema>;
export type UpdateGarbageProviderInput = z.infer<typeof updateGarbageProviderSchema>;
export type GarbageProviderQueryInput = z.infer<typeof garbageProviderQuerySchema>;

export type CreateGarbageAssignmentInput = z.infer<typeof createGarbageAssignmentSchema>;
export type UpdateGarbageAssignmentInput = z.infer<typeof updateGarbageAssignmentSchema>;
export type GarbageAssignmentQueryInput = z.infer<typeof garbageAssignmentQuerySchema>;

export type CreateGarbageCollectionRequestInput = z.infer<typeof createGarbageCollectionRequestSchema>;
export type UpdateGarbageCollectionRequestInput = z.infer<typeof updateGarbageCollectionRequestSchema>;
export type GarbageCollectionRequestQueryInput = z.infer<typeof garbageCollectionRequestQuerySchema>;

export type DashboardQueryInput = z.infer<typeof dashboardQuerySchema>;

// ============================================================================
// PROPERTY SCHEMAS
// ============================================================================

const propertyStatusSchema = z.enum(['draft', 'published', 'archived', 'rented', 'under_maintenance']);
const propertyTypeSchemaExt = z.enum(['apartment', 'house', 'commercial', 'land', 'mixed_use', 'other']);
const ownershipTypeSchema = z.enum(['individual', 'corporate', 'joint', 'trust']);
const ownershipStatusSchema = z.enum(['active', 'transferred', 'disputed', 'terminated']);
const assignmentTypeSchemaExt = z.enum(['property_manager', 'caretaker', 'letting_agent', 'maintenance', 'security', 'other']);
const assignmentStatusSchema = z.enum(['active', 'suspended', 'revoked', 'expired']);

export const createPropertySchema = z.object({
  title: z.string().trim().min(1).max(255),
  description: z.string().max(5000).optional().nullable(),
  propertyType: propertyTypeSchemaExt,
  address: z.string().trim().min(1).max(500),
  city: z.string().trim().min(1).max(100),
  county: z.string().trim().min(1).max(100),
  country: z.string().length(2).default('KE'),
  latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
  longitude: z.coerce.number().min(-180).max(180).optional().nullable(),
  totalUnits: z.coerce.number().int().min(0).default(0),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  status: propertyStatusSchema.default('draft'),
});

export const updatePropertySchema = z.object({
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(5000).optional().nullable(),
  propertyType: propertyTypeSchemaExt.optional(),
  address: z.string().trim().min(1).max(500).optional(),
  city: z.string().trim().min(1).max(100).optional(),
  county: z.string().trim().min(1).max(100).optional(),
  country: z.string().length(2).optional(),
  latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
  longitude: z.coerce.number().min(-180).max(180).optional().nullable(),
  totalUnits: z.coerce.number().int().min(0).optional(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  status: propertyStatusSchema.optional(),
});

export const propertyQuerySchema = z.object({
  status: propertyStatusSchema.optional(),
  propertyType: propertyTypeSchemaExt.optional(),
  city: z.string().max(100).optional(),
  county: z.string().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// UNIT SCHEMAS
// ============================================================================

const unitStatusSchema = z.enum(['draft', 'available', 'reserved', 'occupied', 'under_maintenance', 'temporarily_unavailable', 'archived']);

export const createUnitSchema = z.object({
  propertyId: uuid,
  unitNumber: z.string().trim().min(1).max(50),
  building: z.string().trim().max(100).optional().nullable(),
  floor: z.coerce.number().int().min(0).optional().nullable(),
  unitType: z.enum(['bedsitter', 'one_bedroom', 'two_bedroom', 'three_bedroom', 'four_plus_bedroom', 'commercial', 'parking', 'storage', 'other']),
  bedrooms: z.coerce.number().int().min(0).max(20).optional().nullable(),
  bathrooms: z.coerce.number().int().min(0).max(20).optional().nullable(),
  areaSqm: z.coerce.number().positive().optional().nullable(),
  rentAmount: z.coerce.number().positive().optional().nullable(),
  depositAmount: z.coerce.number().nonnegative().default(0),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  description: z.string().max(5000).optional().nullable(),
  status: unitStatusSchema.default('draft'),
  hasSeparateMeter: z.boolean().default(false),
  meterNumber: z.string().trim().max(100).optional().nullable(),
});

export const updateUnitSchema = z.object({
  unitNumber: z.string().trim().min(1).max(50).optional(),
  building: z.string().trim().max(100).optional().nullable(),
  floor: z.coerce.number().int().min(0).optional().nullable(),
  unitType: z.enum(['bedsitter', 'one_bedroom', 'two_bedroom', 'three_bedroom', 'four_plus_bedroom', 'commercial', 'parking', 'storage', 'other']).optional(),
  bedrooms: z.coerce.number().int().min(0).max(20).optional().nullable(),
  bathrooms: z.coerce.number().int().min(0).max(20).optional().nullable(),
  areaSqm: z.coerce.number().positive().optional().nullable(),
  rentAmount: z.coerce.number().positive().optional().nullable(),
  depositAmount: z.coerce.number().nonnegative().optional(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  description: z.string().max(5000).optional().nullable(),
  status: unitStatusSchema.optional(),
  hasSeparateMeter: z.boolean().optional(),
  meterNumber: z.string().trim().max(100).optional().nullable(),
});

export const unitQuerySchema = z.object({
  propertyId: uuid.optional(),
  status: unitStatusSchema.optional(),
  unitType: z.enum(['bedsitter', 'one_bedroom', 'two_bedroom', 'three_bedroom', 'four_plus_bedroom', 'commercial', 'parking', 'storage', 'other']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// PROPERTY DOCUMENT SCHEMAS
// ============================================================================

const documentVisibilitySchema = z.enum(['private', 'shared', 'public']);

export const createPropertyDocumentSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  category: z.string().trim().min(1).max(100),
  title: z.string().trim().min(1).max(255),
  description: z.string().max(1000).optional().nullable(),
  fileName: z.string().trim().min(1).max(255),
  filePath: z.string().trim().min(1).max(500),
  fileSizeBytes: z.coerce.number().nonnegative().optional(),
  mimeType: z.string().trim().max(100).optional().nullable(),
  visibility: documentVisibilitySchema.default('private'),
});

export const updatePropertyDocumentSchema = z.object({
  category: z.string().trim().min(1).max(100).optional(),
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(1000).optional().nullable(),
  visibility: documentVisibilitySchema.optional(),
});

// ============================================================================
// ENQUIRY SCHEMAS
// ============================================================================

const enquiryStatusSchemaExt = z.enum(['new', 'contacted', 'interested', 'site_visit_requested', 'site_visit_scheduled', 'site_visit_completed', 'rental_terms_discussed', 'offer_sent', 'offer_accepted', 'rental_arrangement_confirmed', 'onboarding_initiated', 'converted_to_tenant', 'lost_declined', 'closed']);
const enquirySourceSchema = z.enum(['public_listing', 'property_detail', 'site_visit_request', 'agency_representative', 'walk_in', 'referral', 'other']);

export const createEnquirySchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  listingId: uuid.optional().nullable(),
  prospectiveRenterName: z.string().trim().min(1).max(255),
  prospectiveRenterEmail: z.email().trim().toLowerCase().optional().nullable(),
  prospectiveRenterPhone: z.string().trim().min(1).max(50),
  enquirySource: enquirySourceSchema.default('other'),
  message: z.string().max(5000).optional().nullable(),
  assignedToUserId: uuid.optional().nullable(),
  followUpDate: z.string().datetime().optional().nullable(),
  internalNotes: z.string().max(5000).optional().nullable(),
});

export const updateEnquirySchema = z.object({
  unitId: uuid.optional().nullable(),
  listingId: uuid.optional().nullable(),
  prospectiveRenterName: z.string().trim().min(1).max(255).optional(),
  prospectiveRenterEmail: z.email().trim().toLowerCase().optional().nullable(),
  prospectiveRenterPhone: z.string().trim().min(1).max(50).optional(),
  enquirySource: enquirySourceSchema.optional(),
  message: z.string().max(5000).optional().nullable(),
  status: enquiryStatusSchemaExt.optional(),
  assignedToUserId: uuid.optional().nullable(),
  followUpDate: z.string().datetime().optional().nullable(),
  internalNotes: z.string().max(5000).optional().nullable(),
});

export const enquiryQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  listingId: uuid.optional(),
  status: enquiryStatusSchemaExt.optional(),
  source: enquirySourceSchema.optional(),
  assignedToUserId: uuid.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const enquiryNoteSchema = z.object({
  note: z.string().trim().min(1).max(5000),
  isInternal: z.boolean().default(true),
});

// ============================================================================
// CONVERSATION SCHEMAS
// ============================================================================

const conversationTypeSchema = z.enum(['enquiry', 'site_visit', 'rental_proposal', 'tenancy', 'maintenance', 'garbage_service', 'general']);
const messageTypeSchema = z.enum(['text', 'system', 'notification']);

export const createConversationSchema = z.object({
  type: conversationTypeSchema.default('general'),
  subject: z.string().trim().max(255).optional().nullable(),
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  enquiryId: uuid.optional().nullable(),
  participantUserIds: z.array(uuid).min(1).max(20),
});

export const sendMessageSchema = z.object({
  conversationId: uuid,
  content: z.string().trim().min(1).max(10000),
  type: messageTypeSchema.default('text'),
  replyToId: uuid.optional().nullable(),
});

export const conversationQuerySchema = z.object({
  type: conversationTypeSchema.optional(),
  propertyId: uuid.optional(),
  enquiryId: uuid.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// RENTAL PROPOSAL SCHEMAS
// ============================================================================

const rentalProposalStatusSchema = z.enum(['draft', 'sent', 'under_review', 'changes_requested', 'accepted', 'declined', 'expired', 'withdrawn', 'confirmed']);
const rentalProposalTypeSchema = z.enum(['new_tenancy', 'renewal', 'rent_increase', 'terms_change']);

export const createRentalProposalSchema = z.object({
  enquiryId: uuid.optional().nullable(),
  rentalApplicationId: uuid.optional().nullable(),
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  prospectiveRenterId: uuid,
  type: rentalProposalTypeSchema.default('new_tenancy'),
  proposedRentAmount: z.coerce.number().positive(),
  proposedDepositAmount: z.coerce.number().nonnegative().default(0),
  proposedStartDate: z.string().date(),
  proposedEndDate: z.string().date().optional().nullable(),
  proposedRentDueDay: z.coerce.number().int().min(1).max(31).default(1),
  specialConditions: z.string().max(5000).optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
  expiresAt: z.string().datetime(),
});

export const updateRentalProposalSchema = z.object({
  proposedRentAmount: z.coerce.number().positive().optional(),
  proposedDepositAmount: z.coerce.number().nonnegative().optional(),
  proposedStartDate: z.string().date().optional(),
  proposedEndDate: z.string().date().optional().nullable(),
  proposedRentDueDay: z.coerce.number().int().min(1).max(31).optional(),
  specialConditions: z.string().max(5000).optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
  expiresAt: z.string().datetime().optional(),
});

export const rentalProposalActionSchema = z.object({
  action: z.enum(['send', 'request_changes', 'accept', 'decline', 'withdraw', 'confirm']),
  reason: z.string().trim().max(1000).optional().nullable(),
});

export const rentalProposalQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  prospectiveRenterId: uuid.optional(),
  status: rentalProposalStatusSchema.optional(),
  type: rentalProposalTypeSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// FINANCIAL SCHEMAS
// ============================================================================

const invoiceStatusSchema = z.enum(['draft', 'issued', 'sent', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded', 'void']);
const chargeTypeSchema = z.enum(['rent', 'deposit', 'service_charge', 'garbage_charge', 'utility_charge', 'maintenance_charge', 'late_fee', 'other']);
const paymentTransactionStatusSchema = z.enum(['pending', 'processing', 'completed', 'failed', 'reversed', 'refunded']);
const paymentProviderSchema = z.enum(['mpesa', 'bank_transfer', 'cash', 'cheque', 'manual', 'other']);
const depositStatusSchema = z.enum(['expected', 'partially_received', 'received', 'refunded', 'partially_refunded', 'forfeited', 'transferred']);
const expenseCategoryTypeSchema = z.enum(['maintenance', 'repair', 'garbage_service', 'utilities', 'insurance', 'property_tax', 'management_fee', 'marketing', 'legal', 'other']);

export const createInvoiceSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  tenantId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  billingPeriodStart: z.string().date(),
  billingPeriodEnd: z.string().date(),
  dueDate: z.string().date(),
  subtotal: z.coerce.number().nonnegative().optional(),
  taxAmount: z.coerce.number().nonnegative().optional(),
  totalAmount: z.coerce.number().nonnegative(),
  notes: z.string().max(5000).optional().nullable(),
});

export const createInvoiceItemSchema = z.object({
  invoiceId: uuid,
  chargeType: chargeTypeSchema,
  description: z.string().trim().min(1).max(255),
  amount: z.coerce.number().positive(),
  billingPeriodStart: z.string().date().optional().nullable(),
  billingPeriodEnd: z.string().date().optional().nullable(),
  quantity: z.coerce.number().int().min(1).default(1),
  unitPrice: z.coerce.number().positive().optional().nullable(),
});

export const recordPaymentSchema = z.object({
  invoiceId: uuid.optional().nullable(),
  tenantId: uuid.optional().nullable(),
  amount: z.coerce.number().positive(),
  provider: paymentProviderSchema,
  transactionReference: z.string().trim().max(100).optional(),
  providerTransactionId: z.string().trim().max(255).optional().nullable(),
  status: z.enum(['pending', 'processing', 'completed', 'failed', 'reversed', 'refunded']).default('completed'),
  paymentDate: z.string().datetime().optional().nullable(),
  callbackPayload: z.record(z.string(), z.unknown()).optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
  idempotencyKey: z.string().trim().max(255).optional(),
});

export const invoiceQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  tenantId: uuid.optional(),
  tenancyId: uuid.optional(),
  status: invoiceStatusSchema.optional(),
  fromDate: z.string().date().optional(),
  toDate: z.string().date().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const recordExpenseSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  category: expenseCategoryTypeSchema,
  description: z.string().trim().min(1).max(255),
  amount: z.coerce.number().positive(),
  expenseDate: z.string().date(),
  receiptDocumentUrl: z.string().max(500).optional().nullable(),
  vendorName: z.string().trim().max(255).optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
});

export const recordDepositSchema = z.object({
  tenantId: uuid,
  tenancyId: uuid.optional().nullable(),
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  expectedAmount: z.coerce.number().positive(),
  receivedAmount: z.coerce.number().nonnegative().default(0),
  depositSchemeReference: z.string().trim().max(255).optional().nullable(),
  heldBy: z.string().trim().max(50).optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
});

// ============================================================================
// MAINTENANCE SCHEMAS
// ============================================================================

const issueCategorySchema = z.enum(['plumbing', 'electrical', 'water_supply', 'security', 'structural', 'cleaning', 'fixtures', 'pest_control', 'hvac', 'appliances', 'other']);
const issuePrioritySchema = z.enum(['low', 'medium', 'high', 'urgent', 'emergency']);
const maintenanceTypeSchema = z.enum(['repair', 'inspection', 'preventive', 'emergency', 'renovation', 'cleaning', 'other']);

export const reportIssueSchema = z.object({
  propertyId: uuid,
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  reporterRole: z.enum(['landlord', 'manager', 'caretaker', 'tenant', 'agent']),
  title: z.string().trim().min(1).max(255),
  description: z.string().trim().min(1).max(5000),
  category: issueCategorySchema,
  priority: issuePrioritySchema.default('medium'),
  assignedToUserId: uuid.optional().nullable(),
});

export const updateIssueSchema = z.object({
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().trim().min(1).max(5000).optional(),
  category: issueCategorySchema.optional(),
  priority: issuePrioritySchema.optional(),
  status: z.enum(['new', 'acknowledged', 'under_assessment', 'awaiting_approval', 'approved', 'assigned', 'in_progress', 'awaiting_parts_access', 'resolved', 'closed', 'rejected', 'cancelled']).optional(),
  assignedToUserId: uuid.optional().nullable(),
  estimatedCost: z.coerce.number().nonnegative().optional().nullable(),
  actualCost: z.coerce.number().nonnegative().optional().nullable(),
  resolutionNotes: z.string().max(5000).optional().nullable(),
});

export const createMaintenanceRequestSchema = z.object({
  issueId: uuid,
  maintenanceType: maintenanceTypeSchema,
  description: z.string().trim().min(1).max(5000),
  assignedToUserId: uuid.optional().nullable(),
  estimatedCost: z.coerce.number().nonnegative().optional().nullable(),
  scheduledDate: z.string().date().optional().nullable(),
});

export const updateMaintenanceRequestSchema = z.object({
  maintenanceType: maintenanceTypeSchema.optional(),
  description: z.string().trim().min(1).max(5000).optional(),
  assignedToUserId: uuid.optional().nullable(),
  estimatedCost: z.coerce.number().nonnegative().optional().nullable(),
  approvedCost: z.coerce.number().nonnegative().optional().nullable(),
  actualCost: z.coerce.number().nonnegative().optional().nullable(),
  scheduledDate: z.string().date().optional().nullable(),
});

export const issueQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  tenancyId: uuid.optional(),
  category: issueCategorySchema.optional(),
  priority: issuePrioritySchema.optional(),
  status: z.enum(['new', 'acknowledged', 'under_assessment', 'awaiting_approval', 'approved', 'assigned', 'in_progress', 'awaiting_parts_access', 'resolved', 'closed', 'rejected', 'cancelled']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// ============================================================================
// LEASE / RENTAL AGREEMENT SCHEMAS
// ============================================================================

const rentalAgreementStatusSchema = z.enum(['draft', 'pending_signature', 'active', 'renewed', 'terminated', 'expired', 'archived']);
const leaseDocumentTypeSchema = z.enum(['tenancy_agreement', 'lease_renewal', 'termination_notice', 'rent_receipt', 'inspection_report', 'maintenance_report', 'notice', 'correspondence', 'other']);

export const createRentalAgreementSchema = z.object({
  tenancyId: uuid,
  agreementNumber: z.string().trim().min(1).max(100),
  startDate: z.string().date(),
  endDate: z.string().date().optional().nullable(),
  monthlyRent: z.coerce.number().positive(),
  depositAmount: z.coerce.number().nonnegative().default(0),
  rentDueDay: z.coerce.number().int().min(1).max(31).default(1),
  paymentMethod: z.string().trim().max(50).optional().nullable(),
  specialConditions: z.string().max(5000).optional().nullable(),
});

export const updateRentalAgreementSchema = z.object({
  endDate: z.string().date().optional().nullable(),
  monthlyRent: z.coerce.number().positive().optional(),
  depositAmount: z.coerce.number().nonnegative().optional(),
  rentDueDay: z.coerce.number().int().min(1).max(31).optional(),
  paymentMethod: z.string().trim().max(50).optional().nullable(),
  specialConditions: z.string().max(5000).optional().nullable(),
  status: rentalAgreementStatusSchema.optional(),
});

export const uploadLeaseDocumentSchema = z.object({
  rentalAgreementId: uuid.optional().nullable(),
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  type: leaseDocumentTypeSchema,
  title: z.string().trim().min(1).max(255),
  description: z.string().max(1000).optional().nullable(),
  fileName: z.string().trim().min(1).max(255),
  filePath: z.string().trim().min(1).max(500),
  isPrivate: z.boolean().default(true),
});

// ============================================================================
// INSPECTION SCHEMAS
// ============================================================================

export const createMoveInInspectionSchema = z.object({
  tenancyId: uuid,
  unitId: uuid,
  inspectionDate: z.string().date(),
  overallCondition: z.enum(['excellent', 'good', 'fair', 'poor']).optional().nullable(),
  meterReadings: z.record(z.string(), z.unknown()).optional().nullable(),
  keyHandover: z.boolean().default(false),
  notes: z.string().max(5000).optional().nullable(),
});

export const createMoveOutInspectionSchema = z.object({
  tenancyId: uuid,
  unitId: uuid,
  inspectionDate: z.string().date(),
  overallCondition: z.enum(['excellent', 'good', 'fair', 'poor']).optional().nullable(),
  meterReadings: z.record(z.string(), z.unknown()).optional().nullable(),
  keyReturned: z.boolean().default(false),
  damageNotes: z.string().max(5000).optional().nullable(),
  cleaningRequired: z.boolean().default(false),
  cleaningCost: z.coerce.number().nonnegative().optional().nullable(),
  repairCost: z.coerce.number().nonnegative().optional().nullable(),
  notes: z.string().max(5000).optional().nullable(),
});

export const createInspectionItemSchema = z.object({
  inspectionId: uuid,
  itemCategory: z.string().trim().min(1).max(100),
  itemName: z.string().trim().min(1).max(255),
  conditionRating: z.enum(['excellent', 'good', 'fair', 'poor', 'damaged', 'missing']),
  notes: z.string().max(1000).optional().nullable(),
  photoUrl: z.string().max(500).optional().nullable(),
});

// ============================================================================
// TYPE EXPORTS (NEW)
// ============================================================================

export type CreatePropertyInput = z.infer<typeof createPropertySchema>;
export type UpdatePropertyInput = z.infer<typeof updatePropertySchema>;
export type PropertyQueryInput = z.infer<typeof propertyQuerySchema>;

export type CreateUnitInput = z.infer<typeof createUnitSchema>;
export type UpdateUnitInput = z.infer<typeof updateUnitSchema>;
export type UnitQueryInput = z.infer<typeof unitQuerySchema>;

export type CreatePropertyDocumentInput = z.infer<typeof createPropertyDocumentSchema>;
export type UpdatePropertyDocumentInput = z.infer<typeof updatePropertyDocumentSchema>;

export type CreateEnquiryInput = z.infer<typeof createEnquirySchema>;
export type UpdateEnquiryInput = z.infer<typeof updateEnquirySchema>;
export type EnquiryQueryInput = z.infer<typeof enquiryQuerySchema>;
export type EnquiryNoteInput = z.infer<typeof enquiryNoteSchema>;

export type CreateConversationInput = z.infer<typeof createConversationSchema>;
export type SendMessageInput = z.infer<typeof sendMessageSchema>;
export type ConversationQueryInput = z.infer<typeof conversationQuerySchema>;

export type CreateRentalProposalInput = z.infer<typeof createRentalProposalSchema>;
export type UpdateRentalProposalInput = z.infer<typeof updateRentalProposalSchema>;
export type RentalProposalActionInput = z.infer<typeof rentalProposalActionSchema>;
export type RentalProposalQueryInput = z.infer<typeof rentalProposalQuerySchema>;

export type CreateInvoiceInput = z.infer<typeof createInvoiceSchema>;
export type CreateInvoiceItemInput = z.infer<typeof createInvoiceItemSchema>;
export type RecordPaymentInput = z.infer<typeof recordPaymentSchema>;
export type InvoiceQueryInput = z.infer<typeof invoiceQuerySchema>;
export type RecordExpenseInput = z.infer<typeof recordExpenseSchema>;
export type RecordDepositInput = z.infer<typeof recordDepositSchema>;

export type ReportIssueInput = z.infer<typeof reportIssueSchema>;
export type UpdateIssueInput = z.infer<typeof updateIssueSchema>;
export type CreateMaintenanceRequestInput = z.infer<typeof createMaintenanceRequestSchema>;
export type UpdateMaintenanceRequestInput = z.infer<typeof updateMaintenanceRequestSchema>;
export type IssueQueryInput = z.infer<typeof issueQuerySchema>;

export type CreateRentalAgreementInput = z.infer<typeof createRentalAgreementSchema>;
export type UpdateRentalAgreementInput = z.infer<typeof updateRentalAgreementSchema>;
export type UploadLeaseDocumentInput = z.infer<typeof uploadLeaseDocumentSchema>;

export type CreateMoveInInspectionInput = z.infer<typeof createMoveInInspectionSchema>;
export type CreateMoveOutInspectionInput = z.infer<typeof createMoveOutInspectionSchema>;
export type CreateInspectionItemInput = z.infer<typeof createInspectionItemSchema>;
