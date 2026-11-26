// Laundry operations domain types (Task 13.8).

export type LaundryCollectionStatus =
  | 'confirmed'
  | 'collection_scheduled'
  | 'collected'
  | 'received_at_facility'
  | 'inspection'
  | 'awaiting_customer_approval'
  | 'processing'
  | 'washing'
  | 'drying'
  | 'ironing'
  | 'folding'
  | 'quality_check'
  | 'ready_for_return'
  | 'out_for_delivery'
  | 'delivered'
  | 'awaiting_customer_confirmation'
  | 'completed'
  | 'cancelled'
  | 'failed'
  | 'exception';

export type LaundryActor = 'customer' | 'provider' | 'provider_staff';

export type LaundryFulfilmentMode = 'dropoff' | 'collection' | 'both';

export interface LaundryOrderScope {
  services?: string[];
  capabilities?: string[];
  specialInstructions?: string;
  preferredCollectionDate?: string;
  preferredWindowStart?: string;
  preferredWindowEnd?: string;
  requestDetails?: Record<string, unknown>;
  [key: string]: unknown;
}

export interface LaundryOrder {
  id: string;
  serviceRequestId: string;
  quotationId: string;
  quotationVersion: number;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  status: LaundryCollectionStatus;
  fulfilmentMode: LaundryFulfilmentMode;
  collectionLocationId: string | null;
  collectionAddress: string | null;
  returnLocationId: string | null;
  returnAddress: string | null;
  propertyId: string | null;
  unitId: string | null;
  tenancyId: string | null;
  agreedPrice: string;
  currency: string;
  scope: LaundryOrderScope;
  checklist: Record<string, boolean>;
  collectionDate: string | null;
  collectionWindowStart: string | null;
  collectionWindowEnd: string | null;
  returnDate: string | null;
  returnWindowStart: string | null;
  returnWindowEnd: string | null;
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

export interface LaundryOrderHistoryEntry {
  id: string;
  action: string;
  previousStatus: LaundryCollectionStatus | null;
  newStatus: LaundryCollectionStatus | null;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface LaundryOrderItem {
  id: string;
  laundryOrderId: string;
  itemCategory: string;
  description: string | null;
  quantity: number;
  customerReference: string | null;
  conditionAtIntake: string | null;
  stainsDamageNotes: string | null;
  specialHandling: string | null;
  processingInstructions: string | null;
  itemStatus: string;
  returnConditionNotes: string | null;
  handoverNotes: string | null;
  photoDocumentIds: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface LaundryOrderInspection {
  id: string;
  laundryOrderId: string;
  itemId: string | null;
  reportedBy: string;
  result: string;
  declaredQuantity: number | null;
  receivedQuantity: number | null;
  description: string | null;
  requiresCustomerApproval: boolean;
  approvalStatus: string;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: Date;
}

export interface LaundryOrderStaffAssignment {
  id: string;
  userId: string;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface LaundryOrderHandover {
  id: string;
  laundryOrderId: string;
  kind: 'collection' | 'return';
  status: string;
  locationId: string | null;
  address: string | null;
  scheduledAt: string | null;
  windowStart: string | null;
  windowEnd: string | null;
  notes: string | null;
  proofDocumentIds: string[];
  confirmedBy: string | null;
  confirmedAt: string | null;
  createdAt: Date;
}

export interface LaundryOrderAmendment {
  id: string;
  laundryOrderId: string;
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

export interface LaundryOrderException {
  id: string;
  laundryOrderId: string;
  reportedBy: string;
  type: string;
  description: string;
  createdAt: Date;
}

export interface LaundryOrderAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface LaundryOrderDetail extends LaundryOrder {
  history: LaundryOrderHistoryEntry[];
  items: LaundryOrderItem[];
  inspections: LaundryOrderInspection[];
  staff: LaundryOrderStaffAssignment[];
  handovers: LaundryOrderHandover[];
  amendments: LaundryOrderAmendment[];
  exceptions: LaundryOrderException[];
  attachments: LaundryOrderAttachment[];
}