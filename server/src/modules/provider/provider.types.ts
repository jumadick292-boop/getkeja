// Provider domain shared types.

export type ProviderCategory =
  | 'moving_service_provider'
  | 'garbage_collection_provider'
  | 'laundry_service_provider';

export const PROVIDER_CATEGORIES: ProviderCategory[] = [
  'moving_service_provider',
  'garbage_collection_provider',
  'laundry_service_provider',
];

// Resolved provider context for an authenticated user. Derived from owned
// specialized_profiles and active organization memberships — never from role
// names alone.
export interface ProviderContext {
  userId: string;
  // Approved + active individual specialized_profile ids (all categories).
  individualProfileIds: string[];
  // Approved + active specialized_profile ids reached through active orgs.
  organizationProfileIds: string[];
  // Union of the above — profiles this user may act as.
  effectiveProfileIds: string[];
  // Approved profile ids grouped by category (for discovery eligibility).
  approvedByCategory: Record<ProviderCategory, string[]>;
  // Active garbage_providers reachable via org membership or ownership.
  garbageProviderIds: string[];
  // Active organization ids the user belongs to.
  organizationIds: string[];
  // Explicitly selected active organization (optional), validated to be one
  // of organizationIds.
  activeOrganizationId: string | null;
  isProvider: boolean;
}

// Normalized inbox/detail row across the three domains.
export interface ProviderRequestRow {
  id: string;
  serviceType: 'moving' | 'garbage' | 'laundry';
  status: string;
  providerId: string | null;
  propertyId: string;
  unitId: string | null;
  preferredAt: Date | null;
  createdAt: Date;
  summary: string | null;
  category: string | null;
  providerName: string | null;
  assigned: boolean;
  // Location / contact fields are populated by the service layer and masked
  // according to authorization.
  propertyCity?: string | null;
  propertyCounty?: string | null;
  pickupLocation?: string | null;
  destinationLocation?: string | null;
  contactName?: string | null;
  contactPhone?: string | null;
  contactEmail?: string | null;
}

export interface ProviderDashboardCounts {
  newEligibleRequests: number;
  assignedRequests: number;
  pendingResponses: number;
  acceptedJobs: number;
  upcomingJobs: number;
  activeJobs: number;
  completedJobs: number;
  cancelledJobs: number;
  pendingQuotations: number;
}