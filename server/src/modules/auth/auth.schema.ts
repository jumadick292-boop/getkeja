import { z } from 'zod';

const passwordSchema = z.string().min(8).max(72);
const nameSchema = z.string().trim().min(1).max(100);
const emailSchema = z.email().trim().toLowerCase().max(254, {
  message: 'Email address must be 254 characters or fewer',
});

const kenyanPhoneSchema = z
  .string()
  .trim()
  .transform((phone) => phone.replace(/[\s()-]/g, ''))
  .pipe(
    z
      .string()
      .regex(
        /^\+?(?:254)?0?[17]\d{8}$/,
        'Invalid Kenyan phone number format. Use format: 07XXXXXXXX or +2547XXXXXXXX',
      ),
  )
  .transform((phone) => {
    const digits = phone.replace(/[\s()+-]/g, '').replace(/^254/, '').replace(/^0/, '');
    return `+254${digits}`;
  });

const roleSchema = z.enum([
  'house_seeker',
  'tenant',
  'landlord',
  'caretaker',
  'property_manager',
  'letting_agent',
  'moving_company',
  'individual_mover',
  'garbage_provider',
  'laundry_provider',
  'service_provider',
]);

const termsAcceptedSchema = z.boolean().refine((val) => val === true, {
  message: 'You must accept the terms and privacy policy',
});

export const registerEmailSchema = z.object({
  firstName: nameSchema,
  lastName: nameSchema,
  email: emailSchema,
  password: passwordSchema,
  role: roleSchema,
  termsAccepted: termsAcceptedSchema,
});

export const registerPhoneSchema = z.object({
  firstName: nameSchema,
  lastName: nameSchema,
  phone: kenyanPhoneSchema,
  password: passwordSchema,
  role: roleSchema,
  termsAccepted: termsAcceptedSchema,
});

export const registerPhoneOtpSchema = z.object({
  firstName: nameSchema,
  lastName: nameSchema,
  phone: kenyanPhoneSchema,
  role: roleSchema,
  termsAccepted: termsAcceptedSchema,
});

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(72),
});

export const loginPhoneSchema = z.object({
  phone: kenyanPhoneSchema,
  password: z.string().min(1).max(72),
});

export const forgotPasswordSchema = z.object({
  email: emailSchema,
});

export const resetPasswordSchema = z.object({
  token: z.string().min(32).max(256),
  password: passwordSchema,
});

export const setPasswordSchema = z.object({
  password: passwordSchema,
  idToken: z.string().min(1).optional(),
});

export const requestEmailVerificationSchema = z.object({
  email: emailSchema,
});

export const confirmEmailVerificationSchema = z.object({
  email: emailSchema,
  code: z.string().length(6, 'Verification code must be 6 digits').regex(/^\d{6}$/),
});

export const requestPhoneVerificationSchema = z.object({
  phone: kenyanPhoneSchema,
});

export const confirmPhoneVerificationSchema = z.object({
  phone: kenyanPhoneSchema,
  otp: z.string().length(6, 'OTP must be 6 digits').regex(/^\d{6}$/),
});

export const googleAuthSchema = z.object({
  idToken: z.string().min(1),
});

export const googleRegistrationSchema = z.object({
  idToken: z.string().min(1),
  role: roleSchema.default('house_seeker'),
});

export const googleLinkSchema = z.object({
  idToken: z.string().min(1),
  password: z.string().min(1).max(72).optional(),
});

export const googleUnlinkSchema = z.object({
  password: z.string().min(1).max(72).optional(),
});

export const requestEmailLoginOtpSchema = z.object({
  email: emailSchema,
});

export const verifyEmailLoginOtpSchema = z.object({
  email: emailSchema,
  otp: z.string().length(6, 'OTP must be 6 digits').regex(/^\d{6}$/),
});

export const requestPhoneLoginOtpSchema = z.object({
  phone: kenyanPhoneSchema,
});

export const verifyPhoneLoginOtpSchema = z.object({
  phone: kenyanPhoneSchema,
  otp: z.string().length(6, 'OTP must be 6 digits').regex(/^\d{6}$/),
});

export const mfaChallengeSchema = z.object({
  challengeId: z.string().min(1),
});

export const verifyMfaSchema = z.object({
  challengeId: z.string().min(1),
  methodType: z.enum(['totp', 'sms', 'email', 'recovery_codes']).optional(),
  code: z.string().min(4).max(32).optional(),
  totpCode: z.string().length(6, 'TOTP code must be 6 digits').regex(/^\d{6}$/).optional(),
  recoveryCode: z.string().min(8).max(32).optional(),
}).refine(
  (value) => [value.code, value.totpCode, value.recoveryCode].filter(Boolean).length === 1,
  { message: 'Provide exactly one MFA verification code' },
).refine(
  (value) => {
    if (value.totpCode && value.methodType && value.methodType !== 'totp') return false;
    if (value.recoveryCode && value.methodType && value.methodType !== 'recovery_codes') return false;
    if (value.code === undefined) return true;
    if (!value.methodType) return false;
    if (value.methodType === 'totp') return /^\d{6}$/.test(value.code);
    if (value.methodType === 'sms' || value.methodType === 'email') {
      return /^\d{4,8}$/.test(value.code);
    }
    return value.code.length >= 8 && value.code.length <= 32;
  },
  { message: 'The MFA code format is invalid for this method' },
);

export const mfaChallengeCodeRequestSchema = z.object({
  challengeId: z.string().uuid(),
  methodType: z.enum(['sms', 'email']),
});

export const mfaEnrollmentCodeRequestSchema = z.object({
  mfaMethodId: z.string().uuid(),
});

export const mfaEnrollmentStartSchema = z.object({
  methodType: z.enum(['totp', 'sms', 'email', 'recovery_codes']),
  methodName: z.string().min(1).max(100).optional(),
  phoneNumber: kenyanPhoneSchema.optional(),
  makePrimary: z.boolean().optional(),
});

export const mfaEnrollmentVerifySchema = z.object({
  mfaMethodId: z.string().uuid(),
  code: z.string().min(4).max(10),
});

export const mfaMethodDisableSchema = z.object({
  mfaMethodId: z.string().uuid(),
  verificationCode: z.string().min(4).max(20),
});

export const mfaMethodSetPrimarySchema = z.object({
  mfaMethodId: z.string().uuid(),
  verificationCode: z.string().min(4).max(20),
});

export const mfaRecoveryCodesRegenerateSchema = z.object({
  verificationCode: z.string().min(4).max(20),
});

export const accountRecoveryRequestSchema = z.object({
  email: emailSchema,
});

export const accountRecoveryPhoneSchema = z.object({
  phone: kenyanPhoneSchema,
});

export const accountRecoveryVerifySchema = z.object({
  token: z.string().min(32).max(256),
  password: passwordSchema,
  mfaMethod: z.enum(['totp', 'sms']).optional(),
  phoneNumber: kenyanPhoneSchema.optional(),
});

export const accountRestoreEmailRequestSchema = z.object({ email: emailSchema });
export const accountRestorePhoneRequestSchema = z.object({ phone: kenyanPhoneSchema });
export const accountRestoreVerifySchema = z.object({ token: z.string().min(32).max(256) });

export const deviceRegistrationSchema = z.object({
  deviceIdentifier: z.string().min(1).max(255),
  platform: z.enum(['web', 'android', 'ios', 'other']),
  deviceName: z.string().min(1).max(100).optional(),
  deviceModel: z.string().max(100).optional(),
  osVersion: z.string().max(50).optional(),
  appVersion: z.string().max(50).optional(),
  pushProvider: z.enum(['fcm', 'apns', 'web_push', 'webpush'])
    .transform((provider) => provider === 'webpush' ? 'web_push' : provider).optional(),
  pushToken: z.string().optional(),
});

export const deviceUpdateSchema = z.object({
  deviceName: z.string().min(1).max(100).optional(),
  deviceModel: z.string().max(100).optional(),
  osVersion: z.string().max(50).optional(),
  appVersion: z.string().max(50).optional(),
  pushProvider: z.enum(['fcm', 'apns', 'web_push', 'webpush'])
    .transform((provider) => provider === 'webpush' ? 'web_push' : provider).optional(),
  pushToken: z.string().optional(),
});

export type AccountRecoveryRequestInput = z.infer<typeof accountRecoveryRequestSchema>;
export type AccountRecoveryPhoneInput = z.infer<typeof accountRecoveryPhoneSchema>;
export type AccountRecoveryVerifyInput = z.infer<typeof accountRecoveryVerifySchema>;

export type MfaEnrollmentStartInput = z.infer<typeof mfaEnrollmentStartSchema>;
export type MfaEnrollmentVerifyInput = z.infer<typeof mfaEnrollmentVerifySchema>;
export type MfaMethodDisableInput = z.infer<typeof mfaMethodDisableSchema>;
export type MfaMethodSetPrimaryInput = z.infer<typeof mfaMethodSetPrimarySchema>;
export type MfaRecoveryCodesRegenerateInput = z.infer<typeof mfaRecoveryCodesRegenerateSchema>;

export type RegisterEmailInput = z.infer<typeof registerEmailSchema>;
export type RegisterPhoneInput = z.infer<typeof registerPhoneSchema>;
export type RegisterPhoneOtpInput = z.infer<typeof registerPhoneOtpSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type LoginPhoneInput = z.infer<typeof loginPhoneSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
export type VerifyEmailRequestInput = z.infer<typeof requestEmailVerificationSchema>;
export type VerifyEmailConfirmInput = z.infer<typeof confirmEmailVerificationSchema>;
export type VerifyPhoneRequestInput = z.infer<typeof requestPhoneVerificationSchema>;
export type VerifyPhoneConfirmInput = z.infer<typeof confirmPhoneVerificationSchema>;
export type GoogleAuthInput = z.infer<typeof googleAuthSchema>;
export type GoogleLinkInput = z.infer<typeof googleLinkSchema>;
export type GoogleUnlinkInput = z.infer<typeof googleUnlinkSchema>;
export type RequestEmailLoginOtpInput = z.infer<typeof requestEmailLoginOtpSchema>;
export type VerifyEmailLoginOtpInput = z.infer<typeof verifyEmailLoginOtpSchema>;
export type RequestPhoneLoginOtpInput = z.infer<typeof requestPhoneLoginOtpSchema>;
export type VerifyPhoneLoginOtpInput = z.infer<typeof verifyPhoneLoginOtpSchema>;
export type MfaChallengeInput = z.infer<typeof mfaChallengeSchema>;
export type VerifyMfaInput = z.infer<typeof verifyMfaSchema>;

export type DeviceRegistrationInput = z.infer<typeof deviceRegistrationSchema>;
export type DeviceUpdateInput = z.infer<typeof deviceUpdateSchema>;

// Organisation schemas
const organisationTypeSchema = z.enum([
  'letting_agency',
  'property_management',
  'moving_company',
  'garbage_collection',
  'laundry',
  'other',
]);

const organisationRoleSchema = z.enum(['owner', 'admin', 'member', 'staff']);

export const createOrganisationSchema = z.object({
  name: z.string().trim().min(1).max(255),
  slug: z.string().trim().min(1).max(100).regex(/^[a-z0-9-]+$/, 'Slug must contain only lowercase letters, numbers, and hyphens'),
  type: organisationTypeSchema,
  description: z.string().max(2000).optional().nullable(),
  contactEmail: z.email().trim().toLowerCase().optional().nullable(),
  contactPhone: z.string().max(50).optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  city: z.string().max(100).optional().nullable(),
  county: z.string().max(100).optional().nullable(),
  country: z.string().length(2).default('KE'),
  registrationNumber: z.string().max(100).optional().nullable(),
  taxId: z.string().max(100).optional().nullable(),
  logoUrl: z.url().max(500).optional().nullable(),
  websiteUrl: z.url().max(500).optional().nullable(),
});

export const updateOrganisationSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(2000).optional().nullable(),
  contactEmail: z.email().trim().toLowerCase().optional().nullable(),
  contactPhone: z.string().max(50).optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  city: z.string().max(100).optional().nullable(),
  county: z.string().max(100).optional().nullable(),
  country: z.string().length(2).optional(),
  registrationNumber: z.string().max(100).optional().nullable(),
  taxId: z.string().max(100).optional().nullable(),
  logoUrl: z.url().max(500).optional().nullable(),
  websiteUrl: z.url().max(500).optional().nullable(),
});

export const createInvitationSchema = z.object({
  email: z.email().trim().toLowerCase(),
  role: organisationRoleSchema,
  expiresAt: z.string().datetime().optional(),
});

export const updateMemberSchema = z.object({
  role: organisationRoleSchema.optional(),
  status: z.enum(['active', 'suspended', 'removed']).optional(),
});

// Admin schemas
export const createRoleSchema = z.object({
  id: z.string().min(1).max(50).regex(/^[a-z_]+$/, 'Role ID must contain only lowercase letters and underscores'),
  name: z.string().trim().min(1).max(100),
  description: z.string().max(500).optional().nullable(),
  isSystem: z.boolean().optional(),
  isPubliclyAssignable: z.boolean().optional(),
});

export const updateRoleSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  description: z.string().max(500).optional().nullable(),
  isPubliclyAssignable: z.boolean().optional(),
});

export const createPermissionSchema = z.object({
  id: z.string().min(1).max(100).regex(/^[a-z.]+$/, 'Permission ID must contain only lowercase letters and dots'),
  name: z.string().trim().min(1).max(200),
  description: z.string().max(1000).optional().nullable(),
  category: z.string().min(1).max(50),
  isSystem: z.boolean().optional(),
});

export const assignRoleToUserSchema = z.object({
  roleId: z.string().min(1).max(50),
  scope: z.enum(['global', 'organization', 'resource']).default('global'),
  organizationId: z.uuid().optional(),
  resourceType: z.string().max(50).optional(),
  resourceId: z.uuid().optional(),
  expiresAt: z.string().datetime().optional(),
});

export const auditQuerySchema = z.object({
  userId: z.uuid().optional(),
  sessionId: z.uuid().optional(),
  decision: z.enum(['allow', 'deny']).optional(),
  permissionId: z.string().max(100).optional(),
  resourceType: z.string().max(50).optional(),
  resourceId: z.uuid().optional(),
  organizationId: z.uuid().optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export const updateAccountProfileSchema = z.object({
  firstName: nameSchema.optional(),
  lastName: nameSchema.optional(),
}).refine((value) => value.firstName !== undefined || value.lastName !== undefined, {
  message: 'At least one profile field is required',
});

export const pauseAccountSchema = z.object({
  confirmation: z.literal('PAUSE'),
  currentPassword: z.string().min(1).max(72).optional(),
});

export const deleteAccountSchema = z.object({
  confirmation: z.literal('DELETE'),
  currentPassword: z.string().min(1).max(72).optional(),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1).max(72),
  newPassword: passwordSchema,
}).refine((value) => value.currentPassword !== value.newPassword, {
  message: 'New password must be different from the current password',
});

export const accountPreferencesSchema = z.object({
  language: z.enum(['en', 'sw']).optional(),
  theme: z.enum(['system', 'light', 'dark']).optional(),
  currency: z.enum(['KES', 'USD', 'EUR', 'GBP']).optional(),
  timezone: z.enum(['Africa/Nairobi', 'Africa/Kampala', 'Africa/Dar_es_Salaam', 'UTC']).optional(),
  dateFormat: z.enum(['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd']).optional(),
  numberFormat: z.enum(['en-KE', 'en-US', 'en-GB', 'sw-KE']).optional(),
  pushNotifications: z.boolean().optional(),
  emailNotifications: z.boolean().optional(),
  smsNotifications: z.boolean().optional(),
}).refine((value) => Object.keys(value).length > 0, {
  message: 'At least one account preference is required',
});

export const privacyPreferencesSchema = z.object({
  marketingEmails: z.boolean().optional(),
  analyticsTracking: z.boolean().optional(),
  personalizedAds: z.boolean().optional(),
  dataSharing: z.boolean().optional(),
}).refine((value) => Object.keys(value).length > 0, {
  message: 'At least one privacy preference is required',
});

export const emailChangeRequestSchema = z.object({
  newEmail: emailSchema,
});

export const emailChangeConfirmSchema = z.object({
  token: z.string().length(6, 'Verification code must be 6 digits').regex(/^\d{6}$/),
});

export const phoneChangeRequestSchema = z.object({
  newPhone: kenyanPhoneSchema,
});

export const phoneChangeConfirmSchema = z.object({
  otp: z.string().length(6).regex(/^\d{6}$/),
});

export const adminUserListSchema = z.object({
  search: z.string().trim().min(1).max(100).optional(),
  status: z.enum([
    'pending_verification',
    'active',
    'suspended',
    'locked',
    'deactivated',
    'deleted',
  ]).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export const adminUserIdParamsSchema = z.object({
  targetUserId: z.uuid(),
});

export const adminUserStatusSchema = z.object({
  action: z.enum(['suspend', 'reinstate', 'lock', 'unlock', 'deactivate', 'reactivate']),
  reason: z.string().trim().min(3).max(500),
});

export type CreateOrganisationInput = z.infer<typeof createOrganisationSchema>;
export type UpdateOrganisationInput = z.infer<typeof updateOrganisationSchema>;
export type CreateInvitationInput = z.infer<typeof createInvitationSchema>;
export type UpdateMemberInput = z.infer<typeof updateMemberSchema>;

export type CreateRoleInput = z.infer<typeof createRoleSchema>;
export type UpdateRoleInput = z.infer<typeof updateRoleSchema>;
export type CreatePermissionInput = z.infer<typeof createPermissionSchema>;
export type AssignRoleToUserInput = z.infer<typeof assignRoleToUserSchema>;
export type AuditQueryInput = z.infer<typeof auditQuerySchema>;

// Property schemas
export const propertyTypeSchema = z.enum(['apartment', 'house', 'commercial', 'land', 'mixed_use', 'other']);

export const createPropertySchema = z.object({
  organisationId: z.uuid().optional().nullable(),
  title: z.string().trim().min(1).max(255),
  description: z.string().max(5000).optional().nullable(),
  propertyType: propertyTypeSchema,
  address: z.string().trim().min(1).max(500),
  city: z.string().trim().min(1).max(100),
  county: z.string().trim().min(1).max(100),
  country: z.string().length(2).default('KE'),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  totalUnits: z.coerce.number().int().min(1).default(1),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
});

export const updatePropertySchema = z.object({
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(5000).optional().nullable(),
  propertyType: propertyTypeSchema.optional(),
  address: z.string().trim().min(1).max(500).optional(),
  city: z.string().trim().min(1).max(100).optional(),
  county: z.string().trim().min(1).max(100).optional(),
  country: z.string().length(2).optional(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  totalUnits: z.coerce.number().int().min(1).optional(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  status: z.enum(['draft', 'published', 'archived', 'rented', 'under_maintenance']).optional(),
});

export const propertyQuerySchema = z.object({
  organisationId: z.uuid().optional(),
  propertyType: propertyTypeSchema.optional(),
  status: z.enum(['draft', 'published', 'archived', 'rented', 'under_maintenance']).optional(),
  city: z.string().max(100).optional(),
  county: z.string().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// Unit schemas
export const unitTypeSchema = z.enum(['bedsitter', 'one_bedroom', 'two_bedroom', 'three_bedroom', 'four_plus_bedroom', 'commercial', 'parking', 'storage', 'other']);

export const createUnitSchema = z.object({
  propertyId: z.uuid(),
  unitNumber: z.string().trim().min(1).max(50),
  unitType: unitTypeSchema,
  floor: z.coerce.number().int().optional().nullable(),
  bedrooms: z.coerce.number().int().min(0).optional(),
  bathrooms: z.coerce.number().int().min(0).optional(),
  areaSqm: z.number().positive().optional().nullable(),
  rentAmount: z.number().nonnegative(),
  depositAmount: z.number().nonnegative().default(0),
  description: z.string().max(2000).optional().nullable(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  status: z.enum(['available', 'occupied', 'under_maintenance', 'reserved']).default('available'),
});

export const updateUnitSchema = z.object({
  unitNumber: z.string().trim().min(1).max(50).optional(),
  unitType: unitTypeSchema.optional(),
  floor: z.coerce.number().int().optional().nullable(),
  bedrooms: z.coerce.number().int().min(0).optional(),
  bathrooms: z.coerce.number().int().min(0).optional(),
  areaSqm: z.number().positive().optional().nullable(),
  rentAmount: z.number().nonnegative().optional(),
  depositAmount: z.number().nonnegative().optional(),
  description: z.string().max(2000).optional().nullable(),
  amenities: z.record(z.string(), z.unknown()).optional().nullable(),
  features: z.record(z.string(), z.unknown()).optional().nullable(),
  images: z.record(z.string(), z.unknown()).optional().nullable(),
  status: z.enum(['available', 'occupied', 'under_maintenance', 'reserved']).optional(),
});

export const unitQuerySchema = z.object({
  propertyId: z.uuid().optional(),
  unitType: unitTypeSchema.optional(),
  status: z.enum(['available', 'occupied', 'under_maintenance', 'reserved']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// Tenancy schemas
export const tenancyTypeSchema = z.enum(['residential', 'commercial', 'short_term']);
export const tenancyStatusSchema = z.enum(['draft', 'pending_approval', 'active', 'terminated', 'expired', 'cancelled', 'disputed']);

export const createTenancySchema = z.object({
  propertyId: z.uuid(),
  unitId: z.uuid(),
  tenancyType: tenancyTypeSchema.default('residential'),
  startDate: z.string().date(),
  endDate: z.string().date().optional().nullable(),
  noticePeriodDays: z.coerce.number().int().min(1).default(30),
  rentAmount: z.number().positive(),
  depositAmount: z.number().nonnegative().default(0),
  depositPaid: z.boolean().default(false),
  depositHeldBy: z.enum(['landlord', 'agency', 'scheme']).optional().nullable(),
  depositSchemeReference: z.string().max(100).optional().nullable(),
  rentDueDay: z.coerce.number().int().min(1).max(31).default(1),
  paymentMethod: z.string().max(50).optional().nullable(),
  paymentReference: z.string().max(100).optional().nullable(),
  termsDocumentUrl: z.url().max(500).optional().nullable(),
  specialConditions: z.string().max(5000).optional().nullable(),
  managedByUserId: z.uuid().optional().nullable(),
  managedByOrganisationId: z.uuid().optional().nullable(),
});

export const updateTenancySchema = z.object({
  tenancyType: tenancyTypeSchema.optional(),
  startDate: z.string().date().optional(),
  endDate: z.string().date().optional().nullable(),
  noticePeriodDays: z.coerce.number().int().min(1).optional(),
  rentAmount: z.number().positive().optional(),
  depositAmount: z.number().nonnegative().optional(),
  depositPaid: z.boolean().optional(),
  depositHeldBy: z.enum(['landlord', 'agency', 'scheme']).optional().nullable(),
  depositSchemeReference: z.string().max(100).optional().nullable(),
  rentDueDay: z.coerce.number().int().min(1).max(31).optional(),
  paymentMethod: z.string().max(50).optional().nullable(),
  paymentReference: z.string().max(100).optional().nullable(),
  termsDocumentUrl: z.url().max(500).optional().nullable(),
  specialConditions: z.string().max(5000).optional().nullable(),
  managedByUserId: z.uuid().optional().nullable(),
  managedByOrganisationId: z.uuid().optional().nullable(),
  status: tenancyStatusSchema.optional(),
});

export const tenancyQuerySchema = z.object({
  propertyId: z.uuid().optional(),
  unitId: z.uuid().optional(),
  tenancyType: tenancyTypeSchema.optional(),
  status: tenancyStatusSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// Tenancy participant schemas
export const participantRoleSchema = z.enum(['primary_tenant', 'co_tenant', 'guarantor', 'emergency_contact', 'authorized_representative']);

export const addTenancyParticipantSchema = z.object({
  userId: z.uuid().optional().nullable(),
  fullName: z.string().trim().min(1).max(255).optional().nullable(),
  email: z.email().trim().toLowerCase().optional().nullable(),
  phone: z.string().max(50).optional().nullable(),
  idNumber: z.string().max(50).optional().nullable(),
  idType: z.enum(['national_id', 'passport', 'alien_id']).optional().nullable(),
  role: participantRoleSchema.default('co_tenant'),
  isPrimary: z.boolean().default(false),
  canAccessDocuments: z.boolean().default(true),
  canReceiveNotices: z.boolean().default(true),
  canAuthorizeRepairs: z.boolean().default(false),
});

export const updateTenancyParticipantSchema = z.object({
  role: participantRoleSchema.optional(),
  isPrimary: z.boolean().optional(),
  canAccessDocuments: z.boolean().optional(),
  canReceiveNotices: z.boolean().optional(),
  canAuthorizeRepairs: z.boolean().optional(),
  status: z.enum(['active', 'removed', 'replaced']).optional(),
});

// Property document schemas
export const documentTypeSchema = z.enum(['lease_agreement', 'rent_receipt', 'inspection_report', 'maintenance_request', 'notice', 'correspondence', 'id_document', 'reference_letter', 'bank_statement', 'insurance', 'other']);
export const documentVisibilitySchema = z.enum(['public', 'participants_only', 'owner_only', 'manager_only']);

export const createPropertyDocumentSchema = z.object({
  propertyId: z.uuid(),
  tenancyId: z.uuid().optional().nullable(),
  unitId: z.uuid().optional().nullable(),
  type: documentTypeSchema,
  title: z.string().trim().min(1).max(255),
  description: z.string().max(2000).optional().nullable(),
  fileUrl: z.url().max(500),
  fileSize: z.number().int().positive().optional(),
  mimeType: z.string().max(100).optional(),
  visibility: documentVisibilitySchema.default('participants_only'),
  expiresAt: z.string().datetime().optional().nullable(),
});

export const updatePropertyDocumentSchema = z.object({
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().max(2000).optional().nullable(),
  visibility: documentVisibilitySchema.optional(),
  expiresAt: z.string().datetime().optional().nullable(),
  status: z.enum(['active', 'archived', 'expired']).optional(),
});

// Site visit schemas
export const visitStatusSchema = z.enum(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show', 'rescheduled']);

export const createSiteVisitSchema = z.object({
  propertyId: z.uuid(),
  unitId: z.uuid().optional().nullable(),
  visitorName: z.string().trim().min(1).max(255),
  visitorEmail: z.email().trim().toLowerCase().optional().nullable(),
  visitorPhone: z.string().trim().min(1).max(50),
scheduledAt: z.string().datetime(),
  durationMinutes: z.coerce.number().int().min(15).max(480).default(30),
  hostedByUserId: z.uuid().optional().nullable(),
  hostedByOrganisationId: z.uuid().optional().nullable(),
  visitorNotes: z.string().max(2000).optional().nullable(),
});

export const updateSiteVisitSchema = z.object({
  unitId: z.uuid().optional().nullable(),
  visitorName: z.string().trim().min(1).max(255).optional(),
  visitorEmail: z.string().email().trim().toLowerCase().optional().nullable(),
  visitorPhone: z.string().trim().min(1).max(50).optional(),
  scheduledAt: z.string().datetime().optional(),
  durationMinutes: z.coerce.number().int().min(15).max(480).optional(),
  hostedByUserId: z.uuid().optional().nullable(),
  hostedByOrganisationId: z.uuid().optional().nullable(),
  visitorNotes: z.string().max(2000).optional().nullable(),
  status: visitStatusSchema.optional(),
  hostNotes: z.string().max(2000).optional().nullable(),
  outcome: z.string().max(2000).optional().nullable(),
});

export const siteVisitQuerySchema = z.object({
  propertyId: z.uuid().optional(),
  unitId: z.uuid().optional(),
  status: visitStatusSchema.optional(),
  hostedByUserId: z.uuid().optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// Rental application schemas
export const applicationStatusSchema = z.enum(['submitted', 'under_review', 'approved', 'rejected', 'withdrawn', 'pending_documents', 'pending_payment', 'expired']);
export const idTypeSchema = z.enum(['national_id', 'passport', 'alien_id']);

export const createRentalApplicationSchema = z.object({
  propertyId: z.uuid(),
  unitId: z.uuid().optional().nullable(),
  applicantName: z.string().trim().min(1).max(255),
  applicantEmail: z.email().trim().toLowerCase(),
  applicantPhone: z.string().trim().min(1).max(50),
  applicantIdNumber: z.string().max(50).optional().nullable(),
  applicantIdType: idTypeSchema.optional().nullable(),
  preferredStartDate: z.string().date().optional().nullable(),
  preferredEndDate: z.string().date().optional().nullable(),
  proposedRentAmount: z.number().positive().optional().nullable(),
  documents: z.record(z.string(), z.unknown()).optional().nullable(),
  employerName: z.string().max(255).optional().nullable(),
  employerContact: z.string().max(255).optional().nullable(),
  monthlyIncome: z.number().positive().optional().nullable(),
  previousLandlordName: z.string().max(255).optional().nullable(),
  previousLandlordContact: z.string().max(255).optional().nullable(),
  guarantorName: z.string().max(255).optional().nullable(),
  guarantorEmail: z.email().trim().toLowerCase().optional().nullable(),
  guarantorPhone: z.string().max(50).optional().nullable(),
  guarantorIdNumber: z.string().max(50).optional().nullable(),
  guarantorRelationship: z.string().max(100).optional().nullable(),
});

export const updateRentalApplicationSchema = z.object({
  status: applicationStatusSchema.optional(),
  proposedRentAmount: z.number().positive().optional().nullable(),
  documents: z.record(z.string(), z.unknown()).optional().nullable(),
  employerName: z.string().max(255).optional().nullable(),
  employerContact: z.string().max(255).optional().nullable(),
  monthlyIncome: z.number().positive().optional().nullable(),
  previousLandlordName: z.string().max(255).optional().nullable(),
  previousLandlordContact: z.string().max(255).optional().nullable(),
  guarantorName: z.string().max(255).optional().nullable(),
  guarantorEmail: z.email().trim().toLowerCase().optional().nullable(),
  guarantorPhone: z.string().max(50).optional().nullable(),
  guarantorIdNumber: z.string().max(50).optional().nullable(),
  guarantorRelationship: z.string().max(100).optional().nullable(),
  reviewedBy: z.uuid().optional().nullable(),
  reviewedAt: z.string().datetime().optional().nullable(),
  reviewNotes: z.string().max(2000).optional().nullable(),
  rejectionReason: z.string().max(2000).optional().nullable(),
  approvedBy: z.uuid().optional().nullable(),
  approvedAt: z.string().datetime().optional().nullable(),
  approvedRentAmount: z.number().positive().optional().nullable(),
  approvedDepositAmount: z.number().nonnegative().optional().nullable(),
  approvedStartDate: z.string().date().optional().nullable(),
  approvedEndDate: z.string().date().optional().nullable(),
  tenancyId: z.uuid().optional().nullable(),
});

export const rentalApplicationQuerySchema = z.object({
  propertyId: z.uuid().optional(),
  unitId: z.uuid().optional(),
  status: applicationStatusSchema.optional(),
  applicantEmail: z.email().trim().toLowerCase().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

// Type exports
export type CreatePropertyInput = z.infer<typeof createPropertySchema>;
export type UpdatePropertyInput = z.infer<typeof updatePropertySchema>;
export type PropertyQueryInput = z.infer<typeof propertyQuerySchema>;

export type CreateUnitInput = z.infer<typeof createUnitSchema>;
export type UpdateUnitInput = z.infer<typeof updateUnitSchema>;
export type UnitQueryInput = z.infer<typeof unitQuerySchema>;

export type CreateTenancyInput = z.infer<typeof createTenancySchema>;
export type UpdateTenancyInput = z.infer<typeof updateTenancySchema>;
export type TenancyQueryInput = z.infer<typeof tenancyQuerySchema>;

export type AddTenancyParticipantInput = z.infer<typeof addTenancyParticipantSchema>;
export type UpdateTenancyParticipantInput = z.infer<typeof updateTenancyParticipantSchema>;

export type CreatePropertyDocumentInput = z.infer<typeof createPropertyDocumentSchema>;
export type UpdatePropertyDocumentInput = z.infer<typeof updatePropertyDocumentSchema>;

export type CreateSiteVisitInput = z.infer<typeof createSiteVisitSchema>;
export type UpdateSiteVisitInput = z.infer<typeof updateSiteVisitSchema>;
export type SiteVisitQueryInput = z.infer<typeof siteVisitQuerySchema>;

export type CreateRentalApplicationInput = z.infer<typeof createRentalApplicationSchema>;
export type UpdateRentalApplicationInput = z.infer<typeof updateRentalApplicationSchema>;
export type RentalApplicationQueryInput = z.infer<typeof rentalApplicationQuerySchema>;
