// Service Requests validation schemas — unified tenant-facing and provider-facing APIs.
import { z } from 'zod';

const uuid = z.string().uuid();

// Base service request types
export const serviceRequestTypeSchema = z.enum(['moving', 'garbage', 'laundry']);
export const serviceRequestStatusSchema = z.enum([
  'submitted',
  'pending_confirmation',
  'accepted',
  'scheduled',
  'in_progress',
  'completed',
  'declined',
  'cancelled',
  'missed_reported',
  'rescheduled',
  'disputed',
  'quality_dispute',
]);

// Moving-specific
export const movingServiceTypeSchema = z.enum([
  'local_move', 'long_distance_move', 'international_move',
  'office_move', 'furniture_move', 'packing_only', 'loading_unloading_only', 'other'
]);

// Garbage-specific
export const garbageRequestTypeSchema = z.enum([
  'regular_collection', 'special_pickup', 'bulky_waste', 'recycling',
  'missed_collection_report'
]);

// Laundry-specific
export const laundryServiceCategorySchema = z.enum([
  'wash_fold', 'dry_clean', 'iron_only', 'bedding_cleaning',
  'household_textile_cleaning', 'other'
]);

export const laundryCollectionPreferenceSchema = z.enum([
  'doorstep', 'lobby', 'designated_area'
]);

// Coordinates schema
const coordinatesSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

// Contact info schema
const contactInfoSchema = z.object({
  name: z.string().trim().max(200).optional().nullable(),
  phone: z.string().trim().max(50).optional().nullable(),
  email: z.string().email().max(254).optional().nullable(),
});

// Inventory item schema (moving)
const inventoryItemSchema = z.object({
  description: z.string().trim().min(1).max(500),
  fragile: z.boolean().default(false),
  dimensions: z.string().trim().max(100).optional().nullable(),
  photos: z.array(z.string().url()).optional().default([]),
  specialHandling: z.string().trim().max(500).optional().nullable(),
});

// ============================================================================
// TENANT-FACING SCHEMAS
// ============================================================================

// Base tenant request fields
const baseTenantRequestSchema = z.object({
  unitId: uuid,
  specialInstructions: z.string().trim().max(2000).optional().nullable(),
  contactInfo: contactInfoSchema.optional(),
  preferredDateTime: z.string().datetime().optional().nullable(),
});

// Tenant Moving Request
export const tenantMovingRequestSchema = baseTenantRequestSchema.extend({
  pickupLocationId: uuid.optional().nullable(), // Saved location ID
  destinationAddress: z.string().trim().min(5).max(500),
  destinationCoordinates: coordinatesSchema.optional().nullable(),
  serviceType: movingServiceTypeSchema.default('other'),
  inventory: z.array(inventoryItemSchema).optional().default([]),
});

// Tenant Garbage Request
export const tenantGarbageRequestSchema = baseTenantRequestSchema.extend({
  requestType: garbageRequestTypeSchema.default('regular_collection'),
  description: z.string().trim().min(5).max(2000),
  preferredDate: z.string().datetime().optional().nullable(),
  isRecurring: z.boolean().default(false),
  recurringTemplateId: uuid.optional().nullable(),
});

// Tenant Laundry Request
export const tenantLaundryRequestSchema = baseTenantRequestSchema.extend({
  providerId: uuid,
  serviceCategory: laundryServiceCategorySchema,
  collectionPreference: laundryCollectionPreferenceSchema.default('doorstep'),
  garmentCount: z.coerce.number().int().min(1).max(500),
  pickupAddress: z.string().trim().min(5).max(500).optional().nullable(),
  deliveryAddress: z.string().trim().min(5).max(500).optional().nullable(),
});

// ============================================================================
// PROVIDER-FACING SCHEMAS
// ============================================================================

// Provider Request Inbox Filters
export const providerRequestFiltersSchema = z.object({
  status: z.array(serviceRequestStatusSchema).optional(),
  serviceType: z.array(serviceRequestTypeSchema).optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
  county: z.string().optional(),
  city: z.string().optional(),
  maxDistanceKm: z.coerce.number().positive().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  offset: z.coerce.number().min(0).default(0),
  sortBy: z.enum(['created_at', 'preferred_date_time', 'distance']).default('created_at'),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

// Quotation Submission (Moving)
export const providerQuotationSchema = z.object({
  basePrice: z.number().positive(),
  pricingBreakdown: z.array(z.object({
    item: z.string().trim().min(1).max(200),
    amount: z.number().min(0),
    description: z.string().trim().max(500).optional().nullable(),
  })).min(1),
  estimatedPickup: z.string().datetime(),
  estimatedDelivery: z.string().datetime(),
  validUntil: z.string().datetime(),
  terms: z.string().trim().min(10).max(5000),
  notes: z.string().trim().max(2000).optional().nullable(),
});

// Quotation Counter/Response
export const quotationResponseSchema = z.object({
  action: z.enum(['accept', 'counter', 'decline']),
  counterOffer: z.object({
    basePrice: z.number().positive(),
    pricingBreakdown: z.array(z.object({
      item: z.string().trim().min(1).max(200),
      amount: z.number().min(0),
      description: z.string().trim().max(500).optional().nullable(),
    })).min(1),
    validUntil: z.string().datetime(),
    terms: z.string().trim().min(10).max(5000),
  }).optional(),
  declineReason: z.string().trim().min(5).max(1000).optional().nullable(),
});

// Job Status Update
export const jobStatusUpdateSchema = z.object({
  status: z.enum([
    'acknowledged',
    'en_route',
    'arrived',
    'loading',
    'transit',
    'unloading',
    'collected',
    'picked_up',
    'processing',
    'ready_for_delivery',
    'delivered',
    'completed',
    'unable_to_fulfil',
    'rescheduled',
    'cancelled',
  ]),
  notes: z.string().trim().max(2000).optional().nullable(),
  location: coordinatesSchema.optional().nullable(),
  evidencePhotos: z.array(z.string().url()).optional().default([]),
  scheduledAt: z.string().datetime().optional().nullable(),
});

// Completion Evidence
export const jobCompletionSchema = z.object({
  evidencePhotos: z.array(z.string().url()).min(1).max(10),
  customerSignature: z.string().optional().nullable(), // Base64 or reference
  completionNotes: z.string().trim().max(2000).optional().nullable(),
  actualPickupTime: z.string().datetime().optional().nullable(),
  actualDeliveryTime: z.string().datetime().optional().nullable(),
});

// Provider Schedule Filters
export const providerScheduleFiltersSchema = z.object({
  dateFrom: z.string().datetime(),
  dateTo: z.string().datetime(),
  status: z.array(serviceRequestStatusSchema).optional(),
  serviceType: z.array(serviceRequestTypeSchema).optional(),
});

// ============================================================================
// ORGANIZATION MANAGEMENT SCHEMAS
// ============================================================================

export const inviteStaffSchema = z.object({
  email: z.string().email().max(254),
  role: z.enum(['admin', 'supervisor', 'dispatcher', 'operations_staff', 'finance']),
  serviceDomains: z.array(z.enum(['moving', 'garbage', 'laundry'])).min(1),
  resourceIds: z.array(uuid).optional().default([]), // Specific properties/units
});

export const updateStaffRoleSchema = z.object({
  role: z.enum(['admin', 'supervisor', 'dispatcher', 'operations_staff', 'finance']).optional(),
  serviceDomains: z.array(z.enum(['moving', 'garbage', 'laundry'])).optional(),
  resourceIds: z.array(uuid).optional(),
  status: z.enum(['active', 'suspended', 'invited']).optional(),
});

// ============================================================================
// RESPONSE SCHEMAS (for OpenAPI documentation)
// ============================================================================

export const serviceRequestResponseSchema = z.object({
  id: uuid,
  type: serviceRequestTypeSchema,
  status: serviceRequestStatusSchema,
  propertyId: uuid,
  unitId: uuid.nullable(),
  tenantId: uuid,
  providerId: uuid.nullable(),
  preferredDateTime: z.string().datetime().nullable(),
  specialInstructions: z.string().nullable(),
  contactInfo: contactInfoSchema.nullable(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

// Moving-specific response
export const movingRequestResponseSchema = serviceRequestResponseSchema.extend({
  type: z.literal('moving'),
  pickupLocation: z.string(),
  destinationLocation: z.string(),
  pickupCoordinates: coordinatesSchema.nullable(),
  destinationCoordinates: coordinatesSchema.nullable(),
  serviceType: movingServiceTypeSchema,
  inventory: z.array(inventoryItemSchema),
  quotation: z.object({
    id: uuid,
    basePrice: z.number(),
    pricingBreakdown: z.array(z.object({
      item: z.string(),
      amount: z.number(),
      description: z.string().nullable(),
    })),
    estimatedPickup: z.string().datetime(),
    estimatedDelivery: z.string().datetime(),
    validUntil: z.string().datetime(),
    terms: z.string(),
    status: z.enum(['pending', 'accepted', 'countered', 'declined', 'expired']),
    counterHistory: z.array(z.object({
      basePrice: z.number(),
      pricingBreakdown: z.array(z.object({
        item: z.string(),
        amount: z.number(),
      })),
      validUntil: z.string().datetime(),
      terms: z.string(),
      createdAt: z.string().datetime(),
      createdBy: z.string(),
    })),
  }).nullable(),
  scheduledAt: z.string().datetime().nullable(),
  startedAt: z.string().datetime().nullable(),
  completedAt: z.string().datetime().nullable(),
  cancelledAt: z.string().datetime().nullable(),
  cancellationReason: z.string().nullable(),
});

// Garbage-specific response
export const garbageRequestResponseSchema = serviceRequestResponseSchema.extend({
  type: z.literal('garbage'),
  requestType: garbageRequestTypeSchema,
  description: z.string(),
  assignmentId: uuid.nullable(),
  scheduledAt: z.string().datetime().nullable(),
  completedAt: z.string().datetime().nullable(),
  missedReportedAt: z.string().datetime().nullable(),
  missedReason: z.string().nullable(),
  isRecurring: z.boolean(),
  recurringTemplateId: uuid.nullable(),
});

// Laundry-specific response
export const laundryRequestResponseSchema = serviceRequestResponseSchema.extend({
  type: z.literal('laundry'),
  serviceCategory: laundryServiceCategorySchema,
  collectionPreference: laundryCollectionPreferenceSchema,
  garmentCount: z.number().int().positive(),
  pickupAddress: z.string().nullable(),
  deliveryAddress: z.string().nullable(),
  scheduledAt: z.string().datetime().nullable(),
  pickedUpAt: z.string().datetime().nullable(),
  processingStartedAt: z.string().datetime().nullable(),
  readyForDeliveryAt: z.string().datetime().nullable(),
  deliveredAt: z.string().datetime().nullable(),
  completedAt: z.string().datetime().nullable(),
  cancelledAt: z.string().datetime().nullable(),
  cancellationReason: z.string().nullable(),
});

// Provider Dashboard Response
export const providerDashboardResponseSchema = z.object({
  profileCompletion: z.number().min(0).max(100),
  verificationStatus: z.enum(['pending', 'verified', 'rejected', 'expired']),
  newRequestsCount: z.number().int().nonnegative(),
  pendingQuotationsCount: z.number().int().nonnegative(),
  acceptedJobsTodayCount: z.number().int().nonnegative(),
  upcomingScheduleCount: z.number().int().nonnegative(),
  activeJobCount: z.number().int().nonnegative(),
  completedThisWeekCount: z.number().int().nonnegative(),
  cancelledDisputedCount: z.number().int().nonnegative(),
  unreadNotificationsCount: z.number().int().nonnegative(),
  earnings: z.object({
    pending: z.number(),
    completed: z.number(),
    paidOut: z.number(),
    currency: z.string().default('KES'),
  }),
});

// Provider Earnings Response
export const providerEarningsResponseSchema = z.object({
  summary: z.object({
    totalEarned: z.number(),
    pendingPayout: z.number(),
    totalPaidOut: z.number(),
    currency: z.string().default('KES'),
  }),
  recentPayouts: z.array(z.object({
    id: uuid,
    amount: z.number(),
    status: z.enum(['pending', 'processing', 'completed', 'failed']),
    requestedAt: z.string().datetime(),
    completedAt: z.string().datetime().nullable(),
  })),
  invoices: z.array(z.object({
    id: uuid,
    invoiceNumber: z.string(),
    amount: z.number(),
    status: z.enum(['draft', 'pending', 'paid', 'partially_paid', 'overdue', 'cancelled']),
    issueDate: z.string().datetime(),
    dueDate: z.string().datetime(),
  })),
});

// Type exports
export type TenantMovingRequest = z.infer<typeof tenantMovingRequestSchema>;
export type TenantGarbageRequest = z.infer<typeof tenantGarbageRequestSchema>;
export type TenantLaundryRequest = z.infer<typeof tenantLaundryRequestSchema>;
export type ProviderRequestFilters = z.infer<typeof providerRequestFiltersSchema>;
export type ProviderQuotation = z.infer<typeof providerQuotationSchema>;
export type QuotationResponse = z.infer<typeof quotationResponseSchema>;
export type JobStatusUpdate = z.infer<typeof jobStatusUpdateSchema>;
export type JobCompletion = z.infer<typeof jobCompletionSchema>;
export type ProviderScheduleFilters = z.infer<typeof providerScheduleFiltersSchema>;
export type InviteStaff = z.infer<typeof inviteStaffSchema>;
export type UpdateStaffRole = z.infer<typeof updateStaffRoleSchema>;