// Cleaning & Property Care operations domain types (Task 13.13).

export type CleaningOperationStatus =
  | 'confirmed'
  | 'assessment_scheduled'
  | 'awaiting_assessment'
  | 'assessment_in_progress'
  | 'scheduled'
  | 'assigned'
  | 'in_progress'
  | 'awaiting_supplies'
  | 'awaiting_customer_decision'
  | 'quality_check'
  | 'completed_pending_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed'
  | 'exception';

export type CleaningActor = 'customer' | 'provider';

export interface CleaningJob {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: CleaningOperationStatus;
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

export interface CleaningHistoryEntry {
  id: string;
  action: string;
  previousStatus: CleaningOperationStatus | null;
  newStatus: CleaningOperationStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface CleaningAssessment {
  id: string;
  jobId: string;
  assessorUserId: string | null;
  status: string;
  scheduledAt: string | null;
  findings: string | null;
  scopeAssessment: string | null;
  recommendedTasks: string | null;
  estimatedDurationMinutes: number | null;
  suppliesRequired: string | null;
  safetyConcerns: string | null;
  customerVisibleReport: string | null;
  internalNotes: string | null;
  photoDocumentIds: string[];
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CleaningChecklistItem {
  id: string;
  label: string;
  done: boolean;
}

export interface CleaningChecklist {
  id: string;
  jobId: string;
  title: string;
  items: CleaningChecklistItem[];
  completedCount: number;
  totalCount: number;
  status: string;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CleaningArea {
  id: string;
  jobId: string;
  name: string;
  areaType: string;
  approximateSize: string | null;
  status: string;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface CleaningMaterial {
  id: string;
  jobId: string;
  description: string;
  quantity: string;
  unit: string;
  suppliedBy: string;
  proposedCost: string | null;
  approvalStatus: string;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface CleaningStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface CleaningAmendment {
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

export interface CleaningException {
  id: string;
  jobId: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface CleaningAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface CleaningJobDetail extends CleaningJob {
  history: CleaningHistoryEntry[];
  assessments: CleaningAssessment[];
  checklists: CleaningChecklist[];
  areas: CleaningArea[];
  materials: CleaningMaterial[];
  staff: CleaningStaffAssignment[];
  amendments: CleaningAmendment[];
  exceptions: CleaningException[];
  attachments: CleaningAttachment[];
}