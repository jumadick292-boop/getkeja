import { randomUUID, createHash, timingSafeEqual } from 'node:crypto';
import { pool } from '../../db/pool.js';
import { ConflictError } from '../../shared/errors.js';
import type {
  AuthUser,
  UserLoginIdentity,
  Role,
  EmailVerificationToken,
  PhoneVerificationToken,
  EmailLoginOtp,
  PhoneLoginOtp,
  MfaChallenge,
  GoogleIdentity,
  UserRole,
  Organisation,
  OrganisationMember,
  OrganisationInvitation,
  MfaMethod,
  MfaTotpSecret,
  MfaRecoveryCode,
  SecurityEvent,
  NotificationTemplate,
  Notification,
  NotificationRecipient,
  NotificationPreferences,
  NotificationDeliveryAttempt,
  NotificationDeadLetter,
  NotificationOutbox,
  Session,
  RefreshToken,
  Device,
} from './auth.types.js';

interface UserRow extends AuthUser {
  password_hash: string;
  first_name: string | null;
  last_name: string | null;
  is_active: boolean;
  is_suspended: boolean;
  is_locked: boolean;
  is_deactivated: boolean;
  account_status: AuthUser['accountStatus'];
  deleted_at: Date | null;
  email_verified: boolean;
  phone_verified: boolean;
  mfa_enabled: boolean;
  mfa_enrolled_at: Date | null;
  last_mfa_verified_at: Date | null;
  mfa_enrollment_required: boolean;
  created_at: Date;
  updated_at: Date;
}

function mapUserRow(row: UserRow): AuthUser {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    firstName: row.first_name,
    lastName: row.last_name,
    roles: row.roles,
    isActive: row.is_active,
    isSuspended: row.is_suspended,
    isLocked: row.is_locked,
    isDeactivated: row.is_deactivated,
    accountStatus: row.account_status,
    deletedAt: row.deleted_at,
    emailVerified: row.email_verified,
    phoneVerified: row.phone_verified,
    mfaEnabled: row.mfa_enabled,
    mfaEnrolledAt: row.mfa_enrolled_at,
    lastMfaVerifiedAt: row.last_mfa_verified_at,
    mfaEnrollmentRequired: row.mfa_enrollment_required,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function findUserByEmail(email: string): Promise<UserRow | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT
       id, email, name, first_name, last_name, password_hash,
       is_active, is_suspended, is_locked, is_deactivated,
       email_verified, phone_verified, mfa_enabled,
       mfa_enrolled_at, last_mfa_verified_at, mfa_enrollment_required,
       account_status, deleted_at,
       created_at, updated_at
     FROM users WHERE lower(email) = lower($1)`,
    [email],
  );
  return result.rows[0];
}

export async function findUserById(id: string): Promise<AuthUser | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT
       id, email, name, first_name, last_name,
       is_active, is_suspended, is_locked, is_deactivated,
       email_verified, phone_verified, mfa_enabled,
       mfa_enrolled_at, last_mfa_verified_at, mfa_enrollment_required,
       account_status, deleted_at,
       created_at, updated_at
     FROM users WHERE id = $1`,
    [id],
  );
  return result.rows[0] ? mapUserRow(result.rows[0]) : undefined;
}

export async function findUserByPhone(phone: string): Promise<UserRow | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT
       u.id, u.email, u.name, u.first_name, u.last_name, u.password_hash,
       u.is_active, u.is_suspended, u.is_locked, u.is_deactivated,
       u.email_verified, u.phone_verified, u.mfa_enabled,
       u.account_status, u.deleted_at,
       u.mfa_enrolled_at, u.last_mfa_verified_at, u.mfa_enrollment_required,
       u.created_at, u.updated_at
     FROM users u
     JOIN user_login_identities li ON li.user_id = u.id
     WHERE li.provider = 'phone' AND li.identifier = $1`,
    [phone],
  );
  return result.rows[0];
}

export async function findUserWithRolesById(id: string): Promise<AuthUser | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT
       u.id, u.email, u.name, u.first_name, u.last_name,
       u.is_active, u.is_suspended, u.is_locked, u.is_deactivated,
       u.email_verified, u.phone_verified, u.mfa_enabled,
       u.mfa_enrolled_at, u.last_mfa_verified_at, u.mfa_enrollment_required,
       u.account_status, u.deleted_at,
       u.created_at, u.updated_at,
       COALESCE(
         json_agg(r.id) FILTER (WHERE r.id IS NOT NULL),
         '[]'
       ) as roles
     FROM users u
     LEFT JOIN user_roles ur ON ur.user_id = u.id
     LEFT JOIN roles r ON r.id = ur.role_id
     WHERE u.id = $1
     GROUP BY u.id`,
    [id],
  );
  return result.rows[0] ? mapUserRow(result.rows[0]) : undefined;
}

export async function hasSystemRole(userId: string): Promise<boolean> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count
     FROM user_roles ur
     JOIN roles r ON r.id = ur.role_id
     WHERE ur.user_id = $1 AND r.is_system = true`,
    [userId],
  );
  return parseInt(result.rows[0]?.count || '0', 10) > 0;
}

export async function createUser(
  email: string,
  passwordHash: string,
  firstName?: string,
  lastName?: string,
  name?: string,
): Promise<AuthUser> {
  const id = randomUUID();
  const fullName = name ?? (firstName && lastName ? `${firstName} ${lastName}` : firstName ?? lastName ?? null);
  const result = await pool.query<UserRow>(
    `INSERT INTO users (id, email, password_hash, name, first_name, last_name)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING
       id, email, name, first_name, last_name,
       is_active, is_suspended, is_locked, is_deactivated,
       email_verified, phone_verified, mfa_enabled,
       mfa_enrolled_at, last_mfa_verified_at, mfa_enrollment_required,
       account_status, deleted_at,
       created_at, updated_at`,
    [id, email, passwordHash, fullName, firstName ?? null, lastName ?? null],
  );
  return mapUserRow(result.rows[0]!);
}

export async function createLoginIdentity(
  userId: string,
  provider: 'email' | 'phone' | 'google',
  identifier: string,
  passwordHash: string | null = null,
  isPrimary = false,
  metadata: Record<string, unknown> | null = null,
): Promise<UserLoginIdentity> {
  const id = randomUUID();
  const result = await pool.query<UserLoginIdentity>(
    `INSERT INTO user_login_identities (id, user_id, provider, identifier, password_hash, is_primary, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, user_id as "userId", provider, identifier, password_hash as "passwordHash",
       verified_at as "verifiedAt", is_primary as "isPrimary", metadata, created_at as "createdAt", updated_at as "updatedAt"`,
    [id, userId, provider, identifier, passwordHash, isPrimary, metadata ? JSON.stringify(metadata) : null],
  );
  return result.rows[0]!;
}

export async function findLoginIdentity(
  provider: 'email' | 'phone' | 'google',
  identifier: string,
): Promise<UserLoginIdentity | undefined> {
  const result = await pool.query<UserLoginIdentity>(
    `SELECT id, user_id as "userId", provider, identifier, password_hash as "passwordHash",
       verified_at as "verifiedAt", is_primary as "isPrimary", metadata, created_at as "createdAt", updated_at as "updatedAt"
     FROM user_login_identities
     WHERE provider = $1 AND identifier = $2`,
    [provider, identifier],
  );
  return result.rows[0];
}

export async function findLoginIdentityById(id: string): Promise<UserLoginIdentity | undefined> {
  const result = await pool.query<UserLoginIdentity>(
    `SELECT id, user_id as "userId", provider, identifier, password_hash as "passwordHash",
       verified_at as "verifiedAt", is_primary as "isPrimary", metadata, created_at as "createdAt", updated_at as "updatedAt"
     FROM user_login_identities WHERE id = $1`,
    [id],
  );
  return result.rows[0];
}

export async function findLoginIdentitiesByUserId(userId: string): Promise<UserLoginIdentity[]> {
  const result = await pool.query<UserLoginIdentity>(
    `SELECT id, user_id as "userId", provider, identifier, password_hash as "passwordHash",
       verified_at as "verifiedAt", is_primary as "isPrimary", metadata, created_at as "createdAt", updated_at as "updatedAt"
     FROM user_login_identities WHERE user_id = $1`,
    [userId],
  );
  return result.rows;
}

export async function updateLoginIdentityVerified(identityId: string): Promise<void> {
  await pool.query(
    'UPDATE user_login_identities SET verified_at = NOW(), updated_at = NOW() WHERE id = $1',
    [identityId],
  );
}

export async function updateLoginIdentityPassword(identityId: string, passwordHash: string): Promise<void> {
  await pool.query(
    'UPDATE user_login_identities SET password_hash = $1, updated_at = NOW() WHERE id = $2',
    [passwordHash, identityId],
  );
}

export async function setPrimaryLoginIdentity(userId: string, identityId: string): Promise<void> {
  await pool.query(
    `UPDATE user_login_identities SET is_primary = FALSE WHERE user_id = $1;
     UPDATE user_login_identities SET is_primary = TRUE, updated_at = NOW() WHERE id = $2`,
    [userId, identityId],
  );
}

export async function deleteLoginIdentity(identityId: string): Promise<void> {
  await pool.query('DELETE FROM user_login_identities WHERE id = $1', [identityId]);
}

export async function getPubliclyAssignableRoles(): Promise<Role[]> {
  const result = await pool.query<Role>(
    `SELECT id, name, description, is_system as "isSystem", is_publicly_assignable as "isPubliclyAssignable",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM roles WHERE is_publicly_assignable = TRUE ORDER BY name`,
  );
  return result.rows;
}

export async function getRoleById(roleId: string): Promise<Role | undefined> {
  const result = await pool.query<Role>(
    `SELECT id, name, description, is_system as "isSystem", is_publicly_assignable as "isPubliclyAssignable",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM roles WHERE id = $1`,
    [roleId],
  );
  return result.rows[0];
}

export async function assignRoleToUser(userId: string, roleId: string, assignedBy: string | null = null): Promise<void> {
  await pool.query(
    `INSERT INTO user_roles (user_id, role_id, assigned_by)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, role_id) DO NOTHING`,
    [userId, roleId, assignedBy],
  );
}

export async function getUserRoles(userId: string): Promise<string[]> {
  const result = await pool.query<{ role_id: string }>(
    'SELECT role_id FROM user_roles WHERE user_id = $1',
    [userId],
  );
  return result.rows.map((r) => r.role_id);
}

export async function removeRoleFromUser(userId: string, roleId: string): Promise<void> {
  await pool.query('DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2', [userId, roleId]);
}

export async function createEmailVerificationToken(
  userId: string,
  loginIdentityId: string,
  tokenHash: string,
  expiresAt: Date,
  maxAttempts = 5,
): Promise<void> {
  await pool.query(
    `INSERT INTO email_verification_tokens (id, user_id, login_identity_id, token_hash, expires_at, max_attempts)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [randomUUID(), userId, loginIdentityId, tokenHash, expiresAt, maxAttempts],
  );
}

export async function findEmailVerificationToken(tokenHash: string): Promise<EmailVerificationToken | undefined> {
  const result = await pool.query<EmailVerificationToken>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", token_hash as "tokenHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM email_verification_tokens
     WHERE token_hash = $1`,
    [tokenHash],
  );
  return result.rows[0];
}

export async function findPendingEmailVerificationToken(loginIdentityId: string): Promise<EmailVerificationToken | undefined> {
  const result = await pool.query<EmailVerificationToken>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", token_hash as "tokenHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM email_verification_tokens
     WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [loginIdentityId],
  );
  return result.rows[0];
}

export async function consumeEmailVerificationToken(
  loginIdentityId: string,
  tokenHash: string,
): Promise<{ userId: string; loginIdentityId: string } | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query<{ user_id: string; login_identity_id: string }>(
      `SELECT user_id, login_identity_id
       FROM email_verification_tokens
       WHERE login_identity_id = $1 AND token_hash = $2
         AND consumed_at IS NULL AND expires_at > NOW()
       FOR UPDATE`,
      [loginIdentityId, tokenHash],
    );
    if (!result.rows[0]) {
      await client.query('ROLLBACK');
      return null;
    }
    await client.query(
      `UPDATE email_verification_tokens SET consumed_at = NOW()
       WHERE login_identity_id = $1 AND token_hash = $2`,
      [loginIdentityId, tokenHash],
    );
    await client.query('COMMIT');
    return { userId: result.rows[0].user_id, loginIdentityId: result.rows[0].login_identity_id };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function incrementEmailVerificationAttempt(
  loginIdentityId: string,
): Promise<{ attemptCount: number; maxAttempts: number } | null> {
  const result = await pool.query<{ attemptCount: number; maxAttempts: number }>(
    `UPDATE email_verification_tokens
     SET attempt_count = attempt_count + 1,
         consumed_at = CASE WHEN attempt_count + 1 >= max_attempts THEN NOW() ELSE consumed_at END
     WHERE id = (
       SELECT id FROM email_verification_tokens
       WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1
     )
     RETURNING attempt_count AS "attemptCount", max_attempts AS "maxAttempts"`,
    [loginIdentityId],
  );
  return result.rows[0] ?? null;
}

export async function invalidateEmailVerificationTokens(loginIdentityId: string): Promise<void> {
  await pool.query(
    'UPDATE email_verification_tokens SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
    [loginIdentityId],
  );
}

export async function createPhoneVerificationToken(
  userId: string,
  loginIdentityId: string,
  otpHash: string,
  expiresAt: Date,
  maxAttempts = 5,
): Promise<void> {
  await pool.query(
    `INSERT INTO phone_verification_tokens (id, user_id, login_identity_id, otp_hash, expires_at, max_attempts)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [randomUUID(), userId, loginIdentityId, otpHash, expiresAt, maxAttempts],
  );
}

export async function findPhoneVerificationToken(
  loginIdentityId: string,
  otpHash: string,
): Promise<PhoneVerificationToken | undefined> {
  const result = await pool.query<PhoneVerificationToken>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM phone_verification_tokens
     WHERE login_identity_id = $1 AND otp_hash = $2 AND consumed_at IS NULL AND expires_at > NOW()`,
    [loginIdentityId, otpHash],
  );
  return result.rows[0];
}

export async function findPendingPhoneVerificationToken(loginIdentityId: string): Promise<PhoneVerificationToken | undefined> {
  const result = await pool.query<PhoneVerificationToken>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM phone_verification_tokens
     WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [loginIdentityId],
  );
  return result.rows[0];
}

export async function consumePhoneVerificationToken(
  loginIdentityId: string,
  otpHash: string,
): Promise<{ userId: string; loginIdentityId: string } | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query<{ user_id: string; login_identity_id: string }>(
      `SELECT user_id, login_identity_id
       FROM phone_verification_tokens
       WHERE login_identity_id = $1 AND otp_hash = $2 AND consumed_at IS NULL AND expires_at > NOW()
       FOR UPDATE`,
      [loginIdentityId, otpHash],
    );
    if (!result.rows[0]) {
      await client.query('ROLLBACK');
      return null;
    }
    await client.query(
      'UPDATE phone_verification_tokens SET consumed_at = NOW() WHERE login_identity_id = $1 AND otp_hash = $2',
      [loginIdentityId, otpHash],
    );
    await client.query('COMMIT');
    return { userId: result.rows[0].user_id, loginIdentityId: result.rows[0].login_identity_id };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function incrementPhoneVerificationAttempt(
  loginIdentityId: string,
): Promise<{ attemptCount: number; maxAttempts: number } | null> {
  const result = await pool.query<{ attemptCount: number; maxAttempts: number }>(
    `UPDATE phone_verification_tokens
     SET attempt_count = attempt_count + 1,
         consumed_at = CASE WHEN attempt_count + 1 >= max_attempts THEN NOW() ELSE consumed_at END
     WHERE id = (
       SELECT id FROM phone_verification_tokens
       WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1
     )
     RETURNING attempt_count AS "attemptCount", max_attempts AS "maxAttempts"`,
    [loginIdentityId],
  );
  return result.rows[0] ?? null;
}

export async function invalidatePhoneVerificationTokens(loginIdentityId: string): Promise<void> {
  await pool.query(
    'UPDATE phone_verification_tokens SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
    [loginIdentityId],
  );
}

export async function createGoogleIdentity(
  userId: string,
  loginIdentityId: string,
  googleSubject: string,
  email: string,
  emailVerified: boolean,
  name: string | null,
  givenName: string | null,
  familyName: string | null,
  picture: string | null,
  locale: string | null,
  rawProfile: Record<string, unknown>,
): Promise<GoogleIdentity> {
  const id = randomUUID();
  const result = await pool.query<GoogleIdentity>(
    `INSERT INTO google_identities (id, user_id, login_identity_id, google_subject, email, email_verified, name, given_name, family_name, picture, locale, raw_profile)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING id, user_id as "userId", login_identity_id as "loginIdentityId", google_subject as "googleSubject",
       email, email_verified as "emailVerified", name, given_name as "givenName", family_name as "familyName",
       picture, locale, raw_profile as "rawProfile", linked_at as "linkedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, userId, loginIdentityId, googleSubject, email, emailVerified, name, givenName, familyName, picture, locale, JSON.stringify(rawProfile)],
  );
  return result.rows[0]!;
}

export async function findGoogleIdentityBySubject(googleSubject: string): Promise<GoogleIdentity | undefined> {
  const result = await pool.query<GoogleIdentity>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", google_subject as "googleSubject",
       email, email_verified as "emailVerified", name, given_name as "givenName", family_name as "familyName",
       picture, locale, raw_profile as "rawProfile", linked_at as "linkedAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM google_identities WHERE google_subject = $1`,
    [googleSubject],
  );
  return result.rows[0];
}

export async function findGoogleIdentityByUserId(userId: string): Promise<GoogleIdentity | undefined> {
  const result = await pool.query<GoogleIdentity>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", google_subject as "googleSubject",
       email, email_verified as "emailVerified", name, given_name as "givenName", family_name as "familyName",
       picture, locale, raw_profile as "rawProfile", linked_at as "linkedAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM google_identities WHERE user_id = $1`,
    [userId],
  );
  return result.rows[0];
}

export async function deleteGoogleIdentity(userId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const identity = await client.query<{ login_identity_id: string }>(
      'SELECT login_identity_id FROM google_identities WHERE user_id = $1 FOR UPDATE',
      [userId],
    );
    if (identity.rows[0]) {
      await client.query(
        `DELETE FROM user_login_identities
         WHERE id = $1 AND user_id = $2 AND provider = 'google'`,
        [identity.rows[0].login_identity_id, userId],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function createSession(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
  await pool.query(
    `INSERT INTO auth_sessions (id, user_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [randomUUID(), userId, tokenHash, expiresAt],
  );
}

export async function findAuthSessionUser(tokenHash: string): Promise<AuthUser | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT
       u.id, u.email, u.name, u.first_name, u.last_name,
       u.is_active, u.is_suspended, u.is_locked, u.is_deactivated,
       u.email_verified, u.phone_verified, u.mfa_enabled,
       u.mfa_enrolled_at, u.last_mfa_verified_at, u.mfa_enrollment_required,
       u.account_status, u.deleted_at,
       u.created_at, u.updated_at
     FROM auth_sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token_hash = $1
       AND s.expires_at > NOW()
       AND u.account_status = 'active'
       AND u.deleted_at IS NULL
       AND u.is_active = TRUE
       AND u.is_suspended = FALSE
       AND u.is_locked = FALSE
       AND u.is_deactivated = FALSE
       AND u.mfa_enabled = TRUE
       AND u.mfa_enrollment_required = FALSE
       AND u.mfa_enrolled_at IS NOT NULL
       AND u.last_mfa_verified_at IS NOT NULL
       AND s.created_at >= u.last_mfa_verified_at`,
    [tokenHash],
  );
  return result.rows[0] ? mapUserRow(result.rows[0]) : undefined;
}

export async function deleteAuthSession(tokenHash: string): Promise<void> {
  await pool.query('DELETE FROM auth_sessions WHERE token_hash = $1', [tokenHash]);
}

export async function deleteAllUserSessions(userId: string): Promise<void> {
  await pool.query('DELETE FROM auth_sessions WHERE user_id = $1', [userId]);
}

export async function deleteExpiredAuthSessions(): Promise<void> {
  await pool.query('DELETE FROM auth_sessions WHERE expires_at <= NOW()');
}

export async function createPasswordResetToken(
  email: string,
  tokenHash: string,
  expiresAt: Date,
): Promise<boolean> {
  const result = await pool.query(
    `INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at)
     SELECT $1, id, $2, $3
     FROM users
     WHERE lower(email) = lower($4)
       AND account_status = 'active'
       AND is_active = TRUE
       AND is_deactivated = FALSE
       AND deleted_at IS NULL`,
    [randomUUID(), tokenHash, expiresAt, email],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function consumePasswordResetToken(
  tokenHash: string,
  passwordHash: string,
): Promise<string | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const tokenResult = await client.query<{ user_id: string }>(
      `SELECT reset_token.user_id
       FROM password_reset_tokens AS reset_token
       JOIN users AS account ON account.id = reset_token.user_id
       WHERE reset_token.token_hash = $1
         AND reset_token.used_at IS NULL
         AND reset_token.expires_at > NOW()
         AND account.account_status = 'active'
         AND account.is_active = TRUE
         AND account.is_deactivated = FALSE
         AND account.deleted_at IS NULL
       FOR UPDATE OF reset_token, account`,
      [tokenHash],
    );
    if (!tokenResult.rows[0]) {
      await client.query('ROLLBACK');
      return null;
    }

    await client.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [passwordHash, tokenResult.rows[0].user_id],
    );
    await client.query(
      `UPDATE user_login_identities
       SET password_hash = $1, updated_at = NOW()
       WHERE user_id = $2 AND provider IN ('email', 'phone')`,
      [passwordHash, tokenResult.rows[0].user_id],
    );
    await client.query(
      'UPDATE password_reset_tokens SET used_at = NOW() WHERE token_hash = $1',
      [tokenHash],
    );
    await client.query(
      'DELETE FROM auth_sessions WHERE user_id = $1',
      [tokenResult.rows[0].user_id],
    );
    await client.query(
      `UPDATE sessions SET revoked_at = NOW(), revoked_reason = 'password_changed',
         is_current = FALSE, updated_at = NOW()
       WHERE user_id = $1 AND revoked_at IS NULL`,
      [tokenResult.rows[0].user_id],
    );
    await client.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_reason = 'password_changed'
       WHERE user_id = $1 AND is_revoked = FALSE`,
      [tokenResult.rows[0].user_id],
    );
    await client.query('COMMIT');
    return tokenResult.rows[0].user_id;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findPasswordResetToken(
  tokenHash: string,
): Promise<{ userId: string; email: string } | null> {
  const result = await pool.query<{ user_id: string; email: string }>(
    `SELECT prt.user_id, u.email
     FROM password_reset_tokens prt
     JOIN users u ON prt.user_id = u.id
     WHERE prt.token_hash = $1
       AND prt.used_at IS NULL
       AND prt.expires_at > NOW()
       AND u.account_status = 'active'
       AND u.is_active = TRUE
       AND u.is_deactivated = FALSE
       AND u.deleted_at IS NULL`,
    [tokenHash],
  );
  if (!result.rows[0]) return null;
  return { userId: result.rows[0].user_id, email: result.rows[0].email };
}

export async function markPasswordResetTokenUsed(tokenHash: string): Promise<void> {
  await pool.query(
    'UPDATE password_reset_tokens SET used_at = NOW() WHERE token_hash = $1',
    [tokenHash],
  );
}

export async function updateUserPasswordHash(userId: string, passwordHash: string): Promise<void> {
  await pool.query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [passwordHash, userId]);
}

export async function updateAllPasswordHashes(userId: string, passwordHash: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [passwordHash, userId],
    );
    await client.query(
      `UPDATE user_login_identities
       SET password_hash = $1, updated_at = NOW()
       WHERE user_id = $2 AND provider IN ('email', 'phone')`,
      [passwordHash, userId],
    );
    await client.query('DELETE FROM auth_sessions WHERE user_id = $1', [userId]);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function setPasswordAndRevokeOtherSessions(
  userId: string,
  passwordHash: string,
  currentSessionId: string,
  reason: string,
): Promise<number> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existingPassword = await client.query<{ password_hash: string | null }>(
      'SELECT password_hash FROM users WHERE id = $1 FOR UPDATE',
      [userId],
    );
    const existingIdentityPassword = await client.query<{ has_password: boolean }>(
      `SELECT EXISTS (
         SELECT 1 FROM user_login_identities
         WHERE user_id = $1 AND provider IN ('email', 'phone') AND password_hash IS NOT NULL
       ) AS has_password`,
      [userId],
    );
    if (existingPassword.rows[0]?.password_hash || existingIdentityPassword.rows[0]?.has_password) {
      throw new ConflictError('A password is already set. Use the change password flow instead.');
    }
    await client.query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [passwordHash, userId]);
    await client.query(
      `UPDATE user_login_identities SET password_hash = $1, updated_at = NOW()
       WHERE user_id = $2 AND provider IN ('email', 'phone')`,
      [passwordHash, userId],
    );
    const revoked = await client.query(
      `UPDATE sessions SET revoked_at = NOW(), revoked_reason = $3, is_current = FALSE, updated_at = NOW()
       WHERE user_id = $1 AND id <> $2 AND revoked_at IS NULL`,
      [userId, currentSessionId, reason],
    );
    await client.query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_reason = $2
       WHERE user_id = $1 AND session_id <> $3 AND is_revoked = FALSE`,
      [userId, reason, currentSessionId],
    );
    await client.query('DELETE FROM auth_sessions WHERE user_id = $1', [userId]);
    await client.query('COMMIT');
    return revoked.rowCount ?? 0;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function updateUserEmailVerified(userId: string, verified: boolean): Promise<void> {
  await pool.query(
    `UPDATE users
     SET email_verified = $1,
         account_status = CASE
           WHEN $1 AND account_status = 'pending_verification' THEN 'active'
           WHEN NOT $1 AND account_status = 'active' AND NOT phone_verified THEN 'pending_verification'
           ELSE account_status
         END,
         updated_at = NOW()
     WHERE id = $2`,
    [verified, userId],
  );
}

export async function activateVerifiedGoogleUser(
  userId: string,
  googleSubject: string,
): Promise<void> {
  await pool.query(
    `UPDATE users u
     SET email_verified = TRUE,
         account_status = 'active',
         updated_at = NOW()
     WHERE u.id = $1
       AND u.account_status = 'pending_verification'
       AND u.is_active = TRUE
       AND u.is_suspended = FALSE
       AND u.is_locked = FALSE
       AND u.is_deactivated = FALSE
       AND u.deleted_at IS NULL
       AND EXISTS (
         SELECT 1
         FROM google_identities g
         WHERE g.user_id = u.id
           AND g.google_subject = $2
           AND g.email_verified = TRUE
       )`,
    [userId, googleSubject],
  );
}

export async function updateUserPhoneVerified(userId: string, verified: boolean): Promise<void> {
  await pool.query(
    `UPDATE users
     SET phone_verified = $1,
         account_status = CASE
           WHEN $1 AND account_status = 'pending_verification' THEN 'active'
           WHEN NOT $1 AND account_status = 'active' AND NOT email_verified THEN 'pending_verification'
           ELSE account_status
         END,
         updated_at = NOW()
     WHERE id = $2`,
    [verified, userId],
  );
}

export async function createOrganisation(data: {
  name: string;
  slug: string;
  type: string;
  description?: string | null;
  contactEmail?: string | null;
  contactPhone?: string | null;
  address?: string | null;
  city?: string | null;
  county?: string | null;
  country?: string;
  registrationNumber?: string | null;
  taxId?: string | null;
  logoUrl?: string | null;
  websiteUrl?: string | null;
}): Promise<Organisation> {
  const id = randomUUID();
  const result = await pool.query<Organisation>(
    `INSERT INTO organisations (id, name, slug, type, description, contact_email, contact_phone, address, city, county, country, registration_number, tax_id, logo_url, website_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
     RETURNING id, name, slug, type, description, contact_email as "contactEmail", contact_phone as "contactPhone",
       address, city, county, country, registration_number as "registrationNumber", tax_id as "taxId",
       logo_url as "logoUrl", website_url as "websiteUrl", is_verified as "isVerified",
       verification_status as "verificationStatus", verification_notes as "verificationNotes",
       verified_at as "verifiedAt", verified_by as "verifiedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.name, data.slug, data.type, data.description ?? null, data.contactEmail ?? null, data.contactPhone ?? null,
     data.address ?? null, data.city ?? null, data.county ?? null, data.country ?? 'KE', data.registrationNumber ?? null,
     data.taxId ?? null, data.logoUrl ?? null, data.websiteUrl ?? null],
  );
  return result.rows[0]!;
}

export async function findOrganisationBySlug(slug: string): Promise<Organisation | undefined> {
  const result = await pool.query<Organisation>(
    `SELECT id, name, slug, type, description, contact_email as "contactEmail", contact_phone as "contactPhone",
       address, city, county, country, registration_number as "registrationNumber", tax_id as "taxId",
       logo_url as "logoUrl", website_url as "websiteUrl", is_verified as "isVerified",
       verification_status as "verificationStatus", verification_notes as "verificationNotes",
       verified_at as "verifiedAt", verified_by as "verifiedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM organisations WHERE slug = $1`,
    [slug],
  );
  return result.rows[0];
}

export async function addOrganisationMember(
  organisationId: string,
  userId: string,
  role: string,
  invitedBy: string | null = null,
): Promise<OrganisationMember> {
  const id = randomUUID();
  const result = await pool.query<OrganisationMember>(
    `INSERT INTO organisation_members (id, organisation_id, user_id, role, status, invited_by, invited_at)
     VALUES ($1, $2, $3, $4, 'invited', $5, NOW())
     RETURNING id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, organisationId, userId, role, invitedBy],
  );
  return result.rows[0]!;
}

export async function findOrganisationMembers(organisationId: string): Promise<OrganisationMember[]> {
  const result = await pool.query<OrganisationMember>(
    `SELECT id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"
FROM organisation_members WHERE organisation_id = $1 AND status = 'active'`,
     [organisationId],
   );
   return result.rows;
 }

export async function findOrganisationById(id: string): Promise<Organisation | undefined> {
  const result = await pool.query<Organisation>(
    `SELECT id, name, slug, type, description, contact_email as "contactEmail", contact_phone as "contactPhone",
       address, city, county, country, registration_number as "registrationNumber", tax_id as "taxId",
       logo_url as "logoUrl", website_url as "websiteUrl", is_verified as "isVerified",
       verification_status as "verificationStatus", verification_notes as "verificationNotes",
       verified_at as "verifiedAt", verified_by as "verifiedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM organisations WHERE id = $1`,
    [id],
  );
  return result.rows[0];
}

export async function updateOrganisation(
  id: string,
  updates: Partial<Pick<Organisation, 'name' | 'description' | 'contactEmail' | 'contactPhone' | 'address' | 'city' | 'county' | 'country' | 'registrationNumber' | 'taxId' | 'logoUrl' | 'websiteUrl'>>
): Promise<Organisation | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    name: 'name',
    description: 'description',
    contactEmail: 'contact_email',
    contactPhone: 'contact_phone',
    address: 'address',
    city: 'city',
    county: 'county',
    country: 'country',
    registrationNumber: 'registration_number',
    taxId: 'tax_id',
    logoUrl: 'logo_url',
    websiteUrl: 'website_url',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findOrganisationById(id);

  fields.push(`updated_at = NOW()`);
  values.push(id);

  const result = await pool.query<Organisation>(
    `UPDATE organisations SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, name, slug, type, description, contact_email as "contactEmail", contact_phone as "contactPhone",
       address, city, county, country, registration_number as "registrationNumber", tax_id as "taxId",
       logo_url as "logoUrl", website_url as "websiteUrl", is_verified as "isVerified",
       verification_status as "verificationStatus", verification_notes as "verificationNotes",
       verified_at as "verifiedAt", verified_by as "verifiedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function findPendingOrganisationInvitation(
  organisationId: string,
  email: string
): Promise<OrganisationInvitation | undefined> {
  const result = await pool.query<OrganisationInvitation>(
    `SELECT id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"
     FROM organisation_invitations
     WHERE organisation_id = $1 AND email = $2 AND status = 'pending'`,
    [organisationId, email],
  );
  return result.rows[0];
}

export async function getOrganisationMembers(organisationId: string): Promise<OrganisationMember[]> {
  const result = await pool.query<OrganisationMember>(
    `SELECT id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM organisation_members WHERE organisation_id = $1`,
    [organisationId],
  );
  return result.rows;
}

export async function createOrganisationInvitation(data: {
  organisationId: string;
  email: string;
  role: string;
  invitedBy: string;
  tokenHash: string;
  expiresAt: Date;
}): Promise<OrganisationInvitation> {
  const id = randomUUID();
  const result = await pool.query<OrganisationInvitation>(
    `INSERT INTO organisation_invitations (id, organisation_id, email, role, invited_by, token_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"`,
    [id, data.organisationId, data.email, data.role, data.invitedBy, data.tokenHash, data.expiresAt],
  );
  return result.rows[0]!;
}

export async function findOrganisationInvitationByTokenHash(tokenHash: string): Promise<OrganisationInvitation | undefined> {
  const result = await pool.query<OrganisationInvitation>(
    `SELECT id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"
     FROM organisation_invitations WHERE token_hash = $1`,
    [tokenHash],
  );
  return result.rows[0];
}

export async function acceptOrganisationInvitation(
  invitationId: string,
  userId: string
): Promise<OrganisationInvitation | undefined> {
  const result = await pool.query<OrganisationInvitation>(
    `UPDATE organisation_invitations
     SET status = 'accepted', accepted_at = NOW(), accepted_by = $2, updated_at = NOW()
     WHERE id = $1 AND status = 'pending'
     RETURNING id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"`,
    [invitationId, userId],
  );
  return result.rows[0];
}

export async function getOrganisationInvitations(
  organisationId: string,
  status?: OrganisationInvitation['status'],
  limit = 50,
  offset = 0
): Promise<OrganisationInvitation[]> {
  let query = `SELECT id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"
     FROM organisation_invitations WHERE organisation_id = $1`;
  const params: unknown[] = [organisationId];
  let paramIndex = 2;

  if (status) {
    query += ` AND status = $${paramIndex++}`;
    params.push(status);
  }

  query += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
  params.push(limit, offset);

  const result = await pool.query<OrganisationInvitation>(query, params);
  return result.rows;
}

export async function revokeOrganisationInvitation(
  invitationId: string,
  revokedBy: string,
  reason: string | null = null
): Promise<OrganisationInvitation | undefined> {
  const result = await pool.query<OrganisationInvitation>(
    `UPDATE organisation_invitations
     SET status = 'revoked', revoked_at = NOW(), revoked_by = $2, revoked_reason = $3, updated_at = NOW()
     WHERE id = $1
     RETURNING id, organisation_id as "organisationId", email, role, invited_by as "invitedBy",
       token_hash as "tokenHash", status, expires_at as "expiresAt", accepted_at as "acceptedAt",
       accepted_by as "acceptedBy", revoked_at as "revokedAt", revoked_by as "revokedBy",
       revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt",
       invited_at as "invitedAt"`,
    [invitationId, revokedBy, reason],
  );
  return result.rows[0];
}

export async function findOrganisationMemberById(memberId: string): Promise<OrganisationMember | undefined> {
  const result = await pool.query<OrganisationMember>(
    `SELECT id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM organisation_members WHERE id = $1`,
    [memberId],
  );
  return result.rows[0];
}

export async function updateOrganisationMember(
  memberId: string,
  updates: { role?: string; status?: OrganisationMember['status']; removedBy?: string }
): Promise<OrganisationMember | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (updates.role !== undefined) {
    fields.push(`role = $${paramIndex++}`);
    values.push(updates.role);
  }
  if (updates.status !== undefined) {
    fields.push(`status = $${paramIndex++}`);
    values.push(updates.status);
    if (updates.status === 'active') {
      fields.push(`joined_at = COALESCE(joined_at, NOW())`);
    }
    if (updates.status === 'removed') {
      fields.push(`removed_at = NOW()`);
    }
  }

  if (fields.length === 0) return findOrganisationMemberById(memberId);

  fields.push(`updated_at = NOW()`);
  values.push(memberId);

  const result = await pool.query<OrganisationMember>(
    `UPDATE organisation_members SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function isLastOwner(organisationId: string, userId: string): Promise<boolean> {
  const result = await pool.query<{ count: number }>(
    `SELECT COUNT(*)::int as count FROM organisation_members
     WHERE organisation_id = $1 AND role = 'owner' AND status = 'active' AND user_id != $2`,
    [organisationId, userId],
  );
  return (result.rows[0]?.count ?? 0) === 0;
}

export async function findUnitById(unitId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_number as "unitNumber", unit_type as "unitType",
       floor_number as "floorNumber", bedrooms, bathrooms, area_sqm as "areaSqm",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", status,
       description, amenities, features, images, has_separate_meter as "hasSeparateMeter",
       meter_number as "meterNumber", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM units WHERE id = $1`,
    [unitId],
  );
  return result.rows[0];
}

// Email Login OTP functions
export async function createEmailLoginOtp(
  userId: string,
  loginIdentityId: string,
  otpHash: string,
  expiresAt: Date,
  maxAttempts = 3,
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM user_login_identities WHERE id = $1 FOR UPDATE', [loginIdentityId]);
    await client.query(
      'UPDATE email_login_otp SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
      [loginIdentityId],
    );
    await client.query(
      `INSERT INTO email_login_otp (id, user_id, login_identity_id, otp_hash, expires_at, max_attempts)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomUUID(), userId, loginIdentityId, otpHash, expiresAt, maxAttempts],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findEmailLoginOtp(
  loginIdentityId: string,
  otpHash: string,
): Promise<EmailLoginOtp | undefined> {
  const result = await pool.query<EmailLoginOtp>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM email_login_otp
     WHERE login_identity_id = $1 AND otp_hash = $2 AND consumed_at IS NULL AND expires_at > NOW()`,
    [loginIdentityId, otpHash],
  );
  return result.rows[0];
}

export async function findPendingEmailLoginOtp(loginIdentityId: string): Promise<EmailLoginOtp | undefined> {
  const result = await pool.query<EmailLoginOtp>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM email_login_otp
     WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [loginIdentityId],
  );
  return result.rows[0];
}

export async function consumeEmailLoginOtp(
  loginIdentityId: string,
  otpHash: string,
): Promise<{ userId: string; loginIdentityId: string } | null> {
  return verifyAndConsumeLoginOtp('email_login_otp', loginIdentityId, otpHash);
}

export async function incrementEmailLoginOtpAttempt(loginIdentityId: string, otpHash: string): Promise<void> {
  await pool.query(
    'UPDATE email_login_otp SET attempt_count = attempt_count + 1 WHERE login_identity_id = $1 AND otp_hash = $2',
    [loginIdentityId, otpHash],
  );
}

export async function invalidateEmailLoginOtpTokens(loginIdentityId: string): Promise<void> {
  await pool.query(
    'UPDATE email_login_otp SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
    [loginIdentityId],
  );
}

// Phone Login OTP functions
export async function createPhoneLoginOtp(
  userId: string,
  loginIdentityId: string,
  otpHash: string,
  expiresAt: Date,
  maxAttempts = 3,
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM user_login_identities WHERE id = $1 FOR UPDATE', [loginIdentityId]);
    await client.query(
      'UPDATE phone_login_otp SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
      [loginIdentityId],
    );
    await client.query(
      `INSERT INTO phone_login_otp (id, user_id, login_identity_id, otp_hash, expires_at, max_attempts)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomUUID(), userId, loginIdentityId, otpHash, expiresAt, maxAttempts],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findPhoneLoginOtp(
  loginIdentityId: string,
  otpHash: string,
): Promise<PhoneLoginOtp | undefined> {
  const result = await pool.query<PhoneLoginOtp>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM phone_login_otp
     WHERE login_identity_id = $1 AND otp_hash = $2 AND consumed_at IS NULL AND expires_at > NOW()`,
    [loginIdentityId, otpHash],
  );
  return result.rows[0];
}

export async function findPendingPhoneLoginOtp(loginIdentityId: string): Promise<PhoneLoginOtp | undefined> {
  const result = await pool.query<PhoneLoginOtp>(
    `SELECT id, user_id as "userId", login_identity_id as "loginIdentityId", otp_hash as "otpHash",
       expires_at as "expiresAt", consumed_at as "consumedAt", attempt_count as "attemptCount",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM phone_login_otp
     WHERE login_identity_id = $1 AND consumed_at IS NULL AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [loginIdentityId],
  );
  return result.rows[0];
}

export async function consumePhoneLoginOtp(
  loginIdentityId: string,
  otpHash: string,
): Promise<{ userId: string; loginIdentityId: string } | null> {
  return verifyAndConsumeLoginOtp('phone_login_otp', loginIdentityId, otpHash);
}

async function verifyAndConsumeLoginOtp(
  table: 'email_login_otp' | 'phone_login_otp',
  loginIdentityId: string,
  otpHash: string,
): Promise<{ userId: string; loginIdentityId: string } | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query<{
      id: string;
      user_id: string;
      login_identity_id: string;
      otp_hash: string;
      expires_at: Date;
      attempt_count: number;
      max_attempts: number;
    }>(
      `SELECT id, user_id, login_identity_id, otp_hash, expires_at, attempt_count, max_attempts
       FROM ${table}
       WHERE login_identity_id = $1 AND consumed_at IS NULL
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [loginIdentityId],
    );
    const challenge = result.rows[0];
    if (!challenge || challenge.expires_at <= new Date() || challenge.attempt_count >= challenge.max_attempts) {
      if (challenge) {
        await client.query(`UPDATE ${table} SET consumed_at = NOW() WHERE id = $1`, [challenge.id]);
      }
      await client.query('COMMIT');
      return null;
    }

    const expected = Buffer.from(challenge.otp_hash, 'hex');
    const received = Buffer.from(otpHash, 'hex');
    const matches =
      expected.length === received.length && timingSafeEqual(expected, received);

    if (matches) {
      await client.query(`UPDATE ${table} SET consumed_at = NOW() WHERE id = $1`, [challenge.id]);
      await client.query('COMMIT');
      return {
        userId: challenge.user_id,
        loginIdentityId: challenge.login_identity_id,
      };
    }

    await client.query(
      `UPDATE ${table}
       SET attempt_count = attempt_count + 1,
           consumed_at = CASE WHEN attempt_count + 1 >= max_attempts THEN NOW() ELSE consumed_at END
       WHERE id = $1`,
      [challenge.id],
    );
    await client.query('COMMIT');
    return null;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function incrementPhoneLoginOtpAttempt(loginIdentityId: string, otpHash: string): Promise<void> {
  await pool.query(
    'UPDATE phone_login_otp SET attempt_count = attempt_count + 1 WHERE login_identity_id = $1 AND otp_hash = $2',
    [loginIdentityId, otpHash],
  );
}

export async function invalidatePhoneLoginOtpTokens(loginIdentityId: string): Promise<void> {
  await pool.query(
    'UPDATE phone_login_otp SET consumed_at = NOW() WHERE login_identity_id = $1 AND consumed_at IS NULL',
    [loginIdentityId],
  );
}

// MFA Challenge functions
export async function createMfaChallenge(
  userId: string,
  challengeType: string,
  challengeData: Record<string, unknown>,
  expiresAt: Date,
  maxAttempts = 3,
): Promise<MfaChallenge> {
  const id = randomUUID();
  const result = await pool.query<MfaChallenge>(
    `INSERT INTO mfa_challenges (id, user_id, challenge_type, challenge_data, expires_at, max_attempts)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, user_id as "userId", challenge_type as "challengeType", challenge_data as "challengeData",
       status, expires_at as "expiresAt", completed_at as "completedAt", failed_attempts as "failedAttempts",
       max_attempts as "maxAttempts", created_at as "createdAt"`,
    [id, userId, challengeType, JSON.stringify(challengeData), expiresAt, maxAttempts],
  );
  return result.rows[0]!;
}

export async function createMfaHandoffChallenge(
  userId: string,
  expiresAt: Date,
  availableMethods: string[],
  maxAttempts = 3,
): Promise<MfaChallenge> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
    await client.query(
      `UPDATE mfa_challenges
       SET status = 'expired'
       WHERE user_id = $1 AND status = 'pending'`,
      [userId],
    );
    const id = randomUUID();
    const result = await client.query<MfaChallenge>(
      `INSERT INTO mfa_challenges (id, user_id, challenge_type, challenge_data, expires_at, max_attempts)
       VALUES ($1, $2, 'totp', $3, $4, $5)
       RETURNING id, user_id as "userId", challenge_type as "challengeType", challenge_data as "challengeData",
         status, expires_at as "expiresAt", completed_at as "completedAt", failed_attempts as "failedAttempts",
         max_attempts as "maxAttempts", created_at as "createdAt"`,
      [id, userId, JSON.stringify({ methods: availableMethods }), expiresAt, maxAttempts],
    );
    await client.query('COMMIT');
    return result.rows[0]!;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findMfaChallenge(challengeId: string): Promise<MfaChallenge | undefined> {
  const result = await pool.query<MfaChallenge>(
    `SELECT id, user_id as "userId", challenge_type as "challengeType", challenge_data as "challengeData",
       status, expires_at as "expiresAt", completed_at as "completedAt", failed_attempts as "failedAttempts",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM mfa_challenges WHERE id = $1`,
    [challengeId],
  );
  return result.rows[0];
}

export async function findPendingMfaChallenge(userId: string): Promise<MfaChallenge | undefined> {
  const result = await pool.query<MfaChallenge>(
    `SELECT id, user_id as "userId", challenge_type as "challengeType", challenge_data as "challengeData",
       status, expires_at as "expiresAt", completed_at as "completedAt", failed_attempts as "failedAttempts",
       max_attempts as "maxAttempts", created_at as "createdAt"
     FROM mfa_challenges
     WHERE user_id = $1 AND status = 'pending' AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [userId],
  );
  return result.rows[0];
}

export async function completeMfaChallenge(challengeId: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE mfa_challenges SET status = 'completed', completed_at = NOW()
     WHERE id = $1 AND status = 'pending' AND expires_at > NOW()
     RETURNING id`,
    [challengeId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function failMfaChallenge(challengeId: string): Promise<void> {
  await pool.query(
    `UPDATE mfa_challenges
     SET failed_attempts = failed_attempts + 1,
         status = CASE WHEN failed_attempts + 1 >= max_attempts THEN 'failed' ELSE status END
     WHERE id = $1 AND status = 'pending'`,
    [challengeId],
  );
}

export async function expireMfaChallenge(challengeId: string): Promise<void> {
  await pool.query(
    `UPDATE mfa_challenges SET status = 'expired' WHERE id = $1`,
    [challengeId],
  );
}

export async function invalidatePendingMfaChallenges(userId: string): Promise<void> {
  await pool.query(
    `UPDATE mfa_challenges SET status = 'expired' WHERE user_id = $1 AND status = 'pending'`,
    [userId],
  );
}

// MFA Methods
export async function createMfaMethod(
  userId: string,
  methodType: 'totp' | 'sms' | 'email' | 'recovery_codes',
  methodName: string | null,
  isPrimary: boolean,
  metadata: Record<string, unknown>,
): Promise<MfaMethod> {
  const id = randomUUID();
  const result = await pool.query<MfaMethod>(
    `INSERT INTO mfa_methods (id, user_id, method_type, method_name, is_primary, is_verified, is_active, metadata)
     VALUES ($1, $2, $3, $4, $5, FALSE, TRUE, $6)
     RETURNING id, user_id as "userId", method_type as "methodType", method_name as "methodName",
       is_primary as "isPrimary", is_verified as "isVerified", is_active as "isActive",
       metadata, verified_at as "verifiedAt", created_at as "createdAt", updated_at as "updatedAt", deleted_at as "deletedAt"`,
    [id, userId, methodType, methodName, isPrimary, JSON.stringify(metadata)],
  );
  return result.rows[0]!;
}

export async function findMfaMethodsByUserId(userId: string): Promise<MfaMethod[]> {
  const result = await pool.query<MfaMethod>(
    `SELECT id, user_id as "userId", method_type as "methodType", method_name as "methodName",
       is_primary as "isPrimary", is_verified as "isVerified", is_active as "isActive",
       metadata, verified_at as "verifiedAt", created_at as "createdAt", updated_at as "updatedAt", deleted_at as "deletedAt"
     FROM mfa_methods
     WHERE user_id = $1 AND deleted_at IS NULL
     ORDER BY is_primary DESC, created_at ASC`,
    [userId],
  );
  return result.rows;
}

export async function findMfaMethodById(methodId: string): Promise<MfaMethod | undefined> {
  const result = await pool.query<MfaMethod>(
    `SELECT id, user_id as "userId", method_type as "methodType", method_name as "methodName",
       is_primary as "isPrimary", is_verified as "isVerified", is_active as "isActive",
       metadata, verified_at as "verifiedAt", created_at as "createdAt", updated_at as "updatedAt", deleted_at as "deletedAt"
     FROM mfa_methods
     WHERE id = $1 AND deleted_at IS NULL`,
    [methodId],
  );
  return result.rows[0];
}

export async function findPrimaryMfaMethod(userId: string): Promise<MfaMethod | undefined> {
  const result = await pool.query<MfaMethod>(
    `SELECT id, user_id as "userId", method_type as "methodType", method_name as "methodName",
       is_primary as "isPrimary", is_verified as "isVerified", is_active as "isActive",
       metadata, verified_at as "verifiedAt", created_at as "createdAt", updated_at as "updatedAt", deleted_at as "deletedAt"
     FROM mfa_methods
     WHERE user_id = $1 AND is_primary = TRUE AND deleted_at IS NULL
     LIMIT 1`,
    [userId],
  );
  return result.rows[0];
}

export async function updateMfaMethod(
  methodId: string,
  updates: Partial<Pick<MfaMethod, 'methodName' | 'isPrimary' | 'isVerified' | 'isActive' | 'metadata'>>,
): Promise<MfaMethod | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (updates.methodName !== undefined) {
    fields.push(`method_name = $${paramIndex++}`);
    values.push(updates.methodName);
  }
  if (updates.isPrimary !== undefined) {
    fields.push(`is_primary = $${paramIndex++}`);
    values.push(updates.isPrimary);
  }
  if (updates.isVerified !== undefined) {
    fields.push(`is_verified = $${paramIndex++}`);
    values.push(updates.isVerified);
    if (updates.isVerified) {
      fields.push(`verified_at = NOW()`);
    }
  }
  if (updates.isActive !== undefined) {
    fields.push(`is_active = $${paramIndex++}`);
    values.push(updates.isActive);
  }
  if (updates.metadata !== undefined) {
    fields.push(`metadata = $${paramIndex++}`);
    values.push(JSON.stringify(updates.metadata));
  }

  if (fields.length === 0) {
    return findMfaMethodById(methodId);
  }

  fields.push(`updated_at = NOW()`);
  values.push(methodId);

  const result = await pool.query<MfaMethod>(
    `UPDATE mfa_methods SET ${fields.join(', ')} WHERE id = $${paramIndex} AND deleted_at IS NULL
     RETURNING id, user_id as "userId", method_type as "methodType", method_name as "methodName",
       is_primary as "isPrimary", is_verified as "isVerified", is_active as "isActive",
       metadata, verified_at as "verifiedAt", created_at as "createdAt", updated_at as "updatedAt", deleted_at as "deletedAt"`,
    values,
  );
  return result.rows[0];
}

export async function consumeMfaOneTimeCode(
  methodId: string,
  codeType: 'otp' | 'email',
  expectedHash: string,
): Promise<boolean> {
  const hashKey = codeType === 'otp' ? 'otpHash' : 'codeHash';
  const expiryKey = codeType === 'otp' ? 'otpExpiresAt' : 'codeExpiresAt';
  const attemptsKey = codeType === 'otp' ? 'otpAttempts' : 'codeAttempts';
  const result = await pool.query(
    `UPDATE mfa_methods
     SET metadata = metadata - $3::text - $4::text - $5::text, updated_at = NOW()
     WHERE id = $1 AND deleted_at IS NULL AND is_active = TRUE
       AND metadata->>$2::text = $6
       AND (metadata->>$3::text)::timestamptz > NOW()
     RETURNING id`,
    [methodId, hashKey, expiryKey, attemptsKey, codeType === 'otp' ? 'otpMaxAttempts' : 'codeMaxAttempts', expectedHash],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function incrementMfaCodeAttempt(
  methodId: string,
  codeType: 'otp' | 'email',
  expectedHash: string,
  maxAttempts: number,
): Promise<number | null> {
  const hashKey = codeType === 'otp' ? 'otpHash' : 'codeHash';
  const attemptsKey = codeType === 'otp' ? 'otpAttempts' : 'codeAttempts';
  const result = await pool.query<{ attempts: number }>(
    `UPDATE mfa_methods
     SET metadata = jsonb_set(
       metadata,
       ARRAY[$2::text],
       to_jsonb(COALESCE(NULLIF(metadata->>$2::text, '')::int, 0) + 1),
       TRUE
     ), updated_at = NOW()
     WHERE id = $1 AND deleted_at IS NULL AND is_active = TRUE
       AND metadata->>$3::text = $4
       AND COALESCE(NULLIF(metadata->>$2::text, '')::int, 0) < $5
     RETURNING (metadata->>$2::text)::int AS attempts`,
    [methodId, attemptsKey, hashKey, expectedHash, maxAttempts],
  );
  return result.rows[0]?.attempts ?? null;
}

export async function deleteMfaMethod(methodId: string): Promise<void> {
  await pool.query(
    `UPDATE mfa_methods SET deleted_at = NOW(), is_active = FALSE WHERE id = $1`,
    [methodId],
  );
}

export async function setPrimaryMfaMethod(userId: string, methodId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE mfa_methods SET is_primary = FALSE WHERE user_id = $1 AND deleted_at IS NULL`,
      [userId],
    );
    await client.query(
      `UPDATE mfa_methods SET is_primary = TRUE, updated_at = NOW() WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [methodId, userId],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// MFA TOTP Secrets
export async function createMfaTotpSecret(
  userId: string,
  mfaMethodId: string,
  encryptedSecret: Buffer,
  algorithm = 'SHA1',
  digits = 6,
  period = 30,
): Promise<MfaTotpSecret> {
  const id = randomUUID();
  const result = await pool.query<MfaTotpSecret>(
    `INSERT INTO mfa_totp_secrets (id, user_id, mfa_method_id, encrypted_secret, algorithm, digits, period, last_used_step)
     VALUES ($1, $2, $3, $4, $5, $6, $7, -1)
     RETURNING id, user_id as "userId", mfa_method_id as "mfaMethodId", encrypted_secret as "encryptedSecret",
       algorithm, digits, period, last_used_step as "lastUsedStep", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, userId, mfaMethodId, encryptedSecret, algorithm, digits, period],
  );
  return result.rows[0]!;
}

export async function findMfaTotpSecretByMethodId(mfaMethodId: string): Promise<MfaTotpSecret | undefined> {
  const result = await pool.query<MfaTotpSecret>(
    `SELECT id, user_id as "userId", mfa_method_id as "mfaMethodId", encrypted_secret as "encryptedSecret",
       algorithm, digits, period, last_used_step as "lastUsedStep", created_at as "createdAt", updated_at as "updatedAt"
     FROM mfa_totp_secrets
     WHERE mfa_method_id = $1`,
    [mfaMethodId],
  );
  return result.rows[0];
}

export async function updateMfaTotpSecretLastUsedStep(mfaMethodId: string, step: number): Promise<boolean> {
  const result = await pool.query(
    `UPDATE mfa_totp_secrets SET last_used_step = $1, updated_at = NOW()
     WHERE mfa_method_id = $2 AND last_used_step < $1
     RETURNING mfa_method_id`,
    [step, mfaMethodId],
  );
  return (result.rowCount ?? 0) > 0;
}

// MFA Recovery Codes
export async function createMfaRecoveryCodes(
  userId: string,
  mfaMethodId: string,
  codeHashes: string[],
): Promise<MfaRecoveryCode[]> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const codes: MfaRecoveryCode[] = [];
    for (const codeHash of codeHashes) {
      const id = randomUUID();
      const result = await client.query<MfaRecoveryCode>(
        `INSERT INTO mfa_recovery_codes (id, user_id, mfa_method_id, code_hash)
         VALUES ($1, $2, $3, $4)
         RETURNING id, user_id as "userId", mfa_method_id as "mfaMethodId", code_hash as "codeHash",
           used_at as "usedAt", created_at as "createdAt"`,
        [id, userId, mfaMethodId, codeHash],
      );
      codes.push(result.rows[0]!);
    }
    await client.query('COMMIT');
    return codes;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findUnusedRecoveryCodes(userId: string): Promise<MfaRecoveryCode[]> {
  const result = await pool.query<MfaRecoveryCode>(
    `SELECT id, user_id as "userId", mfa_method_id as "mfaMethodId", code_hash as "codeHash",
       used_at as "usedAt", created_at as "createdAt"
     FROM mfa_recovery_codes
     WHERE user_id = $1 AND used_at IS NULL
     ORDER BY created_at ASC`,
    [userId],
  );
  return result.rows;
}

export async function consumeRecoveryCode(userId: string, codeHash: string): Promise<MfaRecoveryCode | undefined> {
  const result = await pool.query<MfaRecoveryCode>(
    `UPDATE mfa_recovery_codes
     SET used_at = NOW()
     WHERE user_id = $1 AND code_hash = $2 AND used_at IS NULL
     RETURNING id, user_id as "userId", mfa_method_id as "mfaMethodId", code_hash as "codeHash",
       used_at as "usedAt", created_at as "createdAt"`,
    [userId, codeHash],
  );
  return result.rows[0];
}

export async function invalidateAllRecoveryCodes(userId: string): Promise<void> {
  await pool.query(
    `UPDATE mfa_recovery_codes SET used_at = NOW() WHERE user_id = $1 AND used_at IS NULL`,
    [userId],
  );
}

export async function countUnusedRecoveryCodes(userId: string): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM mfa_recovery_codes WHERE user_id = $1 AND used_at IS NULL`,
    [userId],
  );
  return parseInt(result.rows[0]?.count || '0', 10);
}

// Security Events
export async function createSecurityEvent(
  userId: string | null,
  eventType: string,
  eventCategory: string,
  severity: 'info' | 'warning' | 'critical',
  ipAddress: string | null,
  userAgent: string | null,
  metadata: Record<string, unknown>,
): Promise<SecurityEvent> {
  const id = randomUUID();
  const result = await pool.query<SecurityEvent>(
    `INSERT INTO security_events (id, user_id, event_type, event_category, severity, ip_address, user_agent, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, user_id as "userId", event_type as "eventType", event_category as "eventCategory",
       severity, ip_address as "ipAddress", user_agent as "userAgent", metadata, created_at as "createdAt"`,
    [id, userId, eventType, eventCategory, severity, ipAddress, userAgent, JSON.stringify(metadata)],
  );
  return result.rows[0]!;
}

export async function findSecurityEventsByUserId(
  userId: string,
  limit = 50,
  offset = 0,
  categories?: string[],
): Promise<SecurityEvent[]> {
  const result = await pool.query<SecurityEvent>(
    `SELECT id, user_id as "userId", event_type as "eventType", event_category as "eventCategory",
       severity, ip_address as "ipAddress", user_agent as "userAgent", metadata, created_at as "createdAt"
     FROM security_events
     WHERE user_id = $1
       AND ($4::text[] IS NULL OR event_category = ANY($4))
     ORDER BY created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset, categories ?? null],
  );
  return result.rows;
}

// MFA Enrollment status
export async function updateUserMfaEnrolled(userId: string, enrolled: boolean): Promise<void> {
  await pool.query(
    `UPDATE users SET mfa_enabled = $1, mfa_enrolled_at = $2, mfa_enrollment_required = $3, updated_at = NOW() WHERE id = $4`,
    [enrolled, enrolled ? new Date() : null, !enrolled, userId],
  );
}

export async function skipUserMfaEnrollment(userId: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE users
     SET mfa_enrollment_required = FALSE, updated_at = NOW()
     WHERE id = $1 AND mfa_enabled = FALSE AND mfa_enrolled_at IS NULL`,
    [userId],
  );
  return (result.rowCount ?? 0) === 1;
}

export async function updateUserLastMfaVerified(userId: string): Promise<void> {
  await pool.query(
    `UPDATE users SET last_mfa_verified_at = NOW(), updated_at = NOW() WHERE id = $1`,
    [userId],
  );
}

// ============================================================================
// NOTIFICATION REPOSITORY FUNCTIONS
// ============================================================================

// Notification Templates
export async function createNotificationTemplate(data: {
  templateKey: string;
  eventType: string;
  channel: string;
  locale: string;
  subject: string | null;
  body: string;
  isActive: boolean;
  version: number;
  metadata: Record<string, unknown>;
  createdBy: string;
}): Promise<NotificationTemplate> {
  const id = randomUUID();
  const result = await pool.query<NotificationTemplate>(
    `INSERT INTO notification_templates (id, template_key, event_type, channel, locale, subject, body, is_active, version, metadata, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING id, template_key as "templateKey", event_type as "eventType", channel, locale, subject, body, is_active as "isActive", version, metadata, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.templateKey, data.eventType, data.channel, data.locale, data.subject, data.body, data.isActive, data.version, JSON.stringify(data.metadata), data.createdBy],
  );
  return result.rows[0]!;
}

export async function findNotificationTemplateByKey(templateKey: string, channel: string, locale: string = 'en'): Promise<NotificationTemplate | undefined> {
  const result = await pool.query<NotificationTemplate>(
    `SELECT id, template_key as "templateKey", event_type as "eventType", channel, locale, subject, body, is_active as "isActive", version, metadata, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_templates
     WHERE template_key = $1 AND channel = $2 AND locale = $3 AND is_active = TRUE
     ORDER BY version DESC
     LIMIT 1`,
    [templateKey, channel, locale],
  );
  return result.rows[0];
}

export async function findNotificationTemplates(eventType?: string, channel?: string): Promise<NotificationTemplate[]> {
  const conditions: string[] = ['is_active = TRUE'];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (eventType) {
    conditions.push(`event_type = $${paramIndex++}`);
    values.push(eventType);
  }
  if (channel) {
    conditions.push(`channel = $${paramIndex++}`);
    values.push(channel);
  }

  const result = await pool.query<NotificationTemplate>(
    `SELECT id, template_key as "templateKey", event_type as "eventType", channel, locale, subject, body, is_active as "isActive", version, metadata, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_templates
     WHERE ${conditions.join(' AND ')}
     ORDER BY event_type, channel, locale`,
    values,
  );
  return result.rows;
}

// Notifications
export async function createNotification(data: {
  userId: string;
  organisationId: string | null;
  eventType: string;
  category: string;
  title: string;
  body: string;
  metadata: Record<string, unknown>;
  priority: string;
  expiresAt: Date | null;
}): Promise<Notification> {
  const id = randomUUID();
  const result = await pool.query<Notification>(
    `INSERT INTO notifications (id, user_id, organisation_id, event_type, category, title, body, metadata, priority, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id, user_id as "userId", organisation_id as "organisationId", event_type as "eventType", category, title, body, metadata, priority, is_read as "isRead", read_at as "readAt", expires_at as "expiresAt", created_at as "createdAt"`,
    [id, data.userId, data.organisationId, data.eventType, data.category, data.title, data.body, JSON.stringify(data.metadata), data.priority, data.expiresAt],
  );
  return result.rows[0]!;
}

export async function createNotificationWithRecipients(data: {
  notification: {
    userId: string;
    organisationId: string | null;
    eventType: string;
    category: string;
    title: string;
    body: string;
    metadata: Record<string, unknown>;
    priority: string;
    expiresAt: Date | null;
  };
  recipientUserIds: string[];
}): Promise<{ notification: Notification; recipients: NotificationRecipient[] }> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const notification = await createNotification(data.notification);

    const recipients: NotificationRecipient[] = [];
    for (const recipientId of data.recipientUserIds) {
      const recipient = await createNotificationRecipient({
        notificationId: notification.id,
        userId: recipientId,
      });
      recipients.push(recipient);
    }

    await client.query('COMMIT');
    return { notification, recipients };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function createNotificationRecipient(data: {
  notificationId: string;
  userId: string;
}): Promise<NotificationRecipient> {
  const id = randomUUID();
  const result = await pool.query<NotificationRecipient>(
    `INSERT INTO notification_recipients (id, notification_id, user_id)
     VALUES ($1, $2, $3)
     RETURNING id, notification_id as "notificationId", user_id as "userId", is_read as "isRead", read_at as "readAt", delivered_channels as "deliveredChannels", created_at as "createdAt"`,
    [id, data.notificationId, data.userId],
  );
  return result.rows[0]!;
}

export async function findNotificationsByUserId(
  userId: string,
  options: {
    category?: string;
    isRead?: boolean;
    limit?: number;
    offset?: number;
  } = {}
): Promise<Notification[]> {
  const { category, isRead, limit = 50, offset = 0 } = options;
  const conditions: string[] = ['user_id = $1'];
  const values: unknown[] = [userId];
  let paramIndex = 2;

  if (category) {
    conditions.push(`category = $${paramIndex++}`);
    values.push(category);
  }
  if (isRead !== undefined) {
    conditions.push(`is_read = $${paramIndex++}`);
    values.push(isRead);
  }

  values.push(limit, offset);

  const result = await pool.query<Notification>(
    `SELECT id, user_id as "userId", organisation_id as "organisationId", event_type as "eventType", category, title, body, metadata, priority, is_read as "isRead", read_at as "readAt", expires_at as "expiresAt", created_at as "createdAt"
     FROM notifications
     WHERE ${conditions.join(' AND ')}
     ORDER BY created_at DESC
     LIMIT $${paramIndex++} OFFSET $${paramIndex}`,
    values,
  );
  return result.rows;
}

export async function findNotificationById(id: string): Promise<Notification | undefined> {
  const result = await pool.query<Notification>(
    `SELECT id, user_id as "userId", organisation_id as "organisationId", event_type as "eventType", category, title, body, metadata, priority, is_read as "isRead", read_at as "readAt", expires_at as "expiresAt", created_at as "createdAt"
     FROM notifications WHERE id = $1`,
    [id],
  );
  return result.rows[0];
}

export async function markNotificationAsRead(notificationId: string, userId: string): Promise<Notification | undefined> {
  const result = await pool.query<Notification>(
    `UPDATE notifications SET is_read = TRUE, read_at = NOW()
     WHERE id = $1 AND user_id = $2
     RETURNING id, user_id as "userId", organisation_id as "organisationId", event_type as "eventType", category, title, body, metadata, priority, is_read as "isRead", read_at as "readAt", expires_at as "expiresAt", created_at as "createdAt"`,
    [notificationId, userId],
  );
  return result.rows[0];
}

export async function markNotificationsAsRead(notificationIds: string[], userId: string): Promise<number> {
  const result = await pool.query(
    `UPDATE notifications SET is_read = TRUE, read_at = NOW()
     WHERE id = ANY($1) AND user_id = $2`,
    [notificationIds, userId],
  );
  return result.rowCount ?? 0;
}

const SESSION_COLUMNS = `id, user_id AS "userId", device_id AS "deviceId",
  token_hash AS "tokenHash", refresh_token_hash AS "refreshTokenHash",
  user_agent AS "userAgent", ip_address::text AS "ipAddress",
  country_code AS "countryCode", city, is_current AS "isCurrent",
  idle_expires_at AS "idleExpiresAt", absolute_expires_at AS "absoluteExpiresAt",
  revoked_at AS "revokedAt", revoked_reason AS "revokedReason",
  created_at AS "createdAt", updated_at AS "updatedAt"`;
const REFRESH_TOKEN_COLUMNS = `id, user_id AS "userId", session_id AS "sessionId",
  token_hash AS "tokenHash", family_id AS "familyId",
  replaced_by_token_id AS "replacedByTokenId", replaced_at AS "replacedAt",
  consumed_at AS "consumedAt", is_revoked AS "isRevoked",
  revoked_reason AS "revokedReason", expires_at AS "expiresAt", created_at AS "createdAt"`;
const DEVICE_COLUMNS = `id, user_id AS "userId", device_identifier AS "deviceIdentifier",
  platform, device_name AS "deviceName", device_model AS "deviceModel",
  os_version AS "osVersion", app_version AS "appVersion",
  push_provider AS "pushProvider", push_token_encrypted AS "pushTokenEncrypted",
  push_token_iv AS "pushTokenIv", push_token_auth_tag AS "pushTokenAuthTag",
  last_ip::text AS "lastIp", last_country_code AS "lastCountryCode",
  last_city AS "lastCity", status, revoked_at AS "revokedAt",
  revoked_reason AS "revokedReason", last_activity_at AS "lastActivityAt",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

export async function createManagedSession(input: {
  userId: string;
  sessionId: string;
  tokenHash: string;
  refreshTokenHash: string;
  familyId: string;
  deviceId: string | null;
  userAgent: string | null;
  ipAddress: string | null;
  idleTimeoutMinutes: number;
  absoluteTimeoutHours: number;
  refreshExpiresAt: Date;
}): Promise<Session> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE sessions SET is_current = FALSE WHERE user_id = $1 AND revoked_at IS NULL',
      [input.userId],
    );
    const result = await client.query<Session>(
      `INSERT INTO sessions
         (id, user_id, device_id, token_hash, refresh_token_hash, user_agent,
          ip_address, is_current, idle_expires_at, absolute_expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE,
          NOW() + ($8 * INTERVAL '1 minute'), NOW() + ($9 * INTERVAL '1 hour'))
       RETURNING ${SESSION_COLUMNS}`,
      [
        input.sessionId, input.userId, input.deviceId, input.tokenHash,
        input.refreshTokenHash, input.userAgent, input.ipAddress,
        input.idleTimeoutMinutes, input.absoluteTimeoutHours,
      ],
    );
    await client.query(
      `INSERT INTO refresh_tokens (user_id, session_id, token_hash, family_id, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [input.userId, input.sessionId, input.refreshTokenHash, input.familyId, input.refreshExpiresAt],
    );
    await client.query('COMMIT');
    return result.rows[0]!;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function findSessionByTokenHash(tokenHash: string): Promise<Session | undefined> {
  const result = await pool.query<Session>(`SELECT ${SESSION_COLUMNS} FROM sessions WHERE token_hash = $1`, [tokenHash]);
  return result.rows[0];
}

export async function findSessionById(id: string): Promise<Session | undefined> {
  const result = await pool.query<Session>(`SELECT ${SESSION_COLUMNS} FROM sessions WHERE id = $1`, [id]);
  return result.rows[0];
}

export async function findSessionsByUserId(userId: string): Promise<Session[]> {
  const result = await pool.query<Session>(
    `SELECT ${SESSION_COLUMNS} FROM sessions WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows;
}

export async function findCurrentSessionByUserId(userId: string): Promise<Session | undefined> {
  const result = await pool.query<Session>(
    `SELECT ${SESSION_COLUMNS} FROM sessions
     WHERE user_id = $1 AND is_current = TRUE AND revoked_at IS NULL
     ORDER BY created_at DESC LIMIT 1`,
    [userId],
  );
  return result.rows[0];
}

export async function revokeSession(id: string, userId: string, reason: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE sessions SET revoked_at = NOW(), revoked_reason = $3, is_current = FALSE, updated_at = NOW()
     WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL`,
    [id, userId, reason],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function revokeAllUserSessions(userId: string, reason: string): Promise<number> {
  const result = await pool.query(
    `UPDATE sessions SET revoked_at = NOW(), revoked_reason = $2, is_current = FALSE, updated_at = NOW()
     WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId, reason],
  );
  return result.rowCount ?? 0;
}

export async function updateSessionActivity(id: string, idleTimeoutMinutes: number): Promise<void> {
  await pool.query(
    `UPDATE sessions SET idle_expires_at = LEAST(NOW() + ($2 * INTERVAL '1 minute'), absolute_expires_at),
       updated_at = NOW() WHERE id = $1 AND revoked_at IS NULL`,
    [id, idleTimeoutMinutes],
  );
}

export async function findRefreshTokenByHash(tokenHash: string): Promise<RefreshToken | undefined> {
  const result = await pool.query<RefreshToken>(
    `SELECT ${REFRESH_TOKEN_COLUMNS} FROM refresh_tokens WHERE token_hash = $1`,
    [tokenHash],
  );
  return result.rows[0];
}

export async function findRefreshTokenById(id: string): Promise<RefreshToken | undefined> {
  const result = await pool.query<RefreshToken>(
    `SELECT ${REFRESH_TOKEN_COLUMNS} FROM refresh_tokens WHERE id = $1`,
    [id],
  );
  return result.rows[0];
}

export async function consumeRefreshToken(
  oldId: string,
  newAccessTokenHash: string,
  newTokenHash: string,
  familyId: string,
  expiresAt: Date,
): Promise<RefreshToken | undefined> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const old = await client.query<{ user_id: string; session_id: string }>(
      `SELECT user_id, session_id FROM refresh_tokens
       WHERE id = $1 AND consumed_at IS NULL AND is_revoked = FALSE AND expires_at > NOW()
       FOR UPDATE`,
      [oldId],
    );
    if (!old.rows[0]) {
      await client.query('ROLLBACK');
      return undefined;
    }
    const inserted = await client.query<RefreshToken>(
      `INSERT INTO refresh_tokens (user_id, session_id, token_hash, family_id, expires_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING ${REFRESH_TOKEN_COLUMNS}`,
      [old.rows[0].user_id, old.rows[0].session_id, newTokenHash, familyId, expiresAt],
    );
    await client.query(
      `UPDATE refresh_tokens SET consumed_at = NOW(), replaced_at = NOW(), replaced_by_token_id = $2
       WHERE id = $1`,
      [oldId, inserted.rows[0]!.id],
    );
    await client.query(
      'UPDATE sessions SET token_hash = $2, refresh_token_hash = $3, updated_at = NOW() WHERE id = $1',
      [old.rows[0].session_id, newAccessTokenHash, newTokenHash],
    );
    await client.query('COMMIT');
    return inserted.rows[0];
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function revokeRefreshTokenById(id: string, reason: string): Promise<void> {
  await pool.query('UPDATE refresh_tokens SET is_revoked = TRUE, revoked_reason = $2 WHERE id = $1', [id, reason]);
}

export async function revokeRefreshTokenFamily(familyId: string, reason: string): Promise<void> {
  await pool.query('UPDATE refresh_tokens SET is_revoked = TRUE, revoked_reason = $2 WHERE family_id = $1', [familyId, reason]);
}

export async function revokeAllUserRefreshTokens(userId: string, reason: string): Promise<void> {
  await pool.query(
    'UPDATE refresh_tokens SET is_revoked = TRUE, revoked_reason = $2 WHERE user_id = $1 AND is_revoked = FALSE',
    [userId, reason],
  );
}

export async function findRefreshTokensBySessionId(sessionId: string): Promise<RefreshToken[]> {
  const result = await pool.query<RefreshToken>(
    `SELECT ${REFRESH_TOKEN_COLUMNS} FROM refresh_tokens WHERE session_id = $1`,
    [sessionId],
  );
  return result.rows;
}

export async function countActiveDevices(userId: string): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count FROM devices WHERE user_id = $1 AND status = 'active'`,
    [userId],
  );
  return Number(result.rows[0]?.count ?? 0);
}

export async function findDeviceByIdentifier(userId: string, identifier: string): Promise<Device | undefined> {
  const result = await pool.query<Device>(
    `SELECT ${DEVICE_COLUMNS} FROM devices
     WHERE user_id = $1 AND device_identifier = $2 AND status = 'active'`,
    [userId, identifier],
  );
  return result.rows[0];
}

export async function createDevice(
  userId: string,
  identifier: string,
  platform: Device['platform'],
  deviceName: string | null,
  deviceModel: string | null,
  osVersion: string | null,
  appVersion: string | null,
  pushProvider: Device['pushProvider'],
  encrypted: Buffer | null,
  iv: Buffer | null,
  authTag: Buffer | null,
): Promise<Device> {
  const result = await pool.query<Device>(
    `INSERT INTO devices
       (user_id, device_identifier, platform, device_name, device_model, os_version,
        app_version, push_provider, push_token_encrypted, push_token_iv, push_token_auth_tag)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING ${DEVICE_COLUMNS}`,
    [userId, identifier, platform, deviceName, deviceModel, osVersion, appVersion, pushProvider, encrypted, iv, authTag],
  );
  return result.rows[0]!;
}

export async function updateDevice(
  id: string,
  userId: string,
  changes: {
    deviceName?: string; deviceModel?: string; osVersion?: string; appVersion?: string;
    pushProvider?: Device['pushProvider']; pushTokenEncrypted?: Buffer | null;
    pushTokenIv?: Buffer | null; pushTokenAuthTag?: Buffer | null;
  },
): Promise<Device | undefined> {
  const result = await pool.query<Device>(
    `UPDATE devices SET device_name = COALESCE($3, device_name),
       device_model = COALESCE($4, device_model), os_version = COALESCE($5, os_version),
       app_version = COALESCE($6, app_version), push_provider = COALESCE($7, push_provider),
       push_token_encrypted = COALESCE($8, push_token_encrypted),
       push_token_iv = COALESCE($9, push_token_iv),
       push_token_auth_tag = COALESCE($10, push_token_auth_tag), updated_at = NOW()
     WHERE id = $1 AND user_id = $2 AND status = 'active'
     RETURNING ${DEVICE_COLUMNS}`,
    [
      id, userId, changes.deviceName ?? null, changes.deviceModel ?? null,
      changes.osVersion ?? null, changes.appVersion ?? null, changes.pushProvider ?? null,
      changes.pushTokenEncrypted ?? null, changes.pushTokenIv ?? null, changes.pushTokenAuthTag ?? null,
    ],
  );
  return result.rows[0];
}

export async function findDevicesByUserId(userId: string): Promise<Device[]> {
  const result = await pool.query<Device>(
    `SELECT ${DEVICE_COLUMNS} FROM devices WHERE user_id = $1 ORDER BY last_activity_at DESC`,
    [userId],
  );
  return result.rows;
}

export async function findDeviceById(id: string): Promise<Device | undefined> {
  const result = await pool.query<Device>(`SELECT ${DEVICE_COLUMNS} FROM devices WHERE id = $1`, [id]);
  return result.rows[0];
}

export async function updateDeviceActivity(id: string, ipAddress: string | null): Promise<void> {
  await pool.query(
    `UPDATE devices SET last_activity_at = NOW(), last_ip = $2, updated_at = NOW()
     WHERE id = $1 AND status = 'active'`,
    [id, ipAddress],
  );
}

export async function revokeDevice(id: string, userId: string, reason: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE devices SET status = 'revoked', revoked_at = NOW(), revoked_reason = $3, updated_at = NOW()
     WHERE id = $1 AND user_id = $2 AND status = 'active'`,
    [id, userId, reason],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function revokeAllUserDevices(userId: string, reason: string): Promise<number> {
  const result = await pool.query(
    `UPDATE devices SET status = 'revoked', revoked_at = NOW(), revoked_reason = $2, updated_at = NOW()
     WHERE user_id = $1 AND status = 'active'`,
    [userId, reason],
  );
  return result.rowCount ?? 0;
}

export async function deleteExpiredDevices(maxInactiveDays: number): Promise<number> {
  const result = await pool.query(
    `UPDATE devices SET status = 'expired', updated_at = NOW()
     WHERE status = 'active' AND last_activity_at < NOW() - ($1 * INTERVAL '1 day')`,
    [maxInactiveDays],
  );
  return result.rowCount ?? 0;
}

export async function markAllNotificationsAsRead(userId: string): Promise<number> {
  const result = await pool.query(
    `UPDATE notifications SET is_read = TRUE, read_at = NOW()
     WHERE user_id = $1 AND is_read = FALSE`,
    [userId],
  );
  return result.rowCount ?? 0;
}

export async function getUnreadNotificationCount(userId: string): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*) as count FROM notifications WHERE user_id = $1 AND is_read = FALSE`,
    [userId],
  );
  return parseInt(result.rows[0]?.count || '0', 10);
}

export async function deleteNotification(notificationId: string, userId: string): Promise<boolean> {
  const result = await pool.query(
    `DELETE FROM notifications WHERE id = $1 AND user_id = $2`,
    [notificationId, userId],
  );
  return (result.rowCount ?? 0) > 0;
}

// Notification Preferences
export async function createNotificationPreferences(data: {
  userId: string;
  emailEnabled?: boolean;
  smsEnabled?: boolean;
  pushEnabled?: boolean;
  inAppEnabled?: boolean;
  securityEmail?: boolean;
  securitySms?: boolean;
  securityPush?: boolean;
  securityInApp?: boolean;
  accountEmail?: boolean;
  accountSms?: boolean;
  accountPush?: boolean;
  accountInApp?: boolean;
  propertyEmail?: boolean;
  propertySms?: boolean;
  propertyPush?: boolean;
  propertyInApp?: boolean;
  tenancyEmail?: boolean;
  tenancySms?: boolean;
  tenancyPush?: boolean;
  tenancyInApp?: boolean;
  serviceEmail?: boolean;
  serviceSms?: boolean;
  servicePush?: boolean;
  serviceInApp?: boolean;
  financialEmail?: boolean;
  financialSms?: boolean;
  financialPush?: boolean;
  financialInApp?: boolean;
  operationalEmail?: boolean;
  operationalSms?: boolean;
  operationalPush?: boolean;
  operationalInApp?: boolean;
  marketingEmail?: boolean;
  marketingSms?: boolean;
  marketingPush?: boolean;
  marketingInApp?: boolean;
  quietHoursStart?: string | null;
  quietHoursEnd?: string | null;
  timezone?: string;
  metadata?: Record<string, unknown>;
}): Promise<NotificationPreferences> {
  const id = randomUUID();
  const result = await pool.query<NotificationPreferences>(
    `INSERT INTO notification_preferences (
      id, user_id, email_enabled, sms_enabled, push_enabled, in_app_enabled,
      security_email, security_sms, security_push, security_in_app,
      account_email, account_sms, account_push, account_in_app,
      property_email, property_sms, property_push, property_in_app,
      tenancy_email, tenancy_sms, tenancy_push, tenancy_in_app,
      service_email, service_sms, service_push, service_in_app,
      financial_email, financial_sms, financial_push, financial_in_app,
      operational_email, operational_sms, operational_push, operational_in_app,
      marketing_email, marketing_sms, marketing_push, marketing_in_app,
      quiet_hours_start, quiet_hours_end, timezone, metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $40)
    RETURNING
      id, user_id as "userId",
      email_enabled as "emailEnabled", sms_enabled as "smsEnabled", push_enabled as "pushEnabled", in_app_enabled as "inAppEnabled",
      security_email as "securityEmail", security_sms as "securitySms", security_push as "securityPush", security_in_app as "securityInApp",
      account_email as "accountEmail", account_sms as "accountSms", account_push as "accountPush", account_in_app as "accountInApp",
      property_email as "propertyEmail", property_sms as "propertySms", property_push as "propertyPush", property_in_app as "propertyInApp",
      tenancy_email as "tenancyEmail", tenancy_sms as "tenancySms", tenancy_push as "tenancyPush", tenancy_in_app as "tenancyInApp",
      service_email as "serviceEmail", service_sms as "serviceSms", service_push as "servicePush", service_in_app as "serviceInApp",
      financial_email as "financialEmail", financial_sms as "financialSms", financial_push as "financialPush", financial_in_app as "financialInApp",
      operational_email as "operationalEmail", operational_sms as "operationalSms", operational_push as "operationalPush", operational_in_app as "operationalInApp",
      marketing_email as "marketingEmail", marketing_sms as "marketingSms", marketing_push as "marketingPush", marketing_in_app as "marketingInApp",
      quiet_hours_start as "quietHoursStart", quiet_hours_end as "quietHoursEnd", timezone, metadata,
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      id, data.userId,
      data.emailEnabled ?? true, data.smsEnabled ?? true, data.pushEnabled ?? true, data.inAppEnabled ?? true,
      data.securityEmail ?? true, data.securitySms ?? true, data.securityPush ?? true, data.securityInApp ?? true,
      data.accountEmail ?? true, data.accountSms ?? true, data.accountPush ?? true, data.accountInApp ?? true,
      data.propertyEmail ?? true, data.propertySms ?? false, data.propertyPush ?? true, data.propertyInApp ?? true,
      data.tenancyEmail ?? true, data.tenancySms ?? true, data.tenancyPush ?? true, data.tenancyInApp ?? true,
      data.serviceEmail ?? true, data.serviceSms ?? false, data.servicePush ?? true, data.serviceInApp ?? true,
      data.financialEmail ?? true, data.financialSms ?? true, data.financialPush ?? true, data.financialInApp ?? true,
      data.operationalEmail ?? true, data.operationalSms ?? false, data.operationalPush ?? true, data.operationalInApp ?? true,
      data.marketingEmail ?? false, data.marketingSms ?? false, data.marketingPush ?? false, data.marketingInApp ?? false,
      data.quietHoursStart ?? null, data.quietHoursEnd ?? null, data.timezone ?? 'UTC', JSON.stringify(data.metadata ?? {}),
    ],
  );
  return result.rows[0]!;
}

export async function findNotificationPreferencesByUserId(userId: string): Promise<NotificationPreferences | undefined> {
  const result = await pool.query<NotificationPreferences>(
    `SELECT
      id, user_id as "userId",
      email_enabled as "emailEnabled", sms_enabled as "smsEnabled", push_enabled as "pushEnabled", in_app_enabled as "inAppEnabled",
      security_email as "securityEmail", security_sms as "securitySms", security_push as "securityPush", security_in_app as "securityInApp",
      account_email as "accountEmail", account_sms as "accountSms", account_push as "accountPush", account_in_app as "accountInApp",
      property_email as "propertyEmail", property_sms as "propertySms", property_push as "propertyPush", property_in_app as "propertyInApp",
      tenancy_email as "tenancyEmail", tenancy_sms as "tenancySms", tenancy_push as "tenancyPush", tenancy_in_app as "tenancyInApp",
      service_email as "serviceEmail", service_sms as "serviceSms", service_push as "servicePush", service_in_app as "serviceInApp",
      financial_email as "financialEmail", financial_sms as "financialSms", financial_push as "financialPush", financial_in_app as "financialInApp",
      operational_email as "operationalEmail", operational_sms as "operationalSms", operational_push as "operationalPush", operational_in_app as "operationalInApp",
      marketing_email as "marketingEmail", marketing_sms as "marketingSms", marketing_push as "marketingPush", marketing_in_app as "marketingInApp",
      quiet_hours_start as "quietHoursStart", quiet_hours_end as "quietHoursEnd", timezone, metadata,
      created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_preferences WHERE user_id = $1`,
    [userId],
  );
  return result.rows[0];
}

export async function updateNotificationPreferences(
  userId: string,
  updates: Partial<Omit<NotificationPreferences, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>
): Promise<NotificationPreferences | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const fieldMap: Record<string, string> = {
    emailEnabled: 'email_enabled',
    smsEnabled: 'sms_enabled',
    pushEnabled: 'push_enabled',
    inAppEnabled: 'in_app_enabled',
    securityEmail: 'security_email',
    securitySms: 'security_sms',
    securityPush: 'security_push',
    securityInApp: 'security_in_app',
    accountEmail: 'account_email',
    accountSms: 'account_sms',
    accountPush: 'account_push',
    accountInApp: 'account_in_app',
    propertyEmail: 'property_email',
    propertySms: 'property_sms',
    propertyPush: 'property_push',
    propertyInApp: 'property_in_app',
    tenancyEmail: 'tenancy_email',
    tenancySms: 'tenancy_sms',
    tenancyPush: 'tenancy_push',
    tenancyInApp: 'tenancy_in_app',
    serviceEmail: 'service_email',
    serviceSms: 'service_sms',
    servicePush: 'service_push',
    serviceInApp: 'service_in_app',
    financialEmail: 'financial_email',
    financialSms: 'financial_sms',
    financialPush: 'financial_push',
    financialInApp: 'financial_in_app',
    operationalEmail: 'operational_email',
    operationalSms: 'operational_sms',
    operationalPush: 'operational_push',
    operationalInApp: 'operational_in_app',
    marketingEmail: 'marketing_email',
    marketingSms: 'marketing_sms',
    marketingPush: 'marketing_push',
    marketingInApp: 'marketing_in_app',
    quietHoursStart: 'quiet_hours_start',
    quietHoursEnd: 'quiet_hours_end',
    timezone: 'timezone',
    metadata: 'metadata',
  };

  for (const [key, dbField] of Object.entries(fieldMap)) {
    const value = updates[key as keyof typeof updates];
    if (value !== undefined) {
      fields.push(`${dbField} = $${paramIndex++}`);
      values.push(key === 'metadata' ? JSON.stringify(value) : value);
    }
  }

  if (fields.length === 0) return findNotificationPreferencesByUserId(userId);

  fields.push(`updated_at = NOW()`);
  values.push(userId);

  const result = await pool.query<NotificationPreferences>(
    `UPDATE notification_preferences SET ${fields.join(', ')} WHERE user_id = $${paramIndex}
     RETURNING
      id, user_id as "userId",
      email_enabled as "emailEnabled", sms_enabled as "smsEnabled", push_enabled as "pushEnabled", in_app_enabled as "inAppEnabled",
      security_email as "securityEmail", security_sms as "securitySms", security_push as "securityPush", security_in_app as "securityInApp",
      account_email as "accountEmail", account_sms as "accountSms", account_push as "accountPush", account_in_app as "accountInApp",
      property_email as "propertyEmail", property_sms as "propertySms", property_push as "propertyPush", property_in_app as "propertyInApp",
      tenancy_email as "tenancyEmail", tenancy_sms as "tenancySms", tenancy_push as "tenancyPush", tenancy_in_app as "tenancyInApp",
      service_email as "serviceEmail", service_sms as "serviceSms", service_push as "servicePush", service_in_app as "serviceInApp",
      financial_email as "financialEmail", financial_sms as "financialSms", financial_push as "financialPush", financial_in_app as "financialInApp",
      operational_email as "operationalEmail", operational_sms as "operationalSms", operational_push as "operationalPush", operational_in_app as "operationalInApp",
      marketing_email as "marketingEmail", marketing_sms as "marketingSms", marketing_push as "marketingPush", marketing_in_app as "marketingInApp",
      quiet_hours_start as "quietHoursStart", quiet_hours_end as "quietHoursEnd", timezone, metadata,
      created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function ensureNotificationPreferences(userId: string): Promise<NotificationPreferences> {
  let prefs = await findNotificationPreferencesByUserId(userId);
  if (!prefs) {
    prefs = await createNotificationPreferences({ userId });
  }
  return prefs;
}

// Notification Delivery Attempts
export async function createDeliveryAttempt(data: {
  notificationId: string;
  recipientId: string | null;
  channel: string;
  provider: string;
  attemptNumber?: number;
}): Promise<NotificationDeliveryAttempt> {
  const id = randomUUID();
  const result = await pool.query<NotificationDeliveryAttempt>(
    `INSERT INTO notification_delivery_attempts (id, notification_id, recipient_id, channel, provider, attempt_number)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, notification_id as "notificationId", recipient_id as "recipientId", channel, provider, attempt_number as "attemptNumber", status, provider_message_id as "providerMessageId", provider_response as "providerResponse", error_code as "errorCode", error_message as "errorMessage", sent_at as "sentAt", delivered_at as "deliveredAt", failed_at as "failedAt", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.notificationId, data.recipientId, data.channel, data.provider, data.attemptNumber ?? 1],
  );
  return result.rows[0]!;
}

export async function updateDeliveryAttempt(
  attemptId: string,
  updates: Partial<Pick<NotificationDeliveryAttempt, 'status' | 'providerMessageId' | 'providerResponse' | 'errorCode' | 'errorMessage' | 'sentAt' | 'deliveredAt' | 'failedAt' | 'nextRetryAt' | 'attemptNumber'>>
): Promise<NotificationDeliveryAttempt | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const fieldMap: Record<string, string> = {
    status: 'status',
    providerMessageId: 'provider_message_id',
    providerResponse: 'provider_response',
    errorCode: 'error_code',
    errorMessage: 'error_message',
    sentAt: 'sent_at',
    deliveredAt: 'delivered_at',
    failedAt: 'failed_at',
    nextRetryAt: 'next_retry_at',
    attemptNumber: 'attempt_number',
  };

  for (const [key, dbField] of Object.entries(fieldMap)) {
    const value = updates[key as keyof typeof updates];
    if (value !== undefined) {
      fields.push(`${dbField} = $${paramIndex++}`);
      values.push(key === 'providerResponse' ? JSON.stringify(value) : value);
    }
  }

  if (fields.length === 0) return findDeliveryAttemptById(attemptId);

  fields.push(`updated_at = NOW()`);
  values.push(attemptId);

  const result = await pool.query<NotificationDeliveryAttempt>(
    `UPDATE notification_delivery_attempts SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, notification_id as "notificationId", recipient_id as "recipientId", channel, provider, attempt_number as "attemptNumber", status, provider_message_id as "providerMessageId", provider_response as "providerResponse", error_code as "errorCode", error_message as "errorMessage", sent_at as "sentAt", delivered_at as "deliveredAt", failed_at as "failedAt", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function findDeliveryAttemptById(attemptId: string): Promise<NotificationDeliveryAttempt | undefined> {
  const result = await pool.query<NotificationDeliveryAttempt>(
    `SELECT id, notification_id as "notificationId", recipient_id as "recipientId", channel, provider, attempt_number as "attemptNumber", status, provider_message_id as "providerMessageId", provider_response as "providerResponse", error_code as "errorCode", error_message as "errorMessage", sent_at as "sentAt", delivered_at as "deliveredAt", failed_at as "failedAt", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_delivery_attempts WHERE id = $1`,
    [attemptId],
  );
  return result.rows[0];
}

export async function findPendingDeliveryAttempts(limit = 100): Promise<NotificationDeliveryAttempt[]> {
  const result = await pool.query<NotificationDeliveryAttempt>(
    `SELECT id, notification_id as "notificationId", recipient_id as "recipientId", channel, provider, attempt_number as "attemptNumber", status, provider_message_id as "providerMessageId", provider_response as "providerResponse", error_code as "errorCode", error_message as "errorMessage", sent_at as "sentAt", delivered_at as "deliveredAt", failed_at as "failedAt", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_delivery_attempts
     WHERE status IN ('pending', 'sent') AND (next_retry_at IS NULL OR next_retry_at <= NOW())
     ORDER BY created_at ASC
     LIMIT $1`,
    [limit],
  );
  return result.rows;
}

export async function findDeliveryAttemptsByNotification(notificationId: string): Promise<NotificationDeliveryAttempt[]> {
  const result = await pool.query<NotificationDeliveryAttempt>(
    `SELECT id, notification_id as "notificationId", recipient_id as "recipientId", channel, provider, attempt_number as "attemptNumber", status, provider_message_id as "providerMessageId", provider_response as "providerResponse", error_code as "errorCode", error_message as "errorMessage", sent_at as "sentAt", delivered_at as "deliveredAt", failed_at as "failedAt", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_delivery_attempts WHERE notification_id = $1 ORDER BY attempt_number`,
    [notificationId],
  );
  return result.rows;
}

// Dead Letters
export async function createDeadLetter(data: {
  deliveryAttemptId: string;
  notificationId: string;
  recipientId: string | null;
  channel: string;
  provider: string;
  failureReason: string;
  payload: Record<string, unknown>;
  retryCount: number;
}): Promise<NotificationDeadLetter> {
  const id = randomUUID();
  const result = await pool.query<NotificationDeadLetter>(
    `INSERT INTO notification_dead_letters (id, delivery_attempt_id, notification_id, recipient_id, channel, provider, failure_reason, payload, retry_count)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING id, delivery_attempt_id as "deliveryAttemptId", notification_id as "notificationId", recipient_id as "recipientId", channel, provider, failure_reason as "failureReason", payload, retry_count as "retryCount", resolved, resolved_by as "resolvedBy", resolved_at as "resolvedAt", resolution_notes as "resolutionNotes", created_at as "createdAt"`,
    [id, data.deliveryAttemptId, data.notificationId, data.recipientId, data.channel, data.provider, data.failureReason, JSON.stringify(data.payload), data.retryCount],
  );
  return result.rows[0]!;
}

export async function findDeadLetters(resolved?: boolean, limit = 50, offset = 0): Promise<NotificationDeadLetter[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (resolved !== undefined) {
    conditions.push(`resolved = $${paramIndex++}`);
    values.push(resolved);
  }

  values.push(limit, offset);

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const result = await pool.query<NotificationDeadLetter>(
    `SELECT id, delivery_attempt_id as "deliveryAttemptId", notification_id as "notificationId", recipient_id as "recipientId", channel, provider, failure_reason as "failureReason", payload, retry_count as "retryCount", resolved, resolved_by as "resolvedBy", resolved_at as "resolvedAt", resolution_notes as "resolutionNotes", created_at as "createdAt"
     FROM notification_dead_letters
     ${whereClause}
     ORDER BY created_at DESC
     LIMIT $${paramIndex++} OFFSET $${paramIndex}`,
    values,
  );
  return result.rows;
}

export async function resolveDeadLetter(deadLetterId: string, resolvedBy: string, notes: string | null): Promise<NotificationDeadLetter | undefined> {
  const result = await pool.query<NotificationDeadLetter>(
    `UPDATE notification_dead_letters SET resolved = TRUE, resolved_by = $1, resolved_at = NOW(), resolution_notes = $2
     WHERE id = $3
     RETURNING id, delivery_attempt_id as "deliveryAttemptId", notification_id as "notificationId", recipient_id as "recipientId", channel, provider, failure_reason as "failureReason", payload, retry_count as "retryCount", resolved, resolved_by as "resolvedBy", resolved_at as "resolvedAt", resolution_notes as "resolutionNotes", created_at as "createdAt"`,
    [resolvedBy, notes, deadLetterId],
  );
  return result.rows[0];
}

// Notification Outbox
export async function createOutboxEvent(data: {
  idempotencyKey: string;
  eventType: string;
  category: string;
  priority: string;
  recipientUserIds: string[];
  organisationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  payload: Record<string, unknown>;
  channels: string[];
  maxRetries?: number;
}): Promise<NotificationOutbox> {
  const id = randomUUID();
  const result = await pool.query<NotificationOutbox>(
    `INSERT INTO notification_outbox (id, idempotency_key, event_type, category, priority, recipient_user_ids, organisation_id, resource_type, resource_id, payload, channels, max_retries)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING id, idempotency_key as "idempotencyKey", event_type as "eventType", category, priority, recipient_user_ids as "recipientUserIds", organisation_id as "organisationId", resource_type as "resourceType", resource_id as "resourceId", payload, channels, status, processing_started_at as "processingStartedAt", processing_completed_at as "processingCompletedAt", error_message as "errorMessage", retry_count as "retryCount", max_retries as "maxRetries", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.idempotencyKey, data.eventType, data.category, data.priority, data.recipientUserIds, data.organisationId, data.resourceType, data.resourceId, JSON.stringify(data.payload), data.channels, data.maxRetries ?? 3],
  );
  return result.rows[0]!;
}

export async function findOutboxEventByIdempotencyKey(idempotencyKey: string): Promise<NotificationOutbox | undefined> {
  const result = await pool.query<NotificationOutbox>(
    `SELECT id, idempotency_key as "idempotencyKey", event_type as "eventType", category, priority, recipient_user_ids as "recipientUserIds", organisation_id as "organisationId", resource_type as "resourceType", resource_id as "resourceId", payload, channels, status, processing_started_at as "processingStartedAt", processing_completed_at as "processingCompletedAt", error_message as "errorMessage", retry_count as "retryCount", max_retries as "maxRetries", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_outbox WHERE idempotency_key = $1`,
    [idempotencyKey],
  );
  return result.rows[0];
}

export async function findPendingOutboxEvents(limit = 100): Promise<NotificationOutbox[]> {
  const result = await pool.query<NotificationOutbox>(
    `SELECT id, idempotency_key as "idempotencyKey", event_type as "eventType", category, priority, recipient_user_ids as "recipientUserIds", organisation_id as "organisationId", resource_type as "resourceType", resource_id as "resourceId", payload, channels, status, processing_started_at as "processingStartedAt", processing_completed_at as "processingCompletedAt", error_message as "errorMessage", retry_count as "retryCount", max_retries as "maxRetries", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_outbox
     WHERE status IN ('pending', 'failed') AND (next_retry_at IS NULL OR next_retry_at <= NOW())
     ORDER BY
       CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 WHEN 'low' THEN 3 END,
       created_at ASC
     LIMIT $1`,
    [limit],
  );
  return result.rows;
}

export async function updateOutboxEvent(
  outboxId: string,
  updates: Partial<Pick<NotificationOutbox, 'status' | 'processingStartedAt' | 'processingCompletedAt' | 'errorMessage' | 'retryCount' | 'nextRetryAt'>>
): Promise<NotificationOutbox | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const fieldMap: Record<string, string> = {
    status: 'status',
    processingStartedAt: 'processing_started_at',
    processingCompletedAt: 'processing_completed_at',
    errorMessage: 'error_message',
    retryCount: 'retry_count',
    nextRetryAt: 'next_retry_at',
  };

  for (const [key, dbField] of Object.entries(fieldMap)) {
    const value = updates[key as keyof typeof updates];
    if (value !== undefined) {
      fields.push(`${dbField} = $${paramIndex++}`);
      values.push(value);
    }
  }

  if (fields.length === 0) return findOutboxEventById(outboxId);

  fields.push(`updated_at = NOW()`);
  values.push(outboxId);

  const result = await pool.query<NotificationOutbox>(
    `UPDATE notification_outbox SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, idempotency_key as "idempotencyKey", event_type as "eventType", category, priority, recipient_user_ids as "recipientUserIds", organisation_id as "organisationId", resource_type as "resourceType", resource_id as "resourceId", payload, channels, status, processing_started_at as "processingStartedAt", processing_completed_at as "processingCompletedAt", error_message as "errorMessage", retry_count as "retryCount", max_retries as "maxRetries", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function findOutboxEventById(outboxId: string): Promise<NotificationOutbox | undefined> {
  const result = await pool.query<NotificationOutbox>(
    `SELECT id, idempotency_key as "idempotencyKey", event_type as "eventType", category, priority, recipient_user_ids as "recipientUserIds", organisation_id as "organisationId", resource_type as "resourceType", resource_id as "resourceId", payload, channels, status, processing_started_at as "processingStartedAt", processing_completed_at as "processingCompletedAt", error_message as "errorMessage", retry_count as "retryCount", max_retries as "maxRetries", next_retry_at as "nextRetryAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM notification_outbox WHERE id = $1`,
    [outboxId],
  );
  return result.rows[0];
}

// ============================================================================
// RBAC FUNCTIONS
// ============================================================================

// Roles
export async function getAllRoles(): Promise<Role[]> {
  const result = await pool.query<Role>(
    `SELECT id, name, description, is_system as "isSystem", is_publicly_assignable as "isPubliclyAssignable",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM roles ORDER BY is_system DESC, name`,
  );
  return result.rows;
}

export async function createRole(data: {
  id: string;
  name: string;
  description: string | null;
  isSystem?: boolean;
  isPubliclyAssignable?: boolean;
}): Promise<Role> {
  const result = await pool.query<Role>(
    `INSERT INTO roles (id, name, description, is_system, is_publicly_assignable)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, name, description, is_system as "isSystem", is_publicly_assignable as "isPubliclyAssignable",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [data.id, data.name, data.description, data.isSystem ?? false, data.isPubliclyAssignable ?? false],
  );
  return result.rows[0]!;
}

export async function updateRole(
  roleId: string,
  updates: Partial<Pick<Role, 'name' | 'description' | 'isPubliclyAssignable'>>
): Promise<Role | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (updates.name !== undefined) {
    fields.push(`name = $${paramIndex++}`);
    values.push(updates.name);
  }
  if (updates.description !== undefined) {
    fields.push(`description = $${paramIndex++}`);
    values.push(updates.description);
  }
  if (updates.isPubliclyAssignable !== undefined) {
    fields.push(`is_publicly_assignable = $${paramIndex++}`);
    values.push(updates.isPubliclyAssignable);
  }

  if (fields.length === 0) return getRoleById(roleId);

  fields.push(`updated_at = NOW()`);
  values.push(roleId);

  const result = await pool.query<Role>(
    `UPDATE roles SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, name, description, is_system as "isSystem", is_publicly_assignable as "isPubliclyAssignable",
       created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteRole(roleId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM roles WHERE id = $1`, [roleId]);
  return (result.rowCount ?? 0) > 0;
}

// Permissions
export interface Permission {
  id: string;
  name: string;
  description: string | null;
  category: string;
  isSystem: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export async function getPermissionById(permissionId: string): Promise<Permission | undefined> {
  const result = await pool.query<Permission>(
    `SELECT id, name, description, category, is_system as "isSystem", created_at as "createdAt", updated_at as "updatedAt"
     FROM permissions WHERE id = $1`,
    [permissionId],
  );
  return result.rows[0];
}

export async function createPermission(data: {
  id: string;
  name: string;
  description: string | null;
  category: string;
  isSystem?: boolean;
}): Promise<Permission> {
  const result = await pool.query<Permission>(
    `INSERT INTO permissions (id, name, description, category, is_system)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, name, description, category, is_system as "isSystem", created_at as "createdAt", updated_at as "updatedAt"`,
    [data.id, data.name, data.description, data.category, data.isSystem ?? false],
  );
  return result.rows[0]!;
}

export async function getAllPermissions(): Promise<Permission[]> {
  const result = await pool.query<Permission>(
    `SELECT id, name, description, category, is_system as "isSystem", created_at as "createdAt", updated_at as "updatedAt"
     FROM permissions ORDER BY category, name`,
  );
  return result.rows;
}

export async function getRolePermissions(roleId: string): Promise<Permission[]> {
  const result = await pool.query<Permission>(
    `SELECT p.id, p.name, p.description, p.category, p.is_system as "isSystem", p.created_at as "createdAt", p.updated_at as "updatedAt"
     FROM permissions p
     JOIN role_permissions rp ON rp.permission_id = p.id
     WHERE rp.role_id = $1
     ORDER BY p.category, p.name`,
    [roleId],
  );
  return result.rows;
}

export async function assignPermissionToRole(roleId: string, permissionId: string): Promise<void> {
  await pool.query(
    `INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)
     ON CONFLICT (role_id, permission_id) DO NOTHING`,
    [roleId, permissionId],
  );
}

export async function removePermissionFromRole(roleId: string, permissionId: string): Promise<void> {
  await pool.query(
    `DELETE FROM role_permissions WHERE role_id = $1 AND permission_id = $2`,
    [roleId, permissionId],
  );
}

export async function setRolePermissions(roleId: string, permissionIds: string[]): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM role_permissions WHERE role_id = $1`, [roleId]);
    for (const permissionId of permissionIds) {
      await client.query(
        `INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)
         ON CONFLICT (role_id, permission_id) DO NOTHING`,
        [roleId, permissionId],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Role Assignments
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

export async function createRoleAssignment(data: {
  roleId: string;
  userId: string;
  scope: 'global' | 'organization' | 'resource';
  organizationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  assignedBy: string | null;
  expiresAt: Date | null;
}): Promise<RoleAssignment> {
  const id = randomUUID();
  const result = await pool.query<RoleAssignment>(
    `INSERT INTO role_assignments (id, role_id, user_id, scope, organization_id, resource_type, resource_id, assigned_by, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING id, role_id as "roleId", user_id as "userId", scope, organization_id as "organizationId", resource_type as "resourceType", resource_id as "resourceId", assigned_by as "assignedBy", assigned_at as "assignedAt", expires_at as "expiresAt", revoked_at as "revokedAt", revoked_by as "revokedBy", revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.roleId, data.userId, data.scope, data.organizationId, data.resourceType, data.resourceId, data.assignedBy, data.expiresAt],
  );
  return result.rows[0]!;
}

export async function getRoleAssignmentById(assignmentId: string): Promise<RoleAssignment | undefined> {
  const result = await pool.query<RoleAssignment>(
    `SELECT id, role_id as "roleId", user_id as "userId", scope, organization_id as "organizationId", resource_type as "resourceType", resource_id as "resourceId", assigned_by as "assignedBy", assigned_at as "assignedAt", expires_at as "expiresAt", revoked_at as "revokedAt", revoked_by as "revokedBy", revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt"
     FROM role_assignments WHERE id = $1`,
    [assignmentId],
  );
  return result.rows[0];
}

export async function revokeRoleAssignment(assignmentId: string, revokedBy: string, reason?: string | null): Promise<boolean> {
  const result = await pool.query(
    `UPDATE role_assignments SET revoked_at = NOW(), revoked_by = $2, revoked_reason = $3, updated_at = NOW() WHERE id = $1`,
    [assignmentId, revokedBy, reason ?? 'revoked'],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function getRoleAssignmentsByOrganization(organizationId: string): Promise<RoleAssignment[]> {
  const result = await pool.query<RoleAssignment>(
    `SELECT id, role_id as "roleId", user_id as "userId", scope, organization_id as "organizationId", resource_type as "resourceType", resource_id as "resourceId", assigned_by as "assignedBy", assigned_at as "assignedAt", expires_at as "expiresAt", revoked_at as "revokedAt", revoked_by as "revokedBy", revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt"
     FROM role_assignments WHERE organization_id = $1 ORDER BY assigned_at DESC`,
    [organizationId],
  );
  return result.rows;
}

// Authorization Audit
export interface AuthorizationAuditEvent {
  id: string;
  userId: string | null;
  action: string;
  resourceType: string | null;
  resourceId: string | null;
  permission: string | null;
  allowed: boolean;
  ipAddress: string | null;
  userAgent: string | null;
  metadata: Record<string, unknown>;
  createdAt: Date;
}

export async function createAuthorizationAuditEvent(data: {
  userId: string | null;
  action: string;
  resourceType: string | null;
  resourceId: string | null;
  permission: string | null;
  allowed: boolean;
  ipAddress: string | null;
  userAgent: string | null;
  metadata: Record<string, unknown>;
}): Promise<AuthorizationAuditEvent> {
  const id = randomUUID();
  const result = await pool.query<AuthorizationAuditEvent>(
    `INSERT INTO authorization_audit (id, user_id, action, resource_type, resource_id, permission, allowed, ip_address, user_agent, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id, user_id as "userId", action, resource_type as "resourceType", resource_id as "resourceId", permission, allowed, ip_address as "ipAddress", user_agent as "userAgent", metadata, created_at as "createdAt"`,
    [id, data.userId, data.action, data.resourceType, data.resourceId, data.permission, data.allowed, data.ipAddress, data.userAgent, JSON.stringify(data.metadata)],
  );
  return result.rows[0]!;
}

export async function getAuthorizationAuditEvents(options: {
  userId?: string;
  organizationId?: string;
  action?: string;
  resourceType?: string;
  allowed?: boolean;
  startDate?: Date;
  endDate?: Date;
  limit?: number;
  offset?: number;
} = {}): Promise<AuthorizationAuditEvent[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (options.userId) {
    conditions.push(`user_id = $${paramIndex++}`);
    values.push(options.userId);
  }
  if (options.action) {
    conditions.push(`action = $${paramIndex++}`);
    values.push(options.action);
  }
  if (options.resourceType) {
    conditions.push(`resource_type = $${paramIndex++}`);
    values.push(options.resourceType);
  }
  if (options.allowed !== undefined) {
    conditions.push(`allowed = $${paramIndex++}`);
    values.push(options.allowed);
  }
  if (options.startDate) {
    conditions.push(`created_at >= $${paramIndex++}`);
    values.push(options.startDate);
  }
  if (options.endDate) {
    conditions.push(`created_at <= $${paramIndex++}`);
    values.push(options.endDate);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  values.push(options.limit ?? 100, options.offset ?? 0);

  const result = await pool.query<AuthorizationAuditEvent>(
    `SELECT id, user_id as "userId", action, resource_type as "resourceType", resource_id as "resourceId", permission, allowed, ip_address as "ipAddress", user_agent as "userAgent", metadata, created_at as "createdAt"
     FROM authorization_audit
     ${whereClause}
     ORDER BY created_at DESC
     LIMIT $${paramIndex++} OFFSET $${paramIndex}`,
    values,
  );
  return result.rows;
}

// Additional functions needed by authorization.service.ts
export async function getUserGlobalRoleIds(userId: string): Promise<string[]> {
  const result = await pool.query<{ role_id: string }>(
    `SELECT role_id FROM role_assignments WHERE user_id = $1 AND scope = 'platform' AND (expires_at IS NULL OR expires_at > NOW())`,
    [userId],
  );
  return result.rows.map(r => r.role_id);
}

export async function getUserOrganisationMemberships(userId: string): Promise<OrganisationMember[]> {
  const result = await pool.query<OrganisationMember>(
    `SELECT id, organisation_id as "organisationId", user_id as "userId", role, status,
       invited_by as "invitedBy", invited_at as "invitedAt", joined_at as "joinedAt",
       removed_at as "removedAt", removed_by as "removedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM organisation_members WHERE user_id = $1 AND status IN ('active', 'invited')`,
    [userId],
  );
  return result.rows;
}

export async function getUserActiveRoleAssignments(userId: string): Promise<RoleAssignment[]> {
  const result = await pool.query<RoleAssignment>(
    `SELECT id, role_id as "roleId", user_id as "userId", scope, organization_id as "organizationId", resource_type as "resourceType", resource_id as "resourceId", assigned_by as "assignedBy", assigned_at as "assignedAt", expires_at as "expiresAt", revoked_at as "revokedAt", revoked_by as "revokedBy", revoked_reason as "revokedReason", created_at as "createdAt", updated_at as "updatedAt"
     FROM role_assignments WHERE user_id = $1 AND (expires_at IS NULL OR expires_at > NOW()) AND revoked_at IS NULL`,
    [userId],
  );
  return result.rows;
}

export async function getRolePermissionIds(roleId: string): Promise<string[]> {
  const result = await pool.query<{ permission_id: string }>(
    `SELECT permission_id FROM role_permissions WHERE role_id = $1`,
    [roleId],
  );
  return result.rows.map(r => r.permission_id);
}

export async function findPropertyById(propertyId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, organisation_id as "organisationId", title, description, property_type as "propertyType", status,
       address, city, county, country, latitude, longitude, total_units as "totalUnits",
       amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
       published_at as "publishedAt", archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM properties WHERE id = $1`,
    [propertyId],
  );
  return result.rows[0];
}

export interface Property {
  id: string;
  organisationId: string | null;
  title: string;
  description: string | null;
  propertyType: string;
  status: string;
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

export async function createProperty(data: {
  organisationId: string | null;
  title: string;
  description: string | null;
  propertyType: string;
  address: string;
  city: string;
  county: string;
  country: string;
  latitude?: number | null;
  longitude?: number | null;
  amenities?: Record<string, unknown> | null;
  features?: Record<string, unknown> | null;
  images?: Record<string, unknown> | null;
  createdBy: string;
}): Promise<Property> {
  const id = randomUUID();
  const result = await pool.query<Property>(
    `INSERT INTO properties (id, organisation_id, title, description, property_type, status, address, city, county, country, latitude, longitude, amenities, features, images, created_by)
     VALUES ($1, $2, $3, $4, $5, 'draft', $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
     RETURNING id, organisation_id as "organisationId", title, description, property_type as "propertyType", status,
       address, city, county, country, latitude, longitude, total_units as "totalUnits",
       amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
       published_at as "publishedAt", archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.organisationId, data.title, data.description, data.propertyType, data.address, data.city, data.county, data.country, data.latitude ?? null, data.longitude ?? null, data.amenities ?? null, data.features ?? null, data.images ?? null, data.createdBy],
  );
  return result.rows[0]!;
}

export async function updateProperty(
  propertyId: string,
  updates: Partial<Pick<Property, 'title' | 'description' | 'propertyType' | 'status' | 'address' | 'city' | 'county' | 'country' | 'latitude' | 'longitude' | 'amenities' | 'features' | 'images'>>,
  _userId?: string
): Promise<Property | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    title: 'title',
    description: 'description',
    propertyType: 'property_type',
    status: 'status',
    address: 'address',
    city: 'city',
    county: 'county',
    country: 'country',
    latitude: 'latitude',
    longitude: 'longitude',
    amenities: 'amenities',
    features: 'features',
    images: 'images',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findPropertyById(propertyId);

  fields.push(`updated_at = NOW()`);
  values.push(propertyId);

  const result = await pool.query<Property>(
    `UPDATE properties SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, organisation_id as "organisationId", title, description, property_type as "propertyType", status,
       address, city, county, country, latitude, longitude, total_units as "totalUnits",
       amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
       published_at as "publishedAt", archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteProperty(propertyId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM properties WHERE id = $1`, [propertyId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findPropertyOwnerships(propertyId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT user_id, ownership_percentage FROM property_ownerships WHERE property_id = $1`,
    [propertyId],
  );
  return result.rows;
}

export async function findPropertyAssignments(propertyId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT user_id, role FROM property_assignments WHERE property_id = $1`,
    [propertyId],
  );
  return result.rows;
}

export async function findUnitsByProperty(propertyId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT id, property_id, name, unit_number, unit_type, floor, area_sqm, status, created_at, updated_at
     FROM units WHERE property_id = $1`,
    [propertyId],
  );
  return result.rows;
}

export async function findUnitAccessAssignments(unitId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT user_id, role FROM unit_access_assignments WHERE unit_id = $1`,
    [unitId],
  );
  return result.rows;
}

export async function findTenancyById(tenancyId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM tenancies WHERE id = $1`,
    [tenancyId],
  );
  return result.rows[0];
}

export async function findTenanciesByProperty(
  propertyId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM tenancies WHERE property_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [propertyId, limit, offset],
  );
  return result.rows;
}

export async function findTenanciesByUnit(
  unitId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM tenancies WHERE unit_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [unitId, limit, offset],
  );
  return result.rows;
}

export async function findTenancyParticipants(tenancyId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT user_id, role, is_primary FROM tenancy_participants WHERE tenancy_id = $1 AND status = 'active'`,
    [tenancyId],
  );
  return result.rows;
}

export async function findTenanciesByUserOrgs(
  organisationIds: string[],
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  if (organisationIds.length === 0) return [];
  const placeholders = organisationIds.map((_, i) => `$${i + 1}`).join(',');
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"
     FROM tenancies
     WHERE property_id IN (SELECT id FROM properties WHERE organisation_id IN (${placeholders}))
     ORDER BY created_at DESC
     LIMIT $${organisationIds.length + 1} OFFSET $${organisationIds.length + 2}`,
    [...organisationIds, limit, offset],
  );
  return result.rows;
}

export async function addTenancyParticipant(data: {
  tenancyId: string;
  userId: string | null;
  fullName?: string | null;
  email?: string | null;
  phone?: string | null;
  idNumber?: string | null;
  idType?: string | null;
  role: string;
  isPrimary?: boolean;
  canAccessDocuments?: boolean;
  canReceiveNotices?: boolean;
  canAuthorizeRepairs?: boolean;
  addedBy: string;
}): Promise<any> {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO tenancy_participants (id, tenancy_id, user_id, full_name, email, phone, id_number, id_type, role, is_primary, can_access_documents, can_receive_notices, can_authorize_repairs, status, added_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'active', $14)
     RETURNING id, tenancy_id as "tenancyId", user_id as "userId", full_name as "fullName", email, phone, id_number as "idNumber", id_type as "idType", role, is_primary as "isPrimary", can_access_documents as "canAccessDocuments", can_receive_notices as "canReceiveNotices", can_authorize_repairs as "canAuthorizeRepairs", status, added_by as "addedBy", created_at as "createdAt"`,
    [id, data.tenancyId, data.userId, data.fullName ?? null, data.email ?? null, data.phone ?? null, data.idNumber ?? null, data.idType ?? null, data.role, data.isPrimary ?? false, data.canAccessDocuments ?? true, data.canReceiveNotices ?? true, data.canAuthorizeRepairs ?? false, data.addedBy],
  );
  return result.rows[0];
}

export async function updateTenancyParticipant(
  participantId: string,
  updates: {
    role?: string;
    isPrimary?: boolean;
    status?: string;
    fullName?: string | null;
    email?: string | null;
    phone?: string | null;
    idNumber?: string | null;
    idType?: string | null;
    canAccessDocuments?: boolean;
    canReceiveNotices?: boolean;
    canAuthorizeRepairs?: boolean;
    removedBy?: string;
  },
  _userId?: string
): Promise<any> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    role: 'role',
    isPrimary: 'is_primary',
    status: 'status',
    fullName: 'full_name',
    email: 'email',
    phone: 'phone',
    idNumber: 'id_number',
    idType: 'id_type',
    canAccessDocuments: 'can_access_documents',
    canReceiveNotices: 'can_receive_notices',
    canAuthorizeRepairs: 'can_authorize_repairs',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) {
    const result = await pool.query(
      `SELECT id, tenancy_id as "tenancyId", user_id as "userId", full_name as "fullName", email, phone, id_number as "idNumber", id_type as "idType", role, is_primary as "isPrimary", can_access_documents as "canAccessDocuments", can_receive_notices as "canReceiveNotices", can_authorize_repairs as "canAuthorizeRepairs", status, added_by as "addedBy", created_at as "createdAt"
       FROM tenancy_participants WHERE id = $1`,
      [participantId],
    );
    return result.rows[0];
  }

  fields.push(`updated_at = NOW()`);
  values.push(participantId);

  const result = await pool.query(
    `UPDATE tenancy_participants SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, tenancy_id as "tenancyId", user_id as "userId", full_name as "fullName", email, phone, id_number as "idNumber", id_type as "idType", role, is_primary as "isPrimary", can_access_documents as "canAccessDocuments", can_receive_notices as "canReceiveNotices", can_authorize_repairs as "canAuthorizeRepairs", status, added_by as "addedBy", created_at as "createdAt"`,
    values,
  );
  return result.rows[0];
}

export async function removeTenancyParticipant(participantId: string, removedBy: string): Promise<boolean> {
  const result = await pool.query(
    `UPDATE tenancy_participants SET status = 'removed', removed_by = $2, left_at = NOW(), updated_at = NOW() WHERE id = $1`,
    [participantId, removedBy],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function findPropertyDocumentById(documentId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM property_documents WHERE id = $1`,
    [documentId],
  );
  return result.rows[0];
}

export async function findPropertyDocumentsByTenancy(tenancyId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM property_documents WHERE tenancy_id = $1 ORDER BY created_at DESC`,
    [tenancyId],
  );
  return result.rows;
}

export interface PropertyDocument {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  title: string;
  description: string | null;
  category: string;
  visibility: string;
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
  status: string;
  uploadedBy: string;
  uploadedAt: Date;
  expiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export async function createPropertyDocument(data: {
  propertyId: string;
  unitId?: string | null;
  tenancyId?: string | null;
  title: string;
  description?: string | null;
  category: string;
  visibility?: string;
  filePath: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  fileHash: string;
  allowedRoles?: string[];
  allowedUserIds?: string[];
  allowedOrganisationIds?: string[];
  uploadedBy: string;
  expiresAt?: Date | null;
}): Promise<PropertyDocument> {
  const id = randomUUID();
  const result = await pool.query<PropertyDocument>(
    `INSERT INTO property_documents (id, property_id, unit_id, tenancy_id, title, description, category, visibility, file_path, file_name, file_size, mime_type, file_hash, allowed_roles, allowed_user_ids, allowed_organisation_ids, uploaded_by, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
     RETURNING id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.propertyId, data.unitId ?? null, data.tenancyId ?? null, data.title, data.description ?? null, data.category, data.visibility ?? 'private', data.filePath, data.fileName, data.fileSize, data.mimeType, data.fileHash, data.allowedRoles ?? [], data.allowedUserIds ?? [], data.allowedOrganisationIds ?? [], data.uploadedBy, data.expiresAt ?? null],
  );
  return result.rows[0]!;
}

export async function updatePropertyDocument(
  documentId: string,
  updates: Partial<Pick<PropertyDocument, 'title' | 'description' | 'category' | 'visibility' | 'allowedRoles' | 'allowedUserIds' | 'allowedOrganisationIds' | 'status' | 'expiresAt'>>,
  _userId?: string
): Promise<PropertyDocument | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    title: 'title',
    description: 'description',
    category: 'category',
    visibility: 'visibility',
    allowedRoles: 'allowed_roles',
    allowedUserIds: 'allowed_user_ids',
    allowedOrganisationIds: 'allowed_organisation_ids',
    status: 'status',
    expiresAt: 'expires_at',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findPropertyDocumentById(documentId);

  fields.push(`updated_at = NOW()`);
  values.push(documentId);

  const result = await pool.query<PropertyDocument>(
    `UPDATE property_documents SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deletePropertyDocument(documentId: string): Promise<boolean> {
  const result = await pool.query(`UPDATE property_documents SET status = 'deleted', updated_at = NOW() WHERE id = $1`, [documentId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findSiteVisitById(visitId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", visitor_name as "visitorName", visitor_email as "visitorEmail", visitor_phone as "visitorPhone", scheduled_at as "scheduledAt", duration_minutes as "durationMinutes", status, hosted_by_user_id as "hostedByUserId", hosted_by_organisation_id as "hostedByOrganisationId", visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM site_visits WHERE id = $1`,
    [visitId],
  );
  return result.rows[0];
}

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
  status: string;
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

export async function createSiteVisit(data: {
  propertyId: string;
  unitId?: string | null;
  userId?: string | null;
  visitorName: string;
  visitorEmail?: string | null;
  visitorPhone: string;
  scheduledAt: Date;
  durationMinutes?: number;
  hostedByUserId?: string | null;
  hostedByOrganisationId?: string | null;
  visitorNotes?: string | null;
  createdBy: string;
}): Promise<SiteVisit> {
  const id = randomUUID();
  const result = await pool.query<SiteVisit>(
    `INSERT INTO site_visits (id, property_id, unit_id, user_id, visitor_name, visitor_email, visitor_phone, scheduled_at, duration_minutes, status, hosted_by_user_id, hosted_by_organisation_id, visitor_notes, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'scheduled', $10, $11, $12, $13)
     RETURNING id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", visitor_name as "visitorName", visitor_email as "visitorEmail", visitor_phone as "visitorPhone", scheduled_at as "scheduledAt", duration_minutes as "durationMinutes", status, hosted_by_user_id as "hostedByUserId", hosted_by_organisation_id as "hostedByOrganisationId", visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.propertyId, data.unitId ?? null, data.userId ?? null, data.visitorName, data.visitorEmail ?? null, data.visitorPhone, data.scheduledAt, data.durationMinutes ?? 30, data.hostedByUserId ?? null, data.hostedByOrganisationId ?? null, data.visitorNotes ?? null, data.createdBy],
  );
  return result.rows[0]!;
}

export async function updateSiteVisit(
  visitId: string,
  updates: Partial<Pick<SiteVisit, 'unitId' | 'userId' | 'visitorName' | 'visitorEmail' | 'visitorPhone' | 'scheduledAt' | 'durationMinutes' | 'status' | 'hostedByUserId' | 'hostedByOrganisationId' | 'visitorNotes' | 'hostNotes' | 'outcome'>>,
  _userId?: string
): Promise<SiteVisit | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    unitId: 'unit_id',
    userId: 'user_id',
    visitorName: 'visitor_name',
    visitorEmail: 'visitor_email',
    visitorPhone: 'visitor_phone',
    scheduledAt: 'scheduled_at',
    durationMinutes: 'duration_minutes',
    status: 'status',
    hostedByUserId: 'hosted_by_user_id',
    hostedByOrganisationId: 'hosted_by_organisation_id',
    visitorNotes: 'visitor_notes',
    hostNotes: 'host_notes',
    outcome: 'outcome',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findSiteVisitById(visitId);

  fields.push(`updated_at = NOW()`);
  values.push(visitId);

  const result = await pool.query<SiteVisit>(
    `UPDATE site_visits SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", visitor_name as "visitorName", visitor_email as "visitorEmail", visitor_phone as "visitorPhone", scheduled_at as "scheduledAt", duration_minutes as "durationMinutes", status, hosted_by_user_id as "hostedByUserId", hosted_by_organisation_id as "hostedByOrganisationId", visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteSiteVisit(visitId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM site_visits WHERE id = $1`, [visitId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findSiteVisitsByProperty(
  propertyId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", visitor_name as "visitorName", visitor_email as "visitorEmail", visitor_phone as "visitorPhone", scheduled_at as "scheduledAt", duration_minutes as "durationMinutes", status, hosted_by_user_id as "hostedByUserId", hosted_by_organisation_id as "hostedByOrganisationId", visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM site_visits WHERE property_id = $1 ORDER BY scheduled_at DESC LIMIT $2 OFFSET $3`,
    [propertyId, limit, offset],
  );
  return result.rows;
}

export async function findSiteVisitsByUser(
  userId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", visitor_name as "visitorName", visitor_email as "visitorEmail", visitor_phone as "visitorPhone", scheduled_at as "scheduledAt", duration_minutes as "durationMinutes", status, hosted_by_user_id as "hostedByUserId", hosted_by_organisation_id as "hostedByOrganisationId", visitor_notes as "visitorNotes", host_notes as "hostNotes", outcome, created_by as "createdBy", updated_by as "updatedBy", created_at as "createdAt", updated_at as "updatedAt"
     FROM site_visits WHERE user_id = $1 ORDER BY scheduled_at DESC LIMIT $2 OFFSET $3`,
    [userId, limit, offset],
  );
  return result.rows;
}

export async function findPropertyDocuments(
  propertyId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM property_documents WHERE property_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [propertyId, limit, offset],
  );
  return result.rows;
}

export async function findPropertyDocumentsByUserOrgs(
  organisationIds: string[],
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  if (organisationIds.length === 0) return [];
  const placeholders = organisationIds.map((_, i) => `$${i + 1}`).join(',');
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", tenancy_id as "tenancyId", title, description, category, visibility, file_path as "filePath", file_name as "fileName", file_size as "fileSize", mime_type as "mimeType", file_hash as "fileHash", allowed_roles as "allowedRoles", allowed_user_ids as "allowedUserIds", allowed_organisation_ids as "allowedOrganisationIds", version, previous_version_id as "previousVersionId", status, uploaded_by as "uploadedBy", uploaded_at as "uploadedAt", expires_at as "expiresAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM property_documents
     WHERE property_id IN (SELECT id FROM properties WHERE organisation_id IN (${placeholders}))
     ORDER BY created_at DESC
     LIMIT $${organisationIds.length + 1} OFFSET $${organisationIds.length + 2}`,
    [...organisationIds, limit, offset],
  );
  return result.rows;
}

export async function findRentalApplicationById(applicationId: string): Promise<any> {
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"
     FROM rental_applications WHERE id = $1`,
    [applicationId],
  );
  return result.rows[0];
}

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
  status: string;
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

export async function createRentalApplication(data: {
  propertyId: string;
  unitId?: string | null;
  userId?: string | null;
  applicantName: string;
  applicantEmail: string;
  applicantPhone: string;
  applicantIdNumber?: string | null;
  applicantIdType?: string | null;
  preferredStartDate?: Date | null;
  preferredEndDate?: Date | null;
  proposedRentAmount?: number | null;
  documents?: Record<string, unknown> | null;
  employerName?: string | null;
  employerContact?: string | null;
  monthlyIncome?: number | null;
  previousLandlordName?: string | null;
  previousLandlordContact?: string | null;
  guarantorName?: string | null;
  guarantorEmail?: string | null;
  guarantorPhone?: string | null;
  guarantorIdNumber?: string | null;
  guarantorRelationship?: string | null;
}): Promise<RentalApplication> {
  const id = randomUUID();
  const result = await pool.query<RentalApplication>(
    `INSERT INTO rental_applications (id, property_id, unit_id, user_id, applicant_name, applicant_email, applicant_phone, applicant_id_number, applicant_id_type, preferred_start_date, preferred_end_date, proposed_rent_amount, documents, employer_name, employer_contact, monthly_income, previous_landlord_name, previous_landlord_contact, guarantor_name, guarantor_email, guarantor_phone, guarantor_id_number, guarantor_relationship)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
     RETURNING id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.propertyId, data.unitId ?? null, data.userId ?? null, data.applicantName, data.applicantEmail, data.applicantPhone, data.applicantIdNumber ?? null, data.applicantIdType ?? null, data.preferredStartDate ?? null, data.preferredEndDate ?? null, data.proposedRentAmount ?? null, data.documents ?? null, data.employerName ?? null, data.employerContact ?? null, data.monthlyIncome ?? null, data.previousLandlordName ?? null, data.previousLandlordContact ?? null, data.guarantorName ?? null, data.guarantorEmail ?? null, data.guarantorPhone ?? null, data.guarantorIdNumber ?? null, data.guarantorRelationship ?? null],
  );
  return result.rows[0]!;
}

export async function updateRentalApplication(
  applicationId: string,
  updates: Partial<Pick<RentalApplication, 'status' | 'preferredStartDate' | 'preferredEndDate' | 'proposedRentAmount' | 'documents' | 'employerName' | 'employerContact' | 'monthlyIncome' | 'previousLandlordName' | 'previousLandlordContact' | 'guarantorName' | 'guarantorEmail' | 'guarantorPhone' | 'guarantorIdNumber' | 'guarantorRelationship' | 'reviewedBy' | 'reviewedAt' | 'reviewNotes' | 'rejectionReason' | 'approvedBy' | 'approvedAt' | 'approvedRentAmount' | 'approvedDepositAmount' | 'approvedStartDate' | 'approvedEndDate' | 'tenancyId'>>,
  _userId?: string
): Promise<RentalApplication | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    status: 'status',
    preferredStartDate: 'preferred_start_date',
    preferredEndDate: 'preferred_end_date',
    proposedRentAmount: 'proposed_rent_amount',
    documents: 'documents',
    employerName: 'employer_name',
    employerContact: 'employer_contact',
    monthlyIncome: 'monthly_income',
    previousLandlordName: 'previous_landlord_name',
    previousLandlordContact: 'previous_landlord_contact',
    guarantorName: 'guarantor_name',
    guarantorEmail: 'guarantor_email',
    guarantorPhone: 'guarantor_phone',
    guarantorIdNumber: 'guarantor_id_number',
    guarantorRelationship: 'guarantor_relationship',
    reviewedBy: 'reviewed_by',
    reviewedAt: 'reviewed_at',
    reviewNotes: 'review_notes',
    rejectionReason: 'rejection_reason',
    approvedBy: 'approved_by',
    approvedAt: 'approved_at',
    approvedRentAmount: 'approved_rent_amount',
    approvedDepositAmount: 'approved_deposit_amount',
    approvedStartDate: 'approved_start_date',
    approvedEndDate: 'approved_end_date',
    tenancyId: 'tenancy_id',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findRentalApplicationById(applicationId);

  fields.push(`updated_at = NOW()`);
  values.push(applicationId);

  const result = await pool.query<RentalApplication>(
    `UPDATE rental_applications SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteRentalApplication(applicationId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM rental_applications WHERE id = $1`, [applicationId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findRentalApplicationsByProperty(
  propertyId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"
     FROM rental_applications WHERE property_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [propertyId, limit, offset],
  );
  return result.rows;
}

export async function findRentalApplicationsByUser(
  userId: string,
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"
     FROM rental_applications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [userId, limit, offset],
  );
  return result.rows;
}

export async function findPropertiesByOrganisation(organisationId: string): Promise<any[]> {
  const result = await pool.query(
    `SELECT id, organisation_id as "organisationId", title, description, property_type as "propertyType", status,
       address, city, county, country, latitude, longitude, total_units as "totalUnits",
       amenities, features, images, created_by as "createdBy", updated_by as "updatedBy",
       published_at as "publishedAt", archived_at as "archivedAt", created_at as "createdAt", updated_at as "updatedAt"
     FROM properties WHERE organisation_id = $1 ORDER BY created_at DESC`,
    [organisationId],
  );
  return result.rows;
}

export async function findPropertiesByUserOrgs(
  organisationIds: string[],
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  if (organisationIds.length === 0) return [];
  const placeholders = organisationIds.map((_, i) => `$${i + 1}`).join(',');
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT p.id, p.organisation_id as "organisationId", p.title, p.description, p.property_type as "propertyType", p.status,
       p.address, p.city, p.county, p.country, p.latitude, p.longitude, p.total_units as "totalUnits",
       p.amenities, p.features, p.images, p.created_by as "createdBy", p.updated_by as "updatedBy",
       p.published_at as "publishedAt", p.archived_at as "archivedAt", p.created_at as "createdAt", p.updated_at as "updatedAt"
     FROM properties p
     WHERE p.organisation_id IN (${placeholders})
     ORDER BY p.created_at DESC
     LIMIT $${organisationIds.length + 1} OFFSET $${organisationIds.length + 2}`,
    [...organisationIds, limit, offset],
  );
  return result.rows;
}

export interface Unit {
  id: string;
  propertyId: string;
  unitNumber: string;
  unitType: string;
  floorNumber: number | null;
  bedrooms: number;
  bathrooms: number;
  areaSqm: number | null;
  rentAmount: number;
  depositAmount: number;
  status: string;
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

export async function createUnit(data: {
  propertyId: string;
  unitNumber: string;
  unitType: string;
  floorNumber?: number | null;
  bedrooms: number;
  bathrooms: number;
  areaSqm?: number | null;
  rentAmount: number;
  depositAmount: number;
  status?: string;
  description?: string | null;
  amenities?: Record<string, unknown> | null;
  features?: Record<string, unknown> | null;
  images?: Record<string, unknown> | null;
  hasSeparateMeter?: boolean;
  meterNumber?: string | null;
  createdBy: string;
}): Promise<Unit> {
  const id = randomUUID();
  const result = await pool.query<Unit>(
    `INSERT INTO units (id, property_id, unit_number, unit_type, floor_number, bedrooms, bathrooms, area_sqm, rent_amount, deposit_amount, status, description, amenities, features, images, has_separate_meter, meter_number, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
     RETURNING id, property_id as "propertyId", unit_number as "unitNumber", unit_type as "unitType",
       floor_number as "floorNumber", bedrooms, bathrooms, area_sqm as "areaSqm",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", status,
       description, amenities, features, images, has_separate_meter as "hasSeparateMeter",
       meter_number as "meterNumber", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.propertyId, data.unitNumber, data.unitType, data.floorNumber ?? null, data.bedrooms, data.bathrooms, data.areaSqm ?? null, data.rentAmount, data.depositAmount, data.status ?? 'vacant', data.description ?? null, data.amenities ?? null, data.features ?? null, data.images ?? null, data.hasSeparateMeter ?? false, data.meterNumber ?? null, data.createdBy],
  );
  return result.rows[0]!;
}

export async function updateUnit(
  unitId: string,
  updates: Partial<Pick<Unit, 'unitNumber' | 'unitType' | 'floorNumber' | 'bedrooms' | 'bathrooms' | 'areaSqm' | 'rentAmount' | 'depositAmount' | 'status' | 'description' | 'amenities' | 'features' | 'images' | 'hasSeparateMeter' | 'meterNumber'>>,
  _userId?: string
): Promise<Unit | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    unitNumber: 'unit_number',
    unitType: 'unit_type',
    floorNumber: 'floor_number',
    bedrooms: 'bedrooms',
    bathrooms: 'bathrooms',
    areaSqm: 'area_sqm',
    rentAmount: 'rent_amount',
    depositAmount: 'deposit_amount',
    status: 'status',
    description: 'description',
    amenities: 'amenities',
    features: 'features',
    images: 'images',
    hasSeparateMeter: 'has_separate_meter',
    meterNumber: 'meter_number',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findUnitById(unitId);

  fields.push(`updated_at = NOW()`);
  values.push(unitId);

  const result = await pool.query<Unit>(
    `UPDATE units SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, property_id as "propertyId", unit_number as "unitNumber", unit_type as "unitType",
       floor_number as "floorNumber", bedrooms, bathrooms, area_sqm as "areaSqm",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", status,
       description, amenities, features, images, has_separate_meter as "hasSeparateMeter",
       meter_number as "meterNumber", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteUnit(unitId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM units WHERE id = $1`, [unitId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findUnitsByUserOrgs(
  organisationIds: string[],
  options?: { limit?: number; offset?: number }
): Promise<any[]> {
  if (organisationIds.length === 0) return [];
  const placeholders = organisationIds.map((_, i) => `$${i + 1}`).join(',');
  const limit = options?.limit ?? 50;
  const offset = options?.offset ?? 0;
  const result = await pool.query(
    `SELECT u.id, u.property_id as "propertyId", u.unit_number as "unitNumber", u.unit_type as "unitType",
       u.floor_number as "floorNumber", u.bedrooms, u.bathrooms, u.area_sqm as "areaSqm",
       u.rent_amount as "rentAmount", u.deposit_amount as "depositAmount", u.status,
       u.description, u.amenities, u.features, u.images, u.has_separate_meter as "hasSeparateMeter",
       u.meter_number as "meterNumber", u.created_by as "createdBy", u.updated_by as "updatedBy",
       u.created_at as "createdAt", u.updated_at as "updatedAt"
     FROM units u
     JOIN properties p ON p.id = u.property_id
     WHERE p.organisation_id IN (${placeholders})
     ORDER BY u.created_at DESC
     LIMIT $${organisationIds.length + 1} OFFSET $${organisationIds.length + 2}`,
    [...organisationIds, limit, offset],
  );
  return result.rows;
}

export interface Tenancy {
  id: string;
  propertyId: string;
  unitId: string;
  tenancyType: string;
  status: string;
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

export async function createTenancy(data: {
  propertyId: string;
  unitId: string;
  tenancyType: string;
  startDate: Date;
  endDate: Date | null;
  noticePeriodDays: number;
  rentAmount: number;
  depositAmount: number;
  depositPaid?: boolean;
  depositHeldBy?: string | null;
  depositSchemeReference?: string | null;
  rentDueDay?: number;
  paymentMethod?: string | null;
  paymentReference?: string | null;
  termsDocumentUrl?: string | null;
  termsAcceptedAt?: Date | null;
  specialConditions?: string | null;
  managedByUserId?: string | null;
  managedByOrganisationId?: string | null;
  createdBy: string;
}): Promise<Tenancy> {
  const id = randomUUID();
  const result = await pool.query<Tenancy>(
    `INSERT INTO tenancies (id, property_id, unit_id, tenancy_type, status, start_date, end_date, notice_period_days, rent_amount, deposit_amount, deposit_paid, deposit_held_by, deposit_scheme_reference, rent_due_day, payment_method, payment_reference, terms_document_url, terms_accepted_at, special_conditions, managed_by_user_id, managed_by_organisation_id, created_by)
     VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
     RETURNING id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [id, data.propertyId, data.unitId, data.tenancyType, data.startDate, data.endDate, data.noticePeriodDays, data.rentAmount, data.depositAmount, data.depositPaid ?? false, data.depositHeldBy ?? null, data.depositSchemeReference ?? null, data.rentDueDay ?? 1, data.paymentMethod ?? null, data.paymentReference ?? null, data.termsDocumentUrl ?? null, data.termsAcceptedAt ?? null, data.specialConditions ?? null, data.managedByUserId ?? null, data.managedByOrganisationId ?? null, data.createdBy],
  );
  return result.rows[0]!;
}

export async function updateTenancy(
  tenancyId: string,
  updates: Partial<Pick<Tenancy, 'tenancyType' | 'status' | 'startDate' | 'endDate' | 'noticePeriodDays' | 'rentAmount' | 'depositAmount' | 'depositPaid' | 'depositHeldBy' | 'depositSchemeReference' | 'rentDueDay' | 'paymentMethod' | 'paymentReference' | 'termsDocumentUrl' | 'termsAcceptedAt' | 'specialConditions' | 'managedByUserId' | 'managedByOrganisationId'>>,
  _userId?: string
): Promise<Tenancy | undefined> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  const columnMap: Record<string, string> = {
    tenancyType: 'tenancy_type',
    status: 'status',
    startDate: 'start_date',
    endDate: 'end_date',
    noticePeriodDays: 'notice_period_days',
    rentAmount: 'rent_amount',
    depositAmount: 'deposit_amount',
    depositPaid: 'deposit_paid',
    depositHeldBy: 'deposit_held_by',
    depositSchemeReference: 'deposit_scheme_reference',
    rentDueDay: 'rent_due_day',
    paymentMethod: 'payment_method',
    paymentReference: 'payment_reference',
    termsDocumentUrl: 'terms_document_url',
    termsAcceptedAt: 'terms_accepted_at',
    specialConditions: 'special_conditions',
    managedByUserId: 'managed_by_user_id',
    managedByOrganisationId: 'managed_by_organisation_id',
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (updates[key as keyof typeof updates] !== undefined) {
      fields.push(`${column} = $${paramIndex++}`);
      values.push(updates[key as keyof typeof updates]);
    }
  }

  if (fields.length === 0) return findTenancyById(tenancyId);

  fields.push(`updated_at = NOW()`);
  values.push(tenancyId);

  const result = await pool.query<Tenancy>(
    `UPDATE tenancies SET ${fields.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, property_id as "propertyId", unit_id as "unitId", tenancy_type as "tenancyType", status,
       start_date as "startDate", end_date as "endDate", notice_period_days as "noticePeriodDays",
       rent_amount as "rentAmount", deposit_amount as "depositAmount", deposit_paid as "depositPaid",
       deposit_held_by as "depositHeldBy", deposit_scheme_reference as "depositSchemeReference",
       rent_due_day as "rentDueDay", payment_method as "paymentMethod", payment_reference as "paymentReference",
       terms_document_url as "termsDocumentUrl", terms_accepted_at as "termsAcceptedAt",
       special_conditions as "specialConditions", managed_by_user_id as "managedByUserId",
       managed_by_organisation_id as "managedByOrganisationId", terminated_at as "terminatedAt",
       terminated_by as "terminatedBy", termination_reason as "terminationReason",
       termination_notice_date as "terminationNoticeDate", created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    values,
  );
  return result.rows[0];
}

export async function deleteTenancy(tenancyId: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM tenancies WHERE id = $1`, [tenancyId]);
  return (result.rowCount ?? 0) > 0;
}

export async function findLegacySessionUserById(sessionId: string): Promise<any> {
  const result = await pool.query(
    `SELECT u.id, u.email, u.name, u.first_name, u.last_name, u.roles, u.is_active
     FROM auth_sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.id = $1 AND s.status = 'active' AND (s.expires_at IS NULL OR s.expires_at > NOW())`,
    [sessionId],
  );
  return result.rows[0];
}

export async function deleteLegacySessionById(sessionId: string): Promise<boolean> {
  const result = await pool.query(
    `DELETE FROM auth_sessions WHERE id = $1`,
    [sessionId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function deleteExpiredSessions(): Promise<number> {
  const legacy = await pool.query(
    `DELETE FROM auth_sessions WHERE expires_at < NOW()`,
  );
  const modern = await pool.query(
    `UPDATE sessions SET revoked_at = NOW(), revoked_reason = 'expired', is_current = FALSE
     WHERE revoked_at IS NULL AND (idle_expires_at <= NOW() OR absolute_expires_at <= NOW())`,
  );
  return (legacy.rowCount ?? 0) + (modern.rowCount ?? 0);
}
