// Provider reviews domain types (Task 13.16).

export type ReviewStatus = 'published' | 'pending_moderation' | 'hidden' | 'removed';

export interface ProviderReview {
  id: string;
  resourceDomain: string;
  resourceId: string;
  customerUserId: string;
  providerProfileId: string;
  providerOrganisationId: string | null;
  overallRating: number;
  comment: string | null;
  qualityRating: number | null;
  professionalismRating: number | null;
  timelinessRating: number | null;
  valueRating: number | null;
  status: ReviewStatus;
  response: string | null;
  responseAt: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ReviewRatingSummary {
  providerProfileId: string;
  averageRating: number | null;
  reviewCount: number;
  distribution: { rating: number; count: number }[];
}