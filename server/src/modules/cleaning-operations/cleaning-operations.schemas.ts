// Cleaning & Property Care validation schemas (Task 13.13) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();

const statusEnum = z.enum([
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'scheduled', 'assigned', 'in_progress',
  'awaiting_supplies', 'awaiting_customer_decision', 'quality_check',
  'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
  'exception',
]);

export const cleaningListQuerySchema = z.object({
  status: statusEnum.optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

export const cleaningIdParamsSchema = z.object({ jobId: uuid });
export const cleaningAmendmentIdParamsSchema = z.object({ jobId: uuid, amendmentId: uuid });
export const cleaningMaterialIdParamsSchema = z.object({ jobId: uuid, materialId: uuid });
export const cleaningChecklistIdParamsSchema = z.object({ jobId: uuid, checklistId: uuid });
export const cleaningStaffParamsSchema = z.object({ jobId: uuid, staffUserId: uuid });

export const createCleaningJobSchema = z.object({
  quotationId: uuid,
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  serviceAddress: z.string().trim().max(500).optional().nullable(),
  assessmentRequired: z.boolean().optional(),
  scope: z.record(z.string(), z.unknown()).optional(),
});

export const cleaningProgressSchema = z.object({
  to: statusEnum,
  reason: z.string().trim().max(1000).optional(),
});

export const cleaningFailSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export const cleaningCancelSchema = z.object({
  reason: z.string().trim().max(1000).optional(),
});

const photos = z.array(uuid).max(20).optional();

export const cleaningAssessmentSchema = z.object({
  scheduledAt: z.string().trim().max(40).optional(),
  assessorUserId: uuid.optional().nullable(),
  findings: z.string().trim().max(4000).optional(),
  scopeAssessment: z.string().trim().max(4000).optional(),
  recommendedTasks: z.string().trim().max(4000).optional(),
  estimatedDurationMinutes: z.coerce.number().int().min(0).max(100000).optional(),
  suppliesRequired: z.string().trim().max(2000).optional(),
  safetyConcerns: z.string().trim().max(2000).optional(),
  customerVisibleReport: z.string().trim().max(4000).optional(),
  internalNotes: z.string().trim().max(4000).optional(),
  photoDocumentIds: photos,
  complete: z.boolean().optional(),
});

export const cleaningChecklistItemSchema = z.object({
  id: z.string().trim().min(1).max(80),
  label: z.string().trim().min(1).max(300),
  done: z.boolean().optional(),
});

export const cleaningChecklistSchema = z.object({
  title: z.string().trim().min(1).max(300),
  items: z.array(cleaningChecklistItemSchema).min(1).max(100).optional(),
});

export const cleaningChecklistUpdateSchema = z.object({
  itemId: z.string().trim().min(1).max(80),
  done: z.boolean(),
});

export const cleaningAreaSchema = z.object({
  name: z.string().trim().min(1).max(200),
  areaType: z.enum(['room', 'area', 'outdoor', 'other']).optional(),
  approximateSize: z.string().trim().max(120).optional(),
  status: z.enum(['pending', 'in_progress', 'done']).optional(),
  notes: z.string().trim().max(1000).optional(),
});

export const cleaningMaterialSchema = z.object({
  description: z.string().trim().min(1).max(500),
  quantity: z.coerce.number().positive().max(100000).optional(),
  unit: z.string().trim().max(32).optional(),
  suppliedBy: z.enum(['provider', 'customer']).optional(),
  proposedCost: z.coerce.number().min(0).max(100000000).optional(),
  notes: z.string().trim().max(1000).optional(),
});

export const cleaningMaterialDecisionSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const assignCleaningStaffSchema = z.object({
  userId: uuid,
  label: z.string().trim().max(120).optional(),
});

export const proposeCleaningAmendmentSchema = z.object({
  reason: z.string().trim().min(1).max(2000),
  revisedScope: z.record(z.string(), z.unknown()).optional(),
  additionalCost: z.coerce.number().min(0).max(100000000).optional(),
  currency: z.string().trim().length(3).optional(),
});

export const decideCleaningAmendmentSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const cleaningCompletionSchema = z.object({
  notes: z.string().trim().max(2000).optional(),
});

export const cleaningCustomerConfirmationSchema = z.object({
  confirm: z.boolean(),
  notes: z.string().trim().max(2000).optional(),
});

export const reportCleaningExceptionSchema = z.object({
  type: z.string().trim().min(1).max(48),
  description: z.string().trim().min(1).max(2000),
});

export const cleaningAttachmentSchema = z.object({
  documentId: uuid,
  kind: z.enum(['before', 'after', 'evidence', 'other']).optional(),
});

export type CreateCleaningJobInput = z.infer<typeof createCleaningJobSchema>;
export type CleaningProgressInput = z.infer<typeof cleaningProgressSchema>;
export type CleaningAssessmentInput = z.infer<typeof cleaningAssessmentSchema>;
export type CleaningChecklistInput = z.infer<typeof cleaningChecklistSchema>;
export type CleaningAreaInput = z.infer<typeof cleaningAreaSchema>;
export type CleaningMaterialInput = z.infer<typeof cleaningMaterialSchema>;
export type ProposeCleaningAmendmentInput = z.infer<typeof proposeCleaningAmendmentSchema>;
export type CleaningAttachmentInput = z.infer<typeof cleaningAttachmentSchema>;
export type CleaningListQuery = z.infer<typeof cleaningListQuerySchema>;