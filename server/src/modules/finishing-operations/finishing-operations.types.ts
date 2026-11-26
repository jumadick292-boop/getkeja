// Finishing & Building Services operations domain types (Task 13.15).

export type FinishingOperationStatus =
  | 'confirmed'
  | 'assessment_scheduled'
  | 'awaiting_assessment'
  | 'assessment_in_progress'
  | 'plan_prepared'
  | 'awaiting_customer_approval'
  | 'scheduled'
  | 'assigned'
  | 'materials_prepared'
  | 'in_progress'
  | 'awaiting_materials'
  | 'quality_inspection'
  | 'awaiting_handover'
  | 'completed_pending_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed'
  | 'exception';

export type FinishingActor = 'customer' | 'provider';

export interface FinishingJob {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: FinishingOperationStatus;
  categoryId: string;
  domain: string;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  serviceAddress: string | null;
  agreedPrice: string;
  currency: string;
  scope: Record<string, unknown>;
  assessmentRequired: boolean;
  customerApprovalRequired: boolean;
  completionNotes: string | null;
  completionSubmittedAt: string | null;
  customerConfirmationStatus: string;
  customerConfirmationNotes: string | null;
  customerConfirmationAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
  failedAt: string | null;
  failureReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface FinishingHistoryEntry {
  id: string;
  action: string;
  previousStatus: FinishingOperationStatus | null;
  newStatus: FinishingOperationStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface FinishingAssessment {
  id: string;
  jobId: string;
  assessorUserId: string | null;
  status: string;
  scheduledAt: string | null;
  findings: string | null;
  measurements: string | null;
  siteReadiness: string | null;
  recommendedScope: string | null;
  estimatedDurationMinutes: number | null;
  safetyConcerns: string | null;
  customerVisibleReport: string | null;
  internalNotes: string | null;
  photoDocumentIds: string[];
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface FinishingPlan {
  id: string;
  jobId: string;
  summary: string;
  steps: unknown[];
  deliverables: string | null;
  scheduledAt: string | null;
  status: string;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface FinishingMaterial {
  id: string;
  jobId: string;
  description: string;
  category: string;
  quantity: string;
  unit: string;
  finishOrSpec: string | null;
  suppliedBy: string;
  proposedCost: string | null;
  approvalStatus: string;
  installStatus: string;
  customerVisible: boolean;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface FinishingInspection {
  id: string;
  jobId: string;
  name: string;
  outcome: string;
  details: string | null;
  correctiveWork: string | null;
  customerVisible: boolean;
  inspectedBy: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface FinishingStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface FinishingAmendment {
  id: string;
  jobId: string;
  proposedBy: string;
  reason: string;
  revisedScope: Record<string, unknown>;
  additionalCost: string;
  currency: string;
  status: string;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: Date;
}

export interface FinishingException {
  id: string;
  jobId: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface FinishingAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface FinishingJobDetail extends FinishingJob {
  history: FinishingHistoryEntry[];
  assessments: FinishingAssessment[];
  plans: FinishingPlan[];
  materials: FinishingMaterial[];
  inspections: FinishingInspection[];
  staff: FinishingStaffAssignment[];
  amendments: FinishingAmendment[];
  exceptions: FinishingException[];
  attachments: FinishingAttachment[];
}