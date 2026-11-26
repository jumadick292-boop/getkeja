// Moving & relocation operations domain types (Task 13.6).

export type MovingJobStatus =
  | 'confirmed'
  | 'awaiting_customer_details'
  | 'preparation'
  | 'ready_for_move'
  | 'in_progress'
  | 'arrived_at_destination'
  | 'unloading'
  | 'awaiting_customer_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed';

export type MovingAssessmentStatus =
  | 'requested'
  | 'accepted'
  | 'declined'
  | 'completed'
  | 'cancelled';

export type MovingChangeStatus = 'pending' | 'accepted' | 'rejected' | 'withdrawn';

export type MovingActor = 'customer' | 'provider' | 'provider_staff' | 'system';

export interface MovingJobScope {
  serviceCategories: string[];
  capabilities: string[];
  inventory?: string;
  accessInstructions?: string;
  notes?: string;
  [key: string]: unknown;
}

export interface MovingJobChecklist {
  [itemId: string]: boolean;
}

export interface MovingJob {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: MovingJobStatus;
  originLocationId: string | null;
  destinationLocationId: string | null;
  originAddress: string | null;
  destinationAddress: string | null;
  originContactInstructions: string | null;
  destinationContactInstructions: string | null;
  originBuildingName: string | null;
  originFloor: string | null;
  originLiftAvailable: boolean | null;
  originAccessNotes: string | null;
  destinationBuildingName: string | null;
  destinationFloor: string | null;
  destinationLiftAvailable: boolean | null;
  destinationAccessNotes: string | null;
  agreedMoveDate: string | null;
  agreedWindowStart: string | null;
  agreedWindowEnd: string | null;
  scope: MovingJobScope;
  agreedPrice: string;
  currency: string;
  checklist: MovingJobChecklist;
  tenancyId: string | null;
  propertyId: string | null;
  unitId: string | null;
  completionNotes: string | null;
  completionSubmittedAt: string | null;
  completionOutstandingIssue: boolean;
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

export interface MovingJobHistoryEntry {
  id: string;
  action: string;
  previousStatus: MovingJobStatus | null;
  newStatus: MovingJobStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface MovingJobStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string;
  createdAt: Date;
  revokedAt: string | null;
}

export interface MovingJobAssessment {
  id: string;
  movingJobId: string;
  requestedBy: string;
  assignedStaffUserId: string | null;
  status: MovingAssessmentStatus;
  proposedAt: string | null;
  locationId: string | null;
  locationAddress: string | null;
  providerNotes: string | null;
  customerNotes: string | null;
  outcome: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface MovingJobScheduleChange {
  id: string;
  movingJobId: string;
  requestedBy: string;
  previousDate: string | null;
  proposedDate: string;
  proposedWindowStart: string | null;
  proposedWindowEnd: string | null;
  reason: string | null;
  status: MovingChangeStatus;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: Date;
}

export interface MovingJobAmendment {
  id: string;
  movingJobId: string;
  proposedBy: string;
  reason: string;
  revisedScope: Record<string, unknown>;
  additionalCost: string;
  currency: string;
  status: MovingChangeStatus;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: Date;
}

export interface MovingJobAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface MovingJobDetail extends MovingJob {
  history: MovingJobHistoryEntry[];
  staff: MovingJobStaffAssignment[];
  assessments: MovingJobAssessment[];
  scheduleChanges: MovingJobScheduleChange[];
  amendments: MovingJobAmendment[];
  attachments: MovingJobAttachment[];
}