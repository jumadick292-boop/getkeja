// Moving & relocation operations validation schemas (Task 13.6). Strict Zod.

import { z } from 'zod';

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/, 'HH:MM');
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD');

export const movingJobIdParamsSchema = z.object({ jobId: uuid });

// Origin / destination access block (shared shape).
const locationBlockSchema = z.object({
  locationId: uuid.optional().nullable(),
  address: z.string().trim().max(500).optional().nullable(),
  contactInstructions: z.string().trim().max(1000).optional().nullable(),
  buildingName: z.string().trim().max(200).optional().nullable(),
  floor: z.string().trim().max(20).optional().nullable(),
  liftAvailable: z.boolean().optional().nullable(),
  accessNotes: z.string().trim().max(1000).optional().nullable(),
});

// Provider creates the operational job from an accepted quotation. The snapshot
// (scope/price) is derived server-side; the provider only supplies logistics.
export const createMovingJobSchema = z
  .object({
    quotationId: uuid,
    origin: locationBlockSchema.optional(),
    destination: locationBlockSchema.optional(),
    agreedMoveDate: date.optional().nullable(),
    agreedWindowStart: time.optional().nullable(),
    agreedWindowEnd: time.optional().nullable(),
    scope: z
      .object({
        serviceCategories: z.array(z.string().trim().max(80)).default([]),
        capabilities: z.array(z.string().trim().max(80)).default([]),
        inventory: z.string().trim().max(4000).optional(),
        accessInstructions: z.string().trim().max(2000).optional(),
        notes: z.string().trim().max(2000).optional(),
      })
      .strict()
      .optional(),
    tenancyId: uuid.optional().nullable(),
    propertyId: uuid.optional().nullable(),
    unitId: uuid.optional().nullable(),
  })
  .strict();

// Operational progress transition.
export const movingProgressSchema = z
  .object({
    toStatus: z.enum([
      'awaiting_customer_details',
      'preparation',
      'ready_for_move',
      'in_progress',
      'arrived_at_destination',
      'unloading',
      'awaiting_customer_confirmation',
    ]),
    reason: z.string().trim().max(1000).optional(),
    checklist: z.record(z.string(), z.boolean()).optional(),
  })
  .strict();

export const movingCancelSchema = z
  .object({ reason: z.string().trim().min(3).max(1000) })
  .strict();

export const movingFailSchema = z
  .object({ reason: z.string().trim().min(3).max(1000) })
  .strict();

// Staff assignment.
export const assignStaffSchema = z
  .object({
    userId: uuid,
    label: z.string().trim().max(120).optional(),
  })
  .strict();

// Checklist update.
export const checklistUpdateSchema = z
  .object({ items: z.record(z.string(), z.boolean()) })
  .strict();

// Assessment lifecycle.
export const createAssessmentSchema = z
  .object({
    proposedAt: z.string().datetime().optional().nullable(),
    locationId: uuid.optional().nullable(),
    locationAddress: z.string().trim().max(500).optional().nullable(),
    providerNotes: z.string().trim().max(2000).optional(),
  })
  .strict();

export const assessmentIdParamsSchema = z.object({ assessmentId: uuid });

export const respondAssessmentSchema = z
  .object({
    accept: z.boolean(),
    customerNotes: z.string().trim().max(2000).optional(),
  })
  .strict();

export const completeAssessmentSchema = z
  .object({
    outcome: z.string().trim().min(1).max(2000),
    providerNotes: z.string().trim().max(2000).optional(),
  })
  .strict();

// Reschedule proposal + decision.
export const proposeRescheduleSchema = z
  .object({
    proposedDate: date,
    proposedWindowStart: time.optional().nullable(),
    proposedWindowEnd: time.optional().nullable(),
    reason: z.string().trim().max(1000).optional(),
  })
  .strict();

export const scheduleChangeIdParamsSchema = z.object({ changeId: uuid });

export const decideRescheduleSchema = z
  .object({ accept: z.boolean() })
  .strict();

// Scope amendment proposal + decision.
export const proposeAmendmentSchema = z
  .object({
    reason: z.string().trim().min(3).max(2000),
    revisedScope: z
      .object({
        serviceCategories: z.array(z.string().trim().max(80)).optional(),
        capabilities: z.array(z.string().trim().max(80)).optional(),
        inventory: z.string().trim().max(4000).optional(),
        notes: z.string().trim().max(2000).optional(),
      })
      .strict()
      .optional(),
    additionalCost: z.coerce.number().min(0).max(100000000).default(0),
  })
  .strict();

export const amendmentIdParamsSchema = z.object({ amendmentId: uuid });

export const decideAmendmentSchema = z
  .object({ accept: z.boolean() })
  .strict();

// Completion submission + customer confirmation.
export const completionSubmissionSchema = z
  .object({
    notes: z.string().trim().max(4000).optional(),
    outstandingIssue: z.boolean().default(false),
    checklist: z.record(z.string(), z.boolean()).optional(),
    evidenceDocumentIds: z.array(uuid).max(20).default([]),
  })
  .strict();

export const customerConfirmationSchema = z
  .object({
    confirm: z.boolean(),
    notes: z.string().trim().max(4000).optional(),
    exception: z
      .object({
        type: z.enum(['incomplete', 'damage', 'missing_items', 'other']),
        description: z.string().trim().min(5).max(4000),
      })
      .optional(),
  })
  .strict();

export const movingJobListQuerySchema = z.object({
  status: z
    .enum([
      'confirmed', 'awaiting_customer_details', 'preparation', 'ready_for_move',
      'in_progress', 'arrived_at_destination', 'unloading',
      'awaiting_customer_confirmation', 'completed', 'cancelled', 'failed',
    ])
    .optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export type CreateMovingJobInput = z.infer<typeof createMovingJobSchema>;
export type MovingProgressInput = z.infer<typeof movingProgressSchema>;
export type AssignStaffInput = z.infer<typeof assignStaffSchema>;
export type CreateAssessmentInput = z.infer<typeof createAssessmentSchema>;
export type ProposeRescheduleInput = z.infer<typeof proposeRescheduleSchema>;
export type ProposeAmendmentInput = z.infer<typeof proposeAmendmentSchema>;
export type CompletionSubmissionInput = z.infer<typeof completionSubmissionSchema>;
export type CustomerConfirmationInput = z.infer<typeof customerConfirmationSchema>;