// Finishing & Building Services validation schemas (Task 13.15) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();

const statusEnum = z.enum([
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'plan_prepared', 'awaiting_customer_approval',
  'scheduled', 'assigned', 'materials_prepared', 'in_progress',
  'awaiting_materials', 'quality_inspection', 'awaiting_handover',
  'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
  'exception',
]);

export const finishingListQuerySchema = z.object({
  status: statusEnum.optional(),
  categoryId: z.string().trim().max(80).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

export const finishingIdParamsSchema = z.object({ jobId: uuid });
export const finishingAmendmentIdParamsSchema = z.object({ jobId: uuid, amendmentId: uuid });
export const finishingMaterialIdParamsSchema = z.object({ jobId: uuid, materialId: uuid });
export const finishingStaffParamsSchema = z.object({ jobId: uuid, staffUserId: uuid });

export const createFinishingJobSchema = z.object({
  quotationId: uuid,
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  serviceAddress: z.string().trim().max(500).optional().nullable(),
  assessmentRequired: z.boolean().optional(),
  scope: z.record(z.string(), z.unknown()).optional(),
});

export const finishingProgressSchema = z.object({
  to: statusEnum,
  reason: z.string().trim().max(1000).optional(),
});

export const finishingFailSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export const finishingCancelSchema = z.object({
  reason: z.string().trim().max(1000).optional(),
});

const photos = z.array(uuid).max(20).optional();

export const finishingAssessmentSchema = z.object({
  scheduledAt: z.string().trim().max(40).optional(),
  assessorUserId: uuid.optional().nullable(),
  findings: z.string().trim().max(4000).optional(),
  measurements: z.string().trim().max(2000).optional(),
  siteReadiness: z.string().trim().max(2000).optional(),
  recommendedScope: z.string().trim().max(4000).optional(),
  estimatedDurationMinutes: z.coerce.number().int().min(0).max(100000).optional(),
  safetyConcerns: z.string().trim().max(2000).optional(),
  customerVisibleReport: z.string().trim().max(4000).optional(),
  internalNotes: z.string().trim().max(4000).optional(),
  photoDocumentIds: photos,
  complete: z.boolean().optional(),
});

export const finishingPlanSchema = z.object({
  summary: z.string().trim().min(1).max(2000),
  steps: z.array(z.string().trim().max(500)).max(50).optional(),
  deliverables: z.string().trim().max(2000).optional(),
  scheduledAt: z.string().trim().max(40).optional(),
});

export const finishingMaterialSchema = z.object({
  description: z.string().trim().min(1).max(500),
  category: z.enum(['material', 'finish', 'tile', 'paint', 'consumable', 'other']).optional(),
  quantity: z.coerce.number().positive().max(100000).optional(),
  unit: z.string().trim().max(32).optional(),
  finishOrSpec: z.string().trim().max(200).optional(),
  suppliedBy: z.enum(['provider', 'customer']).optional(),
  proposedCost: z.coerce.number().min(0).max(100000000).optional(),
  installStatus: z.enum(['pending', 'applied', 'installed', 'finished']).optional(),
  customerVisible: z.boolean().optional(),
  notes: z.string().trim().max(1000).optional(),
});

export const finishingMaterialDecisionSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const finishingInspectionSchema = z.object({
  name: z.string().trim().min(1).max(200),
  outcome: z.enum(['pending', 'passed', 'failed']).optional(),
  details: z.string().trim().max(2000).optional(),
  correctiveWork: z.string().trim().max(2000).optional(),
  customerVisible: z.boolean().optional(),
});

export const assignFinishingStaffSchema = z.object({
  userId: uuid,
  label: z.string().trim().max(120).optional(),
});

export const proposeFinishingAmendmentSchema = z.object({
  reason: z.string().trim().min(1).max(2000),
  revisedScope: z.record(z.string(), z.unknown()).optional(),
  additionalCost: z.coerce.number().min(0).max(100000000).optional(),
  currency: z.string().trim().length(3).optional(),
});

export const decideFinishingAmendmentSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const finishingCompletionSchema = z.object({
  notes: z.string().trim().max(2000).optional(),
});

export const finishingCustomerConfirmationSchema = z.object({
  confirm: z.boolean(),
  notes: z.string().trim().max(2000).optional(),
});

export const reportFinishingExceptionSchema = z.object({
  type: z.string().trim().min(1).max(48),
  description: z.string().trim().min(1).max(2000),
});

export const finishingAttachmentSchema = z.object({
  documentId: uuid,
  kind: z.enum(['before', 'survey', 'progress', 'inspection', 'after', 'handover', 'evidence', 'other']).optional(),
});

export type CreateFinishingJobInput = z.infer<typeof createFinishingJobSchema>;
export type FinishingProgressInput = z.infer<typeof finishingProgressSchema>;
export type FinishingAssessmentInput = z.infer<typeof finishingAssessmentSchema>;
export type FinishingPlanInput = z.infer<typeof finishingPlanSchema>;
export type FinishingMaterialInput = z.infer<typeof finishingMaterialSchema>;
export type FinishingInspectionInput = z.infer<typeof finishingInspectionSchema>;
export type ProposeFinishingAmendmentInput = z.infer<typeof proposeFinishingAmendmentSchema>;
export type FinishingAttachmentInput = z.infer<typeof finishingAttachmentSchema>;
export type FinishingListQuery = z.infer<typeof finishingListQuerySchema>;