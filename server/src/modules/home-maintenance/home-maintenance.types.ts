// Home Maintenance & Repairs operations domain types (Task 13.12).

export type HomeMaintenanceStatus =
  | 'confirmed'
  | 'inspection_scheduled'
  | 'awaiting_inspection'
  | 'inspection_in_progress'
  | 'awaiting_customer_approval'
  | 'work_scheduled'
  | 'assigned'
  | 'in_progress'
  | 'awaiting_parts'
  | 'awaiting_customer_decision'
  | 'quality_check'
  | 'completed_pending_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed'
  | 'exception';

export type HomeMaintenanceActor = 'customer' | 'provider';

export interface HomeMaintenanceJob {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: HomeMaintenanceStatus;
  categoryId: string;
  domain: string;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  serviceAddress: string | null;
  agreedPrice: string;
  currency: string;
  scope: Record<string, unknown>;
  inspectionRequired: boolean;
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

export interface HomeMaintenanceHistoryEntry {
  id: string;
  action: string;
  previousStatus: HomeMaintenanceStatus | null;
  newStatus: HomeMaintenanceStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface HomeMaintenanceInspection {
  id: string;
  jobId: string;
  technicianUserId: string | null;
  status: string;
  scheduledAt: string | null;
  findings: string | null;
  diagnosis: string | null;
  recommendedWork: string | null;
  estimatedDurationMinutes: number | null;
  materialsRequired: string | null;
  safetyConcerns: string | null;
  customerVisibleReport: string | null;
  internalNotes: string | null;
  photoDocumentIds: string[];
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface HomeMaintenanceWorkPlan {
  id: string;
  jobId: string;
  summary: string;
  steps: unknown[];
  scheduledAt: string | null;
  status: string;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface HomeMaintenancePart {
  id: string;
  jobId: string;
  description: string;
  quantity: string;
  unit: string;
  modelSpec: string | null;
  suppliedBy: string;
  proposedCost: string | null;
  approvalStatus: string;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
}

export interface HomeMaintenanceStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface HomeMaintenanceAmendment {
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

export interface HomeMaintenanceException {
  id: string;
  jobId: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface HomeMaintenanceAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface HomeMaintenanceJobDetail extends HomeMaintenanceJob {
  history: HomeMaintenanceHistoryEntry[];
  inspections: HomeMaintenanceInspection[];
  workPlans: HomeMaintenanceWorkPlan[];
  parts: HomeMaintenancePart[];
  staff: HomeMaintenanceStaffAssignment[];
  amendments: HomeMaintenanceAmendment[];
  exceptions: HomeMaintenanceException[];
  attachments: HomeMaintenanceAttachment[];
}