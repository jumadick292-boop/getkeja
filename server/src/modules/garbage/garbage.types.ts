// Garbage collection operations domain types (Task 13.7).

export type GarbageCollectionStatus =
  | 'confirmed'
  | 'scheduled'
  | 'provider_assigned'
  | 'en_route'
  | 'arrived'
  | 'collecting'
  | 'completed'
  | 'awaiting_customer_confirmation'
  | 'cancelled'
  | 'missed'
  | 'failed'
  | 'rescheduled';

export type GarbageAgreementStatus =
  | 'proposed'
  | 'active'
  | 'suspended'
  | 'completed'
  | 'cancelled';

export type GarbageOccurrenceStatus =
  | 'scheduled'
  | 'completed'
  | 'missed'
  | 'cancelled'
  | 'failed';

export type GarbageActor = 'customer' | 'provider' | 'provider_staff' | 'system';

export interface GarbageJobScope {
  wasteCategory?: string;
  estimatedQuantity?: string;
  binCount?: number;
  accessInstructions?: string;
  specialInstructions?: string;
  [key: string]: unknown;
}

export interface GarbageJob {
  id: string;
  serviceRequestId: string | null;
  recurringOccurrenceId: string | null;
  agreementId: string | null;
  quotationId: string | null;
  quotationVersion: number | null;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: GarbageCollectionStatus;
  collectionLocationId: string | null;
  collectionAddress: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  wasteCategory: string | null;
  estimatedQuantity: string | null;
  binCount: number | null;
  agreedPrice: string;
  currency: string;
  scope: GarbageJobScope;
  checklist: Record<string, boolean>;
  scheduledDate: string | null;
  windowStart: string | null;
  windowEnd: string | null;
  completionNotes: string | null;
  completionSubmittedAt: string | null;
  completionOutstandingIssue: boolean;
  customerConfirmationStatus: string;
  customerConfirmationNotes: string | null;
  customerConfirmationAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
  missedAt: string | null;
  missedReason: string | null;
  failedAt: string | null;
  failureReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface GarbageJobHistoryEntry {
  id: string;
  action: string;
  previousStatus: GarbageCollectionStatus | null;
  newStatus: GarbageCollectionStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface GarbageJobStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  createdAt: Date;
  revokedAt: string | null;
}

export interface GarbageJobException {
  id: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface GarbageJobAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface GarbageJobDetail extends GarbageJob {
  history: GarbageJobHistoryEntry[];
  staff: GarbageJobStaffAssignment[];
  exceptions: GarbageJobException[];
  attachments: GarbageJobAttachment[];
}

export interface GarbageRecurringAgreement {
  id: string;
  serviceRequestId: string | null;
  quotationId: string | null;
  providerProfileId: string;
  customerUserId: string;
  providerOrganisationId: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  status: GarbageAgreementStatus;
  frequency: string;
  intervalDays: number | null;
  daysOfWeek: number[];
  windowStart: string | null;
  windowEnd: string | null;
  startDate: string;
  endDate: string | null;
  agreedAmount: string;
  currency: string;
  billingFrequency: string | null;
  wasteCategory: string | null;
  scope: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

export interface GarbageRecurringOccurrence {
  id: string;
  agreementId: string;
  periodKey: string;
  scheduledDate: string;
  windowStart: string | null;
  windowEnd: string | null;
  status: GarbageOccurrenceStatus;
  generatedAt: Date;
}