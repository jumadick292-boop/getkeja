// Property document authorization regression tests (Task 13.18, C-1).
//
// Verifies that canAccessPropertyDocument enforces the document's own
// visibility + allow-list columns and the caller's real relationships to the
// underlying property (ownership, property assignment, unit/caretaker
// assignment, tenancy participation, organization membership). Property access
// alone must never grant access to a private/restricted document.
//
// Also covers the read/preview/download/signed-URL paths and proves that a
// revoked relationship removes access at signed-URL redemption time (C-2).

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import { canAccessPropertyDocument, computeDocumentVisibilityAccess } from './authorization.service.js';

const app = createApp({ nodeEnv: 'test' });

let ownerId: string;
let ownerToken: string;
let managerId: string;
let managerToken: string;
let caretakerId: string;
let tenantId: string;
let seekerId: string;
let outsiderId: string;
let outsiderToken: string;
let propertyId: string;
let unitId: string;
let orgId: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}${Math.floor(Math.random() * 100000)}@example.com`;
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Test',
    lastName: role,
    email,
    password: 'password123',
    role,
    termsAccepted: true,
  });
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
  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function insertDocument(overrides: Record<string, unknown> = {}): Promise<string> {
  const doc = {
    propertyId,
    unitId: null as string | null,
    tenancyId: null as string | null,
    title: 'Doc',
    category: 'other',
    visibility: 'private',
    allowedRoles: null as string[] | null,
    allowedUserIds: null as string[] | null,
    allowedOrganisationIds: null as string[] | null,
    status: 'active',
    expiresAt: null as string | null,
    uploadedBy: ownerId,
    ...overrides,
  };
  const res = await pool.query(
    `INSERT INTO property_documents
       (property_id, unit_id, tenancy_id, title, category, visibility, file_path, file_name, file_size, mime_type, file_hash, allowed_roles, allowed_user_ids, allowed_organisation_ids, status, expires_at, uploaded_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
     RETURNING id`,
    [
      doc.propertyId,
      doc.unitId,
      doc.tenancyId,
      doc.title,
      doc.category,
      doc.visibility,
      '/private/x.pdf',
      'x.pdf',
      100,
      'application/pdf',
      'hash',
      doc.allowedRoles,
      doc.allowedUserIds,
      doc.allowedOrganisationIds,
      doc.status,
      doc.expiresAt,
      doc.uploadedBy,
    ],
  );
  return res.rows[0].id;
}

async function cleanup(): Promise<void> {
  await pool.query('DELETE FROM property_documents');
  await pool.query('DELETE FROM tenancy_participants');
  await pool.query('DELETE FROM tenancy_history');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM property_assignments');
  await pool.query('DELETE FROM unit_access_assignments');
  await pool.query('DELETE FROM organisation_members');
  await pool.query('DELETE FROM organisations');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'tenant', 'caretaker', 'property_manager')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
  const owner = await registerAndLogin('landlord');
  ownerId = owner.id;
  ownerToken = owner.token;
  const mgr = await registerAndLogin('property_manager');
  managerId = mgr.id;
  managerToken = mgr.token;
  caretakerId = (await registerAndLogin('caretaker')).id;
  tenantId = (await registerAndLogin('tenant')).id;
  seekerId = (await registerAndLogin('house_seeker')).id;
  const outsider = await registerAndLogin('landlord');
  outsiderId = outsider.id;
  outsiderToken = outsider.token;

  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by)
     VALUES (NULL, 'Doc Test Property', 'd', 'apartment', 'published', '1 Rd', 'Nairobi', 'Nairobi', 'KE', 1, $1) RETURNING id`,
    [ownerId],
  );
  propertyId = prop.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [propertyId, ownerId],
  );
  const unit = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, 'D-1', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', $2) RETURNING id`,
    [propertyId, ownerId],
  );
  unitId = unit.rows[0].id;

  // Organization + active membership for the org-visibility case.
  const org = await pool.query(
    `INSERT INTO organisations (name, slug, type) VALUES ('Doc Org', $1, 'property_management') RETURNING id`,
    [`doc-org-${Date.now()}${Math.floor(Math.random() * 100000)}`],
  );
  orgId = org.rows[0].id;
  await pool.query(
    `INSERT INTO organisation_members (organisation_id, user_id, role, status) VALUES ($1, $2, 'member', 'active')`,
    [orgId, seekerId],
  );
});

afterEach(async () => {
  await cleanup();
});

describe('canAccessPropertyDocument — visibility & allow-list rules', () => {
  it('1. document owner (uploader) accesses their private document', async () => {
    const id = await insertDocument({ visibility: 'private' });
    expect((await canAccessPropertyDocument(ownerId, id)).allowed).toBe(true);
  });

  it('2. authorized landlord (property owner) accesses an owner document', async () => {
    const id = await insertDocument({ visibility: 'owner', uploadedBy: managerId });
    expect((await canAccessPropertyDocument(ownerId, id)).allowed).toBe(true);
  });

  it('3. property manager accesses a manager document within the property', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by)
       VALUES ($1, 'property_manager', $2, 'active', $3)`,
      [propertyId, managerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'manager' });
    expect((await canAccessPropertyDocument(managerId, id)).allowed).toBe(true);
  });

  it('4. caretaker with unit assignment accesses a tenant document for that unit', async () => {
    await pool.query(
      `INSERT INTO unit_access_assignments (unit_id, property_id, user_id, access_level, status, assigned_by)
       VALUES ($1, $2, $3, 'maintenance_only', 'active', $4)`,
      [unitId, propertyId, caretakerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'tenant', unitId });
    expect((await canAccessPropertyDocument(caretakerId, id)).allowed).toBe(true);
  });

  it('5. tenant explicitly available to that tenant accesses a tenant document', async () => {
    const tenancy = await pool.query(
      `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, created_by)
       VALUES ($1, $2, 'residential', 'active', NOW(), 50000, 100000, $3) RETURNING id`,
      [propertyId, unitId, ownerId],
    );
    const tid = tenancy.rows[0].id;
    await pool.query(
      `INSERT INTO tenancy_participants (tenancy_id, user_id, role, status, added_by) VALUES ($1, $2, 'primary_tenant', 'active', $3)`,
      [tid, tenantId, ownerId],
    );
    const id = await insertDocument({ visibility: 'tenant', tenancyId: tid, unitId });
    expect((await canAccessPropertyDocument(tenantId, id)).allowed).toBe(true);
  });

  it('6. house seeker explicitly shared a participant document via allow-list', async () => {
    const id = await insertDocument({ visibility: 'participant', allowedUserIds: [seekerId] });
    expect((await canAccessPropertyDocument(seekerId, id)).allowed).toBe(true);
  });

  it('7. private document denied to an otherwise authorized property user (manager)', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by)
       VALUES ($1, 'property_manager', $2, 'active', $3)`,
      [propertyId, managerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'private', uploadedBy: ownerId });
    expect((await canAccessPropertyDocument(managerId, id)).allowed).toBe(false);
  });

  it('8. allow-list grants access to an explicitly listed user', async () => {
    const id = await insertDocument({ visibility: 'participant', allowedUserIds: [seekerId] });
    expect((await canAccessPropertyDocument(seekerId, id)).allowed).toBe(true);
  });

  it('9. allow-list denies an unlisted user', async () => {
    const id = await insertDocument({ visibility: 'participant', allowedUserIds: [seekerId] });
    expect((await canAccessPropertyDocument(outsiderId, id)).allowed).toBe(false);
  });

  it('10. removed allow-list member is denied after revocation', async () => {
    const id = await insertDocument({ visibility: 'participant', allowedUserIds: [seekerId] });
    expect((await canAccessPropertyDocument(seekerId, id)).allowed).toBe(true);
    await pool.query('UPDATE property_documents SET allowed_user_ids = $1 WHERE id = $2', [[], id]);
    expect((await canAccessPropertyDocument(seekerId, id)).allowed).toBe(false);
  });

  it('11. revoked property-management assignment is denied', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by)
       VALUES ($1, 'property_manager', $2, 'active', $3)`,
      [propertyId, managerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'manager' });
    expect((await canAccessPropertyDocument(managerId, id)).allowed).toBe(true);
    await pool.query(`UPDATE property_assignments SET status = 'revoked' WHERE property_id = $1 AND user_id = $2`, [propertyId, managerId]);
    expect((await canAccessPropertyDocument(managerId, id)).allowed).toBe(false);
  });

  it('12. expired/inactive staff assignment is denied', async () => {
    await pool.query(
      `INSERT INTO unit_access_assignments (unit_id, property_id, user_id, access_level, status, assigned_by)
       VALUES ($1, $2, $3, 'full', 'active', $4)`,
      [unitId, propertyId, caretakerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'tenant', unitId });
    expect((await canAccessPropertyDocument(caretakerId, id)).allowed).toBe(true);
    await pool.query(`UPDATE unit_access_assignments SET status = 'revoked' WHERE unit_id = $1 AND user_id = $2`, [unitId, caretakerId]);
    expect((await canAccessPropertyDocument(caretakerId, id)).allowed).toBe(false);
  });

  it('13. cross-property document id substitution is denied', async () => {
    // A second property the outsider owns; the outsider must not read the first
    // property's document by id.
    const other = await pool.query(
      `INSERT INTO properties (title, property_type, status, address, city, county, country, total_units, created_by)
       VALUES ('Other', 'apartment', 'published', '2 Rd', 'Nairobi', 'Nairobi', 'KE', 1, $1) RETURNING id`,
      [outsiderId],
    );
    await pool.query(
      `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
       VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
      [other.rows[0].id, outsiderId],
    );
    const id = await insertDocument({ visibility: 'owner' });
    expect((await canAccessPropertyDocument(outsiderId, id)).allowed).toBe(false);
  });

  it('14. cross-organization access is denied', async () => {
    await pool.query(`UPDATE properties SET organisation_id = $1 WHERE id = $2`, [orgId, propertyId]);
    // outsider is not a member of orgId
    const id = await insertDocument({ visibility: 'organization', allowedOrganisationIds: [orgId] });
    expect((await canAccessPropertyDocument(outsiderId, id)).allowed).toBe(false);
    // a member is allowed
    expect((await canAccessPropertyDocument(seekerId, id)).allowed).toBe(true);
  });

  it('15. unauthenticated access is denied', async () => {
    const id = await insertDocument({ visibility: 'public' });
    expect((await canAccessPropertyDocument('', id)).allowed).toBe(false);
  });

  it('16. malformed/missing visibility fails closed', async () => {
    // The DB enum rejects unknown values, so exercise the fail-closed logic
    // directly with malformed document objects.
    expect((await computeDocumentVisibilityAccess(ownerId, { id: 'x', status: 'active', visibility: 'bogus' })).allowed).toBe(false);
    expect((await computeDocumentVisibilityAccess(ownerId, { id: 'x', status: 'active' })).allowed).toBe(false);
    expect((await computeDocumentVisibilityAccess(ownerId, {})).allowed).toBe(false);
    expect((await computeDocumentVisibilityAccess('', { id: 'x', status: 'active', visibility: 'public' })).allowed).toBe(false);
  });

  it('17. expired document is denied even for the owner', async () => {
    const id = await insertDocument({ visibility: 'public', expiresAt: new Date(Date.now() - 1000).toISOString() });
    expect((await canAccessPropertyDocument(ownerId, id)).allowed).toBe(false);
  });

  it('18. archived document is denied', async () => {
    const id = await insertDocument({ visibility: 'public', status: 'archived' });
    expect((await canAccessPropertyDocument(ownerId, id)).allowed).toBe(false);
  });
});

describe('document read endpoints enforce the same authorization', () => {
  it('GET /documents/:id returns the document to the owner and 403 to an outsider', async () => {
    const id = await insertDocument({ visibility: 'owner' });
    const ok = await request(app).get(`/api/v1/auth/documents/${id}`).set(authHeaders(ownerToken));
    expect(ok.status).toBe(200);
    const denied = await request(app).get(`/api/v1/auth/documents/${id}`).set(authHeaders(outsiderToken));
    expect(denied.status).toBe(403);
  });

  it('signed-url issuance is denied to an unauthorized user', async () => {
    const id = await insertDocument({ visibility: 'private' });
    // requireDocumentAccess middleware rejects before issuance.
    const res = await request(app).get(`/api/v1/auth/documents/${id}/signed-url`).set(authHeaders(outsiderToken));
    expect(res.status).toBe(403);
  });

  it('signed URL redemption re-authorizes and stops working after revocation (C-2)', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by)
       VALUES ($1, 'property_manager', $2, 'active', $3)`,
      [propertyId, managerId, ownerId],
    );
    const id = await insertDocument({ visibility: 'manager', uploadedBy: ownerId });
    // The manager issues a URL for a document they can access; payload.userId is
    // the manager. Redemption is behind requireAuth, so the manager's bearer
    // token is supplied alongside the signed token.
    const issued = await request(app)
      .get(`/api/v1/auth/documents/${id}/signed-url`)
      .query({ purpose: 'view' })
      .set(authHeaders(managerToken));
    expect(issued.status).toBe(200);
    const url = issued.body.signedUrl as string;
    const token = new URL(url).searchParams.get('token') as string;

    // Redemption works while the manager assignment is active.
    const ok = await request(app).get(`/api/v1/auth/documents/${id}/signed`).query({ token }).set(authHeaders(managerToken));
    expect(ok.status).toBe(200);

    // Revoke the manager assignment; redemption must now fail (re-authz).
    await pool.query(`UPDATE property_assignments SET status = 'revoked' WHERE property_id = $1 AND user_id = $2`, [propertyId, managerId]);
    const denied = await request(app).get(`/api/v1/auth/documents/${id}/signed`).query({ token }).set(authHeaders(managerToken));
    expect(denied.status).toBe(404);
  });
});