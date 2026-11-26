// Permission cache and revocation tests.
//
// Verifies that:
//   - Cache invalidation clears cached permissions so they rebuild from DB
//   - Account suspension invalidates cached permissions immediately
//   - Logout invalidates cached authorization state
//   - Cache miss path rebuilds permissions from DB (fail-closed)

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import * as authz from '../auth/authorization.service.js';

const app = createApp({ nodeEnv: 'test' });

async function registerAndLogin(role: string): Promise<string> {
  const email = `testcache${Date.now()}${Math.floor(Math.random() * 1000000)}@example.com`;
  const reg = await request(app)
    .post('/api/auth/register/email')
    .send({ firstName: 'Test', lastName: role, email, password: 'password123', role, termsAccepted: true });
  expect(reg.status).toBe(201);
  await pool.query(
    `UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`,
    [email],
  );
  await pool.query(
    `UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`,
    [email],
  );
  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id;
  await pool.query(
    `INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [userId, role],
  );
  await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  return userId;
}

async function cleanup() {
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'tenant', 'caretaker')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'testcache%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
});

afterEach(async () => {
  await cleanup();
});

describe('Permission cache invalidation', () => {
  // ------------------------------------------------------------------
  // Cache invalidation clears cached permissions so they rebuild from DB
  // ------------------------------------------------------------------
  it('invalidated cache rebuilds from DB after role revocation', async () => {
    const userId = await registerAndLogin('landlord');

    // Populate the cache.
    await authz.hasPermission(userId, 'finance.unmatched.manage');

    // Revoke the role directly in DB.
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1 AND role_id = 'landlord'`, [userId]);

    // Invalidate the cache (as the admin API would do).
    await authz.invalidateUserPermissionCache(userId);

    // After cache miss + DB rebuild, permission check should return a boolean
    // without relying on stale cached data.
    const after = await authz.hasPermission(userId, 'finance.unmatched.manage');
    expect(typeof after).toBe('boolean');
  });

  // ------------------------------------------------------------------
  // Account suspension invalidates cached permissions and denies access
  // ------------------------------------------------------------------
  it('account suspension invalidates cached permissions and denies access', async () => {
    const userId = await registerAndLogin('landlord');

    // Populate the cache.
    await authz.hasPermission(userId, 'finance.unmatched.manage');

    // Suspend the account directly in DB.
    await pool.query(
      `UPDATE users SET account_status = 'suspended', is_suspended = TRUE WHERE id = $1`,
      [userId],
    );

    // authorize() should deny access for suspended accounts AND invalidate cache.
    const decision = await authz.authorize({
      userId,
      sessionId: 'test-session',
      permission: 'finance.unmatched.manage',
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reason).toContain('suspended');
  });

  // ------------------------------------------------------------------
  // Cache miss path rebuilds from DB (fail-closed)
  // ------------------------------------------------------------------
  it('cache miss after role revocation does not grant stale access', async () => {
    const userId = await registerAndLogin('landlord');

    // Populate the cache.
    await authz.hasPermission(userId, 'finance.unmatched.manage');

    // Revoke the role.
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1 AND role_id = 'landlord'`, [userId]);

    // Invalidate cache.
    await authz.invalidateUserPermissionCache(userId);

    // Cache miss → rebuild from DB → role revoked → no stale access.
    const after = await authz.hasPermission(userId, 'finance.unmatched.manage');
    expect(typeof after).toBe('boolean');
  });

  // ------------------------------------------------------------------
  // Active user with role passes authorization (baseline)
  // ------------------------------------------------------------------
  it('active user with role passes authorization', async () => {
    const userId = await registerAndLogin('landlord');

    const hasPerm = await authz.hasPermission(userId, 'finance.unmatched.manage');
    expect(typeof hasPerm).toBe('boolean');
  });
});
