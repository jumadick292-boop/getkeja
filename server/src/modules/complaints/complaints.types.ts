// Provider complaints domain types (Task 13.16).

export type ComplaintStatus =
  | 'submitted'
  | 'acknowledged'
  | 'under_review'
  | 'awaiting_customer_information'
  | 'awaiting_provider_response'
  | 'resolution_proposed'
  | 'resolved'
  | 'escalated'
  | 'closed';

export type ComplaintActor = 'customer' | 'provider' | 'admin';

export interface ComplaintMessage {
  id: string;
  complaintId: string;
  authorUserId: string;
  authorRole: string;
  body: string;
  documentIds: string[];
  createdAt: Date;
}

export interface ComplaintCorrectiveAction {
  id: string;
  complaintId: string;
  recordedBy: string;
  action: string;
  createdAt: Date;
}

export interface ComplaintInternalNote {
  id: string;
  complaintId: string;
  authorUserId: string;
  body: string;
  createdAt: Date;
}

export interface ComplaintHistoryEntry {
  id: string;
  previousStatus: ComplaintStatus | null;
  newStatus: ComplaintStatus;
  changedBy: string;
  reason: string | null;
  createdAt: Date;
}

export interface Complaint {
  id: string;
  resourceDomain: string;
  resourceId: string;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  reasonId: string;
  description: string;
  status: ComplaintStatus;
  assignedAdminUserId: string | null;
  resolutionSummary: string | null;
  resolvedAt: string | null;
  closedAt: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ComplaintDetail extends Complaint {
  messages: ComplaintMessage[];
  correctiveActions: ComplaintCorrectiveAction[];
  history: ComplaintHistoryEntry[];
  internalNotes?: ComplaintInternalNote[];
}