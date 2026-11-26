// Laundry operations validation schemas (Task 13.8). Strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/, 'HH:MM');
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD');

export const laundryOrderIdParamsSchema = z.object({ orderId: uuid });
export const laundryAmendmentIdParamsSchema = z.object({ orderId: uuid, amendmentId: uuid });
export const laundryInspectionIdParamsSchema = z.object({ orderId: uuid, inspectionId: uuid });

const locationBlock = z.object({
  locationId: uuid.optional().nullable(),
  address: z.string().trim().max(500).optional().nullable(),
});

// One-time order from an accepted quotation.
export const createLaundryOrderSchema = z
  .object({
    quotationId: uuid,
    fulfilmentMode: z.enum(['dropoff', 'collection', 'both']).default('dropoff'),
    collection: locationBlock.optional(),
    returnLocation: locationBlock.optional(),
    propertyId: uuid.optional().nullable(),
    unitId: uuid.optional().nullable(),
    tenancyId: uuid.optional().nullable(),
    collectionDate: date.optional().nullable(),
    collectionWindowStart: time.optional().nullable(),
    collectionWindowEnd: time.optional().nullable(),
    returnDate: date.optional().nullable(),
    returnWindowStart: time.optional().nullable(),
    returnWindowEnd: time.optional().nullable(),
    scope: z
      .object({
        services: z.array(z.string().trim().max(80)).max(30).optional(),
        capabilities: z.array(z.string().trim().max(80)).max(30).optional(),
        specialInstructions: z.string().trim().max(2000).optional(),
        preferredCollectionDate: date.optional(),
        preferredWindowStart: time.optional(),
        preferredWindowEnd: time.optional(),
      })
      .strict()
      .optional(),
    // Optional initial items supplied by the provider at creation.
    items: z
      .array(
        z
          .object({
            itemCategory: z.string().trim().min(1).max(80),
            description: z.string().trim().max(1000).optional(),
            quantity: z.coerce.number().int().min(1).max(10000),
            customerReference: z.string().trim().max(120).optional(),
            conditionAtIntake: z.enum(['new', 'good', 'worn', 'damaged', 'unknown']).optional(),
            stainsDamageNotes: z.string().trim().max(1000).optional(),
            specialHandling: z.string().trim().max(1000).optional(),
            processingInstructions: z.string().trim().max(1000).optional(),
          })
          .strict(),
      )
      .max(200)
      .optional(),
  })
  .strict();

export const laundryProgressSchema = z
  .object({
    toStatus: z.enum([
      'collection_scheduled', 'collected', 'received_at_facility', 'inspection',
      'awaiting_customer_approval', 'processing', 'washing', 'drying', 'ironing',
      'folding', 'quality_check', 'ready_for_return', 'out_for_delivery', 'delivered',
      'awaiting_customer_confirmation',
    ]),
    reason: z.string().trim().max(1000).optional(),
    checklist: z.record(z.string(), z.boolean()).optional(),
  })
  .strict();

export const laundryCancelSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();
export const laundryFailSchema = z.object({ reason: z.string().trim().min(3).max(1000) }).strict();

export const assignLaundryStaffSchema = z
  .object({ userId: uuid, label: z.string().trim().max(120).optional() })
  .strict();

export const laundryChecklistUpdateSchema = z.object({ items: z.record(z.string(), z.boolean()) }).strict();

// Item intake / inventory.
export const laundryItemSchema = z
  .object({
    itemCategory: z.string().trim().min(1).max(80),
    description: z.string().trim().max(1000).optional(),
    quantity: z.coerce.number().int().min(1).max(10000),
    customerReference: z.string().trim().max(120).optional(),
    conditionAtIntake: z.enum(['new', 'good', 'worn', 'damaged', 'unknown']).optional(),
    stainsDamageNotes: z.string().trim().max(1000).optional(),
    specialHandling: z.string().trim().max(1000).optional(),
    processingInstructions: z.string().trim().max(1000).optional(),
    photoDocumentIds: z.array(uuid).max(20).default([]),
  })
  .strict();

export const laundryItemUpdateSchema = z
  .object({
    itemCategory: z.string().trim().min(1).max(80).optional(),
    description: z.string().trim().max(1000).optional(),
    quantity: z.coerce.number().int().min(1).max(10000).optional(),
    conditionAtIntake: z.enum(['new', 'good', 'worn', 'damaged', 'unknown']).optional(),
    stainsDamageNotes: z.string().trim().max(1000).optional(),
    specialHandling: z.string().trim().max(1000).optional(),
    processingInstructions: z.string().trim().max(1000).optional(),
    itemStatus: z.enum(['received', 'processing', 'processed', 'ready', 'returned', 'missing', 'damaged']).optional(),
    returnConditionNotes: z.string().trim().max(1000).optional(),
    handoverNotes: z.string().trim().max(1000).optional(),
  })
  .strict();

// Inspection + discrepancy approval.
export const laundryInspectionSchema = z
  .object({
    itemId: uuid.optional().nullable(),
    result: z.enum(['ok', 'discrepancy', 'damage', 'missing']),
    declaredQuantity: z.coerce.number().int().min(0).max(10000).optional(),
    receivedQuantity: z.coerce.number().int().min(0).max(10000).optional(),
    description: z.string().trim().min(3).max(4000),
    requiresCustomerApproval: z.boolean().default(false),
  })
  .strict();

export const resolveInspectionSchema = z
  .object({
    decision: z.enum(['approve', 'reject']),
    notes: z.string().trim().max(2000).optional(),
  })
  .strict();

export const laundryCompletionSchema = z
  .object({
    notes: z.string().trim().max(4000).optional(),
    outstandingIssue: z.boolean().default(false),
    checklist: z.record(z.string(), z.boolean()).optional(),
    evidenceDocumentIds: z.array(uuid).max(20).default([]),
  })
  .strict();

export const laundryCustomerConfirmationSchema = z
  .object({
    confirm: z.boolean(),
    notes: z.string().trim().max(4000).optional(),
    exception: z
      .object({
        type: z.enum(['missing_items', 'damaged_items', 'incomplete', 'other']),
        description: z.string().trim().min(5).max(4000),
      })
      .optional(),
  })
  .strict();

export const reportLaundryExceptionSchema = z
  .object({
    type: z.enum(['missing_items', 'damaged_items', 'delayed', 'stain', 'other']),
    description: z.string().trim().min(5).max(4000),
  })
  .strict();

// Scheduling / rescheduling of handovers.
export const scheduleHandoverSchema = z
  .object({
    kind: z.enum(['collection', 'return']),
    location: locationBlock.optional(),
    scheduledAt: z.string().datetime().optional(),
    windowStart: time.optional().nullable(),
    windowEnd: time.optional().nullable(),
    notes: z.string().trim().max(2000).optional(),
  })
  .strict();

export const rescheduleLaundrySchema = z
  .object({
    kind: z.enum(['collection', 'return']),
    scheduledDate: date,
    windowStart: time.optional().nullable(),
    windowEnd: time.optional().nullable(),
    reason: z.string().trim().max(1000).optional(),
  })
  .strict();

export const confirmHandoverSchema = z
  .object({
    proofDocumentIds: z.array(uuid).max(20).default([]),
    notes: z.string().trim().max(2000).optional(),
  })
  .strict();

// Amendments.
export const proposeLaundryAmendmentSchema = z
  .object({
    reason: z.string().trim().min(3).max(2000),
    revisedScope: z.record(z.string(), z.unknown()).optional(),
    additionalCost: z.coerce.number().min(0).max(100000000),
  })
  .strict();

export const decideLaundryAmendmentSchema = z.object({ accept: z.boolean() }).strict();

export const laundryOrderListQuerySchema = z.object({
  status: z
    .enum([
      'confirmed', 'collection_scheduled', 'collected', 'received_at_facility',
      'inspection', 'awaiting_customer_approval', 'processing', 'washing',
      'drying', 'ironing', 'folding', 'quality_check', 'ready_for_return',
      'out_for_delivery', 'delivered', 'awaiting_customer_confirmation',
      'completed', 'cancelled', 'failed', 'exception',
    ])
    .optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export type CreateLaundryOrderInput = z.infer<typeof createLaundryOrderSchema>;
export type LaundryProgressInput = z.infer<typeof laundryProgressSchema>;
export type LaundryCompletionInput = z.infer<typeof laundryCompletionSchema>;
export type LaundryCustomerConfirmationInput = z.infer<typeof laundryCustomerConfirmationSchema>;
export type LaundryItemInput = z.infer<typeof laundryItemSchema>;
export type LaundryInspectionInput = z.infer<typeof laundryInspectionSchema>;
export type ScheduleHandoverInput = z.infer<typeof scheduleHandoverSchema>;
export type ProposeLaundryAmendmentInput = z.infer<typeof proposeLaundryAmendmentSchema>;