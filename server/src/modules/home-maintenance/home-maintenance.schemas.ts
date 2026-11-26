// Home Maintenance & Repairs validation schemas (Task 13.12) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();

const statusEnum = z.enum([
  'confirmed', 'inspection_scheduled', 'awaiting_inspection',
  'inspection_in_progress', 'awaiting_customer_approval', 'work_scheduled',
  'assigned', 'in_progress', 'awaiting_parts', 'awaiting_customer_decision',
  'quality_check', 'completed_pending_confirmation', 'completed',
  'cancelled', 'failed', 'exception',
]);

export const homeMaintenanceListQuerySchema = z.object({
  status: statusEnum.optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

export const homeMaintenanceIdParamsSchema = z.object({ jobId: uuid });
export const homeMaintenanceInspectionIdParamsSchema = z.object({ jobId: uuid, inspectionId: uuid });
export const homeMaintenanceAmendmentIdParamsSchema = z.object({ jobId: uuid, amendmentId: uuid });
export const homeMaintenancePartIdParamsSchema = z.object({ jobId: uuid, partId: uuid });
export const homeMaintenanceStaffParamsSchema = z.object({ jobId: uuid, staffUserId: uuid });

export const createHomeMaintenanceJobSchema = z.object({
  quotationId: uuid,
  propertyId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  tenancyId: uuid.optional().nullable(),
  serviceAddress: z.string().trim().max(500).optional().nullable(),
  inspectionRequired: z.boolean().optional(),
  scope: z.record(z.string(), z.unknown()).optional(),
});

export const homeMaintenanceProgressSchema = z.object({
  to: statusEnum,
  reason: z.string().trim().max(1000).optional(),
});

export const homeMaintenanceFailSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export const homeMaintenanceCancelSchema = z.object({
  reason: z.string().trim().max(1000).optional(),
});

export const homeMaintenanceScheduleSchema = z.object({
  scheduledAt: z.string().trim().min(1).max(40),
  technicianUserId: uuid.optional().nullable(),
});

const photos = z.array(uuid).max(20).optional();

export const homeMaintenanceInspectionSchema = z.object({
  scheduledAt: z.string().trim().max(40).optional(),
  technicianUserId: uuid.optional().nullable(),
  findings: z.string().trim().max(4000).optional(),
  diagnosis: z.string().trim().max(4000).optional(),
  recommendedWork: z.string().trim().max(4000).optional(),
  estimatedDurationMinutes: z.coerce.number().int().min(0).max(100000).optional(),
  materialsRequired: z.string().trim().max(2000).optional(),
  safetyConcerns: z.string().trim().max(2000).optional(),
  customerVisibleReport: z.string().trim().max(4000).optional(),
  internalNotes: z.string().trim().max(4000).optional(),
  photoDocumentIds: photos,
  complete: z.boolean().optional(),
});

export const homeMaintenanceWorkPlanSchema = z.object({
  summary: z.string().trim().min(1).max(2000),
  steps: z.array(z.string().trim().max(500)).max(50).optional(),
  scheduledAt: z.string().trim().max(40).optional(),
});

export const homeMaintenancePartSchema = z.object({
  description: z.string().trim().min(1).max(500),
  quantity: z.coerce.number().positive().max(100000).optional(),
  unit: z.string().trim().max(32).optional(),
  modelSpec: z.string().trim().max(200).optional(),
  suppliedBy: z.enum(['provider', 'customer']).optional(),
  proposedCost: z.coerce.number().min(0).max(100000000).optional(),
  notes: z.string().trim().max(1000).optional(),
});

export const homeMaintenancePartDecisionSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const assignHomeMaintenanceStaffSchema = z.object({
  userId: uuid,
  label: z.string().trim().max(120).optional(),
});

export const proposeHomeMaintenanceAmendmentSchema = z.object({
  reason: z.string().trim().min(1).max(2000),
  revisedScope: z.record(z.string(), z.unknown()).optional(),
  additionalCost: z.coerce.number().min(0).max(100000000).optional(),
  currency: z.string().trim().length(3).optional(),
});

export const decideHomeMaintenanceAmendmentSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

export const homeMaintenanceCompletionSchema = z.object({
  notes: z.string().trim().max(2000).optional(),
});

export const homeMaintenanceCustomerConfirmationSchema = z.object({
  confirm: z.boolean(),
  notes: z.string().trim().max(2000).optional(),
});

export const reportHomeMaintenanceExceptionSchema = z.object({
  type: z.string().trim().min(1).max(48),
  description: z.string().trim().min(1).max(2000),
});

export type CreateHomeMaintenanceJobInput = z.infer<typeof createHomeMaintenanceJobSchema>;
export type HomeMaintenanceProgressInput = z.infer<typeof homeMaintenanceProgressSchema>;
export type HomeMaintenanceInspectionInput = z.infer<typeof homeMaintenanceInspectionSchema>;
export type HomeMaintenanceWorkPlanInput = z.infer<typeof homeMaintenanceWorkPlanSchema>;
export type HomeMaintenancePartInput = z.infer<typeof homeMaintenancePartSchema>;
export type ProposeHomeMaintenanceAmendmentInput = z.infer<typeof proposeHomeMaintenanceAmendmentSchema>;
export type HomeMaintenanceListQuery = z.infer<typeof homeMaintenanceListQuerySchema>;