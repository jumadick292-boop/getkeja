import { beforeEach, describe, expect, it, vi } from 'vitest';
import argon2 from 'argon2';
import { createHmac } from 'node:crypto';
import { loadEnv } from '../../config/env.js';
import type { AuthUser } from './auth.types.js';

const mocks = vi.hoisted(() => ({
  clientQuery: vi.fn(),
  clientRelease: vi.fn(),
  poolConnect: vi.fn(),
  poolQuery: vi.fn(),
  findUser: vi.fn(),
  findIdentities: vi.fn(),
  updatePasswords: vi.fn(),
  createSecurityEvent: vi.fn(),
  revokeSessions: vi.fn(),
  hasPlatformRole: vi.fn(),
}));

vi.mock('../../db/pool.js', () => ({
  pool: {
    connect: mocks.poolConnect,
    query: mocks.poolQuery,
  },
}));

vi.mock('./auth.repository.js', () => ({
  findUserWithRolesById: mocks.findUser,
  findLoginIdentitiesByUserId: mocks.findIdentities,
  updateAllPasswordHashes: mocks.updatePasswords,
  createSecurityEvent: mocks.createSecurityEvent,
}));

vi.mock('./session.service.js', () => ({
  revokeAllUserSessions: mocks.revokeSessions,
}));

vi.mock('./authorization.service.js', () => ({
  hasPlatformRole: mocks.hasPlatformRole,
}));

import {
  changePassword,
  confirmEmailChange,
  confirmPhoneChange,
  getAccountPreferences,
  updatePrivacyPreferences,
  updateAccountPreferences,
  updateUserStatus,
} from './account.service.js';

function makeUser(overrides: Partial<AuthUser> = {}): AuthUser {
  return {
    id: 'target-user',
    email: 'user@example.com',
    name: 'Test User',
    firstName: 'Test',
    lastName: 'User',
    roles: ['house_seeker'],
    isActive: true,
    isSuspended: false,
    isLocked: false,
    isDeactivated: false,
    emailVerified: true,
    phoneVerified: false,
    mfaEnabled: true,
    mfaEnrolledAt: new Date(),
    lastMfaVerifiedAt: new Date(),
    mfaEnrollmentRequired: false,
    accountStatus: 'active',
    deletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

describe('account administration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.poolQuery.mockReset();
    mocks.clientQuery.mockResolvedValue({ rowCount: 1, rows: [] });
    mocks.poolConnect.mockResolvedValue({
      query: mocks.clientQuery,
      release: mocks.clientRelease,
    });
    mocks.findUser.mockResolvedValue(makeUser());
    mocks.hasPlatformRole.mockResolvedValue(false);
    mocks.revokeSessions.mockResolvedValue(1);
    mocks.updatePasswords.mockResolvedValue(undefined);
    mocks.createSecurityEvent.mockResolvedValue(undefined);
  });

  it('suspends a user, writes an audit event, and revokes their sessions', async () => {
    const result = await updateUserStatus(
      { id: 'admin-user' },
      'target-user',
      'suspend',
      'Policy review',
    );

    expect(result).toEqual({ accountStatus: 'suspended' });
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE users'),
      ['target-user', 'suspended', false, true, false, false],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO security_events'),
      [
        'target-user',
        expect.stringContaining('"action":"suspend"'),
      ],
    );
    expect(mocks.revokeSessions).toHaveBeenCalledWith(
      'target-user',
      'admin_suspend',
    );
  });

  it('does not allow an administrator to change their own status', async () => {
    await expect(
      updateUserStatus(
        { id: 'target-user' },
        'target-user',
        'suspend',
        'Policy review',
      ),
    ).rejects.toThrow('Administrators cannot change their own account status');

    expect(mocks.poolConnect).not.toHaveBeenCalled();
  });

  it('restricts changes to a super-admin account to another super-admin', async () => {
    mocks.findUser.mockResolvedValue(makeUser({ roles: ['super_admin'] }));

    await expect(
      updateUserStatus(
        { id: 'admin-user' },
        'target-user',
        'suspend',
        'Policy review',
      ),
    ).rejects.toThrow('Only a super administrator can modify this account');

    expect(mocks.poolConnect).not.toHaveBeenCalled();
  });

  it('does not reinstate a user who is not suspended', async () => {
    await expect(
      updateUserStatus(
        { id: 'admin-user' },
        'target-user',
        'reinstate',
        'Review completed',
      ),
    ).rejects.toThrow('User is not suspended');
  });

  it('changes the password only after verifying the current password', async () => {
    const currentHash = await argon2.hash('Current-password-1');
    mocks.findIdentities.mockResolvedValue([
      { passwordHash: currentHash },
    ]);

    await expect(
      changePassword('target-user', 'wrong-password', 'New-password-2'),
    ).rejects.toThrow('Invalid credentials');
    expect(mocks.updatePasswords).not.toHaveBeenCalled();

    await changePassword(
      'target-user',
      'Current-password-1',
      'New-password-2',
    );

    expect(mocks.updatePasswords).toHaveBeenCalledWith(
      'target-user',
      expect.stringMatching(/^\$argon2/),
    );
    expect(mocks.revokeSessions).toHaveBeenCalledWith(
      'target-user',
      'password_changed',
    );
  });

  it('reads persisted account and notification preferences', async () => {
    mocks.poolQuery
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({
        rows: [{
          language: 'sw',
          theme: 'dark',
          currency: 'KES',
          timezone: 'Africa/Nairobi',
          dateFormat: 'dd/MM/yyyy',
          numberFormat: 'sw-KE',
          pushNotifications: false,
          emailNotifications: true,
          smsNotifications: false,
        }],
      });

    await expect(getAccountPreferences('target-user')).resolves.toMatchObject({
      language: 'sw',
      theme: 'dark',
      pushNotifications: false,
      smsNotifications: false,
    });
  });

  it('updates account preferences transactionally and returns saved values', async () => {
    mocks.poolQuery
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({
        rows: [{
          language: 'sw',
          theme: 'system',
          currency: 'KES',
          timezone: 'Africa/Nairobi',
          dateFormat: 'dd/MM/yyyy',
          numberFormat: 'en-KE',
          pushNotifications: false,
          emailNotifications: true,
          smsNotifications: true,
        }],
      });

    const result = await updateAccountPreferences('target-user', {
      language: 'sw',
      pushNotifications: false,
    });

    expect(result.language).toBe('sw');
    expect(result.pushNotifications).toBe(false);
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE user_account_preferences SET language'),
      ['target-user', 'sw'],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE notification_preferences SET push_enabled'),
      ['target-user', false],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
  });

  it('updates privacy consent and marketing email preferences transactionally', async () => {
    mocks.poolQuery
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({
        rows: [{
          marketingEmails: true,
          analyticsTracking: false,
          personalizedAds: false,
          dataSharing: false,
        }],
      });

    const result = await updatePrivacyPreferences('target-user', {
      marketingEmails: true,
      analyticsTracking: false,
    });

    expect(result.marketingEmails).toBe(true);
    expect(result.analyticsTracking).toBe(false);
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE user_account_preferences SET analytics_tracking'),
      ['target-user', false],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('SET marketing_email = $2'),
      ['target-user', true],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
  });

  it('changes an email identity only after a matching verification token', async () => {
    mocks.clientQuery.mockImplementation(async (sql: string) => {
      if (sql.includes('SELECT id, target_identifier, token_hash, attempt_count, max_attempts')) {
        return {
          rows: [{
            id: 'pending-email-token',
            target_identifier: 'new@example.com',
            token_hash: createHmac('sha256', loadEnv().COOKIE_SECRET).update('123456').digest('hex'),
            attempt_count: 0,
            max_attempts: 5,
          }],
        };
      }
      if (sql.includes('SELECT 1 FROM users WHERE lower(email)')) {
        return { rowCount: 0, rows: [] };
      }
      if (sql.includes('UPDATE user_login_identities')) {
        return { rowCount: 1, rows: [{ id: 'email-identity' }] };
      }
      return { rowCount: 1, rows: [] };
    });

    await confirmEmailChange('target-user', '123456');

    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('SET identifier = $3,'),
      ['target-user', 'email', 'new@example.com'],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('SET email = $2'),
      ['target-user', 'new@example.com'],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
  });

  it('rejects incorrect email-change codes and increments attempts', async () => {
    mocks.clientQuery.mockImplementation(async (sql: string) => {
      if (sql.includes('SELECT id, target_identifier, token_hash, attempt_count, max_attempts')) {
        return {
          rows: [{
            id: 'pending-email-token',
            target_identifier: 'new@example.com',
            token_hash: createHmac('sha256', loadEnv().COOKIE_SECRET).update('111111').digest('hex'),
            attempt_count: 0,
            max_attempts: 5,
          }],
        };
      }
      return { rowCount: 1, rows: [] };
    });

    await expect(confirmEmailChange('target-user', '222222')).rejects.toThrow(
      'Invalid or expired verification code',
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('SET attempt_count = $2'),
      ['pending-email-token', 1],
    );
  });

  it('counts incorrect phone-change codes and rejects them', async () => {
    mocks.clientQuery.mockImplementation(async (sql: string) => {
      if (sql.includes('SELECT id, target_identifier, token_hash')) {
        return {
          rows: [{
            id: 'pending-token',
            target_identifier: '+254712345678',
            token_hash: createHmac('sha256', loadEnv().COOKIE_SECRET).update('111111').digest('hex'),
            attempt_count: 0,
            max_attempts: 5,
          }],
        };
      }
      if (sql.includes('SELECT 1 FROM user_login_identities')) {
        return { rowCount: 0, rows: [] };
      }
      return { rowCount: 1, rows: [] };
    });

    await expect(confirmPhoneChange('target-user', '222222')).rejects.toThrow(
      'Invalid or expired verification code',
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('SET attempt_count = $2'),
      ['pending-token', 1],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
    expect(mocks.clientQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE users SET phone_verified'),
      expect.anything(),
    );
  });

  it('updates verified phone identity only after a valid code', async () => {
    mocks.clientQuery.mockImplementation(async (sql: string) => {
      if (sql.includes('SELECT id, target_identifier, token_hash')) {
        return {
          rows: [{
            id: 'pending-token',
            target_identifier: '+254712345678',
            token_hash: createHmac('sha256', loadEnv().COOKIE_SECRET).update('123456').digest('hex'),
            attempt_count: 0,
            max_attempts: 5,
          }],
        };
      }
      if (sql.includes('UPDATE user_login_identities')) {
        return { rowCount: 0, rows: [] };
      }
      if (sql.includes('SELECT 1 FROM user_login_identities')) {
        return { rowCount: 0, rows: [] };
      }
      return { rowCount: 1, rows: [] };
    });

    await confirmPhoneChange('target-user', '123456');

    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO user_login_identities'),
      expect.arrayContaining(['target-user', 'phone', '+254712345678']),
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('phone_verified = TRUE'),
      ['target-user'],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
  });
});
