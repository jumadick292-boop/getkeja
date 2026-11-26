// Zod validation for the rental application workflow API.
import { z } from 'zod';

const uuid = z.string().uuid();
const dateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD').optional().nullable();

export const applicationIdParamSchema = z.object({
  applicationId: uuid,
});

export const documentIdParamSchema = z.object({
  documentId: uuid,
});

// Create / save-draft body (applicant). `id` updates an existing draft.
export const saveApplicationSchema = z.object({
  id: uuid.optional(),
  propertyId: uuid,
  listingId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  preferredStartDate: dateStr,
  preferredEndDate: dateStr,
  proposedRentAmount: z.coerce.number().nonnegative().max(100_000_000).optional(),
  employerName: z.string().trim().max(255).optional().nullable(),
  employerContact: z.string().trim().max(255).optional().nullable(),
  monthlyIncome: z.coerce.number().nonnegative().max(1_000_000_000).optional(),
  previousLandlordName: z.string().trim().max(255).optional().nullable(),
  previousLandlordContact: z.string().trim().max(255).optional().nullable(),
  guarantorName: z.string().trim().max(255).optional().nullable(),
  guarantorEmail: z.string().trim().max(255).optional().nullable(),
  guarantorPhone: z.string().trim().max(50).optional().nullable(),
  guarantorRelationship: z.string().trim().max(50).optional().nullable(),
});

export const submitApplicationSchema = z.object({
  propertyId: uuid,
  listingId: uuid.optional().nullable(),
  unitId: uuid.optional().nullable(),
  preferredStartDate: dateStr,
  preferredEndDate: dateStr,
  proposedRentAmount: z.coerce.number().nonnegative().max(100_000_000).optional(),
  employerName: z.string().trim().max(255).optional().nullable(),
  employerContact: z.string().trim().max(255).optional().nullable(),
  monthlyIncome: z.coerce.number().nonnegative().max(1_000_000_000).optional(),
  previousLandlordName: z.string().trim().max(255).optional().nullable(),
  previousLandlordContact: z.string().trim().max(255).optional().nullable(),
  guarantorName: z.string().trim().max(255).optional().nullable(),
  guarantorEmail: z.string().trim().max(255).optional().nullable(),
  guarantorPhone: z.string().trim().max(50).optional().nullable(),
  guarantorRelationship: z.string().trim().max(50).optional().nullable(),
});

export const resubmitApplicationSchema = z.object({
  preferredStartDate: dateStr,
  preferredEndDate: dateStr,
  proposedRentAmount: z.coerce.number().nonnegative().max(100_000_000).optional(),
  employerName: z.string().trim().max(255).optional().nullable(),
  employerContact: z.string().trim().max(255).optional().nullable(),
  monthlyIncome: z.coerce.number().nonnegative().max(1_000_000_000).optional(),
  guarantorName: z.string().trim().max(255).optional().nullable(),
  guarantorPhone: z.string().trim().max(50).optional().nullable(),
  responseNote: z.string().trim().max(2000).optional().nullable(),
});

// Manager transition actions (approve handled separately for onboarding terms).
export const transitionActionSchema = z.object({
  action: z.enum([
    'start_review',
    'request_information',
    'shortlist',
    'send_proposal',
    'start_negotiation',
    'reject',
    'cancel',
  ]),
  reason: z.string().trim().max(2000).optional().nullable(),
});

export const approveApplicationSchema = z.object({
  reason: z.string().trim().max(2000).optional().nullable(),
  approvedRentAmount: z.coerce.number().positive().optional(),
  approvedDepositAmount: z.coerce.number().nonnegative().optional(),
  approvedStartDate: dateStr,
  approvedEndDate: dateStr,
});

export const addNoteSchema = z.object({
  note: z.string().trim().min(1).max(5000),
});

export const listApplicationsQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  status: z
    .enum([
      'draft',
      'submitted',
      'under_review',
      'information_requested',
      'resubmitted',
      'shortlisted',
      'proposal_sent',
      'negotiation',
      'approved',
      'rejected',
      'withdrawn',
      'expired',
      'cancelled',
      'pending_documents',
      'pending_payment',
    ])
    .optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const attachDocumentSchema = z.object({
  category: z.string().trim().max(100).optional(),
});

export type SaveApplicationInput = z.infer<typeof saveApplicationSchema>;
export type SubmitApplicationInput = z.infer<typeof submitApplicationSchema>;
export type ResubmitApplicationInput = z.infer<typeof resubmitApplicationSchema>;
export type TransitionActionInput = z.infer<typeof transitionActionSchema>;
export type ApproveApplicationInput = z.infer<typeof approveApplicationSchema>;
export type ListApplicationsQuery = z.infer<typeof listApplicationsQuerySchema>;