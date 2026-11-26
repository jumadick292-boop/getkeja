// Garbage collection operations validation schemas (Task 13.7). Strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/, 'HH:MM');
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD');

export const garbageJobIdParamsSchema = z.object({ jobId: uuid });
export const agreementIdParamsSchema = z.object({ agreementId: uuid });
export const occurrenceIdParamsSchema = z.object({ occurrenceId: uuid });

const locationBlock = z.object({
  locationId: uuid.optional().nullable(),
  address: z.string().trim().max(500).optional().nullable(),
});

// One-time collection job from an accepted quotation.
export const createGarbageJobSchema = z
  .object({
    quotationId: uuid,
    location: locationBlock.optional(),
    propertyId: uuid.optional().nullable(),
    unitId: uuid.optional().nullable(),
    tenancyId: uuid.optional().nullable(),
    wasteCategory: z.string().trim().max(80).optional(),
    estimatedQuantity: z.string().trim().max(120).optional(),
    binCount: z.coerce.number().int().min(0).max(1000).optional(),
    scheduledDate: date.optional().nullable(),
    windowStart: time.optional().nullable(),
    windowEnd: time.optional().nullable(),
    scope: z
      .object({
        wasteCategory: z.string().trim().max(80).optional(),
        estimatedQuantity: z.string().trim().max(120).optional(),
        binCount: z.coerce.number().int().min(0).max(1000).optional(),
        accessInstructions: z.string().trim().max(2000).optional(),
        specialInstructions: z.string().trim().max(2000).optional(),
      })
      .strict()
      .optional(),
  })
  .strict();

export const garbageProgressSchema = z
  .object({
    toStatus: z.enum([
      'scheduled',
      'provider_assigned',
      'en_route',
      'arrived',
      'collecting',
      'awaiting_customer_confirmation',
    ]),
    reason: z.string().trim().max(1000).optional(),
    checklist: z.record(z.string(), z.boolean()).optional(),
  })
  .strict();

export const garbageCancelSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();
export const garbageMissSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();
export const garbageFailSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();

export const assignGarbageStaffSchema = z
  .object({ userId: uuid, label: z.string().trim().max(120).optional() })
  .strict();

export const garbageChecklistUpdateSchema = z.object({ items: z.record(z.string(), z.boolean()) }).strict();

export const garbageCompletionSchema = z
  .object({
    notes: z.string().trim().max(4000).optional(),
    outstandingIssue: z.boolean().default(false),
    checklist: z.record(z.string(), z.boolean()).optional(),
    evidenceDocumentIds: z.array(uuid).max(20).default([]),
    wasteCategory: z.string().trim().max(80).optional(),
    estimatedQuantity: z.string().trim().max(120).optional(),
    binCount: z.coerce.number().int().min(0).max(1000).optional(),
  })
  .strict();

export const garbageCustomerConfirmationSchema = z
  .object({
    confirm: z.boolean(),
    notes: z.string().trim().max(4000).optional(),
    exception: z
      .object({
        type: z.enum(['incomplete', 'missed', 'quantity_disagreement', 'other']),
        description: z.string().trim().min(5).max(4000),
      })
      .optional(),
  })
  .strict();

export const reportGarbageExceptionSchema = z
  .object({
    type: z.enum(['incomplete', 'missed', 'quantity_disagreement', 'damage', 'other']),
    description: z.string().trim().min(5).max(4000),
  })
  .strict();

// Recurring agreement proposal (provider) from an accepted quotation/request.
export const createGarbageAgreementSchema = z
  .object({
    quotationId: uuid.optional().nullable(),
    serviceRequestId: uuid.optional().nullable(),
    frequency: z.enum(['weekly', 'biweekly', 'monthly', 'custom']),
    intervalDays: z.coerce.number().int().min(1).max(365).optional(),
    daysOfWeek: z.array(z.coerce.number().int().min(0).max(6)).max(7).default([]),
    windowStart: time.optional().nullable(),
    windowEnd: time.optional().nullable(),
    startDate: date,
    endDate: date.optional().nullable(),
    agreedAmount: z.coerce.number().min(0).max(100000000),
    billingFrequency: z.enum(['per_collection', 'weekly', 'monthly', 'custom']).optional(),
    wasteCategory: z.string().trim().max(80).optional(),
    propertyId: uuid.optional().nullable(),
    unitId: uuid.optional().nullable(),
    tenancyId: uuid.optional().nullable(),
    scope: z.record(z.string(), z.unknown()).optional(),
  })
  .strict()
  .refine((v) => v.quotationId != null || v.serviceRequestId != null, {
    message: 'quotationId or serviceRequestId is required',
  });

export const decideAgreementSchema = z.object({ accept: z.boolean() }).strict();

export const rescheduleGarbageSchema = z
  .object({
    scheduledDate: date,
    windowStart: time.optional().nullable(),
    windowEnd: time.optional().nullable(),
    reason: z.string().trim().max(1000).optional(),
  })
  .strict();

export const garbageJobListQuerySchema = z.object({
  status: z
    .enum([
      'confirmed', 'scheduled', 'provider_assigned', 'en_route', 'arrived',
      'collecting', 'completed', 'awaiting_customer_confirmation',
      'cancelled', 'missed', 'failed', 'rescheduled',
    ])
    .optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export type CreateGarbageJobInput = z.infer<typeof createGarbageJobSchema>;
export type GarbageProgressInput = z.infer<typeof garbageProgressSchema>;
export type GarbageCompletionInput = z.infer<typeof garbageCompletionSchema>;
export type GarbageCustomerConfirmationInput = z.infer<typeof garbageCustomerConfirmationSchema>;
export type CreateGarbageAgreementInput = z.infer<typeof createGarbageAgreementSchema>;