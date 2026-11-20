export type ProfileCategory =
  | 'house_seeker'
  | 'tenant'
  | 'landlord'
  | 'real_estate_agent'
  | 'agency'
  | 'property_manager'
  | 'caretaker'
  | 'moving_service_provider'
  | 'garbage_collection_provider'
  | 'laundry_service_provider';

export type ProfileVerificationStatus =
  | 'draft'
  | 'incomplete'
  | 'submitted'
  | 'pending_review'
  | 'approved'
  | 'rejected'
  | 'suspended';

export interface UserProfile {
  id: string;
  userId: string;
  displayName: string | null;
  profilePhotoUrl: string | null;
  bio: string | null;
  phoneNumber: string | null;
  websiteUrl: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface SpecializedProfile {
  id: string;
  userId: string;
  profileCategory: ProfileCategory;
  userProfileId: string | null;
  organisationId: string | null;
  fullName: string | null;
  displayName: string | null;
  profilePhotoUrl: string | null;
  businessName: string | null;
  businessLogoUrl: string | null;
  description: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  websiteUrl: string | null;
  verificationStatus: ProfileVerificationStatus;
  submittedAt: Date | null;
  reviewedAt: Date | null;
  reviewedBy: string | null;
  rejectionReason: string | null;
  completionPercentage: number;
  missingFields: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface ProviderProfileExtension {
  id: string;
  specializedProfileId: string;
  serviceTypes: string[];
  serviceDescription: string | null;
  operatingStatus: string;
  registrationNumber: string | null;
  taxId: string | null;
  businessHours: Record<string, unknown> | null;
  available247: boolean;
  emergencyService: boolean;
  insuranceInfo: Record<string, unknown> | null;
  certifications: Record<string, unknown> | null;
  bookingContactEmail: string | null;
  bookingContactPhone: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ProfileVerificationRecord {
  id: string;
  specializedProfileId: string;
  previousStatus: ProfileVerificationStatus | null;
  newStatus: ProfileVerificationStatus;
  reviewedBy: string | null;
  reviewerRole: string | null;
  documentsSubmitted: string[];
  documentsReviewed: string[];
  decision: string;
  reviewNotes: string | null;
  rejectionReason: string | null;
  requestedChanges: string | null;
  submittedAt: Date;
  reviewedAt: Date | null;
  createdAt: Date;
}

export interface ProfileCompletionMetadata {
  id: string;
  specializedProfileId: string;
  totalRequiredFields: number;
  completedFields: number;
  completionPercentage: number;
  missingFields: string[];
  optionalFields: string[];
  isSubmitted: boolean;
  submittedAt: Date | null;
  canSubmit: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ProfileWithCompletion extends SpecializedProfile {
  completion?: ProfileCompletionMetadata | null;
}

export interface ProfileWithVerification extends SpecializedProfile {
  verificationRecords?: ProfileVerificationRecord[];
}

export interface FullProfile extends SpecializedProfile {
  completion?: ProfileCompletionMetadata | null;
  verificationRecords?: ProfileVerificationRecord[];
  providerExtension?: ProviderProfileExtension | null;
}