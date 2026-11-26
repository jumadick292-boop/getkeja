import { z } from 'zod';

const latitude = z.coerce.number().finite().min(-90).max(90);
const longitude = z.coerce.number().finite().min(-180).max(180);

export const sortEnum = z.enum([
  'relevance',
  'newest',
  'price_asc',
  'price_desc',
]);

const locationPreferenceSchema = z
  .object({
    county: z.string().trim().max(100).optional(),
    city: z.string().trim().max(100).optional(),
    neighbourhood: z.string().trim().max(120).optional(),
    latitude: latitude.optional(),
    longitude: longitude.optional(),
    radiusKm: z.coerce.number().finite().positive().max(100).optional(),
  })
  .strict();

// ---------------------------------------------------------------------------
// Discovery / search
// ---------------------------------------------------------------------------
export const searchQuerySchema = z
  .object({
    q: z.string().trim().max(120).optional(),
    city: z.string().trim().max(100).optional(),
    county: z.string().trim().max(100).optional(),
    neighbourhood: z.string().trim().max(120).optional(),
    propertyType: z.string().trim().max(50).optional(),
    rentMin: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    rentMax: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    bedrooms: z.coerce.number().int().min(0).max(20).optional(),
    bathrooms: z.coerce.number().int().min(0).max(20).optional(),
    furnished: z.enum(['true', 'false']).optional(),
    amenities: z.string().trim().max(300).optional(),
    sort: sortEnum.default('relevance'),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.rentMin !== undefined && value.rentMax !== undefined && value.rentMin > value.rentMax) {
      ctx.addIssue({ code: 'custom', path: ['rentMax'], message: 'rentMax must be >= rentMin' });
    }
  });

export type SearchQuery = z.infer<typeof searchQuerySchema>;

export const mapBoundsQuerySchema = z
  .object({
    north: latitude,
    south: latitude,
    east: longitude,
    west: longitude,
    q: z.string().trim().max(120).optional(),
    propertyType: z.string().trim().max(50).optional(),
    rentMin: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    rentMax: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    bedrooms: z.coerce.number().int().min(0).max(20).optional(),
    limit: z.coerce.number().int().min(1).max(200).default(100),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.north <= value.south) {
      ctx.addIssue({ code: 'custom', path: ['north'], message: 'north must be greater than south' });
    }
  });

export type MapBoundsQuery = z.infer<typeof mapBoundsQuerySchema>;

export const listingIdParamSchema = z.object({ listingId: z.string().uuid() });
export type ListingIdParam = z.infer<typeof listingIdParamSchema>;

export const relatedListingsQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(20).default(6),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

export type RelatedListingsQuery = z.infer<typeof relatedListingsQuerySchema>;

// ---------------------------------------------------------------------------
// Saved homes
// ---------------------------------------------------------------------------
export const saveListingSchema = z
  .object({
    listingId: z.string().uuid(),
    collection: z.string().trim().max(120).optional(),
    notes: z.string().trim().max(1000).optional(),
  })
  .strict();

export type SaveListing = z.infer<typeof saveListingSchema>;

export const savedListingsQuerySchema = z
  .object({
    collection: z.string().trim().max(120).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

// ---------------------------------------------------------------------------
// Saved searches
// ---------------------------------------------------------------------------
const searchCriteriaSchema = z
  .object({
    q: z.string().trim().max(120).optional(),
    city: z.string().trim().max(100).optional(),
    county: z.string().trim().max(100).optional(),
    neighbourhood: z.string().trim().max(120).optional(),
    propertyType: z.string().trim().max(50).optional(),
    rentMin: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    rentMax: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    bedrooms: z.coerce.number().int().min(0).max(20).optional(),
    bathrooms: z.coerce.number().int().min(0).max(20).optional(),
    furnished: z.enum(['true', 'false']).optional(),
    amenities: z.string().trim().max(300).optional(),
    sort: sortEnum.optional(),
  })
  .strict();

const alertFrequencySchema = z.enum(['immediate', 'daily', 'weekly']).default('immediate');

export type AlertFrequency = z.infer<typeof alertFrequencySchema>;

export const createSavedSearchSchema = z
  .object({
    name: z.string().trim().min(1).max(160),
    criteria: searchCriteriaSchema,
    alertsEnabled: z.boolean().default(true),
    alertFrequency: alertFrequencySchema,
  })
  .strict();

export type CreateSavedSearch = z.infer<typeof createSavedSearchSchema>;

export const updateSavedSearchSchema = z
  .object({
    name: z.string().trim().min(1).max(160).optional(),
    criteria: searchCriteriaSchema.optional(),
    alertsEnabled: z.boolean().optional(),
    alertFrequency: alertFrequencySchema.optional(),
  })
  .strict();

export type UpdateSavedSearch = z.infer<typeof updateSavedSearchSchema>;

export const savedSearchIdParamSchema = z.object({ searchId: z.string().uuid() });

export const runSavedSearchQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

export type RunSavedSearchQuery = z.infer<typeof runSavedSearchQuerySchema>;

// ---------------------------------------------------------------------------
// Property comparison
// ---------------------------------------------------------------------------

const MAX_COMPARISON_ITEMS = 4;

export const comparisonAddSchema = z
  .object({
    listingId: z.string().uuid(),
  })
  .strict();

export type ComparisonAdd = z.infer<typeof comparisonAddSchema>;

export const comparisonItemParamSchema = z.object({ listingId: z.string().uuid() });

export type ComparisonItemParam = z.infer<typeof comparisonItemParamSchema>;

export const comparisonQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

export type ComparisonQuery = z.infer<typeof comparisonQuerySchema>;

export { MAX_COMPARISON_ITEMS };

// ---------------------------------------------------------------------------
// Enquiries (house seeker side)
// ---------------------------------------------------------------------------
export const createSeekerEnquirySchema = z
  .object({
    propertyId: z.string().uuid(),
    listingId: z.string().uuid().optional(),
    unitId: z.string().uuid().optional(),
    message: z.string().trim().min(1).max(4000),
    phone: z.string().trim().max(50).optional(),
  })
  .strict();

export type CreateSeekerEnquiry = z.infer<typeof createSeekerEnquirySchema>;

export const enquiryIdParamSchema = z.object({ enquiryId: z.string().uuid() });

export const seekerEnquiryQuerySchema = z
  .object({
    status: z.string().trim().max(40).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

// ---------------------------------------------------------------------------
// Listing reports
// ---------------------------------------------------------------------------
export const listingReportReason = z.enum([
  'suspicious',
  'incorrect_info',
  'misleading_photos',
  'unavailable',
  'fraud',
  'inappropriate',
  'other',
]);

export const createListingReportSchema = z
  .object({
    listingId: z.string().uuid(),
    reason: listingReportReason,
    details: z.string().trim().max(4000).optional(),
    evidenceUrls: z.array(z.string().url()).max(10).default([]),
  })
  .strict();

export type CreateListingReport = z.infer<typeof createListingReportSchema>;

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------
export const updatePreferencesSchema = z
  .object({
    minBudget: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    maxBudget: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    preferredPropertyTypes: z.array(z.string().trim().max(50)).max(20).optional(),
    preferredBedrooms: z.coerce.number().int().min(0).max(20).optional(),
    preferredBathrooms: z.coerce.number().int().min(0).max(20).optional(),
    preferredAmenities: z.array(z.string().trim().max(50)).max(50).optional(),
    preferredLocations: z.array(locationPreferenceSchema).max(30).optional(),
    moveInDate: z.string().trim().max(10).optional(),
    alertsEnabled: z.boolean().optional(),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.minBudget !== undefined && value.maxBudget !== undefined && value.minBudget > value.maxBudget) {
      ctx.addIssue({ code: 'custom', path: ['maxBudget'], message: 'maxBudget must be >= minBudget' });
    }
  });

export type UpdatePreferences = z.infer<typeof updatePreferencesSchema>;

// ---------------------------------------------------------------------------
// Site visits (house seeker side)
// ---------------------------------------------------------------------------
export const createSeekerSiteVisitSchema = z
  .object({
    propertyId: z.string().uuid(),
    listingId: z.string().uuid().optional(),
    unitId: z.string().uuid().optional(),
    scheduledAt: z.string().datetime(),
    durationMinutes: z.coerce.number().int().min(15).max(240).default(30),
    visitorNotes: z.string().trim().max(2000).optional(),
    phone: z.string().trim().max(50).optional(),
  })
  .strict();

export type CreateSeekerSiteVisit = z.infer<typeof createSeekerSiteVisitSchema>;

export const siteVisitIdParamSchema = z.object({ visitId: z.string().uuid() });

export const rescheduleVisitSchema = z
  .object({
    scheduledAt: z.string().datetime(),
    durationMinutes: z.coerce.number().int().min(15).max(240).optional(),
  })
  .strict();

export const cancelVisitSchema = z
  .object({
    reason: z.string().trim().max(1000).optional(),
  })
  .strict();

export const propertyIdParamSchema = z.object({ propertyId: z.string().uuid() });

export const availabilityQuerySchema = z
  .object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD'),
  })
  .strict();

export type AvailabilityQuery = z.infer<typeof availabilityQuerySchema>;

export const seekerSiteVisitQuerySchema = z
  .object({
    status: z.enum(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show', 'rescheduled']).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

// ---------------------------------------------------------------------------
// Conversations & messages (house seeker side)
// ---------------------------------------------------------------------------
export const startConversationSchema = z
  .object({
    enquiryId: z.string().uuid().optional(),
    listingId: z.string().uuid().optional(),
    propertyId: z.string().uuid(),
    unitId: z.string().uuid().optional(),
    subject: z.string().trim().max(255).optional(),
    landlordUserId: z.string().uuid(),
    message: z.string().trim().min(1).max(4000),
  })
  .strict();

export type StartConversation = z.infer<typeof startConversationSchema>;

export const conversationIdParamSchema = z.object({ conversationId: z.string().uuid() });

export const seekerMessagesQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

export const sendMessageSchema = z
  .object({
    conversationId: z.string().uuid(),
    content: z.string().trim().min(1).max(4000),
  })
  .strict();

export type SendMessage = z.infer<typeof sendMessageSchema>;

// ---------------------------------------------------------------------------
// Rental applications (house seeker side)
// ---------------------------------------------------------------------------
export const createSeekerApplicationSchema = z
  .object({
    propertyId: z.string().uuid(),
    listingId: z.string().uuid().optional(),
    unitId: z.string().uuid().optional(),
    preferredStartDate: z.string().trim().max(10).optional(),
    preferredEndDate: z.string().trim().max(10).optional(),
    proposedRentAmount: z.coerce.number().finite().min(0).max(10_000_000).optional(),
    employerName: z.string().trim().max(255).optional(),
    employerContact: z.string().trim().max(255).optional(),
    monthlyIncome: z.coerce.number().finite().min(0).max(1_000_000_000).optional(),
    previousLandlordName: z.string().trim().max(255).optional(),
    previousLandlordContact: z.string().trim().max(255).optional(),
    guarantorName: z.string().trim().max(255).optional(),
    guarantorPhone: z.string().trim().max(50).optional(),
    guarantorRelationship: z.string().trim().max(50).optional(),
    documents: z.array(z.string().url()).max(20).optional(),
  })
  .strict();

export type CreateSeekerApplication = z.infer<typeof createSeekerApplicationSchema>;

export const applicationIdParamSchema = z.object({ applicationId: z.string().uuid() });

export const seekerApplicationQuerySchema = z
  .object({
    status: z.string().trim().max(40).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

// ---------------------------------------------------------------------------
// Rental proposals (house seeker responses)
// ---------------------------------------------------------------------------
export const proposalIdParamSchema = z.object({ proposalId: z.string().uuid() });

export const respondToProposalSchema = z
  .object({
    action: z.enum(['accept', 'decline', 'request_changes', 'counter']),
    version: z.coerce.number().int().positive().optional(),
    reason: z.string().trim().max(2000).optional(),
    counter: z
      .object({
        rentAmount: z.coerce.number().finite().min(0).max(10_000_000).optional(),
        depositAmount: z.coerce.number().finite().min(0).max(10_000_000).optional(),
        startDate: z.string().trim().max(10).optional(),
        endDate: z.string().trim().max(10).optional(),
      })
      .strict()
      .optional(),
  })
  .strict();

export type RespondToProposal = z.infer<typeof respondToProposalSchema>;

export const seekerProposalQuerySchema = z
  .object({
    status: z.string().trim().max(40).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .strict();

// ---------------------------------------------------------------------------
// Rental journey (dashboard)
// ---------------------------------------------------------------------------
export const seekerJourneyQuerySchema = z.object({}).strict();