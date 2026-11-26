// Installation & Technical Services operations domain types (Task 13.14).

export type InstallationOperationStatus =
  | 'confirmed'
  | 'assessment_scheduled'
  | 'awaiting_assessment'
  | 'assessment_in_progress'
  | 'plan_prepared'
  | 'awaiting_customer_approval'
  | 'scheduled'
  | 'assigned'
  | 'in_progress'
  | 'awaiting_equipment'
  | 'testing'
  | 'awaiting_handover'
  | 'completed_pending_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed'
  | 'exception';

export type InstallationActor = 'customer' | 'provider';

export interface InstallationJob {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: InstallationOperationStatus;
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

export interface InstallationHistoryEntry {
  id: string;
  action: string;
  previousStatus: InstallationOperationStatus | null;
  newStatus: InstallationOperationStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface InstallationAssessment {
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

export interface InstallationPlan {
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

export interface InstallationEquipment {
  id: string;
  jobId: string;
  description: string;
  category: string;
  quantity: string;
  unit: string;
  serialOrId: string | null;
  suppliedBy: string;
  proposedCost: string | null;
  approvalStatus: string;
  installStatus: string;
  customerVisible: boolean;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface InstallationTest {
  id: string;
  jobId: string;
  name: string;
  outcome: string;
  details: string | null;
  correctiveWork: string | null;
  customerVisible: boolean;
  testedBy: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface InstallationStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface InstallationAmendment {
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

export interface InstallationException {
  id: string;
  jobId: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface InstallationAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface InstallationJobDetail extends InstallationJob {
  history: InstallationHistoryEntry[];
  assessments: InstallationAssessment[];
  plans: InstallationPlan[];
  equipment: InstallationEquipment[];
  tests: InstallationTest[];
  staff: InstallationStaffAssignment[];
  amendments: InstallationAmendment[];
  exceptions: InstallationException[];
  attachments: InstallationAttachment[];
}