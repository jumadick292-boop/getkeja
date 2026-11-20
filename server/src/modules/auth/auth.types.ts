export interface AuthUser {
  id: string;
  email: string;
  name: string | null;
  firstName: string | null;
  lastName: string | null;
  roles: string[];
  isActive: boolean;
  isSuspended: boolean;
  isLocked: boolean;
  isDeactivated: boolean;
  emailVerified: boolean;
  phoneVerified: boolean;
  mfaEnabled: boolean;
  mfaEnrolledAt: Date | null;
  lastMfaVerifiedAt: Date | null;
  mfaEnrollmentRequired: boolean;
  accountStatus: AccountStatus;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserLoginIdentity {
  id: string;
  userId: string;
  provider: 'email' | 'phone' | 'google';
  identifier: string;
  passwordHash: string | null;
  verifiedAt: Date | null;
  isPrimary: boolean;
  metadata: Record<string, unknown> | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Role {
  id: string;
  name: string;
  description: string | null;
  isSystem: boolean;
  isPubliclyAssignable: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface EmailVerificationToken {
  id: string;
  userId: string;
  loginIdentityId: string;
  tokenHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  maxAttempts: number;
  createdAt: Date;
}

export interface PhoneVerificationToken {
  id: string;
  userId: string;
  loginIdentityId: string;
  otpHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  maxAttempts: number;
  createdAt: Date;
}

export interface EmailLoginOtp {
  id: string;
  userId: string;
  loginIdentityId: string;
  otpHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  maxAttempts: number;
  createdAt: Date;
}

export interface PhoneLoginOtp {
  id: string;
  userId: string;
  loginIdentityId: string;
  otpHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  maxAttempts: number;
  createdAt: Date;
}

export interface MfaChallenge {
  id: string;
  userId: string;
  challengeType: string;
  challengeData: Record<string, unknown>;
  status: 'pending' | 'completed' | 'expired' | 'failed';
  expiresAt: Date;
  completedAt: Date | null;
  failedAttempts: number;
  maxAttempts: number;
  createdAt: Date;
}

export interface GoogleIdentity {
  id: string;
  userId: string;
  loginIdentityId: string;
  googleSubject: string;
  email: string;
  emailVerified: boolean;
  name: string | null;
  givenName: string | null;
  familyName: string | null;
  picture: string | null;
  locale: string | null;
  rawProfile: Record<string, unknown> | null;
  linkedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserRole {
  userId: string;
  roleId: string;
  assignedAt: Date;
  assignedBy: string | null;
}

export interface Organisation {
  id: string;
  name: string;
  slug: string;
  type: string;
  description: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  address: string | null;
  city: string | null;
  county: string | null;
  country: string;
  registrationNumber: string | null;
  taxId: string | null;
  logoUrl: string | null;
  websiteUrl: string | null;
  isVerified: boolean;
  verificationStatus: 'pending' | 'in_review' | 'verified' | 'rejected';
  verificationNotes: string | null;
  verifiedAt: Date | null;
  verifiedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OrganisationMember {
  id: string;
  organisationId: string;
  userId: string;
  role: string;
  status: 'active' | 'invited' | 'suspended' | 'removed';
  invitedBy: string | null;
  invitedAt: Date | null;
  joinedAt: Date | null;
  removedAt: Date | null;
  removedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
  email?: string;
}

export type AccountStatus =
  | 'pending_verification'
  | 'active'
  | 'suspended'
  | 'locked'
  | 'deactivated'
  | 'deleted';

export interface RegistrationResult {
  user: AuthUser;
  verificationRequired: boolean;
  verificationChannel: 'email' | 'sms' | 'none';
  verificationId?: string;
  verificationDeliveryFailed?: boolean;
}

export interface VerificationResult {
  success: boolean;
  message: string;
  user?: AuthUser;
}

export interface LoginResult {
  user: AuthUser;
  accessToken?: string;
  refreshToken?: string;
  sessionId?: string;
  expiresIn?: number;
  authenticationStatus: 'complete' | 'mfa_required' | 'mfa_enrollment_required';
  challengeId?: string;
  availableMethods?: string[];
  enrollmentToken?: string;
}

export interface MfaHandoffResult {
  challengeId: string;
  availableMethods: string[];
  expiresAt: Date;
}

export interface MfaMethod {
  id: string;
  userId: string;
  methodType: 'totp' | 'sms' | 'email' | 'recovery_codes';
  methodName: string | null;
  isPrimary: boolean;
  isVerified: boolean;
  isActive: boolean;
  metadata: Record<string, unknown>;
  verifiedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

export interface MfaTotpSecret {
  id: string;
  userId: string;
  mfaMethodId: string;
  encryptedSecret: Buffer;
  algorithm: string;
  digits: number;
  period: number;
  lastUsedStep: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface MfaRecoveryCode {
  id: string;
  userId: string;
  mfaMethodId: string;
  codeHash: string;
  usedAt: Date | null;
  createdAt: Date;
}

export interface Permission {
  id: string;
  name: string;
  description: string | null;
  category: string;
  isSystem: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface RoleAssignment {
  id: string;
  userId: string;
  roleId: string;
  scope: 'global' | 'organization' | 'resource';
  organizationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  assignedBy: string | null;
  assignedAt: Date;
  expiresAt: Date | null;
  revokedAt: Date | null;
  revokedBy: string | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface OrganisationInvitation {
  id: string;
  organisationId: string;
  email: string;
  role: string;
  invitedBy: string;
  tokenHash: string;
  status: 'pending' | 'accepted' | 'expired' | 'revoked';
  expiresAt: Date;
  acceptedAt: Date | null;
  acceptedBy: string | null;
  revokedAt: Date | null;
  revokedBy: string | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
  invitedAt: Date;
}

export interface AuthorizationAuditEvent {
  id: string;
  userId: string | null;
  sessionId: string | null;
  decision: 'allow' | 'deny';
  permissionId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  organizationId: string | null;
  ipAddress: string | null;
  userAgent: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export interface AuthorizationContext {
  userId: string;
  sessionId: string;
  permission: string;
  resourceType?: string;
  resourceId?: string;
  organizationId?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Record<string, unknown>;
}

export interface AuthorizationDecision {
  allowed: boolean;
  reason: string;
  matchedRoles: string[];
  matchedPermissions: string[];
  matchedAssignments: RoleAssignment[];
  requiredMfa?: boolean;
  mfaMethods?: string[];
}

export interface ResolvedPermissions {
  permissions: Set<string>;
  roles: Set<string>;
  assignments: RoleAssignment[];
  organizationMemberships: OrganisationMember[];
  globalRoles: string[];
  cached: boolean;
  resolvedAt: Date;
}

export interface UserAuthorizationProfile {
  userId: string;
  globalRoles: string[];
  organizationMemberships: OrganisationMember[];
  roleAssignments: RoleAssignment[];
  permissions: Set<string>;
  isActive: boolean;
  isSuspended: boolean;
  isLocked: boolean;
  isDeactivated: boolean;
  mfaEnabled: boolean;
  mfaEnrolledAt: Date | null;
  lastMfaVerifiedAt: Date | null;
}

export interface SecurityEvent {
  id: string;
  userId: string | null;
  eventType: string;
  eventCategory: string;
  severity: 'info' | 'warning' | 'critical';
  ipAddress: string | null;
  userAgent: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

// ============================================================================
// NOTIFICATION TYPES
// ============================================================================

export type NotificationCategory =
  | 'security'
  | 'account'
  | 'property'
  | 'tenancy'
  | 'service'
  | 'financial'
  | 'operational'
  | 'marketing';

export type NotificationPriority = 'low' | 'normal' | 'high' | 'critical';

export type NotificationChannel = 'email' | 'sms' | 'push' | 'in_app';

export type DeliveryStatus =
  | 'pending'
  | 'sent'
  | 'delivered'
  | 'failed'
  | 'bounced'
  | 'complained'
  | 'suppressed';

export type OutboxStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'dead_letter';

export interface NotificationTemplate {
  id: string;
  templateKey: string;
  eventType: string;
  channel: NotificationChannel;
  locale: string;
  subject: string | null;
  body: string;
  isActive: boolean;
  version: number;
  metadata: Record<string, unknown>;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Notification {
  id: string;
  userId: string;
  organisationId: string | null;
  eventType: string;
  category: NotificationCategory;
  title: string;
  body: string;
  metadata: Record<string, unknown>;
  priority: NotificationPriority;
  isRead: boolean;
  readAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
}

export interface NotificationRecipient {
  id: string;
  notificationId: string;
  userId: string;
  isRead: boolean;
  readAt: Date | null;
  deliveredChannels: NotificationChannel[];
  createdAt: Date;
}

export interface NotificationPreferences {
  id: string;
  userId: string;
  // Global channel preferences
  emailEnabled: boolean;
  smsEnabled: boolean;
  pushEnabled: boolean;
  inAppEnabled: boolean;
  // Category preferences
  securityEmail: boolean;
  securitySms: boolean;
  securityPush: boolean;
  securityInApp: boolean;
  accountEmail: boolean;
  accountSms: boolean;
  accountPush: boolean;
  accountInApp: boolean;
  propertyEmail: boolean;
  propertySms: boolean;
  propertyPush: boolean;
  propertyInApp: boolean;
  tenancyEmail: boolean;
  tenancySms: boolean;
  tenancyPush: boolean;
  tenancyInApp: boolean;
  serviceEmail: boolean;
  serviceSms: boolean;
  servicePush: boolean;
  serviceInApp: boolean;
  financialEmail: boolean;
  financialSms: boolean;
  financialPush: boolean;
  financialInApp: boolean;
  operationalEmail: boolean;
  operationalSms: boolean;
  operationalPush: boolean;
  operationalInApp: boolean;
  marketingEmail: boolean;
  marketingSms: boolean;
  marketingPush: boolean;
  marketingInApp: boolean;
  // Quiet hours
  quietHoursStart: string | null;
  quietHoursEnd: string | null;
  timezone: string;
  metadata: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

export interface NotificationDeliveryAttempt {
  id: string;
  notificationId: string;
  recipientId: string | null;
  channel: NotificationChannel;
  provider: string;
  attemptNumber: number;
  status: DeliveryStatus;
  providerMessageId: string | null;
  providerResponse: Record<string, unknown> | null;
  errorCode: string | null;
  errorMessage: string | null;
  sentAt: Date | null;
  deliveredAt: Date | null;
  failedAt: Date | null;
  nextRetryAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface NotificationDeadLetter {
  id: string;
  deliveryAttemptId: string;
  notificationId: string;
  recipientId: string | null;
  channel: NotificationChannel;
  provider: string;
  failureReason: string;
  payload: Record<string, unknown>;
  retryCount: number;
  resolved: boolean;
  resolvedBy: string | null;
  resolvedAt: Date | null;
  resolutionNotes: string | null;
  createdAt: Date;
}

export interface NotificationOutbox {
  id: string;
  idempotencyKey: string;
  eventType: string;
  category: string;
  priority: string;
  recipientUserIds: string[];
  organisationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  payload: Record<string, unknown>;
  channels: NotificationChannel[];
  status: OutboxStatus;
  processingStartedAt: Date | null;
  processingCompletedAt: Date | null;
  errorMessage: string | null;
  retryCount: number;
  maxRetries: number;
  nextRetryAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export type MfaMethodType = 'totp' | 'sms' | 'email' | 'recovery_codes';

export interface MfaEnrollmentStartResult {
  method: MfaMethodType;
  methodId: string;
  provisioningUri?: string;
  qrCodeDataUrl?: string;
  secret?: string; // Only returned once during enrollment
  recoveryCodes?: string[]; // Only returned once during enrollment
}

export interface MfaEnrollmentVerifyResult {
  success: boolean;
  message: string;
  mfaStatus?: 'enrolled' | 'pending';
}

export interface MfaStatusResult {
  mfaEnabled: boolean;
  mfaEnrolled: boolean;
  enrollmentRequired: boolean;
  methods: MfaMethod[];
  recoveryCodesRemaining: number;
}

export interface MfaChallengeResult {
  challengeId: string;
  availableMethods: MfaMethodType[];
  expiresAt: Date;
}

export interface MfaVerifyResult {
  success: boolean;
  message: string;
  authenticationStatus?: 'mfa_verified' | 'complete';
  sessionToken?: string;
  user?: AuthUser;
}

export interface Session {
  id: string;
  userId: string;
  deviceId: string | null;
  tokenHash: string;
  refreshTokenHash: string | null;
  userAgent: string | null;
  ipAddress: string | null;
  countryCode: string | null;
  city: string | null;
  isCurrent: boolean;
  idleExpiresAt: Date;
  absoluteExpiresAt: Date;
  revokedAt: Date | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface RefreshToken {
  id: string;
  userId: string;
  sessionId: string;
  tokenHash: string;
  familyId: string;
  replacedByTokenId: string | null;
  replacedAt: Date | null;
  consumedAt: Date | null;
  isRevoked: boolean;
  revokedReason: string | null;
  expiresAt: Date;
  createdAt: Date;
}

export interface Device {
  id: string;
  userId: string;
  deviceIdentifier: string;
  platform: 'web' | 'android' | 'ios' | 'other';
  deviceName: string | null;
  deviceModel: string | null;
  osVersion: string | null;
  appVersion: string | null;
  pushProvider: 'fcm' | 'apns' | 'web_push' | null;
  pushTokenEncrypted: Buffer | null;
  pushTokenIv: Buffer | null;
  pushTokenAuthTag: Buffer | null;
  lastIp: string | null;
  lastCountryCode: string | null;
  lastCity: string | null;
  status: 'active' | 'revoked' | 'expired';
  revokedAt: Date | null;
  revokedReason: string | null;
  lastActivityAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface DeviceRegistrationInput {
  deviceIdentifier: string;
  platform: 'web' | 'android' | 'ios' | 'other';
  deviceName?: string;
  deviceModel?: string;
  osVersion?: string;
  appVersion?: string;
  pushProvider?: 'fcm' | 'apns' | 'web_push';
  pushToken?: string;
}

export interface DeviceUpdateInput {
  deviceName?: string;
  deviceModel?: string;
  osVersion?: string;
  appVersion?: string;
  pushProvider?: 'fcm' | 'apns' | 'web_push';
  pushToken?: string;
}

export interface SessionResult {
  user: AuthUser;
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  expiresIn: number;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface JwtPayload {
  sub: string; // userId
  sid: string; // sessionId
  jti: string; // tokenId
  iss: string;
  aud: string;
  iat: number;
  exp: number;
  type: 'access';
}

export interface RefreshTokenPayload {
  sub: string; // userId
  sid: string; // sessionId
  jti: string; // tokenId
  fid: string; // familyId
  iss: string;
  aud: string;
  iat: number;
  exp: number;
  type: 'refresh';
}

// ============================================================================
// PROPERTY, UNIT, TENANCY RESOURCE TYPES
// ============================================================================

export type PropertyType = 'apartment' | 'house' | 'commercial' | 'land' | 'hostel' | 'other';
export type PropertyStatus = 'draft' | 'published' | 'archived' | 'rented' | 'under_maintenance';

export interface Property {
  id: string;
  organisationId: string | null;
  title: string;
  description: string | null;
  propertyType: PropertyType;
  status: PropertyStatus;
  address: string;
  city: string;
  county: string;
  country: string;
  latitude: number | null;
  longitude: number | null;
  totalUnits: number;
  amenities: Record<string, unknown> | null;
  features: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  createdBy: string;
  updatedBy: string | null;
  publishedAt: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export type OwnershipType = 'individual' | 'corporate' | 'joint' | 'trust';
export type OwnershipStatus = 'active' | 'transferred' | 'disputed' | 'terminated';

export interface PropertyOwnership {
  id: string;
  propertyId: string;
  ownerType: OwnershipType;
  userId: string | null;
  organisationId: string | null;
  ownershipShare: number;
  isVerified: boolean;
  verifiedBy: string | null;
  verifiedAt: Date | null;
  verificationNotes: string | null;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  status: OwnershipStatus;
  titleDeedReference: string | null;
  titleDeedImageUrl: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export type AssignmentType = 'property_manager' | 'caretaker' | 'letting_agent' | 'maintenance' | 'security' | 'other';
export type AssignmentStatus = 'active' | 'suspended' | 'revoked' | 'expired';

export interface PropertyAssignment {
  id: string;
  propertyId: string;
  assignmentType: AssignmentType;
  userId: string | null;
  organisationId: string | null;
  scopeDescription: string | null;
  permissions: Record<string, unknown> | null;
  status: AssignmentStatus;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  assignedBy: string;
  revokedBy: string | null;
  revokedAt: Date | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type UnitType = 'bedsitter' | '1_bedroom' | '2_bedroom' | '3_bedroom' | 'commercial' | 'parking' | 'storage' | 'other';
export type UnitStatus = 'vacant' | 'occupied' | 'reserved' | 'under_maintenance' | 'unavailable';

export interface Unit {
  id: string;
  propertyId: string;
  unitNumber: string;
  unitType: UnitType;
  floorNumber: number | null;
  bedrooms: number;
  bathrooms: number;
  areaSqm: number | null;
  rentAmount: number;
  depositAmount: number;
  status: UnitStatus;
  description: string | null;
  amenities: Record<string, unknown> | null;
  features: Record<string, unknown> | null;
  images: Record<string, unknown> | null;
  hasSeparateMeter: boolean;
  meterNumber: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type UnitAccessLevel = 'full' | 'view_only' | 'maintenance_only' | 'inspection_only';
export type UnitAccessStatus = 'active' | 'suspended' | 'revoked' | 'expired';

export interface UnitAccessAssignment {
  id: string;
  unitId: string;
  propertyId: string;
  userId: string | null;
  organisationId: string | null;
  accessLevel: UnitAccessLevel;
  permissions: Record<string, unknown> | null;
  status: UnitAccessStatus;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  assignedBy: string;
  revokedBy: string | null;
  revokedAt: Date | null;
  revokedReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type TenancyStatus = 'draft' | 'pending_approval' | 'active' | 'terminated' | 'expired' | 'cancelled' | 'disputed';

export interface Tenancy {
  id: string;
  propertyId: string;
  unitId: string;
  tenancyType: string;
  status: TenancyStatus;
  startDate: Date;
  endDate: Date | null;
  noticePeriodDays: number;
  rentAmount: number;
  depositAmount: number;
  depositPaid: boolean;
  depositHeldBy: string | null;
  depositSchemeReference: string | null;
  rentDueDay: number;
  paymentMethod: string | null;
  paymentReference: string | null;
  termsDocumentUrl: string | null;
  termsAcceptedAt: Date | null;
  specialConditions: string | null;
  managedByUserId: string | null;
  managedByOrganisationId: string | null;
  terminatedAt: Date | null;
  terminatedBy: string | null;
  terminationReason: string | null;
  terminationNoticeDate: Date | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type ParticipantRole = 'primary_tenant' | 'co_tenant' | 'guarantor' | 'emergency_contact' | 'authorized_representative';
export type ParticipantStatus = 'active' | 'removed' | 'replaced';

export interface TenancyParticipant {
  id: string;
  tenancyId: string;
  userId: string | null;
  fullName: string | null;
  email: string | null;
  phone: string | null;
  idNumber: string | null;
  idType: string | null;
  role: ParticipantRole;
  isPrimary: boolean;
  canAccessDocuments: boolean;
  canReceiveNotices: boolean;
  canAuthorizeRepairs: boolean;
  status: ParticipantStatus;
  joinedAt: Date;
  leftAt: Date | null;
  addedBy: string;
  removedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type DocumentCategory = 'ownership' | 'title_deed' | 'lease_agreement' | 'tenant_id' | 'tenant_passport' | 'inspection_report' | 'maintenance_record' | 'insurance' | 'valuation' | 'floor_plan' | 'compliance_certificate' | 'utility_bill' | 'correspondence' | 'other';
export type DocumentVisibility = 'private' | 'owner' | 'manager' | 'tenant' | 'participant' | 'organization' | 'public';
export type DocumentStatus = 'active' | 'archived' | 'deleted';

export interface PropertyDocument {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  title: string;
  description: string | null;
  category: DocumentCategory;
  visibility: DocumentVisibility;
  filePath: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  fileHash: string;
  allowedRoles: string[];
  allowedUserIds: string[];
  allowedOrganisationIds: string[];
  version: number;
  previousVersionId: string | null;
  status: DocumentStatus;
  uploadedBy: string;
  uploadedAt: Date;
  expiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export type VisitStatus = 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no_show' | 'rescheduled';

export interface SiteVisit {
  id: string;
  propertyId: string;
  unitId: string | null;
  userId: string | null;
  visitorName: string;
  visitorEmail: string | null;
  visitorPhone: string;
  scheduledAt: Date;
  durationMinutes: number;
  status: VisitStatus;
  hostedByUserId: string | null;
  hostedByOrganisationId: string | null;
  visitorNotes: string | null;
  hostNotes: string | null;
  outcome: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export type ApplicationStatus = 'submitted' | 'under_review' | 'approved' | 'rejected' | 'withdrawn' | 'pending_documents' | 'pending_payment' | 'expired';

export interface RentalApplication {
  id: string;
  propertyId: string;
  unitId: string | null;
  userId: string | null;
  applicantName: string;
  applicantEmail: string;
  applicantPhone: string;
  applicantIdNumber: string | null;
  applicantIdType: string | null;
  status: ApplicationStatus;
  preferredStartDate: Date | null;
  preferredEndDate: Date | null;
  proposedRentAmount: number | null;
  documents: Record<string, unknown> | null;
  employerName: string | null;
  employerContact: string | null;
  monthlyIncome: number | null;
  previousLandlordName: string | null;
  previousLandlordContact: string | null;
  guarantorName: string | null;
  guarantorEmail: string | null;
  guarantorPhone: string | null;
  guarantorIdNumber: string | null;
  guarantorRelationship: string | null;
  reviewedBy: string | null;
  reviewedAt: Date | null;
  reviewNotes: string | null;
  rejectionReason: string | null;
  approvedBy: string | null;
  approvedAt: Date | null;
  approvedRentAmount: number | null;
  approvedDepositAmount: number | null;
  approvedStartDate: Date | null;
  approvedEndDate: Date | null;
  tenancyId: string | null;
  createdAt: Date;
  updatedAt: Date;
}
