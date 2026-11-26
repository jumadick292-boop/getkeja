import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let tenantUserId: string;
let accessToken: string;
let propertyId: string;
let unitId: string;
let tenancyId: string;
let tenantRecordId: string;
let garbageProviderId: string;
let garbageAssignmentId: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}@example.com`;
  const phone = `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`;

  const reg = await request(app)
    .post('/api/auth/register/email')
    .send({
      firstName: 'Test',
      lastName: 'Tenant',
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
    `INSERT INTO user_roles (user_id, role_id) VALUES ($1, 'tenant') ON CONFLICT DO NOTHING`,
    [userId],
  );

  const login = await request(app)
    .post('/api/auth/login/email')
    .send({ email, password: 'password123' });
  expect(login.status).toBe(200);

  const token = login.headers['x-access-token'] as string;
  expect(token).toBeDefined();

  return { id: userId, token };
}

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createTestProperty(userId: string): Promise<string> {
  const result = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by)
     VALUES (NULL, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id`,
    ['Test Property', 'A test property', 'apartment', 'published', 'Test Address', 'Nairobi', 'Nairobi', 'KE', 2, userId],
  );
  const pid = result.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [pid, userId],
  );
  return pid;
}

async function createTestUnit(propertyId: string, userId: string): Promise<string> {
  const result = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING id`,
    [propertyId, 'A-101', 'one_bedroom', 1, 1, 50000, 100000, 'occupied', userId],
  );
  return result.rows[0].id;
}

async function createTestTenancy(propertyId: string, unitId: string, userId: string): Promise<string> {
  const result = await pool.query(
    `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
     VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
     RETURNING id`,
    [propertyId, unitId, new Date(Date.now() + 86400000).toISOString(), userId],
  );
  const tid = result.rows[0].id;
  await pool.query(
    `INSERT INTO tenants (property_id, unit_id, tenancy_id, user_id, full_name, phone, status, created_by)
     VALUES ($1, $2, $3, $4, 'Test Tenant', '+254700000000', 'active', $4)`,
    [propertyId, unitId, tid, userId],
  );
  return tid;
}

async function createGarbageProviderAndAssignment(userId: string): Promise<{ providerId: string; assignmentId: string }> {
  const prov = await pool.query(
    `INSERT INTO garbage_providers (organisation_id, name, contact_person, contact_phone, contact_email, service_areas, status, created_by)
     VALUES (NULL, $1, $2, $3, $4, $5, 'active', $6)
     RETURNING id`,
    ['Test Garbage Provider', 'Contact Person', '+254700000000', 'provider@test.com', '[]', userId],
  );
  const providerId = prov.rows[0].id;
  const assign = await pool.query(
    `INSERT INTO garbage_provider_assignments (property_id, unit_id, garbage_provider_id, assignment_type, frequency, status, assigned_by, effective_from)
     VALUES ($1, $2, $3, 'scheduled', 'weekly', 'active', $4, CURRENT_DATE)
     RETURNING id`,
    [propertyId, unitId, providerId, userId],
  );
  return { providerId, assignmentId: assign.rows[0].id };
}

async function cleanupTestData(): Promise<void> {
  await pool.query('DELETE FROM moving_status_history');
  await pool.query('DELETE FROM laundry_status_history');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM moving_requests');
  await pool.query('DELETE FROM laundry_requests');
  await pool.query('DELETE FROM garbage_collection_requests');
  await pool.query('DELETE FROM property_issues');
  await pool.query('DELETE FROM garbage_provider_assignments');
  await pool.query('DELETE FROM garbage_providers');
  await pool.query('DELETE FROM unit_occupancy_history');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM tenants');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query('DELETE FROM user_roles WHERE role_id = \'tenant\'');
  await pool.query('DELETE FROM users WHERE email LIKE \'test%@example.com\'');
}

beforeEach(async () => {
  await cleanupTestData();

  const { id, token } = await registerAndLogin('tenant');
  tenantUserId = id;
  accessToken = token;

  propertyId = await createTestProperty(tenantUserId);
  unitId = await createTestUnit(propertyId, tenantUserId);
  tenancyId = await createTestTenancy(propertyId, unitId, tenantUserId);

  // Get the tenant record id
  const tenantResult = await pool.query(
    `SELECT id FROM tenants WHERE user_id = $1 AND status = 'active' LIMIT 1`,
    [tenantUserId],
  );
  tenantRecordId = tenantResult.rows[0].id;

  // Create garbage provider and assignment for garbage tests
  const garbage = await createGarbageProviderAndAssignment(tenantUserId);
  garbageProviderId = garbage.providerId;
  garbageAssignmentId = garbage.assignmentId;
});

afterEach(async () => {
  await cleanupTestData();
});

describe('Tenant Maintenance Requests API', () => {
  describe('POST /api/v1/tenant/maintenance-requests', () => {
    it('should create a maintenance request successfully', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'Leaking faucet',
          category: 'plumbing',
          priority: 'high',
          description: 'The kitchen faucet is leaking and needs repair.',
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.title).toBe('Leaking faucet');
      expect(response.body.data.category).toBe('plumbing');
      expect(response.body.data.priority).toBe('high');
      expect(response.body.data.status).toBe('new');
      expect(response.body.data.unitId).toBe(unitId);
    });

    it('should reject missing required fields', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: '',
          category: 'plumbing',
          priority: 'high',
          description: 'Short',
        });

      expect(response.status).toBe(400);
    });

    it('should reject request against wrong unit', async () => {
      const otherUnit = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [propertyId, 'A-102', 'one_bedroom', 1, 1, 50000, 100000, 'occupied', tenantUserId],
      );
      const otherUnitId = otherUnit.rows[0].id;

      const response = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId: otherUnitId,
          title: 'Test',
          category: 'plumbing',
          priority: 'medium',
          description: 'Test description',
        });

      expect(response.status).toBe(403);

      await pool.query('DELETE FROM units WHERE id = $1', [otherUnitId]);
    });

    it('should record outbox event for new maintenance request', async () => {
      await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'Test Issue',
          category: 'electrical',
          priority: 'medium',
          description: 'Test description for outbox.',
        });

      const outbox = await pool.query(
        `SELECT id, event_type, idempotency_key FROM notification_outbox WHERE event_type = 'maintenance_request.created'`,
      );
      expect(outbox.rows.length).toBe(1);
      expect(outbox.rows[0].idempotency_key).toMatch(/^maintenance_request\.created:/);
    });

    it('should create duplicate maintenance requests (no duplicate protection for issues)', async () => {
      await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'First Issue',
          category: 'plumbing',
          priority: 'medium',
          description: 'First issue description.',
        });

      const response = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'Second Issue',
          category: 'plumbing',
          priority: 'medium',
          description: 'Second issue description.',
        });

      expect(response.status).toBe(201);
    });
  });

  describe('DELETE /api/v1/tenant/maintenance-requests/:requestId', () => {
    it('should cancel a maintenance request owned by the tenant', async () => {
      const create = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'Cancellable Issue',
          category: 'plumbing',
          priority: 'medium',
          description: 'To be cancelled.',
        });

      const requestId = create.body.data.id;

      const response = await request(app)
        .delete(`/api/v1/tenant/maintenance-requests/${requestId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('cancelled');
    });

    it('should reject cancelling another tenant\'s maintenance request', async () => {
      const create = await request(app)
        .post('/api/v1/tenant/maintenance-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          title: 'Owned Issue',
          category: 'plumbing',
          priority: 'medium',
          description: 'Owned by this tenant.',
        });

      const requestId = create.body.data.id;

      // Register another tenant
      const { id: otherUserId, token: otherToken } = await registerAndLogin('tenant');
      await pool.query(
        `UPDATE tenants SET user_id = $1 WHERE id = $2`,
        [otherUserId, tenantRecordId],
      );

      const response = await request(app)
        .delete(`/api/v1/tenant/maintenance-requests/${requestId}`)
        .set(authHeaders(otherToken));

      expect(response.status).toBe(403);

      await pool.query('DELETE FROM users WHERE id = $1', [otherUserId]);
      await pool.query('DELETE FROM user_roles WHERE user_id = $1', [otherUserId]);
    });
  });
});

describe('Tenant Garbage Requests API', () => {
  describe('POST /api/v1/tenant/garbage-requests', () => {
    it('should create a garbage request successfully', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          category: 'regular_collection',
          description: 'Garbage was not collected this week.',
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.requestType).toBe('regular_collection');
      expect(response.body.data.status).toBe('pending');
      expect(response.body.data.garbageProviderId).toBe(garbageProviderId);
      expect(response.body.data.unitId).toBe(unitId);
    });

    it('should reject missing garbage provider assignment', async () => {
      // Remove the garbage assignment
      await pool.query('DELETE FROM garbage_provider_assignments WHERE id = $1', [garbageAssignmentId]);

      const response = await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          category: 'regular_collection',
          description: 'No collection.',
        });

      expect(response.status).toBe(403);
    });

    it('should reject request against wrong unit', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId: '00000000-0000-0000-0000-000000000000',
          category: 'regular_collection',
          description: 'No collection.',
        });

      expect(response.status).toBe(403);
    });

    it('should record outbox event for new garbage request', async () => {
      await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          category: 'special_pickup',
          description: 'Extra garbage pickup needed.',
        });

      const outbox = await pool.query(
        `SELECT id, event_type, idempotency_key FROM notification_outbox WHERE event_type = 'garbage_request.created'`,
      );
      expect(outbox.rows.length).toBe(1);
    });
  });

  describe('DELETE /api/v1/tenant/garbage-requests/:requestId', () => {
    it('should cancel a garbage request owned by the tenant', async () => {
      const create = await request(app)
        .post('/api/v1/tenant/garbage-requests')
        .set(authHeaders(accessToken))
        .send({
          unitId,
          category: 'regular_collection',
          description: 'To be cancelled.',
        });

      const requestId = create.body.data.id;

      const response = await request(app)
        .delete(`/api/v1/tenant/garbage-requests/${requestId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('cancelled');
    });
  });
});

describe('Tenant Moving Requests API', () => {
  describe('POST /api/v1/tenant/moving-requests', () => {
    it('should create a moving request successfully', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(authHeaders(accessToken))
        .send({
          pickupUnitId: unitId,
          destinationAddress: 'New Address, Nairobi',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Furniture and boxes',
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('submitted');
      expect(response.body.data.pickupLocation).toContain(unitId);
      expect(response.body.data.destinationLocation).toBe('New Address, Nairobi');
    });

    it('should create a moving request with provider (pending_confirmation)', async () => {
      const { rows: [{ id: providerId }] } = await pool.query(
        `INSERT INTO specialized_profiles (user_id, profile_category, full_name, business_name, verification_status)
         VALUES ($1, 'moving_service_provider', $2, $3, 'approved')
         RETURNING id`,
        [tenantUserId, 'Moving Co', 'Moving Company'],
      );

      const response = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(authHeaders(accessToken))
        .send({
          pickupUnitId: unitId,
          destinationAddress: 'New Address, Nairobi',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Furniture',
          providerId: providerId,
        });

      expect(response.status).toBe(201);
      expect(response.body.data.status).toBe('pending_confirmation');
      expect(response.body.data.providerId).toBe(providerId);

      await pool.query('DELETE FROM specialized_profiles WHERE id = $1', [providerId]);
    });

    it('should reject request against wrong pickup unit', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(authHeaders(accessToken))
        .send({
          pickupUnitId: '00000000-0000-0000-0000-000000000000',
          destinationAddress: 'New Address',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Items',
        });

      expect(response.status).toBe(403);
    });

    it('should record outbox event for new moving request', async () => {
      await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(authHeaders(accessToken))
        .send({
          pickupUnitId: unitId,
          destinationAddress: 'New Address',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Items',
        });

      const outbox = await pool.query(
        `SELECT id, event_type FROM notification_outbox WHERE event_type = 'moving_request.created'`,
      );
      expect(outbox.rows.length).toBe(1);
    });
  });

  describe('DELETE /api/v1/tenant/moving-requests/:requestId', () => {
    it('should cancel a moving request owned by the tenant', async () => {
      const create = await request(app)
        .post('/api/v1/tenant/moving-requests')
        .set(authHeaders(accessToken))
        .send({
          pickupUnitId: unitId,
          destinationAddress: 'New Address',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          itemDescription: 'Items',
        });

      const requestId = create.body.data.id;

      const response = await request(app)
        .delete(`/api/v1/tenant/moving-requests/${requestId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('cancelled');
    });
  });
});

describe('Tenant Laundry Requests API', () => {
  describe('POST /api/v1/tenant/laundry-requests', () => {
    it('should create a laundry request successfully', async () => {
      const { rows: [{ id: providerId }] } = await pool.query(
        `INSERT INTO specialized_profiles (user_id, profile_category, full_name, business_name, verification_status)
         VALUES ($1, 'laundry_service_provider', $2, $3, 'approved')
         RETURNING id`,
        [tenantUserId, 'Laundry Co', 'Laundry Service'],
      );

      const response = await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(authHeaders(accessToken))
        .send({
          providerId: providerId,
          serviceCategory: 'wash_fold',
          collectionPreference: 'doorstep',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 10,
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('pending_confirmation');
      expect(response.body.data.providerId).toBe(providerId);
      expect(response.body.data.garmentCount).toBe(10);

      await pool.query('DELETE FROM specialized_profiles WHERE id = $1', [providerId]);
    });

    it('should reject invalid provider', async () => {
      const response = await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(authHeaders(accessToken))
        .send({
          providerId: '00000000-0000-0000-0000-000000000000',
          serviceCategory: 'wash_fold',
          collectionPreference: 'doorstep',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 10,
        });

      expect(response.status).toBe(404);
    });

    it('should reject request without active unit', async () => {
      // Temporarily remove the tenant's unit/tenancy association
      await pool.query(
        `UPDATE tenants SET unit_id = NULL, tenancy_id = NULL WHERE id = $1`,
        [tenantRecordId],
      );

      const { rows: [{ id: providerId }] } = await pool.query(
        `INSERT INTO specialized_profiles (user_id, profile_category, full_name, business_name, verification_status)
         VALUES ($1, 'laundry_service_provider', $2, $3, 'approved')
         RETURNING id`,
        [tenantUserId, 'Laundry Co', 'Laundry Service'],
      );

      const response = await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(authHeaders(accessToken))
        .send({
          providerId: providerId,
          serviceCategory: 'wash_fold',
          collectionPreference: 'doorstep',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 10,
        });

      expect(response.status).toBe(403);

      // Restore the tenant's unit/tenancy association
      await pool.query(
        `UPDATE tenants SET unit_id = $1, tenancy_id = $2 WHERE id = $3`,
        [unitId, tenancyId, tenantRecordId],
      );

      await pool.query('DELETE FROM specialized_profiles WHERE id = $1', [providerId]);
    });

    it('should record outbox event for new laundry request', async () => {
      const { rows: [{ id: providerId }] } = await pool.query(
        `INSERT INTO specialized_profiles (user_id, profile_category, full_name, business_name, verification_status)
         VALUES ($1, 'laundry_service_provider', $2, $3, 'approved')
         RETURNING id`,
        [tenantUserId, 'Laundry Co', 'Laundry Service'],
      );

      await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(authHeaders(accessToken))
        .send({
          providerId: providerId,
          serviceCategory: 'dry_clean',
          collectionPreference: 'lobby',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 5,
        });

      const outbox = await pool.query(
        `SELECT id, event_type FROM notification_outbox WHERE event_type = 'laundry_request.created'`,
      );
      expect(outbox.rows.length).toBe(1);

      await pool.query('DELETE FROM specialized_profiles WHERE id = $1', [providerId]);
    });
  });

  describe('DELETE /api/v1/tenant/laundry-requests/:requestId', () => {
    it('should cancel a laundry request owned by the tenant', async () => {
      const { rows: [{ id: providerId }] } = await pool.query(
        `INSERT INTO specialized_profiles (user_id, profile_category, full_name, business_name, verification_status)
         VALUES ($1, 'laundry_service_provider', $2, $3, 'approved')
         RETURNING id`,
        [tenantUserId, 'Laundry Co', 'Laundry Service'],
      );

      const create = await request(app)
        .post('/api/v1/tenant/laundry-requests')
        .set(authHeaders(accessToken))
        .send({
          providerId: providerId,
          serviceCategory: 'wash_fold',
          collectionPreference: 'doorstep',
          preferredDateTime: new Date(Date.now() + 86400000).toISOString(),
          garmentCount: 10,
        });

      const requestId = create.body.data.id;

      const response = await request(app)
        .delete(`/api/v1/tenant/laundry-requests/${requestId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('cancelled');

      await pool.query('DELETE FROM specialized_profiles WHERE id = $1', [providerId]);
    });
  });
});
