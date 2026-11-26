// Tenant-facing validation schemas.
import { z } from 'zod';

const uuid = z.string().uuid();

export const tenantDashboardQuerySchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(50),
  offset: z.coerce.number().min(0).default(0),
});

export const tenancyQuerySchema = z.object({
  status: z.enum(['draft', 'pending', 'active', 'terminated', 'expired', 'historical']).optional(),
  limit: z.coerce.number().min(1).max(100).default(50),
  offset: z.coerce.number().min(0).default(0),
});

// Matches DB issue_category enum: plumbing, electrical, water_supply, security,
// structural, cleaning, fixtures, pest_control, hvac, appliances, other
const maintenanceCategorySchema = z.enum([
  'plumbing', 'electrical', 'water_supply', 'security', 'structural',
  'cleaning', 'fixtures', 'pest_control', 'hvac', 'appliances', 'other',
]);

// Matches DB issue_priority enum: low, medium, high, urgent, emergency
const maintenancePrioritySchema = z.enum(['low', 'medium', 'high', 'urgent', 'emergency']);

export const tenantMaintenanceReportSchema = z.object({
  unitId: uuid,
  title: z.string().trim().min(1).max(255),
  category: maintenanceCategorySchema,
  priority: maintenancePrioritySchema.default('medium'),
  description: z.string().trim().min(10).max(5000),
  photos: z.array(z.string().url()).optional().default([]),
  accessInstructions: z.string().trim().max(1000).optional().nullable(),
  preferredAvailability: z.string().datetime().optional().nullable(),
});

// Matches DB collection_request_type enum
const garbageRequestTypeSchema = z.enum([
  'regular_collection', 'special_pickup', 'bulky_waste', 'recycling',
]);

export const tenantGarbageRequestSchema = z.object({
  unitId: uuid,
  category: garbageRequestTypeSchema.default('regular_collection'),
  description: z.string().trim().min(5).max(2000),
  preferredDate: z.string().datetime().optional().nullable(),
});

export const tenantMovingRequestSchema = z.object({
  pickupUnitId: uuid,
  destinationAddress: z.string().trim().min(5).max(500),
  preferredDateTime: z.string().datetime(),
  itemDescription: z.string().trim().min(5).max(2000),
  specialInstructions: z.string().trim().max(1000).optional().nullable(),
  providerId: uuid.optional().nullable(),
  contactName: z.string().trim().max(200).optional().nullable(),
  contactPhone: z.string().trim().max(50).optional().nullable(),
  contactEmail: z.string().email().max(254).optional().nullable(),
});

const laundryServiceCategorySchema = z.enum([
  'wash_fold', 'dry_clean', 'iron_only', 'bedding_cleaning',
  'household_textile_cleaning', 'other',
]);

const laundryCollectionPreferenceSchema = z.enum([
  'doorstep', 'lobby', 'designated_area',
]);

export const tenantLaundryRequestSchema = z.object({
  providerId: uuid,
  serviceCategory: laundryServiceCategorySchema,
  collectionPreference: laundryCollectionPreferenceSchema.default('doorstep'),
  preferredDateTime: z.string().datetime(),
  garmentCount: z.coerce.number().int().min(1).max(500),
  specialInstructions: z.string().trim().max(1000).optional().nullable(),
  contactName: z.string().trim().max(200).optional().nullable(),
  contactPhone: z.string().trim().max(50).optional().nullable(),
  contactEmail: z.string().email().max(254).optional().nullable(),
});

// Shared pagination + status filter for tenant request lists.
export const tenantRequestListQuerySchema = z.object({
  status: z.string().trim().max(40).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const notificationMarkReadSchema = z.object({
  notificationIds: z.array(z.string().uuid()).min(1),
});

export const signedUrlRequestSchema = z.object({
  documentId: z.string().uuid(),
  purpose: z.enum(['download', 'view']).default('view'),
  ttlSeconds: z.coerce.number().min(60).max(86400).default(3600),
});
