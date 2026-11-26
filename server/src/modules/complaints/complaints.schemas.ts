// Provider complaints validation schemas (Task 13.16) — strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();

const statusEnum = z.enum([
  'submitted', 'acknowledged', 'under_review', 'awaiting_customer_information',
  'awaiting_provider_response', 'resolution_proposed', 'resolved', 'escalated', 'closed',
]);

export const complaintResourceParamsSchema = z.object({
  domain: z.string().trim().min(1).max(40),
  resourceId: uuid,
});

export const createComplaintSchema = z
  .object({
    reasonId: z.string().trim().min(1).max(48),
    description: z.string().trim().min(10).max(4000),
    documentIds: z.array(uuid).max(20).optional(),
  })
  .strict();

export const complaintIdParamsSchema = z.object({ complaintId: uuid });

export const complaintListQuerySchema = z.object({
  status: statusEnum.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const complaintMessageSchema = z
  .object({
    body: z.string().trim().min(1).max(4000),
    documentIds: z.array(uuid).max(20).optional(),
  })
  .strict();

export const complaintTransitionSchema = z
  .object({
    to: statusEnum,
    reason: z.string().trim().max(1000).optional(),
    resolutionSummary: z.string().trim().max(4000).optional(),
  })
  .strict();

export const complaintCorrectiveActionSchema = z
  .object({ action: z.string().trim().min(1).max(4000) })
  .strict();

export const complaintInternalNoteSchema = z
  .object({ body: z.string().trim().min(1).max(4000) })
  .strict();

export const complaintAssignSchema = z
  .object({ adminUserId: uuid })
  .strict();

export type CreateComplaintInput = z.infer<typeof createComplaintSchema>;
export type ComplaintMessageInput = z.infer<typeof complaintMessageSchema>;
export type ComplaintTransitionInput = z.infer<typeof complaintTransitionSchema>;
export type ComplaintCorrectiveActionInput = z.infer<typeof complaintCorrectiveActionSchema>;
export type ComplaintInternalNoteInput = z.infer<typeof complaintInternalNoteSchema>;