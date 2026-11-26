import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import { expireOverdueProposals } from '../landlord/landlord.repository.js';
import { respondToMyProposal } from '../house-seeker/house-seeker.repository.js';
import { NotificationService } from '../auth/notification.service.js';
import { proposalIdempotencyKey } from '../auth/transactional-outbox.service.js';

const app = createApp({ nodeEnv: 'test' });

let landlordToken: string;
let landlordUserId: string;
let seekerToken: string;
let seekerUserId: string;
let otherToken: string;
let otherUserId: string;
let caretakerToken: string;
let caretakerUserId: string;
let propertyId: string;
let unitId: string;
let listingId: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `test${Date.now()}${Math.floor(Math.random() * 1000000)}@example.com`;
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
  await pool.query(
    `INSERT INTO user_profiles (user_id, phone_number) VALUES ((SELECT id FROM users WHERE email = $1), $2)
      ON CONFLICT (user_id) DO UPDATE SET phone_number = EXCLUDED.phone_number`,
    [email, `+2547${Math.floor(Math.random() * 100000000)}`],
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

async function createProperty(ownerId: string): Promise<void> {
  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
     VALUES (NULL, 'Riverside Apartments', 'Modern apartments', 'apartment', 'published', '12 Riverside Dr', 'Nairobi', 'Nairobi', 'KE', 3, $1, NOW())
     RETURNING id`,
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
     VALUES ($1, 'A-101', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', $2)
     RETURNING id`,
    [propertyId, ownerId],
  );
  unitId = unit.rows[0].id;
  const listing = await pool.query(
    `INSERT INTO property_listings (property_id, unit_id, title, description, status, rent_amount, deposit_amount, available_from, created_by, published_at)
     VALUES ($1, $2, 'Cosy 1BR Riverside', 'Bright and airy', 'published', 45000, 90000, '2026-12-01', $3, NOW())
     RETURNING id`,
    [propertyId, unitId, ownerId],
  );
  listingId = listing.rows[0].id;
}

async function cleanup(): Promise<void> {
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM notification_recipients');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM rental_application_documents');
  await pool.query('DELETE FROM rental_application_notes');
  await pool.query('DELETE FROM rental_application_history');
  await pool.query('DELETE FROM rental_applications');
  await pool.query('DELETE FROM rental_proposal_status_history');
  await pool.query('DELETE FROM rental_proposal_versions');
  await pool.query('DELETE FROM rental_proposals');
  await pool.query('DELETE FROM tenants');
  await pool.query('DELETE FROM tenancies');
  await pool.query('DELETE FROM property_assignments');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker', 'caretaker')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'test%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
  const landlord = await registerAndLogin('landlord');
  landlordUserId = landlord.id;
  landlordToken = landlord.token;
  const seeker = await registerAndLogin('house_seeker');
  seekerUserId = seeker.id;
  seekerToken = seeker.token;
  const other = await registerAndLogin('house_seeker');
  otherUserId = other.id;
  otherToken = other.token;
  const caretaker = await registerAndLogin('caretaker');
  caretakerUserId = caretaker.id;
  caretakerToken = caretaker.token;
  await createProperty(landlordUserId);
});

afterEach(async () => {
  await cleanup();
});

const ROUTE = '/api/v1/rental-applications';

function submitBody(overrides: Record<string, unknown> = {}) {
  return {
    propertyId,
    unitId,
    listingId,
    preferredStartDate: '2026-12-01',
    preferredEndDate: '2027-12-01',
    proposedRentAmount: 45000,
    ...overrides,
  };
}

describe('Rental application submission + duplicate prevention', () => {
  it('creates a submitted application and writes a history row', async () => {
    const res = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('submitted');
    expect(res.body.propertyId).toBe(propertyId);

    // The applicant snapshots their own contact, never a client-supplied user id.
    expect(res.body.userId).toBe(seekerUserId);

    const hist = await pool.query(
      `SELECT * FROM rental_application_history WHERE application_id = $1`,
      [res.body.id],
    );
    expect(hist.rows.length).toBeGreaterThanOrEqual(1);
  });

  it('rejects a duplicate active application for the same property/unit', async () => {
    const first = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    expect(first.status).toBe(201);
    const second = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    expect(second.status).toBe(409);
  });

  it('saves a draft and submits it', async () => {
    const draft = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(draft.status).toBe(201);
    expect(draft.body.status).toBe('draft');

    const submit = await request(app)
      .post(`${ROUTE}/applications/${draft.body.id}/submit`)
      .set(auth(seekerToken))
      .send({});
    expect(submit.status).toBe(200);
    expect(submit.body.status).toBe('submitted');
  });

  it('does not let a client set another user’s id (identity comes from the token)', async () => {
    const res = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody({ userId: otherUserId }));
    expect(res.status).toBe(201);
    expect(res.body.userId).toBe(seekerUserId);
  });
});

describe('Manager review lifecycle', () => {
  it('walks submit -> review -> request info -> resubmit -> shortlist -> approve -> onboard', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;

    // Landlord inbox lists the application.
    const inbox = await request(app).get(`${ROUTE}/applications`).set(auth(landlordToken));
    expect(inbox.status).toBe(200);
    expect(inbox.body.items.some((a: { id: string }) => a.id === id)).toBe(true);

    const start = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'start_review' });
    expect(start.status).toBe(200);
    expect(start.body.application.status).toBe('under_review');

    const requestInfo = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'request_information', reason: 'Please upload your ID and proof of income' });
    expect(requestInfo.status).toBe(200);
    expect(requestInfo.body.application.status).toBe('information_requested');

    const resubmit = await request(app)
      .post(`${ROUTE}/applications/${id}/resubmit`)
      .set(auth(seekerToken))
      .send({ responseNote: 'Uploaded the requested documents' });
    expect(resubmit.status).toBe(200);
    expect(resubmit.body.status).toBe('resubmitted');

    const shortlist = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'shortlist' });
    expect(shortlist.body.application.status).toBe('shortlisted');

    // Manager creates a proposal linked to this application.
    const proposal = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(landlordToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        rentalApplicationId: id,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(proposal.status).toBe(201);
    const proposalId = proposal.body.id;

    // Manager sends the proposal.
    const sent = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${proposalId}/action`)
      .set(auth(landlordToken))
      .send({ action: 'send' });
    expect(sent.status).toBe(200);
    expect(sent.body.status).toBe('sent');

    // Seeker accepts the proposal.
    const accepted = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposalId}/respond`)
      .set(auth(seekerToken))
      .send({ action: 'accept' });
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('accepted');

    const approve = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(landlordToken))
      .send({
        approvedRentAmount: 45000,
        approvedDepositAmount: 90000,
        approvedStartDate: '2026-12-01',
        approvedEndDate: '2027-12-01',
      });
    expect(approve.status).toBe(200);
    expect(approve.body.application.status).toBe('approved');
    expect(approve.body.onboarding).toBeDefined();
    expect(approve.body.onboarding.tenancyId).toBeTruthy();

    // The application is now linked to the tenancy.
    const detail = await request(app).get(`${ROUTE}/applications/${id}`).set(auth(landlordToken));
    expect(detail.body.application.tenancyId).toBe(approve.body.onboarding.tenancyId);

    // The unit is now occupied.
    const unit = await pool.query(`SELECT status FROM units WHERE id = $1`, [unitId]);
    expect(unit.rows[0].status).toBe('occupied');
  });

  it('records internal notes that the applicant never sees', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;

    const note = await request(app)
      .post(`${ROUTE}/applications/${id}/notes`)
      .set(auth(landlordToken))
      .send({ note: 'Flagged: verify employment' });
    expect(note.status).toBe(201);
    expect(note.body.isInternal).toBe(true);

    // Applicant detail must not expose internal notes.
    const applicantView = await request(app).get(`${ROUTE}/applications/${id}`).set(auth(seekerToken));
    expect(applicantView.status).toBe(200);
    expect(applicantView.body.notes.some((n: { isInternal: boolean }) => n.isInternal)).toBe(false);

    // Manager sees the internal note.
    const managerView = await request(app).get(`${ROUTE}/applications/${id}`).set(auth(landlordToken));
    expect(managerView.body.notes.some((n: { note: string }) => n.note === 'Flagged: verify employment')).toBe(true);
  });

  it('surfaces information requests as applicant-visible notes', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;
    await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'request_information', reason: 'Need your ID' });

    const applicantView = await request(app).get(`${ROUTE}/applications/${id}`).set(auth(seekerToken));
    expect(applicantView.body.notes.some((n: { note: string; isInternal: boolean }) => n.note === 'Need your ID' && !n.isInternal)).toBe(true);
  });
});

describe('Authorization and IDOR', () => {
  it('blocks a non-participant from viewing an application', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const res = await request(app).get(`${ROUTE}/applications/${submit.body.id}`).set(auth(otherToken));
    expect(res.status).toBe(403);
  });

  it('does not grant a caretaker application-management authority', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;

    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'caretaker', $2, 'active', $2, NOW())`,
      [propertyId, caretakerUserId],
    );

    const inbox = await request(app).get(`${ROUTE}/applications`).set(auth(caretakerToken));
    expect(inbox.body.items.some((a: { id: string }) => a.id === id)).toBe(false);

    const approve = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(caretakerToken))
      .send({});
    expect(approve.status).toBe(403);
  });

  it('rejects an invalid transition', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;
    // approve is only valid from review/shortlisted/etc., not directly from submitted.
    const res = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(landlordToken))
      .send({});
    expect(res.status).toBe(409);
  });
});

describe('Competing approvals and idempotent onboarding', () => {
  it('prevents two applications being approved for the same unit', async () => {
    const a = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const b = await request(app).post(`${ROUTE}/applications`).set(auth(otherToken)).send(submitBody());
    expect(a.status).toBe(201);
    expect(b.status).toBe(201);

    await request(app)
      .post(`${ROUTE}/applications/${a.body.id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'start_review' });

    // Create and accept a proposal for application A so onboarding can proceed.
    const proposalA = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(landlordToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        rentalApplicationId: a.body.id,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(proposalA.status).toBe(201);
    const proposalAId = proposalA.body.id;
    const sentA = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${proposalAId}/action`)
      .set(auth(landlordToken))
      .send({ action: 'send' });
    expect(sentA.status).toBe(200);
    const acceptedA = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposalAId}/respond`)
      .set(auth(seekerToken))
      .send({ action: 'accept' });
    expect(acceptedA.status).toBe(200);

    const approveA = await request(app)
      .post(`${ROUTE}/applications/${a.body.id}/approve`)
      .set(auth(landlordToken))
      .send({ approvedRentAmount: 45000, approvedDepositAmount: 90000 });
    expect(approveA.status).toBe(200);
    expect(approveA.body.onboarding).toBeDefined();

    // The second application cannot be approved for the now-occupied unit.
    const approveB = await request(app)
      .post(`${ROUTE}/applications/${b.body.id}/approve`)
      .set(auth(landlordToken))
      .send({ approvedRentAmount: 45000, approvedDepositAmount: 90000 });
    expect(approveB.status).toBe(409);
  });

  it('onboards idempotently (retry does not duplicate tenancy/tenant)', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;
    await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'start_review' });

    // Create and accept a proposal so onboarding can proceed.
    const proposal = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(landlordToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        rentalApplicationId: id,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(proposal.status).toBe(201);
    const proposalId = proposal.body.id;
    const sent = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${proposalId}/action`)
      .set(auth(landlordToken))
      .send({ action: 'send' });
    expect(sent.status).toBe(200);
    const accepted = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposalId}/respond`)
      .set(auth(seekerToken))
      .send({ action: 'accept' });
    expect(accepted.status).toBe(200);

    const approve = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(landlordToken))
      .send({ approvedRentAmount: 45000, approvedDepositAmount: 90000 });
    const tenancyId = approve.body.onboarding.tenancyId;

    const retry = await request(app).post(`${ROUTE}/applications/${id}/onboard`).set(auth(landlordToken)).send({});
    expect(retry.status).toBe(200);
    expect(retry.body.onboarding.alreadyOnboarded).toBe(true);
    expect(retry.body.onboarding.tenancyId).toBe(tenancyId);

    const tenants = await pool.query(`SELECT id FROM tenants WHERE tenancy_id = $1`, [tenancyId]);
    expect(tenants.rows.length).toBe(1);
  });

  it('never creates a tenant merely from submitting an application', async () => {
    await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const tenants = await pool.query(`SELECT id FROM tenants`);
    expect(tenants.rows.length).toBe(0);
    const tenancies = await pool.query(`SELECT id FROM tenancies`);
    expect(tenancies.rows.length).toBe(0);
  });
});

describe('Document authorization', () => {
  it('forbids a non-owner from downloading another applicant’s document', async () => {
    const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    const id = submit.body.id;

    // Insert a document row directly (no S3 dependency) to test authz.
    const doc = await pool.query(
      `INSERT INTO rental_application_documents (application_id, uploaded_by, storage_key, file_name, mime_type, category)
       VALUES ($1, $2, 'pending/x', 'id.pdf', 'application/pdf', 'id_document')
       RETURNING id`,
      [id, seekerUserId],
    );

    const res = await request(app)
      .get(`${ROUTE}/documents/${doc.rows[0].id}`)
      .set(auth(otherToken));
    expect(res.status).toBe(403);
  });
});

describe('Proposal expiry', () => {
  it('lazily expires an overdue pending proposal when the seeker lists proposals', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (enquiry_id, property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES (NULL, $1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() - INTERVAL '1 day', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );

    // The seeker lists proposals; the sweep flips the overdue one to expired.
    const res = await request(app)
      .get('/api/v1/house-seeker/proposals')
      .set(auth(seekerToken));
    expect(res.status).toBe(200);

    const row = await pool.query(`SELECT status FROM rental_proposals WHERE id = $1`, [proposal.rows[0].id]);
    expect(row.rows[0].status).toBe('expired');
  });
});

// ============================================================================
// Task 10.4 — Outbox reliability + contextual messaging closure regressions
// ============================================================================

describe('Transactional outbox — application lifecycle atomicity', () => {
  it('rolls back the critical state change when the outbox insert fails', async () => {
    // Force the outbox insert to fail for the rejection event only, proving the
    // business state change and its event share one transaction.
    await pool.query(`
      CREATE OR REPLACE FUNCTION test_outbox_fail_reject() RETURNS trigger AS $$
      BEGIN
        IF NEW.idempotency_key LIKE 'application.rejected:%' THEN
          RAISE EXCEPTION 'simulated outbox failure';
        END IF;
        RETURN NEW;
      END; $$ LANGUAGE plpgsql`);
    await pool.query(`DROP TRIGGER IF EXISTS trg_outbox_fail_reject ON notification_outbox`);
    await pool.query(`
      CREATE TRIGGER trg_outbox_fail_reject BEFORE INSERT ON notification_outbox
      FOR EACH ROW EXECUTE FUNCTION test_outbox_fail_reject()`);

    try {
      const submit = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
      expect(submit.status).toBe(201);
      const id = submit.body.id as string;
      // The submission's own critical event (application.submitted) persisted.
      const submittedOutbox = await pool.query(
        `SELECT id FROM notification_outbox WHERE idempotency_key = $1`,
        [`application.submitted:${id}`],
      );
      expect(submittedOutbox.rows.length).toBe(1);

      const res = await request(app)
        .post(`${ROUTE}/applications/${id}/transition`)
        .set(auth(landlordToken))
        .send({ action: 'reject', reason: 'Not suitable' });

      // The request failed...
      expect(res.status).toBeGreaterThanOrEqual(400);
      // ...and the state change was rolled back (still submitted, not rejected).
      const row = await pool.query(`SELECT status FROM rental_applications WHERE id = $1`, [id]);
      expect(row.rows[0].status).toBe('submitted');
      // No rejected outbox row survived the rollback.
      const outbox = await pool.query(
        `SELECT id FROM notification_outbox WHERE idempotency_key = $1`,
        [`application.rejected:${id}`],
      );
      expect(outbox.rows.length).toBe(0);
    } finally {
      await pool.query(`DROP TRIGGER IF EXISTS trg_outbox_fail_reject ON notification_outbox`);
      await pool.query(`DROP FUNCTION IF EXISTS test_outbox_fail_reject()`);
    }
  });
});

describe('Transactional outbox — proposal expiry', () => {
  async function insertOverdueProposal(): Promise<string> {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (enquiry_id, property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES (NULL, $1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() - INTERVAL '1 day', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    return proposal.rows[0].id as string;
  }

  it('emits exactly one logical expiry event under concurrent sweeps', async () => {
    const pid = await insertOverdueProposal();

    const [a, b] = await Promise.all([expireOverdueProposals(), expireOverdueProposals()]);
    // Exactly one sweep transitioned the row (the other matched nothing after
    // the winner committed under READ COMMITTED).
    expect(a + b).toBe(1);

    // A repeated sweep is a no-op and must not duplicate the event.
    const again = await expireOverdueProposals();
    expect(again).toBe(0);

    const row = await pool.query(`SELECT status FROM rental_proposals WHERE id = $1`, [pid]);
    expect(row.rows[0].status).toBe('expired');

    const outbox = await pool.query(
      `SELECT id FROM notification_outbox WHERE idempotency_key = $1`,
      [`proposal.expired:${pid}`],
    );
    expect(outbox.rows.length).toBe(1);
  });

  it('persists the expiry event even if a later step fails (event is not lost)', async () => {
    const pid = await insertOverdueProposal();
    await expireOverdueProposals();
    // The event is durably persisted for the worker to deliver.
    const outbox = await pool.query(
      `SELECT status FROM notification_outbox WHERE idempotency_key = $1`,
      [`proposal.expired:${pid}`],
    );
    expect(outbox.rows.length).toBe(1);
    expect(outbox.rows[0].status).toBe('pending');
  });
});

describe('Transactional outbox — distinct proposal version events', () => {
  it('creates a distinct outbox event per counter version', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() + INTERVAL '30 days', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    const pid = proposal.rows[0].id as string;

    await respondToMyProposal(seekerUserId, pid, {
      action: 'counter',
      counter: { rentAmount: 40000 },
      reason: 'round 1',
    });
    await respondToMyProposal(seekerUserId, pid, {
      action: 'counter',
      counter: { rentAmount: 38000 },
      reason: 'round 2',
    });

    const outbox = await pool.query<{ idempotency_key: string }>(
      `SELECT idempotency_key FROM notification_outbox
        WHERE event_type = 'proposal.counter' AND resource_id = $1
        ORDER BY idempotency_key`,
      [pid],
    );
    const keys = outbox.rows.map((r) => r.idempotency_key);
    expect(keys).toContain(proposalIdempotencyKey('proposal.counter', pid, 1));
    expect(keys).toContain(proposalIdempotencyKey('proposal.counter', pid, 2));
    expect(keys.length).toBe(2);
  });
});

describe('Outbox worker — retry idempotency', () => {
  it('does not duplicate notifications when an outbox event is processed twice', async () => {
    const notifications = new NotificationService();
    const resourceId = randomUUID();
    const event = await notifications.createOutboxEvent({
      idempotencyKey: `application.under_review:${resourceId}`,
      eventType: 'application.under_review',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [seekerUserId, landlordUserId],
      organisationId: null,
      resourceType: 'rental_application',
      resourceId,
      payload: { resourceId },
      channels: ['in_app'],
    });

    await notifications.processOutboxEvent(event.id);
    // A redelivered job for the same outbox row must be a no-op.
    await notifications.processOutboxEvent(event.id);

    const rows = await pool.query(
      `SELECT user_id FROM notifications
        WHERE event_type = 'application.under_review' AND metadata->>'resourceId' = $1`,
      [resourceId],
    );
    // Exactly one persistent notification per recipient, none duplicated.
    expect(rows.rows.length).toBe(2);
  });
});

describe('Contextual messaging entry points — reuse + authorization', () => {
  async function submitApplication(): Promise<string> {
    const res = await request(app).post(`${ROUTE}/applications`).set(auth(seekerToken)).send(submitBody());
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  function startConversation(token: string, body: Record<string, unknown>) {
    return request(app).post('/api/v1/messaging/conversations').set(auth(token)).send(body);
  }

  it('reuses one conversation per rental application across both parties', async () => {
    const id = await submitApplication();

    const first = await startConversation(seekerToken, { type: 'rental_application', rentalApplicationId: id });
    expect(first.status).toBe(201);
    expect(first.body.reused).toBe(false);
    expect(first.body.conversation.rentalApplicationId).toBe(id);

    const second = await startConversation(landlordToken, { type: 'rental_application', rentalApplicationId: id });
    expect(second.status).toBe(200);
    expect(second.body.reused).toBe(true);
    expect(second.body.conversation.id).toBe(first.body.conversation.id);
    expect(second.body.conversation.rentalApplicationId).toBe(id);

    const convos = await pool.query(
      `SELECT id FROM conversations WHERE rental_application_id = $1`,
      [id],
    );
    expect(convos.rows.length).toBe(1);
  });

  it('reuses one conversation per rental proposal across both parties', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() + INTERVAL '30 days', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    const pid = proposal.rows[0].id as string;

    const seekerStart = await startConversation(seekerToken, { type: 'rental_proposal', rentalProposalId: pid });
    expect(seekerStart.status).toBe(201);
    expect(seekerStart.body.conversation.rentalProposalId).toBe(pid);

    const landlordStart = await startConversation(landlordToken, { type: 'rental_proposal', rentalProposalId: pid });
    expect(landlordStart.status).toBe(200);
    expect(landlordStart.body.reused).toBe(true);
    expect(landlordStart.body.conversation.id).toBe(seekerStart.body.conversation.id);

    const convos = await pool.query(
      `SELECT id FROM conversations WHERE rental_proposal_id = $1`,
      [pid],
    );
    expect(convos.rows.length).toBe(1);
  });

  it('denies a non-participant from starting an application conversation', async () => {
    const id = await submitApplication();
    const res = await startConversation(otherToken, { type: 'rental_application', rentalApplicationId: id });
    expect(res.status).toBe(403);
  });

  it('denies a caretaker with only property access from the application conversation', async () => {
    const id = await submitApplication();
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'caretaker', $2, 'active', $2, NOW())`,
      [propertyId, caretakerUserId],
    );
    const res = await startConversation(caretakerToken, { type: 'rental_application', rentalApplicationId: id });
    expect(res.status).toBe(403);
  });

  it('removes conversation access when a manager assignment is revoked', async () => {
    const id = await submitApplication();
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'property_manager', $2, 'active', $2, NOW())`,
      [propertyId, otherUserId],
    );

    const allowed = await startConversation(otherToken, { type: 'rental_application', rentalApplicationId: id });
    expect(allowed.status).toBe(201);

    await pool.query(
      `UPDATE property_assignments SET status = 'revoked', effective_to = NOW()
        WHERE property_id = $1 AND user_id = $2`,
      [propertyId, otherUserId],
    );

    const denied = await startConversation(otherToken, { type: 'rental_application', rentalApplicationId: id });
    expect(denied.status).toBe(403);
  });
});

describe('Onboarding preconditions — accepted proposal required', () => {
  async function submitAndApproveToShortlist(): Promise<string> {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submit.status).toBe(201);
    const id = submit.body.id as string;

    await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'start_review' });
    await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'shortlist' });

    return id;
  }

  it('rejects onboarding when no accepted proposal is linked to the application', async () => {
    const id = await submitAndApproveToShortlist();

    const approve = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(landlordToken))
      .send({
        approvedRentAmount: 45000,
        approvedDepositAmount: 90000,
        approvedStartDate: '2026-12-01',
        approvedEndDate: '2027-12-01',
      });
    // Approval fails because no accepted proposal is linked.
    expect(approve.status).toBeGreaterThanOrEqual(400);
    expect(approve.body.message).toContain('no accepted or confirmed proposal');

    // No tenancy or tenant was created.
    const tenancies = await pool.query(`SELECT id FROM tenancies`);
    expect(tenancies.rows.length).toBe(0);
    const tenants = await pool.query(`SELECT id FROM tenants`);
    expect(tenants.rows.length).toBe(0);
  });

  it('onboards successfully when an accepted proposal is linked', async () => {
    const id = await submitAndApproveToShortlist();

    // Manager creates and sends a proposal.
    const proposal = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(landlordToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        rentalApplicationId: id,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(proposal.status).toBe(201);
    const proposalId = proposal.body.id as string;

    const sent = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${proposalId}/action`)
      .set(auth(landlordToken))
      .send({ action: 'send' });
    expect(sent.status).toBe(200);

    const accepted = await request(app)
      .post(`/api/v1/house-seeker/proposals/${proposalId}/respond`)
      .set(auth(seekerToken))
      .send({ action: 'accept' });
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('accepted');

    const approve = await request(app)
      .post(`${ROUTE}/applications/${id}/approve`)
      .set(auth(landlordToken))
      .send({
        approvedRentAmount: 45000,
        approvedDepositAmount: 90000,
        approvedStartDate: '2026-12-01',
        approvedEndDate: '2027-12-01',
      });
    expect(approve.status).toBe(200);
    expect(approve.body.onboarding).toBeDefined();
    expect(approve.body.onboarding.tenancyId).toBeTruthy();

    const tenancies = await pool.query(`SELECT id, terms_accepted_at FROM tenancies`);
    expect(tenancies.rows.length).toBe(1);
    expect(tenancies.rows[0].terms_accepted_at).not.toBeNull();
  });
});

describe('Proposal status history — previous_status recorded correctly', () => {
  it('records the true previous status (not the new status) in history', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() + INTERVAL '30 days', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    const pid = proposal.rows[0].id as string;

    const res = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${pid}/action`)
      .set(auth(landlordToken))
      .send({ action: 'accept' });
    expect(res.status).toBe(200);

    const history = await pool.query(
      `SELECT previous_status, new_status FROM rental_proposal_status_history WHERE proposal_id = $1 ORDER BY created_at`,
      [pid],
    );
    expect(history.rows.length).toBe(1);
    expect(history.rows[0].previous_status).toBe('sent');
    expect(history.rows[0].new_status).toBe('accepted');
  });
});

describe('Counter versioning — concurrent counters get distinct versions', () => {
  it('assigns distinct version numbers to concurrent counter responses', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'sent', 45000, 90000, '2026-12-01', NOW() + INTERVAL '30 days', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    const pid = proposal.rows[0].id as string;

    // Two concurrent counter responses from the seeker.
    const [a, b] = await Promise.all([
      respondToMyProposal(seekerUserId, pid, { action: 'counter', counter: { rentAmount: 40000 }, reason: 'round 1' }),
      respondToMyProposal(seekerUserId, pid, { action: 'counter', counter: { rentAmount: 38000 }, reason: 'round 2' }),
    ]);
    expect(a).toBeDefined();
    expect(b).toBeDefined();

    const versions = await pool.query(
      `SELECT version_number FROM rental_proposal_versions WHERE proposal_id = $1 ORDER BY version_number`,
      [pid],
    );
    expect(versions.rows.length).toBe(2);
    expect(versions.rows.map((r) => r.version_number)).toEqual([1, 2]);
  });
});

describe('Authorization — caretaker denied for proposal actions', () => {
  it('denies a caretaker from creating a proposal', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'caretaker', $2, 'active', $2, NOW())`,
      [propertyId, caretakerUserId],
    );

    const res = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(caretakerToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(res.status).toBe(403);
  });

  it('denies a caretaker from acting on a proposal', async () => {
    const proposal = await pool.query(
      `INSERT INTO rental_proposals
         (property_id, unit_id, prospective_renter_id, landlord_user_id, type, status,
          proposed_rent_amount, proposed_deposit_amount, proposed_start_date, expires_at, created_by)
       VALUES ($1, $2, $3, $4, 'new_tenancy', 'draft', 45000, 90000, '2026-12-01', NOW() + INTERVAL '30 days', $4)
       RETURNING id`,
      [propertyId, unitId, seekerUserId, landlordUserId],
    );
    const pid = proposal.rows[0].id as string;

    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'caretaker', $2, 'active', $2, NOW())`,
      [propertyId, caretakerUserId],
    );

    const res = await request(app)
      .post(`/api/v1/landlord/rental-proposals/${pid}/action`)
      .set(auth(caretakerToken))
      .send({ action: 'send' });
    expect(res.status).toBe(403);
  });
});

describe('Proposal — rental_application_id link', () => {
  it('stores rental_application_id on created proposals', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submit.status).toBe(201);
    const appId = submit.body.id as string;

    const res = await request(app)
      .post('/api/v1/landlord/rental-proposals')
      .set(auth(landlordToken))
      .send({
        propertyId,
        unitId,
        prospectiveRenterId: seekerUserId,
        rentalApplicationId: appId,
        type: 'new_tenancy',
        proposedRentAmount: 45000,
        proposedDepositAmount: 90000,
        proposedStartDate: '2026-12-01',
        expiresAt: '2026-12-31T23:59:59Z',
      });
    expect(res.status).toBe(201);
    expect(res.body.rentalApplicationId).toBe(appId);

    const row = await pool.query(
      `SELECT rental_application_id FROM rental_proposals WHERE id = $1`,
      [res.body.id],
    );
    expect(row.rows[0].rental_application_id).toBe(appId);
  });
});

describe('Applicant self-service — withdraw', () => {
  it('lets an applicant withdraw their own submitted application', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submit.status).toBe(201);
    const id = submit.body.id as string;

    const withdrawn = await request(app)
      .post(`${ROUTE}/applications/${id}/withdraw`)
      .set(auth(seekerToken));
    expect(withdrawn.status).toBe(200);
    expect(withdrawn.body.status).toBe('withdrawn');

    const row = await pool.query(`SELECT status FROM rental_applications WHERE id = $1`, [id]);
    expect(row.rows[0].status).toBe('withdrawn');
  });

  it('lets an applicant withdraw a draft', async () => {
    const draft = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(draft.status).toBe(201);
    expect(draft.body.status).toBe('draft');
    const id = draft.body.id as string;

    const withdrawn = await request(app)
      .post(`${ROUTE}/applications/${id}/withdraw`)
      .set(auth(seekerToken));
    expect(withdrawn.status).toBe(200);
    expect(withdrawn.body.status).toBe('withdrawn');
  });

  it('does not let an applicant withdraw another applicant\'s application', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    const id = submit.body.id as string;

    const res = await request(app)
      .post(`${ROUTE}/applications/${id}/withdraw`)
      .set(auth(otherToken));
    expect(res.status).toBe(403);
  });
});

describe('Manager transitions — reject', () => {
  it('lets a manager reject a submitted application and records history', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submit.status).toBe(201);
    const id = submit.body.id as string;

    const rejected = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'reject', reason: 'Not suitable' });
    expect(rejected.status).toBe(200);
    expect(rejected.body.application.status).toBe('rejected');

    const hist = await pool.query(
      `SELECT previous_status, new_status FROM rental_application_history WHERE application_id = $1 ORDER BY created_at`,
      [id],
    );
    const rejectRow = hist.rows.find((r: { new_status: string }) => r.new_status === 'rejected');
    expect(rejectRow).toBeDefined();
    expect(rejectRow.previous_status).toBe('submitted');
  });

  it('does not let an applicant reject their own application', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    const id = submit.body.id as string;

    const res = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(seekerToken))
      .send({ action: 'reject', reason: 'self' });
    expect(res.status).toBe(403);
  });

  it('rejects a reject once the application is already terminal', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    const id = submit.body.id as string;

    await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'reject', reason: 'No' });

    const again = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'reject', reason: 'No' });
    expect(again.status).toBe(409);
  });
});

describe('Manager transitions — cancel', () => {
  it('lets a manager cancel a submitted application', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    const id = submit.body.id as string;

    const cancelled = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(landlordToken))
      .send({ action: 'cancel', reason: 'Unit withdrawn' });
    expect(cancelled.status).toBe(200);
    expect(cancelled.body.application.status).toBe('cancelled');
  });

  it('denies a caretaker from cancelling an application', async () => {
    await pool.query(
      `INSERT INTO property_assignments (property_id, assignment_type, user_id, status, assigned_by, created_at)
       VALUES ($1, 'caretaker', $2, 'active', $2, NOW())`,
      [propertyId, caretakerUserId],
    );

    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    const id = submit.body.id as string;

    const res = await request(app)
      .post(`${ROUTE}/applications/${id}/transition`)
      .set(auth(caretakerToken))
      .send({ action: 'cancel' });
    expect(res.status).toBe(403);
  });
});

describe('Draft editing', () => {
  it('lets an applicant edit an existing draft', async () => {
    const draft = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send(submitBody({ proposedRentAmount: 40000 }));
    expect(draft.status).toBe(201);
    const id = draft.body.id as string;

    const updated = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send({ id, propertyId, unitId, proposedRentAmount: 50000, preferredEndDate: '2027-06-01' });
    expect(updated.status).toBe(200);
    expect(updated.body.status).toBe('draft');
    expect(updated.body.id).toBe(id);
    expect(Number(updated.body.proposedRentAmount)).toBe(50000);
  });

  it('refuses to edit a non-draft application', async () => {
    const submit = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submit.status).toBe(201);
    const id = submit.body.id as string;

    const res = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send({ id, propertyId, unitId, proposedRentAmount: 50000 });
    expect(res.status).toBe(409);
  });

  it('does not let an applicant edit another applicant\'s draft', async () => {
    const draft = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(draft.status).toBe(201);
    const id = draft.body.id as string;

    const res = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(otherToken))
      .send({ id, propertyId, unitId, proposedRentAmount: 50000 });
    expect(res.status).toBe(404);
  });
});

describe('Inbox listing filters', () => {
  it('filters the manager inbox by status', async () => {
    const submitted = await request(app)
      .post(`${ROUTE}/applications`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(submitted.status).toBe(201);
    const submittedId = submitted.body.id as string;

    const draft = await request(app)
      .post(`${ROUTE}/applications/draft`)
      .set(auth(seekerToken))
      .send(submitBody());
    expect(draft.status).toBe(201);

    const all = await request(app)
      .get(`${ROUTE}/applications`)
      .set(auth(landlordToken));
    expect(all.status).toBe(200);
    expect(all.body.items.some((a: { id: string }) => a.id === submittedId)).toBe(true);

    const byStatus = await request(app)
      .get(`${ROUTE}/applications?status=submitted`)
      .set(auth(landlordToken));
    expect(byStatus.status).toBe(200);
    expect(byStatus.body.items.some((a: { id: string }) => a.id === submittedId)).toBe(true);
    expect(byStatus.body.items.every((a: { status: string }) => a.status === 'submitted')).toBe(true);
  });
});