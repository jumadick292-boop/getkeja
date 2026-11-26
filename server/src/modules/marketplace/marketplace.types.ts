// Service marketplace domain types (Task 13.5).
// One unified request + quotation engine shared by every service category.

export type ServiceDomain =
  | 'moving'
  | 'garbage'
  | 'laundry'
  | 'cleaning'
  | 'plumbing'
  | 'electrical'
  | 'hvac'
  | 'pest_control'
  | 'landscaping'
  | 'carpentry'
  | 'painting'
  | 'roofing'
  | 'flooring'
  | 'tiling'
  | 'appliances'
  | 'networking'
  | 'solar'
  | 'general';

export type ServiceRequestStatus =
  | 'open'
  | 'quoted'
  | 'accepted'
  | 'in_progress'
  | 'completed'
  | 'cancelled'
  | 'expired';

export type ServiceQuotationStatus =
  | 'submitted'
  | 'revised'
  | 'accepted'
  | 'declined'
  | 'withdrawn'
  | 'superseded'
  | 'expired';

export type LifecycleActor = 'customer' | 'provider' | 'system';

export interface ServiceCategory {
  id: string;
  domain: ServiceDomain;
  name: string;
  description: string | null;
  isActive: boolean;
  sortOrder: number;
}

export interface ServiceRequestDetails {
  rooms?: number;
  areaSqM?: number;
  frequency?: 'one_time' | 'weekly' | 'fortnightly' | 'monthly';
  urgency?: 'standard' | 'urgent';
  brand?: string;
  model?: string;
  accessInstructions?: string;
  notes?: string;
  // Networking (Wi-Fi / Internet)
  propertyUse?: 'residential' | 'commercial';
  propertyType?: string;
  coverageAreaSqM?: number;
  existingEquipment?: string;
  jobType?: 'new_installation' | 'troubleshooting' | 'maintenance';
  preferredDate?: string;
  photos?: string[];
  // Solar
  existingSystem?: string;
  powerRequirementsKw?: number;
  existingInverterBatteryPanel?: string;
  // Painting & decoration
  surface?: 'interior' | 'exterior';
  surfacePreparation?: string;
  finishType?: 'painting' | 'wallpaper' | 'decorative';
}

export interface ServiceRequestAttachment {
  id: string;
  documentId: string;
  kind: string;
  uploadedBy: string;
  createdAt: Date;
}

export interface ServiceQuotationItem {
  id: string;
  description: string;
  quantity: string;
  unitPrice: string;
  amount: string;
  sortOrder: number;
}

export interface ServiceQuotation {
  id: string;
  serviceRequestId: string;
  providerProfileId: string;
  providerName: string | null;
  versionNumber: number;
  status: ServiceQuotationStatus;
  currency: string;
  subtotalAmount: string;
  totalAmount: string;
  estimatedStart: string | null;
  estimatedCompletion: string | null;
  validUntil: string;
  terms: string | null;
  notes: string | null;
  supersedesId: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
  items?: ServiceQuotationItem[];
}

export interface ServiceRequestHistoryEntry {
  id: string;
  action: string;
  previousStatus: ServiceRequestStatus | null;
  newStatus: ServiceRequestStatus;
  changedBy: string;
  changeReason: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface ServiceRequest {
  id: string;
  categoryId: string;
  categoryName: string;
  domain: ServiceDomain;
  customerUserId: string;
  status: ServiceRequestStatus;
  title: string | null;
  description: string;
  details: ServiceRequestDetails;
  savedLocationId: string | null;
  serviceAddress: string | null;
  serviceCounty: string | null;
  serviceCity: string | null;
  serviceLatitude: string | null;
  serviceLongitude: string | null;
  preferredDateTime: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  acceptedQuotationId: string | null;
  assignedProviderId: string | null;
  scheduledAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
  quotations?: ServiceQuotation[];
  attachments?: ServiceRequestAttachment[];
  history?: ServiceRequestHistoryEntry[];
}