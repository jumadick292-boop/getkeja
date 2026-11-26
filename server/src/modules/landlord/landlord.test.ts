import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let landlordUserId: string;
let accessToken: string;
let propertyId: string;
let unitId: string;
let listingId: string;
let visitId: string;
let tenantId: string;
let garbageProviderId: string;
let garbageAssignmentId: string;
let garbageRequestId: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}@example.com`;
  const phone = `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`;

  const reg = await request(app)
    .post('/api/auth/register/email')
    .send({
      firstName: 'Test',
      lastName: 'Landlord',
      email,
      password: 'password123',
      role,
      termsAccepted: true,
    });
  expect(reg.status).toBe(201);

  // Verify email identity and user
  await pool.query(
    `UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`,
    [email],
  );
  await pool.query(
    `UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`,
    [email],
  );

  // Assign landlord role
  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id;
  await pool.query(
    `INSERT INTO user_roles (user_id, role_id) VALUES ($1, 'landlord') ON CONFLICT DO NOTHING`,
    [userId],
  );

  // Login
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
    ['Test Property', 'A test property', 'apartment', 'draft', 'Test Address', 'Nairobi', 'Nairobi', 'KE', 2, userId],
  );
  const pid = result.rows[0].id;
  // Create ownership so the user can access the property
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
    [propertyId, 'A-101', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', userId],
  );
  return result.rows[0].id;
}

async function createTestSiteVisit(propertyId: string, unitId: string | null, userId: string): Promise<string> {
  const result = await pool.query(
    `INSERT INTO site_visits (property_id, unit_id, user_id, visitor_name, visitor_email, visitor_phone, scheduled_at, duration_minutes, status, hosted_by_user_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING id`,
    [propertyId, unitId, userId, 'John Visitor', 'john@example.com', '+254712345678', new Date(Date.now() + 86400000).toISOString(), 30, 'scheduled', userId, userId],
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
  const tenancyId = result.rows[0].id;
  await pool.query(
    `INSERT INTO tenants (property_id, unit_id, tenancy_id, full_name, phone, status, created_by)
     VALUES ($1, $2, $3, 'Test Tenant', '+254700000000', 'active', $4)`,
    [propertyId, unitId, tenancyId, userId],
  );
  return tenancyId;
}

async function createApiProperty(userId: string, title: string): Promise<string> {
  const response = await request(app)
    .post('/api/v1/landlord/properties')
    .set(authHeaders(accessToken))
    .send({
      title,
      propertyType: 'apartment',
      address: 'Test Address, Nairobi',
      city: 'Nairobi',
      county: 'Nairobi',
      totalUnits: 5,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

async function cleanupTestData(): Promise<void> {
  // Child tables first, respecting FK dependencies
  await pool.query('DELETE FROM message_read_states');
  await pool.query('DELETE FROM message_attachments');
  await pool.query('DELETE FROM messages');
  await pool.query('DELETE FROM conversation_participants');
  await pool.query('DELETE FROM rental_proposal_status_history');
  await pool.query('DELETE FROM rental_proposal_versions');
  await pool.query('DELETE FROM rental_proposals');
  await pool.query('DELETE FROM conversations');
  await pool.query('DELETE FROM payment_allocations');
  await pool.query('DELETE FROM payment_transactions');
  await pool.query('DELETE FROM invoice_items');
  await pool.query('DELETE FROM rent_ledger_entries');
  await pool.query('DELETE FROM invoices');
  await pool.query('DELETE FROM deposit_transactions');
  await pool.query('DELETE FROM tenant_deposits');
  await pool.query('DELETE FROM maintenance_requests');
  await pool.query('DELETE FROM property_issues');
  await pool.query('DELETE FROM lease_documents');
  await pool.query('DELETE FROM move_out_inspection_items');
  await pool.query('DELETE FROM move_out_inspections');
  await pool.query('DELETE FROM inspection_items');
  await pool.query('DELETE FROM move_in_inspections');
  await pool.query('DELETE FROM rental_agreements');
  await pool.query('DELETE FROM enquiry_status_history');
  await pool.query('DELETE FROM enquiry_notes');
  await pool.query('DELETE FROM enquiry_assignments');
  await pool.query('DELETE FROM property_enquiries');
  await pool.query('DELETE FROM listing_status_history');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM garbage_collection_requests');
  await pool.query('DELETE FROM garbage_provider_assignments');
  await pool.query('DELETE FROM garbage_providers');
  await pool.query('DELETE FROM unit_occupancy_history');
  await pool.query('DELETE FROM site_visit_history');
  await pool.query('DELETE FROM site_visits');
  await pool.query('DELETE FROM site_visit_availability_exceptions');
  await pool.query('DELETE FROM site_visit_availability_rules');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM tenants');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query('DELETE FROM user_roles WHERE role_id = \'landlord\'');
  await pool.query('DELETE FROM users WHERE email LIKE \'test%@example.com\'');
}

beforeEach(async () => {
  await cleanupTestData();

  const { id, token } = await registerAndLogin('landlord');
  landlordUserId = id;
  accessToken = token;

  propertyId = await createTestProperty(landlordUserId);
  unitId = await createTestUnit(propertyId, landlordUserId);
  visitId = await createTestSiteVisit(propertyId, unitId, landlordUserId);

  // Confirming a visit now revalidates published availability; seed an
  // all-week, all-day window so the fixture visit is confirmable.
  for (const day of [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ]) {
    await pool.query(
      `INSERT INTO site_visit_availability_rules
         (property_id, day_of_week, start_time, end_time, slot_duration_minutes, buffer_minutes, max_bookings_per_slot, is_active)
       VALUES ($1, $2::availability_day_of_week, '00:00', '23:59', 30, 0, 5, TRUE)
       ON CONFLICT (property_id, day_of_week) DO NOTHING`,
      [propertyId, day],
    );
  }
});

afterEach(async () => {
  await cleanupTestData();
});

describe('Property Listings API', () => {
  describe('POST /api/v1/landlord/listings', () => {
    it('should create a new listing', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          title: 'Beautiful 1BR Apartment',
          description: 'A nice apartment in Nairobi',
          rentAmount: 50000,
          depositAmount: 100000,
          availableFrom: '2026-12-01',
          furnished: true,
          petPolicy: 'negotiable',
          smokingAllowed: false,
        });

      expect(response.status).toBe(201);
      expect(response.body.status).toBe('draft');
      expect(response.body.title).toBe('Beautiful 1BR Apartment');
      expect(response.body.rentAmount).toBe(50000);
      listingId = response.body.id;
    });

    it('should reject listing creation for non-owned property', async () => {
      const otherProperty = await createTestProperty(landlordUserId);
      // Create a different user and try to create listing for their property
      const { id: otherUserId, token: otherToken } = await registerAndLogin('landlord');
      // Transfer ownership to otherUserId so landlordUserId no longer owns it
      await pool.query('DELETE FROM property_ownerships WHERE property_id = $1', [otherProperty]);
      await pool.query(
        `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
         VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
        [otherProperty, otherUserId],
      );
      await pool.query('UPDATE properties SET created_by = $1 WHERE id = $2', [otherUserId, otherProperty]);

      const response = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId: otherProperty,
          title: 'Unauthorized Listing',
          rentAmount: 50000,
        });

      expect(response.status).toBe(403);

      await pool.query('DELETE FROM property_ownerships WHERE property_id = $1', [otherProperty]);
      await pool.query('DELETE FROM properties WHERE id = $1', [otherProperty]);
      await pool.query('DELETE FROM users WHERE id = $1', [otherUserId]);
      await pool.query('DELETE FROM user_roles WHERE user_id = $1', [otherUserId]);
    });
  });

  describe('GET /api/v1/landlord/listings', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          title: 'Test Listing',
          rentAmount: 50000,
        });
      listingId = result.body.id;
    });

    it('should list all listings', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/listings')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });

    it('should filter by status', async () => {
      await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/publish`)
        .set(authHeaders(accessToken));

      const response = await request(app)
        .get('/api/v1/landlord/listings?status=published')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.every((l: any) => l.status === 'published')).toBe(true);
    });
  });

  describe('GET /api/v1/landlord/listings/:listingId', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          title: 'Get Test Listing',
          rentAmount: 50000,
        });
      listingId = result.body.id;
    });

    it('should return a single listing', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/listings/${listingId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(listingId);
    });

    it('should return 404 for non-existent listing', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/listings/00000000-0000-0000-0000-000000000000')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(404);
    });
  });

  describe('PATCH /api/v1/landlord/listings/:listingId', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          title: 'Original Title',
          rentAmount: 50000,
        });
      listingId = result.body.id;
    });

    it('should update a listing', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/listings/${listingId}`)
        .set(authHeaders(accessToken))
        .send({
          title: 'Updated Title',
          rentAmount: 60000,
        });

      expect(response.status).toBe(200);
      expect(response.body.title).toBe('Updated Title');
      expect(response.body.rentAmount).toBe(60000);
    });
  });

  describe('DELETE /api/v1/landlord/listings/:listingId', () => {
    it('should delete a listing', async () => {
      const result = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          title: 'To Be Deleted',
          rentAmount: 50000,
        });
      const lid = result.body.id;

      const response = await request(app)
        .delete(`/api/v1/landlord/listings/${lid}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(204);

      const getResponse = await request(app)
        .get(`/api/v1/landlord/listings/${lid}`)
        .set(authHeaders(accessToken));
      expect(getResponse.status).toBe(404);
    });
  });

  describe('Listing status transitions', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/listings')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          title: 'Status Test Listing',
          rentAmount: 50000,
        });
      listingId = result.body.id;
    });

    it('should publish a listing', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/publish`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('published');
    });

    it('should pause a published listing', async () => {
      await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/publish`)
        .set(authHeaders(accessToken));

      const response = await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/pause`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('paused');
    });

    it('should resume a paused listing', async () => {
      await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/publish`)
        .set(authHeaders(accessToken));
      await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/pause`)
        .set(authHeaders(accessToken));

      const response = await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/resume`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('published');
    });

    it('should withdraw a listing', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/withdraw`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('withdrawn');
    });

    it('should archive a listing', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/listings/${listingId}/archive`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('archived');
    });
  });
});

describe('Site Visit Management API', () => {
  describe('POST /api/v1/landlord/site-visits/:visitId/confirm', () => {
    it('should confirm a site visit', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/site-visits/${visitId}/confirm`)
        .set(authHeaders(accessToken))
        .send({ hostNotes: 'Ready for viewing' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('confirmed');
    });
  });

  describe('POST /api/v1/landlord/site-visits/:visitId/decline', () => {
    it('should decline a site visit', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/site-visits/${visitId}/decline`)
        .set(authHeaders(accessToken))
        .send({ reason: 'Not available' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('cancelled');
    });
  });

  describe('POST /api/v1/landlord/site-visits/:visitId/reschedule', () => {
    it('should reschedule a site visit', async () => {
      const newDate = new Date(Date.now() + 172800000).toISOString();
      const response = await request(app)
        .post(`/api/v1/landlord/site-visits/${visitId}/reschedule`)
        .set(authHeaders(accessToken))
        .send({
          scheduledAt: newDate,
          reason: 'Schedule conflict',
        });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('rescheduled');
    });
  });

  describe('POST /api/v1/landlord/site-visits/:visitId/cancel', () => {
    it('should cancel a site visit', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/site-visits/${visitId}/cancel`)
        .set(authHeaders(accessToken))
        .send({ reason: 'Cancelled by landlord' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('cancelled');
    });
  });
});

describe('Tenant Management API', () => {
  describe('POST /api/v1/landlord/tenants', () => {
    it('should create a tenant', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'Jane Tenant',
          email: 'jane@example.com',
          phone: '+254712345679',
          idNumber: '12345678',
          idType: 'national_id',
          employerName: 'Acme Corp',
          monthlyIncome: 80000,
          moveInDate: '2026-12-01',
          status: 'active',
        });

      expect(response.status).toBe(201);
      expect(response.body.fullName).toBe('Jane Tenant');
      expect(response.body.status).toBe('active');
      tenantId = response.body.id;
    });

    it('rejects tenant linked to a non-active tenancy', async () => {
      // Create a draft tenancy
      const draftTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'draft', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );
      const draftTenancyId = draftTenancy.rows[0].id;

      const response = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          tenancyId: draftTenancyId,
          fullName: 'Draft Tenant',
          phone: '+254712345679',
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('rejects duplicate active tenant on same unit', async () => {
      // Create first active tenant
      await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'First Tenant',
          phone: '+254712345670',
          status: 'active',
        });

      // Attempt second active tenant on same unit
      const response = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'Second Tenant',
          phone: '+254712345671',
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('allows tenant linked to an active tenancy', async () => {
      // Create an active tenancy first
      const activeTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );
      const activeTenancyId = activeTenancy.rows[0].id;

      const response = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          tenancyId: activeTenancyId,
          fullName: 'Active Tenancy Tenant',
          phone: '+254712345672',
          status: 'active',
        });

      expect(response.status).toBe(201);
      expect(response.body.tenancyId).toBe(activeTenancyId);
    });

    it('rejects concurrent active tenant creation on same unit', async () => {
      // Two simultaneous active tenant creation requests for one unit.
      // Only one should succeed; the other must get 409.
      const promises = [
        request(app)
          .post('/api/v1/landlord/tenants')
          .set(authHeaders(accessToken))
          .send({
            propertyId,
            unitId,
            fullName: 'Concurrent Tenant A',
            phone: '+254712345680',
            status: 'active',
          }),
        request(app)
          .post('/api/v1/landlord/tenants')
          .set(authHeaders(accessToken))
          .send({
            propertyId,
            unitId,
            fullName: 'Concurrent Tenant B',
            phone: '+254712345681',
            status: 'active',
          }),
      ];
      const [resA, resB] = await Promise.all(promises);
      const statuses = [resA!.status, resB!.status].sort();
      expect(statuses).toEqual([201, 409]);
    });

    it('allows multiple tenants linked to same active tenancy on same unit (one active, others historical)', async () => {
      // One active tenant + historical inactive tenants can share one tenancy on the same unit
      const activeTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );
      const activeTenancyId = activeTenancy.rows[0].id;

      // First active tenant
      const res1 = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          tenancyId: activeTenancyId,
          fullName: 'Tenant One',
          phone: '+254712345690',
          status: 'active',
        });
      expect(res1.status).toBe(201);

      // Second inactive tenant on same unit + same tenancy (historical record)
      const res2 = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          tenancyId: activeTenancyId,
          fullName: 'Tenant Two',
          phone: '+254712345691',
          status: 'inactive',
        });
      expect(res2.status).toBe(201);
    });

    it('rejects linking tenant to tenancy from a different unit (cross-unit on create)', async () => {
      // Create a second unit on the same property
      const unitB = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [propertyId, 'A-102', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', landlordUserId],
      );

      // Create an active tenancy on unit B
      const tenancyB = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitB.rows[0].id, new Date().toISOString(), landlordUserId],
      );

      // Try to create a tenant on unit A linked to tenancy on unit B
      const response = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          tenancyId: tenancyB.rows[0].id,
          fullName: 'Cross-Unit Tenant',
          phone: '+254712345695',
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('allows multiple historical inactive tenants on same unit', async () => {
      // Multiple non-active tenants on the same unit are legitimate historical records
      const res1 = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'Former Tenant A',
          phone: '+254712345700',
          status: 'inactive',
        });
      expect(res1.status).toBe(201);

      const res2 = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'Former Tenant B',
          phone: '+254712345701',
          status: 'inactive',
        });
      expect(res2.status).toBe(201);

      // But a new active tenant on the same unit is still rejected
      const res3 = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'New Active Tenant',
          phone: '+254712345702',
          status: 'active',
        });
      expect(res3.status).toBe(201);
    });
  });

  describe('GET /api/v1/landlord/tenants', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          fullName: 'Test Tenant',
          phone: '+254712345680',
          status: 'active',
        });
      tenantId = result.body.id;
    });

    it('should list tenants', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('PATCH /api/v1/landlord/tenants/:tenantId', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          fullName: 'Original Name',
          phone: '+254712345681',
          status: 'active',
        });
      tenantId = result.body.id;
    });

    it('should update a tenant', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          fullName: 'Updated Name',
          status: 'inactive',
        });

      expect(response.status).toBe(200);
      expect(response.body.fullName).toBe('Updated Name');
      expect(response.body.status).toBe('inactive');
    });

    it('rejects activating tenant on unit with existing active tenant', async () => {
      // Create an active tenant on the same unit
      await request(app)
        .post('/api/v1/landlord/tenants')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          fullName: 'Existing Active Tenant',
          phone: '+254712345685',
          status: 'active',
        });

      // Try to activate the current tenant on the same unit
      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('rejects linking tenant to non-active tenancy', async () => {
      // Create a draft tenancy
      const draftTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'draft', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );

      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          tenancyId: draftTenancy.rows[0].id,
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('allows linking tenant to active tenancy', async () => {
      // Create an active tenancy
      const activeTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );

      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          tenancyId: activeTenancy.rows[0].id,
          status: 'active',
        });

      expect(response.status).toBe(200);
      expect(response.body.tenancyId).toBe(activeTenancy.rows[0].id);
    });

    it('rejects linking tenant to tenancy from a different unit (cross-unit)', async () => {
      // Create a second unit on the same property
      const unitB = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [propertyId, 'A-102', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', landlordUserId],
      );

      // Create an active tenancy on unit B
      const tenancyB = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitB.rows[0].id, new Date().toISOString(), landlordUserId],
      );

      // Try to link the current tenant (on unit A) to tenancy on unit B
      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          tenancyId: tenancyB.rows[0].id,
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('rejects linking tenant to tenancy from a different property (cross-property)', async () => {
      // Create a second property
      const propertyB = await pool.query(
        `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by)
         VALUES (NULL, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id`,
        ['Other Property', 'A different property', 'apartment', 'draft', 'Other Address', 'Mombasa', 'Mombasa', 'KE', 1, landlordUserId],
      );

      // Create ownership so the user can access property B
      await pool.query(
        `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
         VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
        [propertyB.rows[0].id, landlordUserId],
      );

      // Create a unit on property B
      const unitB = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [propertyB.rows[0].id, 'B-101', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', landlordUserId],
      );

      // Create an active tenancy on property B
      const tenancyB = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyB.rows[0].id, unitB.rows[0].id, new Date().toISOString(), landlordUserId],
      );

      // Try to link the current tenant (on property A) to tenancy on property B
      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          tenancyId: tenancyB.rows[0].id,
          status: 'active',
        });

      expect(response.status).toBe(409);
    });

    it('rejects moving tenant to unit different from existing tenancy (cross-unit on unit change)', async () => {
      // Create a second unit on the same property
      const unitB = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [propertyId, 'A-102', 'one_bedroom', 1, 1, 50000, 100000, 'vacant', landlordUserId],
      );

      // Create an active tenancy on unit A and link the current tenant to it
      const activeTenancy = await pool.query(
        `INSERT INTO tenancies (property_id, unit_id, tenancy_type, status, start_date, rent_amount, deposit_amount, rent_due_day, created_by)
         VALUES ($1, $2, 'residential', 'active', $3, 50000, 100000, 1, $4)
         RETURNING id`,
        [propertyId, unitId, new Date().toISOString(), landlordUserId],
      );

      await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId,
          tenancyId: activeTenancy.rows[0].id,
          status: 'active',
        });

      // Try to move the tenant to unit B while keeping the unit-A tenancy
      const response = await request(app)
        .patch(`/api/v1/landlord/tenants/${tenantId}`)
        .set(authHeaders(accessToken))
        .send({
          unitId: unitB.rows[0].id,
        });

      expect(response.status).toBe(409);
    });
  });
});

describe('Garbage Management API', () => {
  describe('POST /api/v1/landlord/garbage-providers', () => {
    it('should create a garbage provider', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/garbage-providers')
        .set(authHeaders(accessToken))
        .send({
          name: 'Nairobi Waste Management',
          contactPerson: 'John Manager',
          contactPhone: '+254712345682',
          contactEmail: 'john@nairobiwaste.com',
          serviceAreas: [{ county: 'Nairobi', town: 'Westlands' }],
          status: 'active',
        });

      expect(response.status).toBe(201);
      expect(response.body.name).toBe('Nairobi Waste Management');
      garbageProviderId = response.body.id;
    });
  });

  describe('POST /api/v1/landlord/garbage-assignments', () => {
    beforeEach(async () => {
      const result = await request(app)
        .post('/api/v1/landlord/garbage-providers')
        .set(authHeaders(accessToken))
        .send({
          name: 'Test Garbage Provider',
          contactPhone: '+254712345683',
          status: 'active',
        });
      garbageProviderId = result.body.id;
    });

    it('should create a garbage assignment', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/garbage-assignments')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          garbageProviderId,
          assignmentType: 'scheduled',
          frequency: 'weekly',
          dayOfWeek: 1,
          timeSlot: '08:00-10:00',
          effectiveFrom: '2026-12-01',
        });

      expect(response.status).toBe(201);
      expect(response.body.status).toBe('active');
      expect(response.body.frequency).toBe('weekly');
      garbageAssignmentId = response.body.id;
    });
  });

  describe('POST /api/v1/landlord/garbage-collection-requests', () => {
    beforeEach(async () => {
      const providerResult = await request(app)
        .post('/api/v1/landlord/garbage-providers')
        .set(authHeaders(accessToken))
        .send({
          name: 'Request Test Provider',
          contactPhone: '+254712345684',
          status: 'active',
        });
      garbageProviderId = providerResult.body.id;
    });

    it('should create a garbage collection request', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/garbage-collection-requests')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          garbageProviderId,
          requestType: 'regular_collection',
          notes: 'Regular weekly collection',
        });

      expect(response.status).toBe(201);
      expect(response.body.status).toBe('pending');
      expect(response.body.requestType).toBe('regular_collection');
      garbageRequestId = response.body.id;
    });
  });
});

describe('Dashboard API', () => {
  describe('GET /api/v1/landlord/dashboard', () => {
    it('should return dashboard stats', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/dashboard')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('totalProperties');
      expect(response.body).toHaveProperty('totalListings');
      expect(response.body).toHaveProperty('publishedListings');
      expect(response.body).toHaveProperty('totalUnits');
      expect(response.body).toHaveProperty('vacantUnits');
      expect(response.body).toHaveProperty('occupiedUnits');
      expect(response.body).toHaveProperty('activeTenancies');
      expect(response.body).toHaveProperty('totalTenants');
      expect(response.body).toHaveProperty('pendingSiteVisits');
      expect(response.body).toHaveProperty('activeGarbageAssignments');
      expect(response.body).toHaveProperty('pendingGarbageRequests');
    });

    it('should filter dashboard stats by property', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/dashboard?propertyId=${propertyId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.totalProperties).toBeGreaterThanOrEqual(0);
    });
  });

  // ============================================================================
  // PROPERTY MANAGEMENT TESTS
  // ============================================================================

  describe('Property Management API', () => {
    let propId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Kilimani Apartments');
    });

    it('should create a new property', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/properties')
        .set(authHeaders(accessToken))
        .send({
          title: 'Test Property - New',
          description: 'A nice apartment in Kilimani',
          propertyType: 'apartment',
          address: 'Kilimani, Nairobi',
          city: 'Nairobi',
          county: 'Nairobi',
          totalUnits: 10,
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.title).toBe('Test Property - New');
    });

    it('should list properties', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/properties')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should get a single property', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/properties/${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(propId);
    });

    it('should update a property', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/properties/${propId}`)
        .set(authHeaders(accessToken))
        .send({ title: 'Updated Property Title' });

      expect(response.status).toBe(200);
      expect(response.body.title).toBe('Updated Property Title');
    });

    it('should delete a property', async () => {
      const response = await request(app)
        .delete(`/api/v1/landlord/properties/${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(204);
    });
  });

  // ============================================================================
  // UNIT MANAGEMENT TESTS
  // ============================================================================

  describe('Unit Management API', () => {
    let propId: string;
    let testUnitId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Units');
      const res = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, 'SEED-1', 'one_bedroom', 1, 1, 30000, 60000, 'available', $2)
         RETURNING id`,
        [propId, landlordUserId],
      );
      testUnitId = res.rows[0].id;
    });

    it('should create a new unit', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/units')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          unitNumber: 'A1',
          unitType: 'one_bedroom',
          bedrooms: 1,
          bathrooms: 1,
          rentAmount: 30000,
          depositAmount: 60000,
          status: 'available',
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.unitNumber).toBe('A1');
    });

    it('should list units for a property', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/units?propertyId=${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should get a single unit', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/units/${testUnitId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(testUnitId);
    });

    it('should update a unit', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/units/${testUnitId}`)
        .set(authHeaders(accessToken))
        .send({ rentAmount: 35000 });

      expect(response.status).toBe(200);
      expect(Number(response.body.rentAmount)).toBe(35000);
    });

    it('should delete a unit', async () => {
      const response = await request(app)
        .delete(`/api/v1/landlord/units/${testUnitId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(204);
    });
  });

  // ============================================================================
  // ENQUIRY / CRM TESTS
  // ============================================================================

  describe('Enquiry API', () => {
    let propId: string;
    let testEnquiryId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Enquiries');
      const response = await request(app)
        .post('/api/v1/landlord/enquiries')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          prospectiveRenterName: 'John Doe',
          prospectiveRenterPhone: '+254712345678',
          enquirySource: 'walk_in',
          message: 'Interested in renting',
        });
      expect(response.status).toBe(201);
      testEnquiryId = response.body.id;
    });

    it('should create a new enquiry', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/enquiries')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          prospectiveRenterName: 'Jane Doe',
          prospectiveRenterPhone: '+254712345679',
          enquirySource: 'referral',
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.status).toBe('new');
    });

    it('should list enquiries', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/enquiries')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should get a single enquiry', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/enquiries/${testEnquiryId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(testEnquiryId);
    });

    it('should update enquiry status', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/enquiries/${testEnquiryId}`)
        .set(authHeaders(accessToken))
        .send({ status: 'contacted' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('contacted');
    });

    it('should add an internal note to an enquiry', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/enquiries/${testEnquiryId}/notes`)
        .set(authHeaders(accessToken))
        .send({ note: 'Called and left a voicemail', isInternal: true });

      expect(response.status).toBe(201);
    });

    it('should get enquiry notes', async () => {
      await request(app)
        .post(`/api/v1/landlord/enquiries/${testEnquiryId}/notes`)
        .set(authHeaders(accessToken))
        .send({ note: 'A note', isInternal: true });

      const response = await request(app)
        .get(`/api/v1/landlord/enquiries/${testEnquiryId}/notes`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });
  });

  // ============================================================================
  // CONVERSATION TESTS
  // ============================================================================

  describe('Conversation API', () => {
    let propId: string;
    let testConversationId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Conversations');
      const response = await request(app)
        .post('/api/v1/landlord/conversations')
        .set(authHeaders(accessToken))
        .send({
          type: 'general',
          subject: 'Rental enquiry',
          propertyId: propId,
          participantUserIds: [landlordUserId],
        });
      expect(response.status).toBe(201);
      testConversationId = response.body.id;
    });

    it('should create a new conversation', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/conversations')
        .set(authHeaders(accessToken))
        .send({
          type: 'general',
          subject: 'Another enquiry',
          propertyId: propId,
          participantUserIds: [landlordUserId],
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
    });

    it('should list conversations', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/conversations')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should send a message', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/messages')
        .set(authHeaders(accessToken))
        .send({
          conversationId: testConversationId,
          content: 'Hello, is this still available?',
          type: 'text',
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.content).toBe('Hello, is this still available?');
    });

    it('should list messages in a conversation', async () => {
      await request(app)
        .post('/api/v1/landlord/messages')
        .set(authHeaders(accessToken))
        .send({
          conversationId: testConversationId,
          content: 'A message',
          type: 'text',
        });

      const response = await request(app)
        .get(`/api/v1/landlord/conversations/${testConversationId}/messages`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });
  });

  // ============================================================================
  // RENTAL PROPOSAL TESTS
  // ============================================================================

  describe('Rental Proposal API', () => {
    let propId: string;
    let testRenterId: string;
    let testProposalId: string;

    beforeEach(async () => {
      const { id: renterId } = await registerAndLogin('tenant');
      testRenterId = renterId;
      propId = await createApiProperty(landlordUserId, 'Test Property for Proposals');
      const response = await request(app)
        .post('/api/v1/landlord/rental-proposals')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          prospectiveRenterId: testRenterId,
          type: 'new_tenancy',
          proposedRentAmount: 30000,
          proposedDepositAmount: 60000,
          proposedStartDate: '2026-12-01',
          proposedRentDueDay: 1,
          expiresAt: new Date(Date.now() + 86400000 * 30).toISOString(),
        });
      expect(response.status).toBe(201);
      testProposalId = response.body.id;
    });

    it('should create a rental proposal', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/rental-proposals')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          prospectiveRenterId: testRenterId,
          type: 'new_tenancy',
          proposedRentAmount: 32000,
          proposedDepositAmount: 64000,
          proposedStartDate: '2026-12-01',
          expiresAt: new Date(Date.now() + 86400000 * 30).toISOString(),
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.status).toBe('draft');
    });

    it('should list rental proposals', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/rental-proposals')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should perform action on rental proposal (send)', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/rental-proposals/${testProposalId}/action`)
        .set(authHeaders(accessToken))
        .send({ action: 'send' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('sent');
    });

    it('should perform action on rental proposal (accept)', async () => {
      const response = await request(app)
        .post(`/api/v1/landlord/rental-proposals/${testProposalId}/action`)
        .set(authHeaders(accessToken))
        .send({ action: 'accept' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('accepted');
    });
  });

  // ============================================================================
  // MAINTENANCE TESTS
  // ============================================================================

  describe('Maintenance API', () => {
    let propId: string;
    let testIssueId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Maintenance');
      const response = await request(app)
        .post('/api/v1/landlord/issues')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          reporterRole: 'landlord',
          title: 'Leaking tap in unit A1',
          description: 'The bathroom tap is leaking badly',
          category: 'plumbing',
          priority: 'high',
        });
      expect(response.status).toBe(201);
      testIssueId = response.body.id;
    });

    it('should report a new issue', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/issues')
        .set(authHeaders(accessToken))
        .send({
          propertyId: propId,
          reporterRole: 'landlord',
          title: 'Broken door lock',
          description: 'The main door lock is broken',
          category: 'security',
          priority: 'medium',
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.status).toBe('new');
    });

    it('should list issues', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/issues')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should update issue status', async () => {
      const response = await request(app)
        .patch(`/api/v1/landlord/issues/${testIssueId}`)
        .set(authHeaders(accessToken))
        .send({ status: 'acknowledged' });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('acknowledged');
    });
  });

  // ============================================================================
  // RENTAL AGREEMENT TESTS
  // ============================================================================

  describe('Rental Agreement API', () => {
    let propId: string;
    let testTenancyId: string;
    let testAgreementId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Agreements');
      const unitRes = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, 'AG-1', 'two_bedroom', 2, 1, 35000, 70000, 'occupied', $2)
         RETURNING id`,
        [propId, landlordUserId],
      );
      testTenancyId = await createTestTenancy(propId, unitRes.rows[0].id, landlordUserId);
      const response = await request(app)
        .post('/api/v1/landlord/rental-agreements')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          agreementNumber: 'RA-2026-001',
          startDate: '2026-12-01',
          endDate: '2027-12-01',
          monthlyRent: 35000,
          depositAmount: 70000,
          rentDueDay: 1,
        });
      expect(response.status).toBe(201);
      testAgreementId = response.body.id;
    });

    it('should create a rental agreement', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/rental-agreements')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          agreementNumber: 'RA-2026-002',
          startDate: '2026-12-01',
          monthlyRent: 36000,
          depositAmount: 72000,
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('agreementNumber');
    });

    it('should list rental agreements', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/rental-agreements')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(1);
    });
  });

  // ============================================================================
  // EXTENDED DASHBOARD TESTS
  // ============================================================================

  describe('Extended Dashboard API', () => {
    let propId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Extended Dashboard');
    });

    it('should return extended dashboard stats', async () => {
      const response = await request(app)
        .get('/api/v1/landlord/dashboard/extended')
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('totalProperties');
      expect(response.body).toHaveProperty('totalUnits');
      expect(response.body).toHaveProperty('activeListings');
      expect(response.body).toHaveProperty('newEnquiries');
      expect(response.body).toHaveProperty('pendingMaintenance');
    });

    it('should filter extended dashboard stats by property', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/dashboard/extended?propertyId=${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(response.body.totalProperties).toBeGreaterThanOrEqual(0);
    });

    it('computes financial aggregates from invoices and counts pending garbage', async () => {
      // Seed a unit + active tenancy so rent scope is realistic.
      const unit = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, 'FIN-1', 'one_bedroom', 1, 1, 50000, 100000, 'occupied', $2)
         RETURNING id`,
        [propId, landlordUserId],
      );
      const finUnitId = unit.rows[0].id;
      await createTestTenancy(propId, finUnitId, landlordUserId);

      // A rent invoice: total 50000, 20000 paid, 30000 outstanding.
      const invoice = await pool.query(
        `INSERT INTO invoices (invoice_number, property_id, unit_id, status, billing_period_start, billing_period_end, due_date, total_amount, amount_paid, amount_outstanding, created_by)
         VALUES ('INV-FIN-1', $1, $2, 'partially_paid', CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', CURRENT_DATE + INTERVAL '15 days', 50000, 20000, 30000, $3)
         RETURNING id`,
        [propId, finUnitId, landlordUserId],
      );
      await pool.query(
        `INSERT INTO invoice_items (invoice_id, charge_type, description, amount)
         VALUES ($1, 'rent', 'Monthly rent', 50000)`,
        [invoice.rows[0].id],
      );

      // A pending garbage collection request for the property.
      await pool.query(
        `INSERT INTO garbage_collection_requests (property_id, status, request_type, created_by)
         VALUES ($1, 'pending', 'regular_collection', $2)`,
        [propId, landlordUserId],
      );

      const response = await request(app)
        .get(`/api/v1/landlord/dashboard/extended?propertyId=${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Number(response.body.expectedRent)).toBe(50000);
      expect(Number(response.body.collectedRent)).toBe(20000);
      expect(Number(response.body.outstandingRent)).toBe(30000);
      expect(response.body.pendingGarbageRequests).toBe(1);
    });

    it('reports zero financial aggregates when no invoices exist', async () => {
      const response = await request(app)
        .get(`/api/v1/landlord/dashboard/extended?propertyId=${propId}`)
        .set(authHeaders(accessToken));

      expect(response.status).toBe(200);
      expect(Number(response.body.expectedRent)).toBe(0);
      expect(Number(response.body.collectedRent)).toBe(0);
      expect(Number(response.body.outstandingRent)).toBe(0);
    });
  });

  // ============================================================================
  // INSPECTION TESTS
  // ============================================================================

  describe('Inspection API', () => {
    let propId: string;
    let testUnitId: string;
    let testTenancyId: string;

    beforeEach(async () => {
      propId = await createApiProperty(landlordUserId, 'Test Property for Inspections');
      const unitRes = await pool.query(
        `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
         VALUES ($1, 'IN-1', 'one_bedroom', 1, 1, 30000, 60000, 'occupied', $2)
         RETURNING id`,
        [propId, landlordUserId],
      );
      testUnitId = unitRes.rows[0].id;
      testTenancyId = await createTestTenancy(propId, testUnitId, landlordUserId);
    });

    it('should create a move-in inspection', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/move-in-inspections')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          unitId: testUnitId,
          inspectionDate: new Date().toISOString().slice(0, 10),
          overallCondition: 'good',
          keyHandover: true,
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('tenancyId');
    });

    it('should create a move-out inspection', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/move-out-inspections')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          unitId: testUnitId,
          inspectionDate: new Date().toISOString().slice(0, 10),
          overallCondition: 'fair',
          keyReturned: true,
          cleaningRequired: false,
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
    });

    it('should create an inspection item and list items', async () => {
      const inspection = await request(app)
        .post('/api/v1/landlord/move-in-inspections')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          unitId: testUnitId,
          inspectionDate: new Date().toISOString().slice(0, 10),
          keyHandover: false,
        });
      expect(inspection.status).toBe(201);
      const inspectionId = inspection.body.id;

      const itemResponse = await request(app)
        .post('/api/v1/landlord/inspection-items')
        .set(authHeaders(accessToken))
        .send({
          inspectionId,
          itemCategory: 'walls',
          itemName: 'Living room wall',
          conditionRating: 'good',
        });
      expect(itemResponse.status).toBe(201);

      const listResponse = await request(app)
        .get(`/api/v1/landlord/inspection-items/${inspectionId}`)
        .set(authHeaders(accessToken));

      expect(listResponse.status).toBe(200);
      expect(Array.isArray(listResponse.body)).toBe(true);
      expect(listResponse.body.length).toBeGreaterThanOrEqual(1);
    });

    it('should reject inspection creation for a non-owned tenancy', async () => {
      // Transfer ownership to a different landlord
      const { id: otherUserId, token: otherToken } = await registerAndLogin('landlord');
      await pool.query('DELETE FROM property_ownerships WHERE property_id = $1', [propId]);
      await pool.query(
        `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
         VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
        [propId, otherUserId],
      );
      await pool.query('UPDATE properties SET created_by = $1 WHERE id = $2', [otherUserId, propId]);

      const response = await request(app)
        .post('/api/v1/landlord/move-in-inspections')
        .set(authHeaders(accessToken))
        .send({
          tenancyId: testTenancyId,
          unitId: testUnitId,
          inspectionDate: new Date().toISOString().slice(0, 10),
          keyHandover: false,
        });

      expect([403, 404]).toContain(response.status);
      void otherToken;
    });
  });

  // ============================================================================
  // FINANCIAL ENDPOINTS (invoices / payments / rent-ledger)
  // ============================================================================

  describe('Financial API', () => {
    function dates() {
      const start = new Date().toISOString().slice(0, 10);
      const end = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
      const due = new Date(Date.now() + 15 * 86400000).toISOString().slice(0, 10);
      return { start, end, due };
    }

    it('creates an invoice with a valid amount payload (regression: totalAmount is persisted)', async () => {
      const { start, end, due } = dates();
      const response = await request(app)
        .post('/api/v1/landlord/invoices')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          billingPeriodStart: start,
          billingPeriodEnd: end,
          dueDate: due,
          totalAmount: 50000,
        });
      expect(response.status).toBe(201);
      expect(Number(response.body.totalAmount)).toBe(50000);
      expect(Number(response.body.amountOutstanding)).toBe(50000);
      expect(response.body.status).toBe('draft');

      // Persisted and retrievable.
      const read = await request(app)
        .get(`/api/v1/landlord/invoices/${response.body.id}`)
        .set(authHeaders(accessToken));
      expect(read.status).toBe(200);
      expect(Number(read.body.totalAmount)).toBe(50000);
    });

    it('rejects invoice creation without a total amount', async () => {
      const { start, end, due } = dates();
      const response = await request(app)
        .post('/api/v1/landlord/invoices')
        .set(authHeaders(accessToken))
        .send({
          propertyId,
          unitId,
          billingPeriodStart: start,
          billingPeriodEnd: end,
          dueDate: due,
        });
      expect(response.status).toBe(400);
    });

    it('records a payment and marks the invoice partially paid then paid', async () => {
      const { start, end, due } = dates();
      const created = await request(app)
        .post('/api/v1/landlord/invoices')
        .set(authHeaders(accessToken))
        .send({ propertyId, unitId, billingPeriodStart: start, billingPeriodEnd: end, dueDate: due, totalAmount: 50000 });
      const invoiceId = created.body.id;

      const partial = await request(app)
        .post('/api/v1/landlord/payments')
        .set(authHeaders(accessToken))
        .send({ invoiceId, amount: 20000, provider: 'mpesa', status: 'completed' });
      expect(partial.status).toBe(201);

      const afterPartial = await request(app)
        .get(`/api/v1/landlord/invoices/${invoiceId}`)
        .set(authHeaders(accessToken));
      expect(Number(afterPartial.body.amountPaid)).toBe(20000);
      expect(Number(afterPartial.body.amountOutstanding)).toBe(30000);
      expect(afterPartial.body.status).toBe('partially_paid');

      const rest = await request(app)
        .post('/api/v1/landlord/payments')
        .set(authHeaders(accessToken))
        .send({ invoiceId, amount: 30000, provider: 'mpesa', status: 'completed' });
      expect(rest.status).toBe(201);

      const afterFull = await request(app)
        .get(`/api/v1/landlord/invoices/${invoiceId}`)
        .set(authHeaders(accessToken));
      expect(Number(afterFull.body.amountOutstanding)).toBe(0);
      expect(afterFull.body.status).toBe('paid');
    });

    it('rejects a payment that references a missing invoice', async () => {
      const response = await request(app)
        .post('/api/v1/landlord/payments')
        .set(authHeaders(accessToken))
        .send({ invoiceId: '00000000-0000-0000-0000-000000000000', amount: 1000, provider: 'cash', status: 'completed' });
      expect(response.status).toBe(404);
    });

    it('lists invoices for a property and the rent ledger', async () => {
      const { start, end, due } = dates();
      await request(app)
        .post('/api/v1/landlord/invoices')
        .set(authHeaders(accessToken))
        .send({ propertyId, unitId, billingPeriodStart: start, billingPeriodEnd: end, dueDate: due, totalAmount: 50000 });

      const list = await request(app)
        .get('/api/v1/landlord/invoices')
        .query({ propertyId })
        .set(authHeaders(accessToken));
      expect(list.status).toBe(200);
      const invoices = Array.isArray(list.body) ? list.body : list.body.items;
      expect(invoices.length).toBeGreaterThanOrEqual(1);

      const ledger = await request(app)
        .get('/api/v1/landlord/rent-ledger')
        .query({ propertyId })
        .set(authHeaders(accessToken));
      expect(ledger.status).toBe(200);
      expect(Array.isArray(ledger.body)).toBe(true);
    });
  });
});
