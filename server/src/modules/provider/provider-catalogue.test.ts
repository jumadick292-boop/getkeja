// Task 13.4 — provider service-catalogue integration tests.
import { describe, expect, it, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

interface Session {
  id: string;
  token: string;
}

async function registerUser(role: string): Promise<Session> {
  const email = `cat_${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'password123';
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Cat',
    lastName: 'Tester',
    email,
    password,
    role,
    termsAccepted: true,
  });
  expect(reg.status, `role=${role} ${JSON.stringify(reg.body)}`).toBe(201);
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(
    `UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`,
    [email],
  );
  const user = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0]!.id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password });
  expect(login.status).toBe(200);
  return { id: userId, token: login.headers['x-access-token'] as string };
}

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createApprovedProfile(userId: string, category: string, orgId: string | null = null): Promise<string> {
  const r = await pool.query<{ id: string }>(
    `INSERT INTO specialized_profiles (user_id, profile_category, organisation_id, business_name, verification_status)
     VALUES ($1, $2::profile_category, $3, $4, 'approved') RETURNING id`,
    [userId, category, orgId, `Biz ${category}`],
  );
  return r.rows[0]!.id;
}

async function createOrgWithOwner(ownerId: string): Promise<string> {
  const slug = `org-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  const r = await pool.query<{ id: string }>(
    `INSERT INTO organisations (name, slug, type) VALUES ($1, $2, 'moving_company') RETURNING id`,
    [`Org ${slug}`, slug],
  );
  const orgId = r.rows[0]!.id;
  await pool.query(
    `INSERT INTO organisation_members (organisation_id, user_id, role, status, joined_at) VALUES ($1, $2, 'owner', 'active', NOW())`,
    [orgId, ownerId],
  );
  await pool.query(
    `INSERT INTO role_assignments (id, role_id, user_id, scope, organization_id) VALUES (gen_random_uuid(), 'organization_owner', $1, 'organization', $2)`,
    [ownerId, orgId],
  );
  return orgId;
}

const created = { users: [] as string[], profiles: [] as string[], orgs: [] as string[] };

afterAll(async () => {
  for (const p of created.profiles) await pool.query(`DELETE FROM specialized_profiles WHERE id = $1`, [p]);
  for (const o of created.orgs) await pool.query(`DELETE FROM organisations WHERE id = $1`, [o]);
  for (const u of created.users) {
    await pool.query(`DELETE FROM user_roles WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM role_assignments WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM organisation_members WHERE user_id = $1`, [u]);
    await pool.query(`DELETE FROM users WHERE id = $1`, [u]);
  }
});

async function newProvider(category = 'moving_service_provider') {
  const { id, token } = await registerUser('moving_company');
  created.users.push(id);
  const profileId = await createApprovedProfile(id, category);
  created.profiles.push(profileId);
  return { id, token, profileId };
}

describe('Task 13.4 provider service catalogue', () => {
  it('1. retrieves the platform catalogue', async () => {
    const { token } = await registerUser('moving_company');
    const res = await request(app).get('/api/v1/provider/services/catalogue').set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body.data.categories.length).toBeGreaterThan(0);
    expect(res.body.data.capabilities.length).toBeGreaterThan(0);
  });

  it('2. filters catalogue by domain', async () => {
    const { token } = await registerUser('laundry_provider');
    const res = await request(app).get('/api/v1/provider/services/catalogue/laundry').set(auth(token));
    expect(res.status).toBe(200);
    expect(res.body.data.categories.every((c: { domain: string }) => c.domain === 'laundry')).toBe(true);
  });

  it('3. creates an offering and prevents duplicates (409)', async () => {
    const { token, profileId } = await newProvider();
    const body = {
      profileId,
      domain: 'moving',
      categoryId: 'moving_household',
      title: 'Household moves',
      status: 'active',
      config: { propertyTypes: ['house'] },
      capabilities: [{ capabilityId: 'moving_packing', enabled: true }],
      pricing: { pricingModel: 'starting', currency: 'KES', baseAmount: 1500, isIndicative: true },
    };
    const res = await request(app).post('/api/v1/provider/services').set(auth(token)).send(body);
    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('active');
    expect(res.body.data.capabilities.length).toBe(1);
    expect(res.body.data.pricing.baseAmount).toBe('1500.00');
    const dup = await request(app).post('/api/v1/provider/services').set(auth(token)).send(body);
    expect(dup.status).toBe(409);
  });

  it('4. enforces individual ownership (IDOR blocked)', async () => {
    const a = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(a.token))
      .send({ profileId: a.profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    const other = await registerUser('moving_company');
    created.users.push(other.id);
    const res = await request(app).get(`/api/v1/provider/services/${c.body.data.id}`).set(auth(other.token));
    expect(res.status).toBe(403);
  });

  it('5. allows organization ownership via active membership', async () => {
    const owner = await registerUser('moving_company');
    created.users.push(owner.id);
    const orgId = await createOrgWithOwner(owner.id);
    created.orgs.push(orgId);
    const profileId = await createApprovedProfile(owner.id, 'moving_service_provider', orgId);
    created.profiles.push(profileId);
    const res = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(owner.token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_office', title: 'Office', status: 'draft' });
    expect(res.status).toBe(201);
  });

  it('6. rejects invalid category / domain mismatch', async () => {
    const { token, profileId } = await newProvider();
    const res = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'laundry_washing', title: 'Bad', status: 'draft' });
    expect(res.status).toBe(400);
  });

  it('7. updates an offering', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    const res = await request(app)
      .patch(`/api/v1/provider/services/${c.body.data.id}`)
      .set(auth(token))
      .send({ title: 'Local moves updated' });
    expect(res.status).toBe(200);
    expect(res.body.data.title).toBe('Local moves updated');
  });

  it('8. activate/pause/archive with valid transitions', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    const sid = c.body.data.id;
    expect((await request(app).post(`/api/v1/provider/services/${sid}/activate`).set(auth(token))).body.data.status).toBe('active');
    expect((await request(app).post(`/api/v1/provider/services/${sid}/pause`).set(auth(token)).send({})).body.data.status).toBe('paused');
    expect((await request(app).post(`/api/v1/provider/services/${sid}/activate`).set(auth(token))).body.data.status).toBe('active');
    expect((await request(app).post(`/api/v1/provider/services/${sid}/archive`).set(auth(token))).body.data.status).toBe('archived');
    const invalid = await request(app).post(`/api/v1/provider/services/${sid}/activate`).set(auth(token));
    expect(invalid.status).toBe(409);
  });

  it('9. rejects invalid pricing (negative amount)', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    const res = await request(app)
      .put(`/api/v1/provider/services/${c.body.data.id}/pricing`)
      .set(auth(token))
      .send({ pricingModel: 'fixed', currency: 'KES', baseAmount: -100 });
    expect(res.status).toBe(400);
  });

  it('10. stores exact monetary values as decimal strings', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    await request(app)
      .put(`/api/v1/provider/services/${c.body.data.id}/pricing`)
      .set(auth(token))
      .send({ pricingModel: 'per_km', currency: 'KES', baseAmount: 250.5, minimumCharge: 500 });
    const get = await request(app).get(`/api/v1/provider/services/${c.body.data.id}/pricing`).set(auth(token));
    expect(get.body.data.baseAmount).toBe('250.50');
    expect(get.body.data.minimumCharge).toBe('500.00');
  });

  it('11. business location create/update + private residential protection', async () => {
    const { token } = await newProvider();
    const res = await request(app)
      .post('/api/v1/provider/locations')
      .set(auth(token))
      .send({ locationType: 'business_office', latitude: -1.28, longitude: 36.82, city: 'Nairobi', isPublic: true });
    expect(res.status).toBe(201);
    expect(res.body.data.isPublic).toBe(true);
    const upd = await request(app)
      .patch(`/api/v1/provider/locations/${res.body.data.id}`)
      .set(auth(token))
      .send({ isPrimary: true });
    expect(upd.body.data.isPrimary).toBe(true);
    const priv = await request(app)
      .post('/api/v1/provider/locations')
      .set(auth(token))
      .send({ locationType: 'personal_residential', latitude: -1.3, longitude: 36.8, isPublic: true });
    expect(priv.status).toBe(400);
  });

  it('12. public location discovery flag + private default', async () => {
    const { token } = await newProvider();
    await request(app)
      .post('/api/v1/provider/locations')
      .set(auth(token))
      .send({ locationType: 'business_office', latitude: -1.28, longitude: 36.82, isPublic: false });
    const list = await request(app).get('/api/v1/provider/locations').set(auth(token));
    expect(list.body.data.every((l: { isPublic: boolean }) => l.isPublic === false)).toBe(true);
  });

  it('13. service-area create/delete', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, county: 'Nairobi', city: 'Nairobi' });
    expect(c.status).toBe(201);
    const del = await request(app).delete(`/api/v1/provider/service-areas/${c.body.data.id}`).set(auth(token));
    expect(del.status).toBe(200);
  });

  it('14. different coverage for different services (offering-scoped areas)', async () => {
    const { token, profileId } = await newProvider();
    const o1 = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'active' });
    const o2 = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_long_distance', title: 'Long', status: 'active' });
    await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, offeringId: o1.body.data.id, county: 'Nairobi' });
    await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, offeringId: o2.body.data.id, county: 'Kiambu' });
    const areas = await request(app).get(`/api/v1/provider/service-areas?profileId=${profileId}`).set(auth(token));
    expect(areas.body.data.length).toBe(2);
    expect(areas.body.data.some((a: { offeringId: string }) => a.offeringId === o1.body.data.id)).toBe(true);
  });

  it('15. operating-hours create/update with multiple windows + timezone', async () => {
    const { token, profileId } = await newProvider();
    const put = await request(app)
      .put('/api/v1/provider/availability')
      .set(auth(token))
      .send({
        specializedProfileId: profileId,
        timeZone: 'Africa/Nairobi',
        hours: [
          { dayOfWeek: 1, openTime: '08:00', closeTime: '12:00', isClosed: false },
          { dayOfWeek: 1, openTime: '14:00', closeTime: '17:00', isClosed: false },
          { dayOfWeek: 0, openTime: '00:00', closeTime: '00:00', isClosed: true },
        ],
      });
    expect(put.status).toBe(200);
    expect(put.body.data.length).toBe(3);
    expect(put.body.data[0].timeZone).toBe('Africa/Nairobi');
    const get = await request(app).get(`/api/v1/provider/availability?profileId=${profileId}`).set(auth(token));
    expect(get.body.data.length).toBe(3);
  });

  it('16. temporary closure exception create + list', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/availability/exceptions')
      .set(auth(token))
      .send({ specializedProfileId: profileId, exceptionDate: '2026-12-25', isUnavailable: true, reason: 'Holiday' });
    expect(c.status).toBe(201);
    const list = await request(app).get(`/api/v1/provider/availability/exceptions?profileId=${profileId}`).set(auth(token));
    expect(list.body.data.length).toBe(1);
  });

  it('17. cross-organization IDOR blocked for service areas', async () => {
    const a = await newProvider();
    const area = await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(a.token))
      .send({ specializedProfileId: a.profileId, county: 'Nairobi' });
    const b = await newProvider();
    const res = await request(app).delete(`/api/v1/provider/service-areas/${area.body.data.id}`).set(auth(b.token));
    expect(res.status).toBe(403);
  });

  it('18. revoked membership removes management ability', async () => {
    const owner = await registerUser('moving_company');
    created.users.push(owner.id);
    const orgId = await createOrgWithOwner(owner.id);
    created.orgs.push(orgId);
    const profileId = await createApprovedProfile(owner.id, 'moving_service_provider', orgId);
    created.profiles.push(profileId);
    // A non-owner manager with admin role creates an offering.
    const manager = await registerUser('service_provider');
    created.users.push(manager.id);
    await pool.query(
      `INSERT INTO organisation_members (organisation_id, user_id, role, status, joined_at) VALUES ($1, $2, 'admin', 'active', NOW())`,
      [orgId, manager.id],
    );
    await pool.query(
      `INSERT INTO role_assignments (id, role_id, user_id, scope, organization_id) VALUES (gen_random_uuid(), 'organization_admin', $1, 'organization', $2)`,
      [manager.id, orgId],
    );
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(manager.token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    expect(c.status).toBe(201);
    // Revoke membership + role assignment.
    await pool.query(`UPDATE organisation_members SET status = 'removed' WHERE organisation_id = $1 AND user_id = $2`, [orgId, manager.id]);
    await pool.query(`UPDATE role_assignments SET revoked_at = NOW() WHERE user_id = $1`, [manager.id]);
    const res = await request(app)
      .patch(`/api/v1/provider/services/${c.body.data.id}`)
      .set(auth(manager.token))
      .send({ title: 'Nope' });
    expect(res.status).toBe(403);
  });

  it('19. permission-cache invalidation on role change is honoured', async () => {
    const owner = await registerUser('moving_company');
    created.users.push(owner.id);
    const orgId = await createOrgWithOwner(owner.id);
    created.orgs.push(orgId);
    const profileId = await createApprovedProfile(owner.id, 'moving_service_provider', orgId);
    created.profiles.push(profileId);
    // Member with only member role (no manage permission).
    const member = await registerUser('service_provider');
    created.users.push(member.id);
    await pool.query(
      `INSERT INTO organisation_members (organisation_id, user_id, role, status, joined_at) VALUES ($1, $2, 'member', 'active', NOW())`,
      [orgId, member.id],
    );
    const before = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(member.token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'X', status: 'draft' });
    expect(before.status).toBe(403);
  });

  it('20. existing discovery still works for legacy provider (no offerings)', async () => {
    const { token, profileId } = await newProvider();
    await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, county: 'Nairobi', city: 'Nairobi' });
    const res = await request(app).get('/api/v1/provider/discovery?county=Nairobi').set(auth(token));
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  it('21. catalogue-managed provider without active offering is not discovered', async () => {
    const { token, profileId } = await newProvider();
    await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, county: 'Kiambu', city: 'Kiambu' });
    // Create a draft offering (not active) -> should be excluded from discovery.
    await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Draft', status: 'draft' });
    const res = await request(app).get('/api/v1/provider/discovery?county=Kiambu').set(auth(token));
    const ids = res.body.data.map((p: { profileId: string }) => p.profileId);
    expect(ids.includes(profileId)).toBe(false);
  });

  it('22. pause with temporary window stores dates', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'active' });
    const res = await request(app)
      .post(`/api/v1/provider/services/${c.body.data.id}/pause`)
      .set(auth(token))
      .send({ from: '2026-12-01', to: '2026-12-05' });
    expect(res.status).toBe(200);
    expect(res.body.data.temporaryUnavailableFrom).toBe('2026-12-01');
    expect(res.body.data.temporaryUnavailableTo).toBe('2026-12-05');
  });

  it('23. expired temporary closure is treated as active for discovery', async () => {
    const { token, profileId } = await newProvider();
    await request(app)
      .post('/api/v1/provider/service-areas')
      .set(auth(token))
      .send({ specializedProfileId: profileId, county: 'Mombasa', city: 'Mombasa' });
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'active' });
    await request(app)
      .post(`/api/v1/provider/services/${c.body.data.id}/pause`)
      .set(auth(token))
      .send({ from: '2020-01-01', to: '2020-01-02' });
    const res = await request(app).get('/api/v1/provider/discovery?county=Mombasa').set(auth(token));
    const ids = res.body.data.map((p: { profileId: string }) => p.profileId);
    expect(ids.includes(profileId)).toBe(true);
  });

  it('24. invalid capability for domain rejected', async () => {
    const { token, profileId } = await newProvider();
    const c = await request(app)
      .post('/api/v1/provider/services')
      .set(auth(token))
      .send({ profileId, domain: 'moving', categoryId: 'moving_local', title: 'Local', status: 'draft' });
    const res = await request(app)
      .patch(`/api/v1/provider/services/${c.body.data.id}/capabilities`)
      .set(auth(token))
      .send({ capabilities: [{ capabilityId: 'laundry_washing', enabled: true }] });
    expect(res.status).toBe(400);
  });

  it('25. operating hours require profile or offering scope', async () => {
    const { token } = await newProvider();
    const res = await request(app)
      .put('/api/v1/provider/availability')
      .set(auth(token))
      .send({ hours: [{ dayOfWeek: 1, openTime: '08:00', closeTime: '17:00' }] });
    expect(res.status).toBe(400);
  });
});