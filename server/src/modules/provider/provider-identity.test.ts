import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let seq = 0;
function uniqueEmail(prefix = 'pid'): string {
  seq += 1;
  return `${prefix}${Date.now()}${seq}${Math.floor(Math.random() * 1e5)}@example.com`;
}
function uniquePhone(): string {
  return `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`;
}

async function registerUser(
  role = 'tenant',
  emailOverride?: string,
): Promise<{ id: string; token: string; email: string }> {
  const email = emailOverride ?? uniqueEmail();
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Prov',
    lastName: 'Ident',
    email,
    password: 'password123',
    role,
    termsAccepted: true,
  });
  expect(reg.status, JSON.stringify(reg.body)).toBe(201);
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
  return { id: userId, token: login.headers['x-access-token'] as string, email };
}

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

describe('Provider identity, organizations and staff', () => {
  let owner: { id: string; token: string; email: string };
  let invitee: { id: string; token: string; email: string };
  let orgId: string;
  let individualProfileId: string;

  beforeAll(async () => {
    owner = await registerUser('moving_company');
    invitee = await registerUser('tenant');
  });

  afterAll(async () => {
    await pool.query('DELETE FROM organisation_invitations');
    await pool.query('DELETE FROM role_assignments');
    await pool.query('DELETE FROM organisation_members');
    await pool.query('DELETE FROM organisations');
    await pool.query('DELETE FROM provider_service_areas');
    await pool.query('DELETE FROM specialized_profiles');
  });

  it('onboards an individual provider profile and submits it', async () => {
    const mover = await registerUser('individual_mover');
    const create = await request(app)
      .post('/api/v1/provider/profile')
      .set(auth(mover.token))
      .send({ profileCategory: 'moving_service_provider', fullName: 'Ind Mover', businessName: 'Mover One' });
    expect(create.status, JSON.stringify(create.body)).toBe(201);
    individualProfileId = create.body.data.id;

    const list = await request(app).get('/api/v1/provider/profile').set(auth(mover.token));
    expect(list.status).toBe(200);
    expect(list.body.data.some((p: any) => p.id === individualProfileId)).toBe(true);

    const submit = await request(app)
      .post(`/api/v1/provider/profiles/${individualProfileId}/submit`)
      .set(auth(mover.token));
    // Incomplete profiles must be blocked from submission.
    expect(submit.status).toBe(400);
  });

  it('prevents duplicate provider profiles for the same category', async () => {
    const mover = await registerUser('individual_mover');
    const first = await request(app)
      .post('/api/v1/provider/profile')
      .set(auth(mover.token))
      .send({ profileCategory: 'moving_service_provider', fullName: 'Dup Mover' });
    expect(first.status).toBe(201);
    const second = await request(app)
      .post('/api/v1/provider/profile')
      .set(auth(mover.token))
      .send({ profileCategory: 'moving_service_provider', fullName: 'Dup Mover 2' });
    expect(second.status).toBe(409);
  });

  it('onboards an organization and lists it for the owner', async () => {
    const create = await request(app)
      .post('/api/v1/provider/organizations')
      .set(auth(owner.token))
      .send({ name: 'Biz Movers', slug: uniqueEmail('slug').replace(/[^a-z0-9]/gi, ''), type: 'moving_company' });
    expect(create.status, JSON.stringify(create.body)).toBe(201);
    orgId = create.body.data.id;

    const list = await request(app).get('/api/v1/provider/organizations').set(auth(owner.token));
    expect(list.status).toBe(200);
    expect(list.body.data.some((o: any) => o.id === orgId)).toBe(true);
  });

  it('invites staff, lists the invitation, and the invitee can accept', async () => {
    const invite = await request(app)
      .post(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(owner.token))
      .send({ email: invitee.email, role: 'member' });
    expect(invite.status, JSON.stringify(invite.body)).toBe(201);
    const token = invite.body.data.token as string;
    expect(token).toBeTruthy();

    const list = await request(app)
      .get(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(owner.token));
    expect(list.status).toBe(200);
    expect(list.body.data.length).toBeGreaterThanOrEqual(1);

    const accept = await request(app)
      .post('/api/v1/provider/invitations/accept')
      .set(auth(invitee.token))
      .send({ token });
    expect(accept.status, JSON.stringify(accept.body)).toBe(200);

    const staff = await request(app)
      .get(`/api/v1/provider/organizations/${orgId}/staff`)
      .set(auth(owner.token));
    expect(staff.body.data.some((m: any) => m.userId === invitee.id)).toBe(true);
  });

  it('rejects duplicate pending invitations', async () => {
    const other = await registerUser('tenant');
    const first = await request(app)
      .post(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(owner.token))
      .send({ email: other.email, role: 'staff' });
    expect(first.status).toBe(201);
    const second = await request(app)
      .post(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(owner.token))
      .send({ email: other.email, role: 'staff' });
    expect(second.status).toBe(409);
  });

  it('rejects accepting an expired invitation', async () => {
    const other = await registerUser('tenant');
    const invite = await request(app)
      .post(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(owner.token))
      .send({ email: other.email, role: 'member' });
    const token = invite.body.data.token as string;
    const inv = await pool.query(`SELECT id FROM organisation_invitations WHERE email = $1`, [other.email]);
    await pool.query(`UPDATE organisation_invitations SET expires_at = NOW() - INTERVAL '1 day' WHERE id = $1`, [
      inv.rows[0].id,
    ]);
    const accept = await request(app)
      .post('/api/v1/provider/invitations/accept')
      .set(auth(other.token))
      .send({ token });
    expect(accept.status).toBe(403);
  });

  it('prevents removing the last owner', async () => {
    const members = await pool.query<{ id: string }>(
      `SELECT id FROM organisation_members WHERE organisation_id = $1 AND role = 'owner'`,
      [orgId],
    );
    const ownerMemberId = members.rows[0]!.id;
    const res = await request(app)
      .delete(`/api/v1/provider/organizations/${orgId}/staff/${ownerMemberId}`)
      .set(auth(owner.token));
    expect(res.status).toBe(403);
  });

  it('denies invitations from a non-member', async () => {
    const outsider = await registerUser('tenant');
    const res = await request(app)
      .post(`/api/v1/provider/organizations/${orgId}/invitations`)
      .set(auth(outsider.token))
      .send({ email: uniqueEmail(), role: 'member' });
    expect(res.status).toBe(403);
  });

  it('prevents a provider from accessing the admin verification queue (no self-approval)', async () => {
    const mover = await registerUser('individual_mover');
    const res = await request(app)
      .get('/api/v1/profile/admin/verification-queue')
      .set(auth(mover.token));
    expect(res.status).toBe(403);
  });

  it('lets a provider manage service areas for their profile', async () => {
    const mover = await registerUser('individual_mover');
    const create = await request(app)
      .post('/api/v1/provider/profile')
      .set(auth(mover.token))
      .send({ profileCategory: 'moving_service_provider', fullName: 'Area Mover' });
    const profileId = create.body.data.id;
    const area = await request(app)
      .post('/api/v1/profile/service-areas')
      .set(auth(mover.token))
      .send({ profileId, county: 'Nairobi', city: 'Nairobi', latitude: -1.2921, longitude: 36.8219, radiusKm: 20 });
    expect(area.status, JSON.stringify(area.body)).toBe(201);
    const list = await request(app)
      .get(`/api/v1/profile/service-areas/${profileId}`)
      .set(auth(mover.token));
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expect(list.body.data.length).toBeGreaterThanOrEqual(1);
  });

  it('resolves garbage provider context via the central profile link', async () => {
    const gpUser = await registerUser('garbage_provider');
    const prof = await request(app)
      .post('/api/v1/provider/profile')
      .set(auth(gpUser.token))
      .send({ profileCategory: 'garbage_collection_provider', fullName: 'Garbage Op' });
    const profileId = prof.body.data.id;
    // Approve the profile directly (admin action) and link a garbage provider.
    await pool.query(`UPDATE specialized_profiles SET verification_status = 'approved' WHERE id = $1`, [
      profileId,
    ]);
    await pool.query(
      `INSERT INTO garbage_providers (name, contact_phone, status, created_by, specialized_profile_id)
       VALUES ('Linked Garbage', '+254700000000', 'active', $1, $2)`,
      [gpUser.id, profileId],
    );
    const inbox = await request(app)
      .get('/api/v1/provider/requests?serviceType=garbage')
      .set(auth(gpUser.token));
    expect(inbox.status).toBe(200);
  });
});