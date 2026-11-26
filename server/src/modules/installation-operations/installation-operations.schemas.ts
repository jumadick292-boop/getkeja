// Installation & Technical Services validation schemas (Task 13.14) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();

const statusEnum = z.enum([
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'plan_prepared', 'awaiting_customer_approval',
  'scheduled', 'assigned', 'in_progress', 'awaiting_equipment', 'testing',
  'awaiting_handover', 'completed_pending_confirmation', 'completed',
  'cancelled', 'failed', 'exception',
]);

export const installationListQuerySchema = z.object({
  status: statusEnum.optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

export const installationIdParamsSchema = z.object({ jobId: uuid });
export const installationAmendmentIdParamsSchema = z.object({ jobId: uuid, amendmentId: uuid });
export const installationEquipmentIdParamsSchema = z.object({ jobId: uuid, equipmentId: uuid });
export const installationStaffParamsSchema = z.object({ jobId: uuid, staffUserId: uuid });

export const createInstallationJobSchema = z.object({
  quotationId: uuid,
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  serviceAddress: z.string().trim().max(500).optional().nullable(),
  assessmentRequired: z.boolean().optional(),
  scope: z.record(z.string(), z.unknown()).optional(),
});

export const installationProgressSchema = z.object({
  to: statusEnum,
  reason: z.string().trim().max(1000).optional(),
});

export const installationFailSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export const installationCancelSchema = z.object({
  reason: z.string().trim().max(1000).optional(),
});

const photos = z.array(uuid).max(20).optional();

export const installationAssessmentSchema = z.object({
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

export const installationPlanSchema = z.object({
  summary: z.string().trim().min(1).max(2000),
  steps: z.array(z.string().trim().max(500)).max(50).optional(),
  deliverables: z.string().trim().max(2000).optional(),
  scheduledAt: z.string().trim().max(40).optional(),
});

export const installationEquipmentSchema = z.object({
  description: z.string().trim().min(1).max(500),
  category: z.enum(['equipment', 'component', 'material', 'consumable', 'other']).optional(),
  quantity: z.coerce.number().positive().max(100000).optional(),
  unit: z.string().trim().max(32).optional(),
  serialOrId: z.string().trim().max(200).optional(),
  suppliedBy: z.enum(['provider', 'customer']).optional(),
  proposedCost: z.coerce.number().min(0).max(100000000).optional(),
  installStatus: z.enum(['pending', 'installed', 'commissioned']).optional(),
  customerVisible: z.boolean().optional(),
  notes: z.string().trim().max(1000).optional(),
});

export const installationEquipmentDecisionSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const installationTestSchema = z.object({
  name: z.string().trim().min(1).max(200),
  outcome: z.enum(['pending', 'passed', 'failed']).optional(),
  details: z.string().trim().max(2000).optional(),
  correctiveWork: z.string().trim().max(2000).optional(),
  customerVisible: z.boolean().optional(),
});

export const assignInstallationStaffSchema = z.object({
  userId: uuid,
  label: z.string().trim().max(120).optional(),
});

export const proposeInstallationAmendmentSchema = z.object({
  reason: z.string().trim().min(1).max(2000),
  revisedScope: z.record(z.string(), z.unknown()).optional(),
  additionalCost: z.coerce.number().min(0).max(100000000).optional(),
  currency: z.string().trim().length(3).optional(),
});

export const decideInstallationAmendmentSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const installationCompletionSchema = z.object({
  notes: z.string().trim().max(2000).optional(),
});

export const installationCustomerConfirmationSchema = z.object({
  confirm: z.boolean(),
  notes: z.string().trim().max(2000).optional(),
});

export const reportInstallationExceptionSchema = z.object({
  type: z.string().trim().min(1).max(48),
  description: z.string().trim().min(1).max(2000),
});

export const installationAttachmentSchema = z.object({
  documentId: uuid,
  kind: z.enum(['before', 'survey', 'progress', 'testing', 'after', 'handover', 'evidence', 'other']).optional(),
});

export type CreateInstallationJobInput = z.infer<typeof createInstallationJobSchema>;
export type InstallationProgressInput = z.infer<typeof installationProgressSchema>;
export type InstallationAssessmentInput = z.infer<typeof installationAssessmentSchema>;
export type InstallationPlanInput = z.infer<typeof installationPlanSchema>;
export type InstallationEquipmentInput = z.infer<typeof installationEquipmentSchema>;
export type InstallationTestInput = z.infer<typeof installationTestSchema>;
export type ProposeInstallationAmendmentInput = z.infer<typeof proposeInstallationAmendmentSchema>;
export type InstallationAttachmentInput = z.infer<typeof installationAttachmentSchema>;
export type InstallationListQuery = z.infer<typeof installationListQuerySchema>;