import { createHash, createHmac, randomBytes, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import argon2 from 'argon2';
import { pool } from '../../db/pool.js';
import { loadEnv } from '../../config/env.js';
import { ConflictError, ForbiddenError, NotFoundError, UnauthorizedError } from '../../shared/errors.js';
import * as authRepository from './auth.repository.js';
import * as authorizationService from './authorization.service.js';
import * as sessionService from './session.service.js';
import type { AuthUser } from './auth.types.js';
import type { z } from 'zod';
import { createEmailProvider } from './providers/email.js';
import { createSmsProvider } from './providers/sms.js';
import type {
  accountPreferencesSchema,
  adminUserListSchema,
  adminUserStatusSchema,
  privacyPreferencesSchema,
  updateAccountProfileSchema,
} from './auth.schema.js';

export type AdminUserList = z.infer<typeof adminUserListSchema>;
type AdminUserAction = z.infer<typeof adminUserStatusSchema>['action'];
type ProfileUpdate = z.infer<typeof updateAccountProfileSchema>;
type AccountPreferencesUpdate = z.infer<typeof accountPreferencesSchema>;
type PrivacyPreferencesUpdate = z.infer<typeof privacyPreferencesSchema>;

const accountPreferenceColumns = {
  language: 'language',
  theme: 'theme',
  currency: 'currency',
  timezone: 'timezone',
  dateFormat: 'date_format',
  numberFormat: 'number_format',
} as const;

const privacyPreferenceColumns = {
  analyticsTracking: 'analytics_tracking',
  personalizedAds: 'personalized_ads',
  dataSharing: 'data_sharing',
} as const;

const ACCOUNT_RESTORE_WINDOW_DAYS = 30;
const ACCOUNT_RESTORE_TOKEN_TTL_MS = 60 * 60 * 1000;

function hashValue(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function hashOtp(otp: string): string {
  return createHmac('sha256', loadEnv().COOKIE_SECRET).update(otp).digest('hex');
}

function normalizePhone(phone: string): string {
  const digits = phone.replace(/[\s()+-]/g, '').replace(/^254/, '').replace(/^0/, '');
  return `+254${digits}`;
}

function emailProvider() {
  const env = loadEnv();
  return createEmailProvider({
    fromAddress: env.EMAIL_FROM_ADDRESS,
    fromName: env.EMAIL_FROM_NAME,
    baseUrl: env.EMAIL_BASE_URL,
  });
}

function smsProvider() {
  const env = loadEnv();
  return createSmsProvider({ fromNumber: env.SMS_FROM_NUMBER });
}

async function ensurePreferenceRows(userId: string): Promise<void> {
  await pool.query(
    `INSERT INTO user_account_preferences (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId],
  );
  await pool.query(
    `INSERT INTO notification_preferences (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId],
  );
}

export async function getAccountPreferences(userId: string) {
  await ensurePreferenceRows(userId);
  const result = await pool.query(
    `SELECT p.language, p.theme, p.currency, p.timezone,
            p.date_format AS "dateFormat", p.number_format AS "numberFormat",
            n.push_enabled AS "pushNotifications",
            n.email_enabled AS "emailNotifications",
            n.sms_enabled AS "smsNotifications"
     FROM user_account_preferences p
     JOIN notification_preferences n USING (user_id)
     WHERE p.user_id = $1`,
    [userId],
  );
  return result.rows[0];
}

export async function updateAccountPreferences(
  userId: string,
  input: AccountPreferencesUpdate,
) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'INSERT INTO user_account_preferences (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
      [userId],
    );
    await client.query(
      'INSERT INTO notification_preferences (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
      [userId],
    );
    const settings = Object.entries(accountPreferenceColumns)
      .filter(([key]) => input[key as keyof AccountPreferencesUpdate] !== undefined);
    if (settings.length > 0) {
      const assignments = settings.map(([, column], index) => `${column} = $${index + 2}`);
      await client.query(
        `UPDATE user_account_preferences SET ${assignments.join(', ')}, updated_at = NOW()
         WHERE user_id = $1`,
        [userId, ...settings.map(([key]) => input[key as keyof AccountPreferencesUpdate])],
      );
    }

    const channels = [
      ['pushNotifications', 'push_enabled'],
      ['emailNotifications', 'email_enabled'],
      ['smsNotifications', 'sms_enabled'],
      ['timezone', 'timezone'],
    ] as const;
    const channelChanges = channels.filter(([key]) => input[key] !== undefined);
    if (channelChanges.length > 0) {
      const assignments = channelChanges.map(([, column], index) => `${column} = $${index + 2}`);
      await client.query(
        `UPDATE notification_preferences SET ${assignments.join(', ')}, updated_at = NOW()
         WHERE user_id = $1`,
        [userId, ...channelChanges.map(([key]) => input[key]!)],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  return getAccountPreferences(userId);
}

export async function getPrivacyPreferences(userId: string) {
  await ensurePreferenceRows(userId);
  const result = await pool.query(
    `SELECT n.marketing_email AS "marketingEmails",
            p.analytics_tracking AS "analyticsTracking",
            p.personalized_ads AS "personalizedAds",
            p.data_sharing AS "dataSharing"
     FROM user_account_preferences p
     JOIN notification_preferences n USING (user_id)
     WHERE p.user_id = $1`,
    [userId],
  );
  return result.rows[0];
}

export async function updatePrivacyPreferences(
  userId: string,
  input: PrivacyPreferencesUpdate,
) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'INSERT INTO user_account_preferences (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
      [userId],
    );
    await client.query(
      'INSERT INTO notification_preferences (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
      [userId],
    );
    const settings = Object.entries(privacyPreferenceColumns)
      .filter(([key]) => input[key as keyof PrivacyPreferencesUpdate] !== undefined);
    if (settings.length > 0) {
      const assignments = settings.map(([, column], index) => `${column} = $${index + 2}`);
      await client.query(
        `UPDATE user_account_preferences SET ${assignments.join(', ')}, updated_at = NOW()
         WHERE user_id = $1`,
        [userId, ...settings.map(([key]) => input[key as keyof PrivacyPreferencesUpdate])],
      );
    }
    if (input.marketingEmails !== undefined) {
      await client.query(
        `UPDATE notification_preferences
         SET marketing_email = $2, updated_at = NOW()
         WHERE user_id = $1`,
        [userId, input.marketingEmails],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  return getPrivacyPreferences(userId);
}

export async function exportAccountData(userId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    const user = await client.query(
      `SELECT id, email, name, first_name AS "firstName", last_name AS "lastName",
              email_verified AS "emailVerified", phone_verified AS "phoneVerified",
              account_status AS "accountStatus", created_at AS "createdAt",
              updated_at AS "updatedAt"
       FROM users WHERE id = $1`,
      [userId],
    );
    if (!user.rows[0]) throw new NotFoundError('Account not found');
    const identities = await client.query(
      `SELECT provider, identifier, verified_at AS "verifiedAt",
              is_primary AS "isPrimary", created_at AS "createdAt"
       FROM user_login_identities WHERE user_id = $1`,
      [userId],
    );
    const roles = await client.query(
      `SELECT r.id, r.name, r.description
       FROM user_roles ur JOIN roles r ON r.id = ur.role_id
       WHERE ur.user_id = $1`,
      [userId],
    );
    const personalProfile = await client.query(
      `SELECT display_name AS "displayName", profile_photo_url AS "profilePhotoUrl",
              bio, phone_number AS "phoneNumber", website_url AS "websiteUrl",
              created_at AS "createdAt", updated_at AS "updatedAt"
       FROM user_profiles WHERE user_id = $1`,
      [userId],
    );
    const specializedProfiles = await client.query(
      `SELECT profile_category AS "profileCategory", full_name AS "fullName",
              display_name AS "displayName", profile_photo_url AS "profilePhotoUrl",
              business_name AS "businessName", business_logo_url AS "businessLogoUrl",
              description, contact_email AS "contactEmail", contact_phone AS "contactPhone",
              website_url AS "websiteUrl", verification_status AS "verificationStatus",
              created_at AS "createdAt", updated_at AS "updatedAt"
       FROM specialized_profiles WHERE user_id = $1`,
      [userId],
    );
    const accountPreferences = await client.query(
      `SELECT language, theme, currency, timezone, date_format AS "dateFormat",
              number_format AS "numberFormat", analytics_tracking AS "analyticsTracking",
              personalized_ads AS "personalizedAds", data_sharing AS "dataSharing"
       FROM user_account_preferences WHERE user_id = $1`,
      [userId],
    );
    const notificationPreferences = await client.query(
      `SELECT email_enabled AS "emailNotifications", sms_enabled AS "smsNotifications",
              push_enabled AS "pushNotifications", marketing_email AS "marketingEmails",
              timezone
       FROM notification_preferences WHERE user_id = $1`,
      [userId],
    );
    const sessions = await client.query(
      `SELECT id, device_id AS "deviceId", user_agent AS "userAgent",
              ip_address AS "ipAddress", country_code AS "countryCode", city,
              is_current AS "isCurrent", idle_expires_at AS "idleExpiresAt",
              absolute_expires_at AS "absoluteExpiresAt", revoked_at AS "revokedAt",
              revoked_reason AS "revokedReason", created_at AS "createdAt"
       FROM sessions WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const devices = await client.query(
      `SELECT id, platform, device_name AS "deviceName", device_model AS "deviceModel",
              os_version AS "osVersion", app_version AS "appVersion",
              push_provider AS "pushProvider", last_ip AS "lastIp",
              last_country_code AS "lastCountryCode", last_city AS "lastCity",
              status, revoked_at AS "revokedAt", revoked_reason AS "revokedReason",
              last_activity_at AS "lastActivityAt", created_at AS "createdAt"
       FROM devices WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const notifications = await client.query(
      `SELECT event_type AS "eventType", category, title, body, metadata,
              priority, is_read AS "isRead", created_at AS "createdAt"
       FROM notifications WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const securityEvents = await client.query(
      `SELECT event_type AS "eventType", event_category AS "eventCategory",
              severity, ip_address AS "ipAddress", user_agent AS "userAgent",
              metadata, created_at AS "createdAt"
       FROM security_events WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const properties = await client.query(
      `SELECT id, title, description, property_type AS "propertyType", status,
              address, city, county, country, created_at AS "createdAt",
              updated_at AS "updatedAt"
       FROM properties WHERE created_by = $1 ORDER BY created_at`,
      [userId],
    );
    const ownerships = await client.query(
      `SELECT property_id AS "propertyId", owner_type AS "ownerType",
              ownership_share AS "ownershipShare", is_verified AS "isVerified",
              effective_from AS "effectiveFrom", effective_to AS "effectiveTo",
              status, created_at AS "createdAt"
       FROM property_ownerships WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const assignments = await client.query(
      `SELECT property_id AS "propertyId", assignment_type AS "assignmentType",
              scope_description AS "scopeDescription", status,
              effective_from AS "effectiveFrom", effective_to AS "effectiveTo",
              created_at AS "createdAt"
       FROM property_assignments WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const organizationMemberships = await client.query(
      `SELECT o.id AS "organizationId", o.name AS "organizationName",
              o.type AS "organizationType", om.role, om.status,
              om.joined_at AS "joinedAt", om.created_at AS "createdAt"
       FROM organisation_members om
       JOIN organisations o ON o.id = om.organisation_id
       WHERE om.user_id = $1 ORDER BY om.created_at`,
      [userId],
    );
    const tenancies = await client.query(
      `SELECT t.id, t.property_id AS "propertyId", t.unit_id AS "unitId",
              t.tenancy_type AS "tenancyType", t.status, t.start_date AS "startDate",
              t.end_date AS "endDate", t.notice_period_days AS "noticePeriodDays",
              t.rent_amount AS "rentAmount", t.deposit_amount AS "depositAmount",
              tp.role AS "participantRole", tp.status AS "participantStatus",
              tp.joined_at AS "joinedAt"
       FROM tenancy_participants tp
       JOIN tenancies t ON t.id = tp.tenancy_id
       WHERE tp.user_id = $1 ORDER BY t.created_at`,
      [userId],
    );
    const uploadedDocuments = await client.query(
      `SELECT id, property_id AS "propertyId", unit_id AS "unitId",
              tenancy_id AS "tenancyId", title, description, category, visibility,
              file_name AS "fileName", file_size AS "fileSize", mime_type AS "mimeType",
              status, uploaded_at AS "uploadedAt", expires_at AS "expiresAt"
       FROM property_documents WHERE uploaded_by = $1 ORDER BY uploaded_at`,
      [userId],
    );
    const applications = await client.query(
      `SELECT id, property_id AS "propertyId", unit_id AS "unitId", applicant_name AS "applicantName",
              applicant_email AS "applicantEmail", applicant_phone AS "applicantPhone",
              status, preferred_start_date AS "preferredStartDate",
              preferred_end_date AS "preferredEndDate", proposed_rent_amount AS "proposedRentAmount",
              documents, created_at AS "createdAt", updated_at AS "updatedAt"
       FROM rental_applications WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    const visits = await client.query(
      `SELECT id, property_id AS "propertyId", unit_id AS "unitId", scheduled_at AS "scheduledAt",
              duration_minutes AS "durationMinutes", status, visitor_notes AS "visitorNotes",
              outcome, created_at AS "createdAt", updated_at AS "updatedAt"
       FROM site_visits WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    await client.query('COMMIT');
    return {
      exportedAt: new Date().toISOString(),
      formatVersion: 1,
      account: user.rows[0],
      loginIdentities: identities.rows,
      roles: roles.rows,
      profile: personalProfile.rows[0] ?? null,
      specializedProfiles: specializedProfiles.rows,
      accountPreferences: accountPreferences.rows[0] ?? null,
      notificationPreferences: notificationPreferences.rows[0] ?? null,
      sessions: sessions.rows,
      devices: devices.rows,
      notifications: notifications.rows,
      securityEvents: securityEvents.rows,
      properties: properties.rows,
      propertyOwnerships: ownerships.rows,
      propertyAssignments: assignments.rows,
      organizationMemberships: organizationMemberships.rows,
      tenancies: tenancies.rows,
      uploadedDocuments: uploadedDocuments.rows,
      rentalApplications: applications.rows,
      siteVisits: visits.rows,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function requestEmailChange(userId: string, newEmail: string): Promise<void> {
  const normalizedEmail = newEmail.trim().toLowerCase();
  const conflict = await pool.query(
    `SELECT 1 FROM users WHERE lower(email) = $1 AND id <> $2
     UNION ALL
     SELECT 1 FROM user_login_identities
       WHERE provider = 'email' AND lower(identifier) = $1 AND user_id <> $2
     LIMIT 1`,
    [normalizedEmail, userId],
  );
  if (conflict.rowCount) throw new ConflictError('Email address is already in use');

  const token = randomInt(0, 1_000_000).toString().padStart(6, '0');
  const env = loadEnv();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE account_contact_change_tokens
       SET consumed_at = NOW()
       WHERE user_id = $1 AND channel = 'email' AND consumed_at IS NULL`,
      [userId],
    );
    await client.query(
      `INSERT INTO account_contact_change_tokens
         (id, user_id, channel, target_identifier, token_hash, expires_at)
       VALUES ($1, $2, 'email', $3, $4, NOW() + ($5 * INTERVAL '1 hour'))`,
      [randomUUID(), userId, normalizedEmail, hashOtp(token), env.EMAIL_VERIFICATION_EXPIRY_HOURS],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  await emailProvider().sendEmail({
    to: normalizedEmail,
    subject: 'Confirm your GetKeja email change',
    text: `Use this verification code in the GetKeja app to confirm your new email address: ${token}\n\nThis code expires in ${env.EMAIL_VERIFICATION_EXPIRY_HOURS} hours. If you did not request this change, ignore this email.`,
    html: `<p>Use this verification code in the GetKeja app to confirm your new email address:</p><p><strong>${token}</strong></p><p>This code expires in ${env.EMAIL_VERIFICATION_EXPIRY_HOURS} hours. If you did not request this change, ignore this email.</p>`,
  });
}

export async function requestPhoneChange(userId: string, newPhone: string): Promise<void> {
  const normalizedPhone = normalizePhone(newPhone);
  const conflict = await pool.query(
    `SELECT 1 FROM user_login_identities
     WHERE provider = 'phone' AND identifier = $1 AND user_id <> $2 LIMIT 1`,
    [normalizedPhone, userId],
  );
  if (conflict.rowCount) throw new ConflictError('Phone number is already in use');

  const otp = randomInt(0, 1_000_000).toString().padStart(6, '0');
  const env = loadEnv();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE account_contact_change_tokens
       SET consumed_at = NOW()
       WHERE user_id = $1 AND channel = 'phone' AND consumed_at IS NULL`,
      [userId],
    );
    await client.query(
      `INSERT INTO account_contact_change_tokens
         (id, user_id, channel, target_identifier, token_hash, expires_at, max_attempts)
       VALUES ($1, $2, 'phone', $3, $4, NOW() + ($5 * INTERVAL '1 minute'), $6)`,
      [
        randomUUID(),
        userId,
        normalizedPhone,
        hashOtp(otp),
        env.PHONE_VERIFICATION_EXPIRY_MINUTES,
        env.MAX_VERIFICATION_ATTEMPTS,
      ],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  await smsProvider().sendOtp(normalizedPhone, otp);
}

async function confirmContactChange(
  userId: string,
  channel: 'email' | 'phone',
  submittedValue: string,
): Promise<void> {
  const client = await pool.connect();
  let invalidOtp = false;
  try {
    await client.query('BEGIN');
    const tokenResult = await client.query<{
      id: string;
      target_identifier: string;
      token_hash: string;
      attempt_count: number;
      max_attempts: number;
    }>(
      `SELECT id, target_identifier, token_hash, attempt_count, max_attempts
       FROM account_contact_change_tokens
       WHERE user_id = $1 AND channel = $2 AND consumed_at IS NULL AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
      [userId, channel],
    );
    const token = tokenResult.rows[0];
    if (!token) throw new UnauthorizedError('Invalid or expired verification code');
    const expected = Buffer.from(token.token_hash);
    const actual = Buffer.from(hashOtp(submittedValue));
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
      const nextAttemptCount = token.attempt_count + 1;
      await client.query(
        `UPDATE account_contact_change_tokens
         SET attempt_count = $2,
             consumed_at = CASE WHEN $2 >= max_attempts THEN NOW() ELSE consumed_at END
         WHERE id = $1`,
        [token.id, nextAttemptCount],
      );
      invalidOtp = true;
      await client.query('COMMIT');
    }

    if (!invalidOtp) {
      const duplicate = channel === 'email'
        ? await client.query(
            `SELECT 1 FROM users WHERE lower(email) = $1 AND id <> $2
             UNION ALL
             SELECT 1 FROM user_login_identities
               WHERE provider = 'email' AND lower(identifier) = $1 AND user_id <> $2
             LIMIT 1`,
            [token.target_identifier, userId],
          )
        : await client.query(
            `SELECT 1 FROM user_login_identities
             WHERE provider = 'phone' AND identifier = $1 AND user_id <> $2 LIMIT 1`,
            [token.target_identifier, userId],
          );
      if (duplicate.rowCount) throw new ConflictError('Contact address is already in use');

      await client.query(
        `UPDATE account_contact_change_tokens SET consumed_at = NOW() WHERE id = $1`,
        [token.id],
      );
      const identity = await client.query<{ id: string }>(
        `WITH existing_identity AS (
           SELECT id FROM user_login_identities
           WHERE user_id = $1 AND provider = $2
           ORDER BY is_primary DESC, created_at LIMIT 1 FOR UPDATE
         )
         UPDATE user_login_identities li
         SET identifier = $3,
             verified_at = NOW(),
             password_hash = COALESCE(
               li.password_hash,
               (SELECT password_hash FROM user_login_identities
                WHERE user_id = $1 AND provider IN ('email', 'phone')
                  AND id <> li.id AND password_hash IS NOT NULL
                ORDER BY is_primary DESC, created_at LIMIT 1),
               (SELECT password_hash FROM users WHERE id = $1)
             ),
             updated_at = NOW()
         FROM existing_identity ei
         WHERE li.id = ei.id
         RETURNING li.id`,
        [userId, channel, token.target_identifier],
      );
      if (identity.rowCount === 0) {
        await client.query(
          `INSERT INTO user_login_identities
             (id, user_id, provider, identifier, password_hash, verified_at, is_primary)
           VALUES (
             $1, $2, $3, $4,
             COALESCE(
               (SELECT password_hash FROM user_login_identities
                WHERE user_id = $2 AND provider IN ('email', 'phone')
                  AND password_hash IS NOT NULL
                ORDER BY is_primary DESC, created_at LIMIT 1),
               (SELECT password_hash FROM users WHERE id = $2)
             ),
             NOW(), FALSE
           )`,
          [randomUUID(), userId, channel, token.target_identifier],
        );
      }
      if (channel === 'email') {
        await client.query(
          `UPDATE users
           SET email = $2,
               email_verified = TRUE,
               account_status = CASE
                 WHEN account_status = 'pending_verification' THEN 'active'
                 ELSE account_status
               END,
               updated_at = NOW()
           WHERE id = $1`,
          [userId, token.target_identifier],
        );
      } else {
        await client.query(
          `UPDATE users
           SET phone_verified = TRUE,
               account_status = CASE
                 WHEN account_status = 'pending_verification' THEN 'active'
                 ELSE account_status
               END,
               updated_at = NOW()
           WHERE id = $1`,
          [userId],
        );
      }
      await client.query(
        `INSERT INTO security_events (user_id, event_type, event_category, severity, metadata)
         VALUES ($1, $2, 'account', 'warning', $3)`,
        [
          userId,
          `${channel}_changed`,
          JSON.stringify({ channel, identifier: token.target_identifier }),
        ],
      );
      await client.query('COMMIT');
    }
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  if (invalidOtp) throw new UnauthorizedError('Invalid or expired verification code');
}

export async function confirmEmailChange(userId: string, token: string): Promise<void> {
  await confirmContactChange(userId, 'email', token);
}

export async function confirmPhoneChange(userId: string, otp: string): Promise<void> {
  await confirmContactChange(userId, 'phone', otp);
}

export async function getAccountStatusDetails(
  userId: string,
  requestedStatus: 'suspended' | 'locked',
) {
  const user = await pool.query<{ account_status: string }>(
    'SELECT account_status FROM users WHERE id = $1',
    [userId],
  );
  if (!user.rows[0]) throw new NotFoundError('Account not found');
  if (user.rows[0].account_status !== requestedStatus) {
    return { status: user.rows[0].account_status, reason: null, lockedUntil: null, changedAt: null };
  }
  const event = await pool.query<{ metadata: { reason?: string }; created_at: Date }>(
    `SELECT metadata, created_at
     FROM security_events
     WHERE user_id = $1 AND event_type = 'admin_account_status_changed'
       AND metadata->>'accountStatus' = $2
     ORDER BY created_at DESC LIMIT 1`,
    [userId, requestedStatus],
  );
  return {
    status: requestedStatus,
    reason: event.rows[0]?.metadata?.reason ?? null,
    lockedUntil: null,
    changedAt: event.rows[0]?.created_at ?? null,
  };
}

export async function getAccountProfile(userId: string) {
  const user = await authRepository.findUserWithRolesById(userId);
  if (!user) throw new NotFoundError('Account not found');
  const identities = await authRepository.findLoginIdentitiesByUserId(userId);

  return {
    id: user.id,
    email: user.email,
    phone: identities.find((identity) => identity.provider === 'phone')?.identifier ?? null,
    firstName: user.firstName,
    lastName: user.lastName,
    emailVerified: user.emailVerified,
    phoneVerified: user.phoneVerified,
    accountStatus: user.accountStatus,
    roles: user.roles,
    createdAt: user.createdAt,
  };
}

export async function updateAccountProfile(userId: string, input: ProfileUpdate) {
  const client = await pool.connect();
  try {
    const updated = await client.query(
      `UPDATE users
       SET first_name = COALESCE($2, first_name),
           last_name = COALESCE($3, last_name),
           name = concat_ws(' ',
             COALESCE($2, first_name),
             COALESCE($3, last_name)
           ),
           updated_at = NOW()
       WHERE id = $1 AND account_status <> 'deleted'
       RETURNING id`,
      [userId, input.firstName ?? null, input.lastName ?? null],
    );
    if (updated.rowCount !== 1) throw new NotFoundError('Account not found');
  } finally {
    client.release();
  }
  return getAccountProfile(userId);
}

export async function getConnectedAccounts(userId: string) {
  const [identities, google] = await Promise.all([
    authRepository.findLoginIdentitiesByUserId(userId),
    authRepository.findGoogleIdentityByUserId(userId),
  ]);
  return {
    hasPassword: identities.some((identity) => Boolean(identity.passwordHash)),
    loginMethods: identities.map(({ id, provider, identifier, verifiedAt, isPrimary, passwordHash }) => ({
      id,
      provider,
      identifier,
      verified: verifiedAt !== null,
      isPrimary,
      hasPassword: Boolean(passwordHash),
    })),
    google: google
      ? {
          linked: true,
          email: google.email,
          emailVerified: google.emailVerified,
          name: google.name,
          picture: google.picture,
          linkedAt: google.linkedAt,
        }
      : { linked: false },
  };
}

export async function changePassword(userId: string, currentPassword: string, newPassword: string): Promise<void> {
  await verifyCurrentPassword(userId, currentPassword);
  const passwordHash = await argon2.hash(newPassword);
  await authRepository.updateAllPasswordHashes(userId, passwordHash);
  await sessionService.revokeAllUserSessions(userId, 'password_changed');
  await authRepository.createSecurityEvent(
    userId,
    'password_changed',
    'account',
    'warning',
    null,
    null,
    {},
  );
  try {
    const user = await authRepository.findUserById(userId);
    if (user?.email && user.emailVerified) {
      const env = loadEnv();
      await createEmailProvider({
        fromAddress: env.EMAIL_FROM_ADDRESS,
        fromName: env.EMAIL_FROM_NAME,
        baseUrl: env.EMAIL_BASE_URL,
      }).sendEmail({
        to: user.email,
        subject: 'A sign-in method changed on your GetKeja account',
        text: 'Your GetKeja password was changed. If you did not make this change, secure your account and contact support.',
        html: '<p>Your GetKeja password was changed. If you did not make this change, secure your account and contact support.</p>',
      });
    } else {
      const verifiedPhone = (await authRepository.findLoginIdentitiesByUserId(userId))
        .find((identity) => identity.provider === 'phone' && identity.verifiedAt)?.identifier;
      if (verifiedPhone) {
        await smsProvider().sendSms({
          to: verifiedPhone,
          body: 'Your GetKeja password was changed. If you did not make this change, secure your account and contact support.',
        });
      }
    }
  } catch (error) {
    console.error('Failed to send password-change security alert', error);
  }
}

export async function requestAccountRestoration(contact: string): Promise<void> {
  const normalizedContact = contact.trim();
  const isEmail = normalizedContact.includes('@');
  const found = isEmail
    ? await pool.query<{
        id: string;
        email: string;
        account_status: string;
        account_status_source: string | null;
        deleted_at: Date | null;
        personal_data_purged_at: Date | null;
        email_verified: boolean;
      }>(
        `SELECT id, email, account_status, account_status_source, deleted_at,
                personal_data_purged_at, email_verified
         FROM users WHERE lower(email) = lower($1)`,
        [normalizedContact],
      )
    : await pool.query<{
        id: string;
        email: string;
        account_status: string;
        account_status_source: string | null;
        deleted_at: Date | null;
        personal_data_purged_at: Date | null;
        phone_verified: boolean;
      }>(
        `SELECT u.id, u.email, u.account_status, u.account_status_source,
                u.deleted_at, u.personal_data_purged_at, u.phone_verified
         FROM users u
         JOIN user_login_identities li ON li.user_id = u.id
         WHERE li.provider = 'phone' AND li.identifier = $1
           AND li.verified_at IS NOT NULL`,
        [normalizePhone(normalizedContact)],
      );

  const user = found.rows[0];
  if (!user || user.personal_data_purged_at) return;

  const isVerifiedContact = isEmail
    ? 'email_verified' in user && user.email_verified
    : 'phone_verified' in user && user.phone_verified;
  if (!isVerifiedContact) return;

  let restoreType: 'reactivate' | 'restore_deleted';
  if (
    user.account_status === 'deactivated' &&
    user.account_status_source === 'user' &&
    user.deleted_at === null
  ) {
    restoreType = 'reactivate';
  } else if (
    user.account_status === 'deleted' &&
    user.account_status_source === 'user' &&
    user.deleted_at !== null &&
    user.deleted_at.getTime() >= Date.now() - ACCOUNT_RESTORE_WINDOW_DAYS * 24 * 60 * 60 * 1000
  ) {
    restoreType = 'restore_deleted';
  } else {
    return;
  }

  const token = randomBytes(32).toString('base64url');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE account_restore_tokens
       SET used_at = NOW()
       WHERE user_id = $1 AND used_at IS NULL`,
      [user.id],
    );
    await client.query(
      `INSERT INTO account_restore_tokens (user_id, restore_type, token_hash, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [user.id, restoreType, hashValue(token), new Date(Date.now() + ACCOUNT_RESTORE_TOKEN_TTL_MS)],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  if (isEmail) {
    await emailProvider().sendAccountRestorationEmail(normalizedContact, token);
  } else {
    await smsProvider().sendOtp(
      normalizePhone(normalizedContact),
      `Your GetKeja account restoration code is ${token}. It expires in 1 hour.`,
    );
  }
}

export async function confirmAccountRestoration(token: string): Promise<void> {
  const client = await pool.connect();
  let restoredUserId: string | undefined;
  try {
    await client.query('BEGIN');
    const tokenResult = await client.query<{
      user_id: string;
      restore_type: 'reactivate' | 'restore_deleted';
    }>(
      `SELECT restore_token.user_id, restore_token.restore_type
       FROM account_restore_tokens restore_token
       JOIN users account ON account.id = restore_token.user_id
       WHERE restore_token.token_hash = $1
         AND restore_token.used_at IS NULL
         AND restore_token.expires_at > NOW()
         AND account.account_status_source = 'user'
         AND account.personal_data_purged_at IS NULL
         AND (
           (restore_token.restore_type = 'reactivate'
             AND account.account_status = 'deactivated'
             AND account.deleted_at IS NULL)
           OR
           (restore_token.restore_type = 'restore_deleted'
             AND account.account_status = 'deleted'
             AND account.deleted_at > NOW() - INTERVAL '30 days')
         )
       FOR UPDATE OF restore_token, account`,
      [hashValue(token)],
    );
    const restore = tokenResult.rows[0];
    if (!restore) throw new ForbiddenError('This restoration code is invalid or expired');

    const updated = await client.query(
      `UPDATE users
       SET account_status = 'active', is_active = TRUE, is_suspended = FALSE,
           is_locked = FALSE, is_deactivated = FALSE, deleted_at = NULL,
           account_status_source = NULL, updated_at = NOW()
       WHERE id = $1 AND account_status_source = 'user'
       RETURNING id`,
      [restore.user_id],
    );
    if (updated.rowCount !== 1) throw new ForbiddenError('This account cannot be restored');

    await client.query(
      `UPDATE account_restore_tokens SET used_at = NOW()
       WHERE user_id = $1 AND used_at IS NULL`,
      [restore.user_id],
    );
    await client.query(
      `INSERT INTO security_events
         (user_id, event_type, event_category, severity, metadata)
       VALUES ($1, 'account_restored_by_owner', 'account', 'warning', $2)`,
      [restore.user_id, JSON.stringify({ restoreType: restore.restore_type })],
    );
    restoredUserId = restore.user_id;
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  if (restoredUserId) {
    await sessionService.revokeAllUserSessions(restoredUserId, 'account_restored_sign_in_required');
  }
}

export async function purgeExpiredDeletedAccounts(limit = 100): Promise<number> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const expired = await client.query<{ id: string }>(
      `SELECT id FROM users
       WHERE account_status = 'deleted'
         AND account_status_source = 'user'
         AND deleted_at <= NOW() - INTERVAL '30 days'
         AND personal_data_purged_at IS NULL
       ORDER BY deleted_at
       LIMIT $1
       FOR UPDATE SKIP LOCKED`,
      [limit],
    );

    for (const { id } of expired.rows) {
      const specializedProfiles = await client.query<{ id: string }>(
        `SELECT id FROM specialized_profiles WHERE user_id = $1`,
        [id],
      );
      const specializedProfileIds = specializedProfiles.rows.map((profile) => profile.id);
      const { deleteUserProfileAssets } = await import('../profile/profile-image-upload.service.js');
      await deleteUserProfileAssets(id, specializedProfileIds);

      const privateDocs = await client.query<{ storage_key: string }>(
        `SELECT storage_key FROM profile_verification_documents
         WHERE specialized_profile_id = ANY($1::uuid[])`,
        [specializedProfileIds],
      );
      const { deletePrivateDocument } = await import('../profile/private-document-storage.service.js');
      for (const { storage_key } of privateDocs.rows) {
        await deletePrivateDocument(storage_key);
      }

      await client.query('DELETE FROM account_restore_tokens WHERE user_id = $1', [id]);
      await client.query('DELETE FROM user_login_identities WHERE user_id = $1', [id]);
      await client.query('DELETE FROM user_profiles WHERE user_id = $1', [id]);
      await client.query(
        `DELETE FROM profile_verification_documents
         WHERE specialized_profile_id = ANY($1::uuid[])`,
        [specializedProfileIds],
      );
      await client.query('DELETE FROM specialized_profiles WHERE user_id = $1', [id]);
      await client.query('DELETE FROM user_roles WHERE user_id = $1', [id]);
      await client.query('DELETE FROM role_assignments WHERE user_id = $1', [id]);
      await client.query('DELETE FROM organisation_members WHERE user_id = $1', [id]);
      await client.query('DELETE FROM organisation_invitations WHERE invited_by = $1', [id]);
      await client.query('DELETE FROM property_assignments WHERE user_id = $1', [id]);
      await client.query('DELETE FROM unit_access_assignments WHERE user_id = $1', [id]);
      await client.query('DELETE FROM saved_locations WHERE user_id = $1', [id]);
      await client.query('DELETE FROM user_account_preferences WHERE user_id = $1', [id]);
      await client.query('DELETE FROM notification_preferences WHERE user_id = $1', [id]);
      await client.query('DELETE FROM notification_recipients WHERE user_id = $1', [id]);
      await client.query('DELETE FROM notification_dead_letters WHERE recipient_id = $1', [id]);
      await client.query('DELETE FROM notification_delivery_attempts WHERE recipient_id = $1', [id]);
      await client.query('DELETE FROM notifications WHERE user_id = $1', [id]);
      await client.query(
        `UPDATE notification_outbox
         SET recipient_user_ids = array_remove(recipient_user_ids, $1::uuid), updated_at = NOW()
         WHERE $1::uuid = ANY(recipient_user_ids)`,
        [id],
      );
      await client.query('DELETE FROM devices WHERE user_id = $1', [id]);
      await client.query('DELETE FROM auth_sessions WHERE user_id = $1', [id]);
      await client.query('DELETE FROM sessions WHERE user_id = $1', [id]);
      await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [id]);
      await client.query('DELETE FROM password_reset_tokens WHERE user_id = $1', [id]);
      await client.query('DELETE FROM email_verification_tokens WHERE user_id = $1', [id]);
      await client.query('DELETE FROM phone_verification_tokens WHERE user_id = $1', [id]);
      await client.query('DELETE FROM email_login_otp WHERE user_id = $1', [id]);
      await client.query('DELETE FROM phone_login_otp WHERE user_id = $1', [id]);
      await client.query('DELETE FROM mfa_challenges WHERE user_id = $1', [id]);
      await client.query('DELETE FROM mfa_methods WHERE user_id = $1', [id]);
      await client.query('DELETE FROM mfa_totp_secrets WHERE user_id = $1', [id]);
      await client.query('DELETE FROM mfa_recovery_codes WHERE user_id = $1', [id]);
      await client.query('DELETE FROM account_contact_change_tokens WHERE user_id = $1', [id]);

      await client.query(
        `UPDATE users
         SET email = 'deleted+' || id::text || '@purged.invalid',
             password_hash = $2, name = NULL, first_name = NULL, last_name = NULL,
             email_verified = FALSE, phone_verified = FALSE, mfa_enabled = FALSE,
             mfa_enrolled_at = NULL, last_mfa_verified_at = NULL,
             mfa_enrollment_required = FALSE, personal_data_purged_at = NOW(),
             updated_at = NOW()
         WHERE id = $1 AND account_status = 'deleted'
           AND account_status_source = 'user' AND personal_data_purged_at IS NULL`,
        [id, randomBytes(64).toString('hex')],
      );
    }
    await client.query('COMMIT');
    return expired.rowCount ?? 0;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function verifyCurrentPassword(userId: string, password?: string): Promise<void> {
  const identities = await authRepository.findLoginIdentitiesByUserId(userId);
  const passwordHashes = identities
    .map((identity) => identity.passwordHash)
    .filter((hash): hash is string => Boolean(hash));
  if (passwordHashes.length === 0) return;
  if (!password) throw new ForbiddenError('Current password is required');

  let valid = false;
  for (const hash of passwordHashes) {
    if (await argon2.verify(hash, password)) {
      valid = true;
      break;
    }
  }
  if (!valid) throw new UnauthorizedError('Invalid credentials');
}

async function changeAccountStatus(
  user: AuthUser,
  accountStatus: 'deactivated' | 'deleted',
  password?: string,
): Promise<void> {
  await verifyCurrentPassword(user.id, password);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const updated = await client.query(
      `UPDATE users
       SET account_status = $2,
           is_active = FALSE,
           is_suspended = FALSE,
           is_locked = FALSE,
           is_deactivated = $3,
           account_status_source = 'user',
           deleted_at = CASE WHEN $2 = 'deleted' THEN NOW() ELSE deleted_at END,
           updated_at = NOW()
       WHERE id = $1 AND account_status = 'active' AND deleted_at IS NULL
       RETURNING id`,
      [user.id, accountStatus, accountStatus === 'deactivated'],
    );
    if (updated.rowCount !== 1) {
      throw new ForbiddenError('Only active accounts can perform this action');
    }
    await client.query(
      `INSERT INTO security_events
         (user_id, event_type, event_category, severity, metadata)
       VALUES ($1, $2, 'account', 'warning', $3)`,
      [
        user.id,
        accountStatus === 'deleted' ? 'account_deletion_requested' : 'account_paused',
        JSON.stringify({ accountStatus }),
      ],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
  await sessionService.revokeAllUserSessions(user.id, `account_${accountStatus}`);
}

export async function pauseAccount(user: AuthUser, password?: string): Promise<void> {
  await changeAccountStatus(user, 'deactivated', password);
}

export async function deleteAccount(user: AuthUser, password?: string): Promise<void> {
  await changeAccountStatus(user, 'deleted', password);
}

export async function listUsers(input: AdminUserList) {
  const result = await pool.query(
    `SELECT id, email, first_name AS "firstName", last_name AS "lastName",
            account_status AS "accountStatus", email_verified AS "emailVerified",
            phone_verified AS "phoneVerified", mfa_enabled AS "mfaEnabled",
            created_at AS "createdAt", updated_at AS "updatedAt"
     FROM users
     WHERE ($1::text IS NULL OR account_status = $1)
       AND ($2::text IS NULL OR email ILIKE '%' || $2 || '%'
            OR first_name ILIKE '%' || $2 || '%'
            OR last_name ILIKE '%' || $2 || '%')
     ORDER BY created_at DESC, id
     LIMIT $3 OFFSET $4`,
    [input.status ?? null, input.search ?? null, input.limit, input.offset],
  );
  return result.rows;
}

export async function getUserForAdmin(targetUserId: string) {
  const user = await authRepository.findUserWithRolesById(targetUserId);
  if (!user) throw new NotFoundError('User not found');
  const identities = await authRepository.findLoginIdentitiesByUserId(targetUserId);
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    accountStatus: user.accountStatus,
    emailVerified: user.emailVerified,
    phoneVerified: user.phoneVerified,
    mfaEnabled: user.mfaEnabled,
    roles: user.roles,
    loginMethods: identities.map(({ provider, identifier, verifiedAt }) => ({
      provider,
      identifier,
      verified: verifiedAt !== null,
    })),
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

interface AdminActor {
  id: string;
}

export async function updateUserStatus(
  actor: AdminActor,
  targetUserId: string,
  action: AdminUserAction,
  reason: string,
): Promise<{ accountStatus: AuthUser['accountStatus'] }> {
  if (actor.id === targetUserId) {
    throw new ForbiddenError('Administrators cannot change their own account status');
  }

  const target = await authRepository.findUserWithRolesById(targetUserId);
  if (!target) throw new NotFoundError('User not found');

  if (target.roles.includes('super_admin') &&
      !(await authorizationService.hasPlatformRole(actor.id, 'super_admin'))) {
    throw new ForbiddenError('Only a super administrator can modify this account');
  }

  const nextStatus = statusAfterAction(target, action);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const updated = await client.query(
      `UPDATE users
       SET account_status = $2,
           is_active = $3,
           is_suspended = $4,
           is_locked = $5,
           is_deactivated = $6,
           account_status_source = CASE WHEN $2 IN ('deactivated', 'deleted') THEN 'admin' ELSE NULL END,
           deleted_at = CASE WHEN $2 = 'deleted' THEN COALESCE(deleted_at, NOW()) ELSE NULL END,
           updated_at = NOW()
       WHERE id = $1
       RETURNING account_status`,
      [
        targetUserId,
        nextStatus,
        nextStatus === 'active' || nextStatus === 'pending_verification',
        nextStatus === 'suspended',
        nextStatus === 'locked',
        nextStatus === 'deactivated',
      ],
    );
    if (updated.rowCount !== 1) throw new NotFoundError('User not found');
    await client.query(
      `INSERT INTO security_events
         (user_id, event_type, event_category, severity, metadata)
       VALUES ($1, 'admin_account_status_changed', 'admin', 'critical', $2)`,
      [
        targetUserId,
        JSON.stringify({ actorUserId: actor.id, action, reason, accountStatus: nextStatus }),
      ],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  if (['suspended', 'locked', 'deactivated', 'deleted'].includes(nextStatus)) {
    await sessionService.revokeAllUserSessions(targetUserId, `admin_${action}`);
  }
  return { accountStatus: nextStatus };
}

function statusAfterAction(user: AuthUser, action: AdminUserAction): AuthUser['accountStatus'] {
  const verified = user.emailVerified || user.phoneVerified;
  switch (action) {
    case 'suspend':
      if (!['active', 'pending_verification'].includes(user.accountStatus)) {
        throw new ForbiddenError('Only active or pending accounts can be suspended');
      }
      return 'suspended';
    case 'reinstate':
      if (user.accountStatus !== 'suspended') throw new ForbiddenError('User is not suspended');
      return verified ? 'active' : 'pending_verification';
    case 'lock':
      if (!['active', 'pending_verification'].includes(user.accountStatus)) {
        throw new ForbiddenError('Only active or pending accounts can be locked');
      }
      return 'locked';
    case 'unlock':
      if (user.accountStatus !== 'locked') throw new ForbiddenError('User is not locked');
      return verified ? 'active' : 'pending_verification';
    case 'deactivate':
      if (!['active', 'pending_verification'].includes(user.accountStatus)) {
        throw new ForbiddenError('Only active or pending accounts can be deactivated');
      }
      return 'deactivated';
    case 'reactivate':
      if (user.accountStatus !== 'deactivated') throw new ForbiddenError('User is not deactivated');
      return verified ? 'active' : 'pending_verification';
  }
}
