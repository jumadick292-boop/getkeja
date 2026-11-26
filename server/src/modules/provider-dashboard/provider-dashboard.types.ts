// Provider dashboard domain types (Task 13.16).

export interface ProviderDashboardFilters {
  domain?: string;
  categoryId?: string;
  status?: string;
  from?: string;
  to?: string;
}

export interface ProviderDashboardMetrics {
  newEligibleRequests: number;
  pendingQuotations: number;
  acceptedQuotations: number;
  activeJobs: number;
  scheduledToday: number;
  upcomingJobs: number;
  awaitingConfirmation: number;
  overdueOrInterrupted: number;
  completedJobs: number;
  cancelledJobs: number;
  unresolvedComplaints: number;
  averageRating: number | null;
  reviewCount: number;
}

export interface DomainMetric {
  domain: string;
  active: number;
  completed: number;
  cancelled: number;
  awaitingConfirmation: number;
}

export interface ProviderDashboard {
  scope: {
    isOrganization: boolean;
    organizationId: string | null;
    profileCount: number;
  };
  metrics: ProviderDashboardMetrics;
  byDomain: DomainMetric[];
  filters: ProviderDashboardFilters;
}

export interface StaffWorkloadEntry {
  userId: string;
  assignedJobs: number;
  activeJobs: number;
  completedJobs: number;
}

export interface ProviderReportRow {
  period: string;
  requests: number;
  quotations: number;
  accepted: number;
  jobsCreated: number;
  jobsCompleted: number;
  jobsCancelled: number;
}

export interface CategoryPerformanceRow {
  domain: string;
  categoryId: string;
  jobs: number;
  completed: number;
  cancelled: number;
  averageRating: number | null;
  reviewCount: number;
}