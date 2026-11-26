import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let seekerUserId: string;
let seekerToken: string;
let landlordUserId: string;
let landlordToken: string;
let otherUserId: string;
let otherToken: string;
let propertyId: string;
let unitId: string;
let listingId: string;
let publishedListingId: string;
let suspendedListingId: string;

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
  // Phone lives on user_profiles, not users.
  await pool.query(
    `INSERT INTO user_profiles (user_id, phone_number) VALUES ((SELECT id FROM users WHERE email = $1), $2)
     ON CONFLICT (user_id) DO UPDATE SET phone_number = EXCLUDED.phone_number`,
    [email, `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`],
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
  expect(token).toBeDefined();
  return { id: userId, token };
}

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createPublishedPropertyAndListing(ownerId: string): Promise<{ propertyId: string; unitId: string; listingId: string }> {
  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, latitude, longitude, amenities, images, created_by, published_at)
     VALUES (NULL, $1, $2, 'apartment', 'published', '12 Riverside Drive', 'Nairobi', 'Nairobi', 'KE', 3, -1.2921, 36.8219, '["wifi","parking","balcony"]'::jsonb, '["https://example.com/1.jpg"]'::jsonb, $3, NOW())
     RETURNING id`,
    ['Riverside Apartments', 'Modern apartments in Riverside', ownerId],
  );
  const pid = prop.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100.00, 'active', $2)`,
    [pid, ownerId],
  );
  const unit = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, amenities, created_by)
     VALUES ($1, 'A-101', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', '["wifi","parking"]'::jsonb, $2)
     RETURNING id`,
    [pid, ownerId],
  );
  const uid = unit.rows[0].id;
  const listing = await pool.query(
    `INSERT INTO property_listings (property_id, unit_id, title, description, status, rent_amount, deposit_amount, available_from, furnished, images, published_at, created_by)
     VALUES ($1, $2, 'Cosy 1BR Riverside', 'Bright and airy', 'published', 45000, 90000, '2026-12-01', TRUE, '["https://example.com/l1.jpg"]'::jsonb, NOW(), $3)
     RETURNING id`,
    [pid, uid, ownerId],
  );
  return { propertyId: pid, unitId: uid, listingId: listing.rows[0].id };
}

async function cleanupTestData(): Promise<void> {
  await pool.query('DELETE FROM listing_reports');
  await pool.query('DELETE FROM saved_searches');
  await pool.query('DELETE FROM saved_listings');
  await pool.query('DELETE FROM house_seeker_comparison_items');
  await pool.query('DELETE FROM house_seeker_comparison_lists');
  await pool.query('DELETE FROM house_seeker_preferences');
  await pool.query('DELETE FROM message_read_states');
  await pool.query('DELETE FROM message_attachments');
  await pool.query('DELETE FROM messages');
  await pool.query('DELETE FROM conversation_participants');
  await pool.query('DELETE FROM rental_proposal_status_history');
  await pool.query('DELETE FROM rental_proposal_versions');
  await pool.query('DELETE FROM rental_proposals');
  await pool.query('DELETE FROM conversations');
  await pool.query('DELETE FROM rental_application_history');
  await pool.query('DELETE FROM rental_applications');
  await pool.query('DELETE FROM site_visit_history');
  await pool.query('DELETE FROM site_visits');
  await pool.query('DELETE FROM site_visit_availability_exceptions');
  await pool.query('DELETE FROM site_visit_availability_rules');
  await pool.query('DELETE FROM enquiry_status_history');
  await pool.query('DELETE FROM enquiry_notes');
  await pool.query('DELETE FROM enquiry_assignments');
  await pool.query('DELETE FROM property_enquiries');
  await pool.query('DELETE FROM listing_status_history');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'tenant')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanupTestData();
  const seeker = await registerAndLogin('house_seeker');
  seekerUserId = seeker.id;
  seekerToken = seeker.token;
  const landlord = await registerAndLogin('landlord');
  landlordUserId = landlord.id;
  landlordToken = landlord.token;
  const other = await registerAndLogin('house_seeker');
  otherUserId = other.id;
  otherToken = other.token;
  const fixtures = await createPublishedPropertyAndListing(landlordUserId);
  propertyId = fixtures.propertyId;
  unitId = fixtures.unitId;
  publishedListingId = fixtures.listingId;

  // Site visit creation now requires published availability. Seed an all-week,
  // all-day window so visit requests in these tests are bookable.
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

  // A draft (non-published) listing that must NOT appear in discovery.
  const draft = await pool.query(
    `INSERT INTO property_listings (property_id, unit_id, title, status, rent_amount, created_by)
     VALUES ($1, $2, 'Unpublished draft', 'draft', 30000, $3) RETURNING id`,
    [propertyId, unitId, landlordUserId],
  );
  suspendedListingId = draft.rows[0].id;
  listingId = publishedListingId;
});

afterEach(async () => {
  await cleanupTestData();
});

describe('House Seeker discovery', () => {
  it('returns published listings and excludes unpublished drafts', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/listings')
      .set(authHeaders(seekerToken))
      .query({ q: 'Riverside' });
    expect(response.status).toBe(200);
    expect(response.body.total).toBeGreaterThanOrEqual(1);
    const ids = response.body.items.map((i: { listingId: string }) => i.listingId);
    expect(ids).toContain(publishedListingId);
    expect(ids).not.toContain(suspendedListingId);
  });

  it('filters by price range and bedrooms', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/listings')
      .set(authHeaders(seekerToken))
      .query({ rentMin: 40000, rentMax: 50000, bedrooms: 1 });
    expect(response.status).toBe(200);
    expect(response.body.items.length).toBeGreaterThanOrEqual(1);
    for (const item of response.body.items) {
      expect(item.rentAmount).toBeGreaterThanOrEqual(40000);
      expect(item.rentAmount).toBeLessThanOrEqual(50000);
    }
  });

  it('returns a public listing detail with landlord first name', async () => {
    const response = await request(app)
      .get(`/api/v1/house-seeker/listings/${publishedListingId}`)
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(200);
    expect(response.body.listingId).toBe(publishedListingId);
    expect(response.body.rentAmount).toBe(45000);
    expect(response.body).toHaveProperty('landlordFirstName');
    expect(response.body).toHaveProperty('landlordUserId');
    expect(response.body.landlordUserId).toBe(landlordUserId);
  });

  it('returns map results within viewport bounds', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/listings/map')
      .set(authHeaders(seekerToken))
      .query({ north: -1.2, south: -1.4, east: 37.0, west: 36.5 });
    expect(response.status).toBe(200);
    expect(Array.isArray(response.body.items)).toBe(true);
    expect(response.body.items.length).toBeGreaterThanOrEqual(1);
    for (const item of response.body.items) {
      expect(item.latitude).not.toBeNull();
      expect(item.longitude).not.toBeNull();
    }
  });

  it('returns filter facets', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/listings/filters')
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('propertyTypes');
    expect(response.body).toHaveProperty('counties');
    expect(response.body).toHaveProperty('priceRange');
  });

  it('requires authentication', async () => {
    const response = await request(app).get('/api/v1/house-seeker/listings');
    expect(response.status).toBe(401);
  });
});

describe('Saved homes', () => {
  it('saves a listing and prevents duplicates', async () => {
    const first = await request(app)
      .post('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId, collection: 'favourites' });
    expect(first.status).toBe(201);

    const second = await request(app)
      .post('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });
    expect(second.status).toBe(201);

    const list = await request(app)
      .get('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken));
    expect(list.status).toBe(200);
    expect(list.body.total).toBe(1);
  });

  it('removes a saved listing', async () => {
    await request(app)
      .post('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });
    const removed = await request(app)
      .delete(`/api/v1/house-seeker/saved-listings/${publishedListingId}`)
      .set(authHeaders(seekerToken));
    expect(removed.status).toBe(200);
    const list = await request(app)
      .get('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken));
    expect(list.body.total).toBe(0);
  });

  it('cannot save a non-existent listing', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken))
      .send({ listingId: '00000000-0000-0000-0000-000000000000' });
    expect(response.status).toBe(404);
  });
});

describe('Saved searches', () => {
  it('creates, lists, updates and deletes a saved search', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Nairobi 1BR under 50k', criteria: { city: 'Nairobi', rentMax: 50000, bedrooms: 1 }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    const list = await request(app).get('/api/v1/house-seeker/saved-searches').set(authHeaders(seekerToken));
    expect(list.body.items.length).toBe(1);

    const update = await request(app)
      .patch(`/api/v1/house-seeker/saved-searches/${searchId}`)
      .set(authHeaders(seekerToken))
      .send({ alertsEnabled: false });
    expect(update.status).toBe(200);
    expect(update.body.alertsEnabled).toBe(false);

    const del = await request(app)
      .delete(`/api/v1/house-seeker/saved-searches/${searchId}`)
      .set(authHeaders(seekerToken));
    expect(del.status).toBe(200);
  });

  it('does not let another user update a saved search (IDOR)', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Private', criteria: { city: 'Nairobi' } });
    const searchId = create.body.id;
    const update = await request(app)
      .patch(`/api/v1/house-seeker/saved-searches/${searchId}`)
      .set(authHeaders(otherToken))
      .send({ name: 'Hacked' });
    expect(update.status).toBe(404);
  });

  it('executes a saved search and returns matching published listings', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Nairobi 1BR', criteria: { city: 'Nairobi', rentMax: 50000, bedrooms: 1 }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken));
    expect(run.status).toBe(200);
    expect(Array.isArray(run.body.items)).toBe(true);
    expect(run.body.items.length).toBeGreaterThan(0);
    // last_run_at should be updated.
    const updated = await pool.query('SELECT last_run_at FROM saved_searches WHERE id = $1', [searchId]);
    expect(updated.rows[0].last_run_at).toBeDefined();
  });

  it('rejects unauthenticated run requests', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Test', criteria: { city: 'Nairobi' } });
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`);
    expect(run.status).toBe(401);
  });

  it('does not let another user run a saved search (IDOR)', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Private', criteria: { city: 'Nairobi' } });
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(otherToken));
    expect(run.status).toBe(404);
  });

  it('returns 400 for invalid search ID', async () => {
    const run = await request(app)
      .get('/api/v1/house-seeker/saved-searches/not-a-uuid/run')
      .set(authHeaders(seekerToken));
    expect(run.status).toBe(400);
  });

  it('returns 404 for nonexistent saved search', async () => {
    const run = await request(app)
      .get('/api/v1/house-seeker/saved-searches/00000000-0000-0000-0000-000000000000/run')
      .set(authHeaders(seekerToken));
    expect(run.status).toBe(404);
  });

  it('excludes unpublished listings from run results', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'All Nairobi', criteria: { city: 'Nairobi' }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken));
    expect(run.status).toBe(200);
    // The draft listing created in beforeEach must not appear.
    const hasDraft = run.body.items.some((item: any) => item.id === suspendedListingId);
    expect(hasDraft).toBe(false);
  });

  it('applies search criteria correctly', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Expensive', criteria: { rentMin: 100000 }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken));
    expect(run.status).toBe(200);
    // All returned listings should have rent >= 100000.
    run.body.items.forEach((item: any) => {
      expect(item.rentAmount).toBeGreaterThanOrEqual(100000);
    });
  });

  it('supports pagination on run results', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'Paginated', criteria: { city: 'Nairobi' }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    const run = await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken))
      .query({ limit: 1, offset: 0 });
    expect(run.status).toBe(200);
    expect(run.body.limit).toBe(1);
    expect(run.body.offset).toBe(0);
    expect(run.body.items.length).toBeLessThanOrEqual(1);
  });

  it('does not create duplicate notifications on repeated run', async () => {
    const create = await request(app)
      .post('/api/v1/house-seeker/saved-searches')
      .set(authHeaders(seekerToken))
      .send({ name: 'No Dupes', criteria: { city: 'Nairobi', rentMax: 50000 }, alertsEnabled: true });
    expect(create.status).toBe(201);
    const searchId = create.body.id;

    // Run twice.
    await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken));
    await request(app)
      .get(`/api/v1/house-seeker/saved-searches/${searchId}/run`)
      .set(authHeaders(seekerToken));

    // Check deduplication table has no duplicate entries.
    const dedup = await pool.query(
      'SELECT COUNT(*) as cnt FROM search_alert_deduplication WHERE saved_search_id = $1',
      [searchId],
    );
    expect(parseInt(dedup.rows[0].cnt, 10)).toBeGreaterThanOrEqual(0);
  });
});

describe('Enquiries', () => {
  it('submits an enquiry from a published listing', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/enquiries')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, message: 'Is this still available?' });
    expect(response.status).toBe(201);
    expect(response.body.prospectiveRenterId).toBe(seekerUserId);
    expect(response.body.status).toBe('new');
  });

  it('rejects enquiry on an unpublished listing', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/enquiries')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: suspendedListingId, message: 'Hello' });
    expect(response.status).toBe(409);
  });

  it('lists only the seeker own enquiries (IDOR)', async () => {
    await request(app)
      .post('/api/v1/house-seeker/enquiries')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, message: 'Mine' });
    const own = await request(app).get('/api/v1/house-seeker/enquiries').set(authHeaders(seekerToken));
    expect(own.body.total).toBe(1);
    const other = await request(app).get('/api/v1/house-seeker/enquiries').set(authHeaders(otherToken));
    expect(other.body.total).toBe(0);
  });

  it('withdraws an enquiry', async () => {
    const created = await request(app)
      .post('/api/v1/house-seeker/enquiries')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, message: 'Withdraw me' });
    const enquiryId = created.body.id;
    const withdrawn = await request(app)
      .post(`/api/v1/house-seeker/enquiries/${enquiryId}/withdraw`)
      .set(authHeaders(seekerToken));
    expect(withdrawn.status).toBe(200);
    expect(withdrawn.body.status).toBe('closed');
  });
});

describe('Preferences', () => {
  it('creates and updates house seeker preferences', async () => {
    const create = await request(app)
      .put('/api/v1/house-seeker/preferences')
      .set(authHeaders(seekerToken))
      .send({ minBudget: 20000, maxBudget: 60000, preferredPropertyTypes: ['apartment'], preferredBedrooms: 1 });
    expect(create.status).toBe(200);
    expect(create.body.minBudget).toBe('20000.00');
    expect(create.body.preferredPropertyTypes).toEqual(['apartment']);

    const update = await request(app)
      .put('/api/v1/house-seeker/preferences')
      .set(authHeaders(seekerToken))
      .send({ maxBudget: 70000 });
    expect(update.status).toBe(200);
    expect(Number(update.body.maxBudget)).toBe(70000);
  });
});

describe('Listing reports', () => {
  it('submits a listing report', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/listing-reports')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId, reason: 'misleading_photos', details: 'Photos look fake' });
    expect(response.status).toBe(201);
    expect(response.body.status).toBe('pending');
  });

  it('rejects an invalid report reason', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/listing-reports')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId, reason: 'bogus_reason' });
    expect(response.status).toBe(400);
  });
});

function futureDate(): string {
  return new Date(Date.now() + 3 * 86400000).toISOString();
}

describe('Site visits (seeker side)', () => {

  it('requests a site visit for a published listing', async () => {
    const future = futureDate();
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: future, visitorNotes: 'Please show me around' });
    expect(response.status).toBe(201);
    expect(response.body.userId).toBe(seekerUserId);
    expect(response.body.status).toBe('scheduled');
  });

  it('rejects a visit in the past', async () => {
    const past = new Date(Date.now() - 3600_000).toISOString();
    const response = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: past });
    expect(response.status).toBe(400);
  });

  it('lists only the seeker own visits (IDOR)', async () => {
    await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: futureDate() });
    const own = await request(app).get('/api/v1/house-seeker/site-visits').set(authHeaders(seekerToken));
    expect(own.body.total).toBe(1);
    const other = await request(app).get('/api/v1/house-seeker/site-visits').set(authHeaders(otherToken));
    expect(other.body.total).toBe(0);
  });

  it('cancels a visit', async () => {
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: futureDate() });
    const visitId = created.body.id;
    const cancelled = await request(app)
      .post(`/api/v1/house-seeker/site-visits/${visitId}/cancel`)
      .set(authHeaders(seekerToken));
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.status).toBe('cancelled');
  });

  it('does not let another user cancel a visit (IDOR)', async () => {
    const created = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: futureDate() });
    const visitId = created.body.id;
    const response = await request(app)
      .post(`/api/v1/house-seeker/site-visits/${visitId}/cancel`)
      .set(authHeaders(otherToken));
    expect(response.status).toBe(403);
  });
});

describe('Conversations & messages', () => {
  it('starts a conversation with the landlord and sends a message', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/conversations')
      .set(authHeaders(seekerToken))
      .send({
        propertyId,
        listingId: publishedListingId,
        landlordUserId,
        subject: 'About Riverside',
        message: 'Hi, is this available?',
      });
    expect(response.status).toBe(201);
    expect(response.body.firstMessage.content).toBe('Hi, is this available?');

    const conversationId = response.body.conversation.id;
    const messages = await request(app)
      .get(`/api/v1/house-seeker/conversations/${conversationId}/messages`)
      .set(authHeaders(seekerToken));
    expect(messages.status).toBe(200);
    expect(messages.body.items.length).toBe(1);
  });

  it('lists only conversations the seeker participates in (IDOR)', async () => {
    const started = await request(app)
      .post('/api/v1/house-seeker/conversations')
      .set(authHeaders(seekerToken))
      .send({ propertyId, landlordUserId, message: 'Hello' });
    const conversationId = started.body.conversation.id;
    const own = await request(app).get('/api/v1/house-seeker/conversations').set(authHeaders(seekerToken));
    expect(own.body.items.length).toBe(1);
    const other = await request(app).get('/api/v1/house-seeker/conversations').set(authHeaders(otherToken));
    expect(other.body.items.length).toBe(0);
    // And the other user cannot read messages in the seeker's conversation.
    const denied = await request(app)
      .get(`/api/v1/house-seeker/conversations/${conversationId}/messages`)
      .set(authHeaders(otherToken));
    expect(denied.status).toBe(403);
  });

  it('marks messages as read', async () => {
    const started = await request(app)
      .post('/api/v1/house-seeker/conversations')
      .set(authHeaders(seekerToken))
      .send({ propertyId, landlordUserId, message: 'Hello' });
    const conversationId = started.body.conversation.id;
    const read = await request(app)
      .post(`/api/v1/house-seeker/conversations/${conversationId}/read`)
      .set(authHeaders(seekerToken));
    expect(read.status).toBe(200);
  });
});

describe('Rental applications', () => {
  it('submits a rental application', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/applications')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, proposedRentAmount: 45000, employerName: 'Acme' });
    expect(response.status).toBe(201);
    expect(response.body.userId).toBe(seekerUserId);
    expect(response.body.status).toBe('submitted');
  });

  it('lists only the seeker own applications (IDOR)', async () => {
    await request(app)
      .post('/api/v1/house-seeker/applications')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId });
    const own = await request(app).get('/api/v1/house-seeker/applications').set(authHeaders(seekerToken));
    expect(own.body.total).toBe(1);
    const other = await request(app).get('/api/v1/house-seeker/applications').set(authHeaders(otherToken));
    expect(other.body.total).toBe(0);
  });

  it('withdraws an application', async () => {
    const created = await request(app)
      .post('/api/v1/house-seeker/applications')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId });
    const applicationId = created.body.id;
    const withdrawn = await request(app)
      .post(`/api/v1/house-seeker/applications/${applicationId}/withdraw`)
      .set(authHeaders(seekerToken));
    expect(withdrawn.status).toBe(200);
    expect(withdrawn.body.status).toBe('withdrawn');
  });
});

describe('Rental proposals (seeker responses)', () => {
  async function createProposal() {
    return pool.query(
      `INSERT INTO rental_proposals (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status, proposed_rent_amount, proposed_deposit_amount, proposed_start_date, proposed_rent_due_day, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, $5, 1, $6, $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId, new Date(Date.now() + 86400000).toISOString(), new Date(Date.now() + 7 * 86400000).toISOString()],
    );
  }

  it('lists the seeker own proposals', async () => {
    await createProposal();
    const response = await request(app).get('/api/v1/house-seeker/proposals').set(authHeaders(seekerToken));
    expect(response.status).toBe(200);
    expect(response.body.total).toBe(1);
  });

  it('accepts a proposal', async () => {
    const proposal = await createProposal();
    const response = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposal.rows[0].id}/respond`)
      .set(authHeaders(seekerToken))
      .send({ action: 'accept' });
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('accepted');
  });

  it('cannot action another user proposal (IDOR)', async () => {
    const proposal = await createProposal();
    const response = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposal.rows[0].id}/respond`)
      .set(authHeaders(otherToken))
      .send({ action: 'accept' });
    expect(response.status).toBe(403);
  });
});

describe('Rental journey dashboard', () => {
  it('returns zeroed counts for a user with no activity', async () => {
    const response = await request(app).get('/api/v1/house-seeker/journey').set(authHeaders(seekerToken));
    expect(response.status).toBe(200);
    expect(response.body.counts).toEqual({
      savedHomes: 0,
      activeEnquiries: 0,
      upcomingVisits: 0,
      pendingProposals: 0,
      activeApplications: 0,
    });
    expect(response.body.upcomingVisits).toEqual([]);
    expect(response.body.recentProposals).toEqual([]);
  });

  it('reflects saved homes, enquiries, visits, proposals and applications in counts', async () => {
    // Saved home.
    const save = await request(app)
      .post('/api/v1/house-seeker/saved-listings')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });
    expect(save.status).toBe(201);

    // Enquiry.
    const enquiry = await request(app)
      .post('/api/v1/house-seeker/enquiries')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, message: 'Is this available?' });
    expect(enquiry.status).toBe(201);

    // Site visit (bookable thanks to seeded availability rules).
    const visit = await request(app)
      .post('/api/v1/house-seeker/site-visits')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId, scheduledAt: futureDate() });
    expect(visit.status).toBe(201);

    // Rental application.
    const application = await request(app)
      .post('/api/v1/house-seeker/applications')
      .set(authHeaders(seekerToken))
      .send({ propertyId, listingId: publishedListingId });
    expect(application.status).toBe(201);

    // Rental proposal from landlord (seeker is the prospective renter). Inserted
    // directly in 'sent' status so it counts as pending for the seeker.
    await pool.query(
      `INSERT INTO rental_proposals (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status, proposed_rent_amount, proposed_deposit_amount, proposed_start_date, proposed_rent_due_day, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, $5, 1, $6, $4)`,
      [propertyId, unitId, seekerUserId, landlordUserId, new Date(Date.now() + 86400000).toISOString(), new Date(Date.now() + 7 * 86400000).toISOString()],
    );

    const journey = await request(app)
      .get('/api/v1/house-seeker/journey')
      .set(authHeaders(seekerToken));
    expect(journey.status).toBe(200);
    expect(journey.body.counts.savedHomes).toBe(1);
    expect(journey.body.counts.activeEnquiries).toBe(1);
    expect(journey.body.counts.upcomingVisits).toBe(1);
    expect(journey.body.counts.activeApplications).toBe(1);
    expect(journey.body.counts.pendingProposals).toBe(1);

    // Upcoming visits list includes the scheduled visit.
    expect(journey.body.upcomingVisits.length).toBe(1);
    expect(journey.body.upcomingVisits[0].propertyId).toBe(propertyId);
    expect(journey.body.upcomingVisits[0].status).toBe('scheduled');

    // Recent proposals list includes the landlord proposal.
    expect(journey.body.recentProposals.length).toBe(1);
    expect(journey.body.recentProposals[0].propertyTitle).toBe('Riverside Apartments');
  });

  it('rejects unknown query parameters on the journey endpoint', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/journey')
      .query({ unexpected: 'value' })
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(400);
  });

  it('requires authentication', async () => {
    const response = await request(app).get('/api/v1/house-seeker/journey');
    expect(response.status).toBe(401);
  });
});

describe('Property comparison', () => {
  it('retrieves an empty comparison list', async () => {
    const response = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(200);
    expect(response.body.items).toEqual([]);
    expect(response.body.total).toBe(0);
  });

  it('adds a published listing to comparison', async () => {
    const add = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });
    expect(add.status).toBe(201);
    expect(add.body.added).toBe(true);
    expect(add.body.listingId).toBe(publishedListingId);

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.status).toBe(200);
    expect(list.body.total).toBe(1);
    expect(list.body.items[0].listingId).toBe(publishedListingId);
    expect(list.body.items[0].title).toBeTruthy();
    expect(list.body.items[0].rentAmount).toBe(45000);
  });

  it('prevents duplicate entries in comparison', async () => {
    await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });

    const duplicate = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });
    expect(duplicate.status).toBe(201);
    expect(duplicate.body.added).toBe(false);
    expect(duplicate.body.reason).toBe('already_in_comparison');

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.body.total).toBe(1);
  });

  it('enforces a maximum of 4 properties in comparison', async () => {
    // Create 4 additional published listings.
    const listingIds = [publishedListingId];
    for (let i = 0; i < 3; i++) {
      const extra = await pool.query(
        `INSERT INTO property_listings (property_id, unit_id, title, status, rent_amount, published_at, created_by)
         VALUES ($1, $2, $3, 'published', 45000, NOW(), $4) RETURNING id`,
        [propertyId, unitId, `Extra Listing ${i + 1}`, landlordUserId],
      );
      listingIds.push(extra.rows[0].id);
    }

    for (const id of listingIds) {
      const add = await request(app)
        .post('/api/v1/house-seeker/comparison')
        .set(authHeaders(seekerToken))
        .send({ listingId: id });
      expect(add.status).toBe(201);
      expect(add.body.added).toBe(true);
    }

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.body.total).toBe(4);

    // A 5th listing should be rejected.
    const fifth = await pool.query(
      `INSERT INTO property_listings (property_id, unit_id, title, status, rent_amount, published_at, created_by)
       VALUES ($1, $2, 'Fifth Listing', 'published', 50000, NOW(), $3) RETURNING id`,
      [propertyId, unitId, landlordUserId],
    );
    const overLimit = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: fifth.rows[0].id });
    expect(overLimit.status).toBe(409);
  });

  it('removes a selected property from comparison', async () => {
    await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });

    const removed = await request(app)
      .delete(`/api/v1/house-seeker/comparison/${publishedListingId}`)
      .set(authHeaders(seekerToken));
    expect(removed.status).toBe(200);
    expect(removed.body.removed).toBe(true);

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.body.total).toBe(0);
  });

  it('returns 404 when removing a listing not in comparison', async () => {
    const response = await request(app)
      .delete(`/api/v1/house-seeker/comparison/${publishedListingId}`)
      .set(authHeaders(seekerToken));
    expect(response.status).toBe(404);
  });

  it('clears the comparison list', async () => {
    await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });

    const cleared = await request(app)
      .delete('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(cleared.status).toBe(200);
    expect(cleared.body.cleared).toBe(true);
    expect(cleared.body.removedCount).toBe(1);

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.body.total).toBe(0);
  });

  it('handles unavailable listings in comparison gracefully', async () => {
    // Add the draft listing (status != published) to comparison.
    const add = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: suspendedListingId });
    expect(add.status).toBe(201);

    const list = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(list.status).toBe(200);
    expect(list.body.total).toBe(1);
    expect(list.body.items[0].listingId).toBe(suspendedListingId);
    expect(list.body.items[0].listingStatus).toBe('draft');
  });

  it('requires authentication for comparison endpoints', async () => {
    const getRes = await request(app).get('/api/v1/house-seeker/comparison');
    expect(getRes.status).toBe(401);

    const postRes = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .send({ listingId: publishedListingId });
    expect(postRes.status).toBe(401);

    const delRes = await request(app).delete(`/api/v1/house-seeker/comparison/${publishedListingId}`);
    expect(delRes.status).toBe(401);

    const clearRes = await request(app).delete('/api/v1/house-seeker/comparison');
    expect(clearRes.status).toBe(401);
  });

  it('prevents cross-user access to comparison (IDOR)', async () => {
    await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: publishedListingId });

    // Other user cannot see seeker's comparison.
    const otherList = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(otherToken));
    expect(otherList.body.total).toBe(0);

    // Other user cannot remove seeker's comparison item.
    const otherRemove = await request(app)
      .delete(`/api/v1/house-seeker/comparison/${publishedListingId}`)
      .set(authHeaders(otherToken));
    expect(otherRemove.status).toBe(404);

    // Seeker's comparison still intact.
    const seekerList = await request(app)
      .get('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken));
    expect(seekerList.body.total).toBe(1);
  });

  it('returns 404 for invalid listing ID on add', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: '00000000-0000-0000-0000-000000000000' });
    expect(response.status).toBe(404);
  });

  it('returns 400 for invalid UUID format', async () => {
    const response = await request(app)
      .post('/api/v1/house-seeker/comparison')
      .set(authHeaders(seekerToken))
      .send({ listingId: 'not-a-uuid' });
    expect(response.status).toBe(400);
  });
});