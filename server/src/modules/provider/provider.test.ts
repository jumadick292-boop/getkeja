import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function registerUser(role = 'tenant'): Promise<{ id: string; token: string }> {
  const email = `prov${Date.now()}${Math.floor(Math.random() * 1e6)}@example.com`;
  const phone = `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`;
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Prov',
    lastName: 'User',
    email,
    password: 'password123',
    role,
    termsAccepted: true,
  });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
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
  const token = login.headers['x-access-token'] as string;
  return { id: userId, token };
}

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createPropertyWithUnit(userId: string): Promise<{ propertyId: string; unitId: string }> {
  const p = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by)
     VALUES (NULL, 'Prov Property', 'desc', 'apartment', 'published', 'Addr', 'Nairobi', 'Nairobi', 'KE', 1, $1)
     RETURNING id`,
    [userId],
  );
  const propertyId = p.rows[0].id;
  const u = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, 'P-1', 'one_bedroom', 1, 1, 50000, 100000, 'occupied', $2) RETURNING id`,
    [propertyId, userId],
  );
  return { propertyId, unitId: u.rows[0].id };
}

async function createTenancy(
  propertyId: string,
  unitId: string,
  tenantUserId: string,
): Promise<string> {
  const t = await pool.query(
    `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
     VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4) RETURNING id`,
    [propertyId, unitId, new Date(Date.now() + 86400000).toISOString(), tenantUserId],
  );
  const tenancyId = t.rows[0].id;
  await pool.query(
    `INSERT INTO tenants (property_id, unit_id, tenancy_id, user_id, full_name, phone, status, created_by)
     VALUES ($1, $2, $3, $4, 'Prov Tenant', '+254700000000', 'active', $4)`,
    [propertyId, unitId, tenancyId, tenantUserId],
  );
  await pool.query(
    `INSERT INTO tenancy_participants (tenancy_id, user_id, role, is_primary, status, added_by)
     VALUES ($1, $2, 'primary_tenant', TRUE, 'active', $2)`,
    [tenancyId, tenantUserId],
  );
  return tenancyId;
}

async function createProviderProfile(
  userId: string,
  category: string,
  opts: { orgId?: string; status?: string } = {},
): Promise<string> {
  const p = await pool.query(
    `INSERT INTO specialized_profiles (user_id, profile_category, organisation_id, business_name, verification_status)
     VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [userId, category, opts.orgId ?? null, `Biz ${category}`, opts.status ?? 'approved'],
  );
  return p.rows[0].id;
}

async function createServiceArea(profileId: string, county = 'Nairobi', city = 'Nairobi'): Promise<void> {
  await pool.query(
    `INSERT INTO provider_service_areas (specialized_profile_id, country, county, city, latitude, longitude, radius_km, is_active)
     VALUES ($1, 'KE', $2, $3, -1.2921, 36.8219, 25, TRUE)`,
    [profileId, county, city],
  );
}

async function createOrg(userId: string): Promise<string> {
  const o = await pool.query(
    `INSERT INTO organisations (name, slug, type, verification_status)
     VALUES ('Prov Org', $1, 'moving_company', 'verified') RETURNING id`,
    [`prov-org-${Date.now()}-${Math.floor(Math.random() * 1e6)}`],
  );
  return o.rows[0].id;
}

async function addOrgMember(orgId: string, userId: string, role = 'member', status = 'active'): Promise<void> {
  await pool.query(
    `INSERT INTO organisation_members (organisation_id, user_id, role, status, joined_at)
     VALUES ($1, $2, $3, $4, NOW())`,
    [orgId, userId, role, status],
  );
}

async function createGarbageProvider(userId: string, orgId: string | null = null): Promise<string> {
  const g = await pool.query(
    `INSERT INTO garbage_providers (organisation_id, name, contact_person, contact_phone, contact_email, service_areas, status, created_by)
     VALUES ($1, 'Garbage Biz', 'Person', '+254700000000', 'g@test.com', '[]', 'active', $2) RETURNING id`,
    [orgId, userId],
  );
  return g.rows[0].id;
}

async function assignGarbage(propertyId: string, unitId: string, providerId: string, userId: string): Promise<void> {
  await pool.query(
    `INSERT INTO garbage_provider_assignments (property_id, unit_id, garbage_provider_id, assignment_type, frequency, status, assigned_by, effective_from)
     VALUES ($1, $2, $3, 'scheduled', 'weekly', 'active', $4, CURRENT_DATE)`,
    [propertyId, unitId, providerId, userId],
  );
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('Provider domain foundation', () => {
  let landlordId: string;
  let tenantA: { id: string; token: string };
  let tenantB: { id: string; token: string };
  let moverProvider: { id: string; token: string };
  let moverProfileId: string;
  let mover2Provider: { id: string; token: string };
  let mover2ProfileId: string;
  let laundryProvider: { id: string; token: string };
  let laundryProfileId: string;
  let unverifiedProvider: { id: string; token: string };
  let orgProviderUser: { id: string; token: string };
  let orgId: string;
  let orgProfileId: string;
  let garbageProviderUser: { id: string; token: string };
  let garbageProviderId: string;
  let propertyA: { propertyId: string; unitId: string };
  let propertyB: { propertyId: string; unitId: string };

  beforeAll(async () => {
    landlordId = (await registerUser('landlord')).id;
    tenantA = await registerUser('tenant');
    tenantB = await registerUser('tenant');

    propertyA = await createPropertyWithUnit(landlordId);
    await createTenancy(propertyA.propertyId, propertyA.unitId, tenantA.id);
    propertyB = await createPropertyWithUnit(landlordId);
    await createTenancy(propertyB.propertyId, propertyB.unitId, tenantB.id);

    // Individual mover (approved + Nairobi service area)
    moverProvider = await registerUser('individual_mover');
    moverProfileId = await createProviderProfile(moverProvider.id, 'moving_service_provider');
    await createServiceArea(moverProfileId);

    // Second mover (for cross-provider IDOR)
    mover2Provider = await registerUser('individual_mover');
    mover2ProfileId = await createProviderProfile(mover2Provider.id, 'moving_service_provider');
    await createServiceArea(mover2ProfileId);

    // Laundry provider (approved)
    laundryProvider = await registerUser('laundry_provider');
    laundryProfileId = await createProviderProfile(laundryProvider.id, 'laundry_service_provider');
    await createServiceArea(laundryProfileId);

    // Unverified mover (draft) — must be denied provider access
    unverifiedProvider = await registerUser('individual_mover');
    await createProviderProfile(unverifiedProvider.id, 'moving_service_provider', { status: 'draft' });

    // Organization provider context
    orgId = await createOrg(landlordId);
    orgProviderUser = await registerUser('moving_company');
    // Org profile is owned by the org (landlord as owner); the member reaches
    // it only through active organization membership.
    orgProfileId = await createProviderProfile(landlordId, 'moving_service_provider', { orgId });
    await createServiceArea(orgProfileId);
    await addOrgMember(orgId, orgProviderUser.id, 'member', 'active');

    // Garbage provider (owned by user)
    garbageProviderUser = await registerUser('garbage_provider');
    garbageProviderId = await createGarbageProvider(garbageProviderUser.id);
    await assignGarbage(propertyA.propertyId, propertyA.unitId, garbageProviderId, landlordId);
  });

  afterAll(async () => {
    await pool.query('DELETE FROM provider_service_areas');
    await pool.query('DELETE FROM moving_status_history');
    await pool.query('DELETE FROM laundry_status_history');
    await pool.query('DELETE FROM notification_outbox');
    await pool.query('DELETE FROM moving_requests');
    await pool.query('DELETE FROM laundry_requests');
    await pool.query('DELETE FROM garbage_collection_requests');
    await pool.query('DELETE FROM garbage_provider_assignments');
    await pool.query('DELETE FROM garbage_providers');
    await pool.query('DELETE FROM organisation_members');
    await pool.query('DELETE FROM organisations');
    await pool.query('DELETE FROM specialized_profiles');
    await pool.query('DELETE FROM tenancy_participants');
    await pool.query('DELETE FROM tenants');
    await pool.query('DELETE FROM tenancies');
    await pool.query('DELETE FROM units');
    await pool.query('DELETE FROM properties');
  });

  // ---- Tenant request lists ------------------------------------------------
  describe('tenant request lists', () => {
    it('lists moving requests for the owning tenant with pagination', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: '123 Destination Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Sofa and fridge',
        });
      expect(created.status).toBe(201);

      const list = await request(app).get('/api/v1/tenant/moving-requests').set(auth(tenantA.token));
      expect(list.status).toBe(200);
      expect(list.body.data.length).toBeGreaterThanOrEqual(1);
      expect(list.body.pagination.total).toBeGreaterThanOrEqual(1);
    });

    it('enforces cross-tenant isolation for moving lists', async () => {
      const list = await request(app).get('/api/v1/tenant/moving-requests').set(auth(tenantB.token));
      expect(list.status).toBe(200);
      expect(list.body.data.length).toBe(0);
    });

    it('filters moving list by status', async () => {
      const list = await request(app)
        .get('/api/v1/tenant/moving-requests?status=submitted')
        .set(auth(tenantA.token));
      expect(list.status).toBe(200);
      for (const row of list.body.data) expect(row.status).toBe('submitted');
    });

    it('lists laundry requests for the owning tenant', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(auth(tenantA.token))
        .send({
          providerId: laundryProfileId,
          serviceCategory: 'wash_fold',
          collectionPreference: 'doorstep',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 5,
        });
      expect(created.status).toBe(201);
      const list = await request(app).get('/api/v1/tenant/laundry-requests').set(auth(tenantA.token));
      expect(list.status).toBe(200);
      expect(list.body.data.length).toBeGreaterThanOrEqual(1);
    });

    it('lists garbage requests (regression) for the owning tenant', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(auth(tenantA.token))
        .send({ unitId: propertyA.unitId, category: 'regular_collection', description: 'Full bin' });
      expect(created.status).toBe(201);
      const list = await request(app).get('/api/v1/tenant/garbage-requests').set(auth(tenantA.token));
      expect(list.status).toBe(200);
      expect(list.body.data.length).toBeGreaterThanOrEqual(1);
      expect(list.body.data[0]).toHaveProperty('requestType');
    });

    it('returns empty results for a tenant with no requests', async () => {
      const list = await request(app).get('/api/v1/tenant/laundry-requests').set(auth(tenantB.token));
      expect(list.status).toBe(200);
      expect(list.body.data.length).toBe(0);
    });
  });

  // ---- Provider request access --------------------------------------------
  describe('provider request access', () => {
    it('lets an eligible individual provider see a discoverable moving request', async () => {
      // Unassigned submitted request in the mover's service area.
      await request(app).post('/api/v1/tenant/moving-requests').set(auth(tenantA.token)).send({
        pickupUnitId: propertyA.unitId,
        destinationAddress: '456 Discoverable Ave',
        preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
        itemDescription: 'Discoverable load',
      });
      const inbox = await request(app)
        .get('/api/v1/provider/requests?serviceType=moving')
        .set(auth(moverProvider.token));
      expect(inbox.status).toBe(200);
      const discoverable = inbox.body.data.find((r: any) => r.assigned === false);
      expect(discoverable).toBeDefined();
    });

    it('denies an unverified provider', async () => {
      const inbox = await request(app).get('/api/v1/provider/requests').set(auth(unverifiedProvider.token));
      expect(inbox.status).toBe(403);
    });

    it('denies a provider without any provider profile (caretaker-style)', async () => {
      const inbox = await request(app).get('/api/v1/provider/requests').set(auth(tenantA.token));
      expect(inbox.status).toBe(403);
    });

    it('does not show laundry requests to a moving provider (category isolation)', async () => {
      const inbox = await request(app)
        .get('/api/v1/provider/requests?serviceType=laundry')
        .set(auth(moverProvider.token));
      expect(inbox.status).toBe(200);
      // Mover has no laundry profile and no laundry assignment.
      expect(inbox.body.data.length).toBe(0);
    });

    it('shows an assigned request to the assigned provider with full detail', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: '789 Assigned Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Assigned load',
          providerId: moverProfileId,
          contactName: 'Secret Customer',
          contactPhone: '+254711222333',
        });
      expect(created.status).toBe(201);
      const detail = await request(app)
        .get(`/api/v1/provider/requests/${created.body.data.id}`)
        .set(auth(moverProvider.token));
      expect(detail.status).toBe(200);
      expect(detail.body.data.assigned).toBe(true);
      expect(detail.body.data.contactPhone).toBe('+254711222333');
    });

    it('masks contact + coordinates on a discoverable request detail', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: 'Masked Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Masked load',
          contactPhone: '+254799888777',
        });
      const detail = await request(app)
        .get(`/api/v1/provider/requests/${created.body.data.id}`)
        .set(auth(moverProvider.token));
      expect(detail.status).toBe(200);
      expect(detail.body.data.assigned).toBe(false);
      expect(detail.body.data.contactPhone).toBeNull();
      expect(detail.body.data.pickupLatitude).toBeNull();
    });

    it('blocks cross-provider IDOR on request detail', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: 'Private Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Private load',
          providerId: mover2ProfileId, // assigned to the OTHER mover
        });
      // Mover must not access a request assigned to another provider.
      const detail = await request(app)
        .get(`/api/v1/provider/requests/${created.body.data.id}`)
        .set(auth(moverProvider.token));
      expect(detail.status).toBe(403);
    });

    it('supports an authorized organization provider context', async () => {
      const inbox = await request(app).get('/api/v1/provider/requests').set(auth(orgProviderUser.token));
      expect(inbox.status).toBe(200);
    });

    it('denies provider access after organization membership is revoked', async () => {
      await pool.query(
        `UPDATE organisation_members SET status = 'removed' WHERE organisation_id = $1 AND user_id = $2`,
        [orgId, orgProviderUser.id],
      );
      const inbox = await request(app).get('/api/v1/provider/requests').set(auth(orgProviderUser.token));
      expect(inbox.status).toBe(403);
      // restore for later tests
      await pool.query(
        `UPDATE organisation_members SET status = 'active' WHERE organisation_id = $1 AND user_id = $2`,
        [orgId, orgProviderUser.id],
      );
    });

    it('shows garbage requests to the owning garbage provider', async () => {
      const inbox = await request(app)
        .get('/api/v1/provider/requests?serviceType=garbage')
        .set(auth(garbageProviderUser.token));
      expect(inbox.status).toBe(200);
      expect(inbox.body.data.length).toBeGreaterThanOrEqual(1);
      expect(inbox.body.data.every((r: any) => r.serviceType === 'garbage')).toBe(true);
    });
  });

  // ---- Provider response + lifecycle --------------------------------------
  describe('provider response and lifecycle', () => {
    it('accepts an assigned request and records an outbox event', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: 'Lifecycle Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Lifecycle load',
          providerId: moverProfileId,
        });
      const requestId = created.body.data.id;
      const respond = await request(app)
        .post(`/api/v1/provider/requests/${requestId}/respond`)
        .set(auth(moverProvider.token))
        .send({ action: 'accept' });
      expect(respond.status).toBe(200);
      expect(respond.body.data.status).toBe('accepted');

      const outbox = await pool.query(
        `SELECT recipient_user_ids, event_type FROM notification_outbox WHERE idempotency_key = $1`,
        [`service_request.accepted:${requestId}`],
      );
      expect(outbox.rows.length).toBe(1);
      expect(outbox.rows[0].recipient_user_ids).toContain(tenantA.id);

      const history = await pool.query(
        `SELECT new_status FROM moving_status_history WHERE moving_request_id = $1 ORDER BY created_at DESC`,
        [requestId],
      );
      expect(history.rows[0].new_status).toBe('accepted');
    });

    it('rejects an invalid transition with 409', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: 'Twice Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Twice load',
          providerId: moverProfileId,
        });
      const requestId = created.body.data.id;
      const first = await request(app)
        .post(`/api/v1/provider/requests/${requestId}/respond`)
        .set(auth(moverProvider.token))
        .send({ action: 'accept' });
      expect(first.status).toBe(200);
      const second = await request(app)
        .post(`/api/v1/provider/requests/${requestId}/respond`)
        .set(auth(moverProvider.token))
        .send({ action: 'accept' });
      expect(second.status).toBe(409);
    });

    it('denies a provider responding to another provider\'s request', async () => {
      const created = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(auth(tenantA.token))
        .send({
          pickupUnitId: propertyA.unitId,
          destinationAddress: 'Forbidden Rd',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Forbidden load',
          providerId: moverProfileId,
        });
      const respond = await request(app)
        .post(`/api/v1/provider/requests/${created.body.data.id}/respond`)
        .set(auth(laundryProvider.token))
        .send({ action: 'accept' });
      expect(respond.status).toBe(403);
    });

    it('declines a garbage request (pending -> cancelled) atomically', async () => {
      const respond = await request(app)
        .post(`/api/v1/provider/requests/${(await lastGarbageRequestId())}/respond`)
        .set(auth(garbageProviderUser.token))
        .send({ action: 'decline', reason: 'Cannot reach area' });
      expect(respond.status).toBe(200);
      expect(respond.body.data.status).toBe('cancelled');
    });
  });

  // ---- Discovery -----------------------------------------------------------
  describe('provider discovery', () => {
    it('returns approved providers within radius (coords)', async () => {
      const res = await request(app)
        .get('/api/v1/provider/discovery?latitude=-1.2921&longitude=36.8219&category=moving_service_provider')
        .set(auth(tenantA.token));
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      // No raw coordinates or contact fields exposed.
      expect(res.body.data[0]).not.toHaveProperty('latitude');
      expect(res.body.data[0]).not.toHaveProperty('contactPhone');
    });

    it('supports text (county) fallback discovery', async () => {
      const res = await request(app)
        .get('/api/v1/provider/discovery?county=Nairobi&category=laundry_service_provider')
        .set(auth(tenantA.token));
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    });

    it('rejects invalid coordinate input', async () => {
      const res = await request(app)
        .get('/api/v1/provider/discovery?latitude=-1.2921')
        .set(auth(tenantA.token));
      expect(res.status).toBe(400);
    });
  });

  // ---- Dashboard -----------------------------------------------------------
  // NOTE: /api/v1/provider/dashboard is served by the Task 13.16 unified
  // provider-dashboard router (mounted before the legacy provider router). The
  // response is the context-scoped unified shape { scope, overview, byDomain }.
  describe('provider dashboard', () => {
    it('returns provider-scoped counts for an individual provider', async () => {
      const res = await request(app).get('/api/v1/provider/dashboard').set(auth(moverProvider.token));
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('scope');
      expect(res.body.data).toHaveProperty('metrics');
      expect(res.body.data).toHaveProperty('byDomain');
    });

    it('returns organization-scoped counts', async () => {
      const res = await request(app)
        .get(`/api/v1/provider/dashboard?organizationId=${orgId}`)
        .set(auth(orgProviderUser.token));
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('scope');
      expect(res.body.data).toHaveProperty('metrics');
    });

    it('denies dashboard to a non-provider', async () => {
      const res = await request(app).get('/api/v1/provider/dashboard').set(auth(tenantA.token));
      expect(res.status).toBe(403);
    });
  });
});

async function lastGarbageRequestId(): Promise<string> {
  const r = await pool.query(
    `SELECT id FROM garbage_collection_requests ORDER BY created_at DESC LIMIT 1`,
  );
  return r.rows[0].id;
}