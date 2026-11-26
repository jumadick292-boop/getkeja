import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';
import { startConversation } from './messaging.service.js';
import { NotificationService, NotificationPreferenceService } from '../auth/notification.service.js';

const app = createApp({ nodeEnv: 'test' });
const notifications = new NotificationService();
const prefService = new NotificationPreferenceService();

let customer: string;
let owner: string;
let staff: string;
let outsider: string;
let orgId: string;
let requestId: string;

async function makeUser(email: string, verified = true): Promise<string> {
  const r = await pool.query(
    `INSERT INTO users (email, name, is_active, email_verified, phone_verified, account_status)
     VALUES ($1, $2, TRUE, $3, $3, 'active') RETURNING id`,
    [email, email.split('@')[0], verified],
  );
  return r.rows[0].id as string;
}

async function cleanup() {
  await pool.query('DELETE FROM message_read_states');
  await pool.query('DELETE FROM messages');
  await pool.query('DELETE FROM conversation_participants');
  await pool.query('DELETE FROM conversations');
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM notification_preferences');
  await pool.query('DELETE FROM organisation_members');
  await pool.query('DELETE FROM specialized_profiles');
  await pool.query('DELETE FROM service_requests');
  await pool.query('DELETE FROM organisations');
  await pool.query(`DELETE FROM users WHERE email LIKE 'pc%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
  const stamp = Date.now();
  customer = await makeUser(`pc-customer-${stamp}@example.com`);
  owner = await makeUser(`pc-owner-${stamp}@example.com`);
  staff = await makeUser(`pc-staff-${stamp}@example.com`);
  outsider = await makeUser(`pc-outsider-${stamp}@example.com`);

  const org = await pool.query(
    `INSERT INTO organisations (name, slug, type, is_active)
     VALUES ('PC Movers', $1, 'moving_company', TRUE) RETURNING id`,
    [`pc-movers-${stamp}`],
  );
  orgId = org.rows[0].id;
  await pool.query(
    `INSERT INTO organisation_members (organisation_id, user_id, role, status)
     VALUES ($1, $2, 'owner', 'active'), ($1, $3, 'staff', 'active')`,
    [orgId, owner, staff],
  );

  const profile = await pool.query(
    `INSERT INTO specialized_profiles (user_id, profile_category, organisation_id)
     VALUES ($1, 'moving_service_provider', $2) RETURNING id`,
    [owner, orgId],
  );

  const cat = await pool.query(`SELECT id FROM service_categories LIMIT 1`);
  const req = await pool.query(
    `INSERT INTO service_requests (category_id, domain, customer_user_id, description, title, status, assigned_provider_id, created_by)
     VALUES ($1, 'moving', $2, 'Need a move', 'My move', 'open', $3, $2) RETURNING id`,
    [cat.rows[0].id, customer, profile.rows[0].id],
  );
  requestId = req.rows[0].id;
});

afterEach(cleanup);

describe('Contextual conversations (Task 13.10)', () => {
  it('creates a marketplace-request conversation for the customer', async () => {
    const res = await startConversation(customer, { type: 'marketplace_request', marketplaceRequestId: requestId });
    expect(res.reused).toBe(false);
    expect(res.conversation.marketplaceRequestId).toBe(requestId);
  });

  it('reuses the same authorized conversation on repeated opens (dedup)', async () => {
    const first = await startConversation(customer, { type: 'marketplace_request', marketplaceRequestId: requestId });
    const second = await startConversation(owner, { type: 'marketplace_request', marketplaceRequestId: requestId });
    expect(second.reused).toBe(true);
    expect(second.conversation.id).toBe(first.conversation.id);
  });

  it('allows the provider owner but denies an unassigned org staff member', async () => {
    await startConversation(customer, { type: 'marketplace_request', marketplaceRequestId: requestId });
    const asOwner = await startConversation(owner, { type: 'marketplace_request', marketplaceRequestId: requestId });
    expect(asOwner.reused).toBe(true);
    // A staff member who is not an owner/admin and not assigned to the resource
    // must not gain access merely by belonging to the organisation.
    await expect(
      startConversation(staff, { type: 'marketplace_request', marketplaceRequestId: requestId }),
    ).rejects.toThrow();
  });

  it('forbids an unrelated provider from opening the conversation', async () => {
    await expect(
      startConversation(outsider, { type: 'marketplace_request', marketplaceRequestId: requestId }),
    ).rejects.toThrow();
  });

  it('denies a staff member whose membership is revoked', async () => {
    await startConversation(customer, { type: 'marketplace_request', marketplaceRequestId: requestId });
    await pool.query(`UPDATE organisation_members SET status = 'removed', removed_at = NOW() WHERE user_id = $1`, [staff]);
    await expect(
      startConversation(staff, { type: 'marketplace_request', marketplaceRequestId: requestId }),
    ).rejects.toThrow();
  });
});

describe('Notification preference + verification enforcement (Task 13.10)', () => {
  it('does not email/SMS/push an unverified contact but still delivers in-app', async () => {
    const unverified = await makeUser(`pc-unverified-${Date.now()}@example.com`, false);
    await notifications.createOutboxEvent({
      idempotencyKey: `pc:test:${unverified}`,
      eventType: 'message.created',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [unverified],
      organisationId: null,
      resourceType: 'conversation',
      resourceId: '00000000-0000-0000-0000-000000000000',
      payload: { subject: 'Hi' },
      channels: ['in_app', 'email', 'sms', 'push'],
    });
    const outbox = await pool.query(`SELECT id FROM notification_outbox WHERE idempotency_key = $1`, [`pc:test:${unverified}`]);
    await notifications.processOutboxEvent(outbox.rows[0].id);
    const attempts = await pool.query(
      `SELECT channel FROM notification_delivery_attempts nda
         JOIN notifications n ON n.id = nda.notification_id WHERE n.user_id = $1`,
      [unverified],
    );
    const channels = attempts.rows.map((r) => r.channel);
    expect(channels).toContain('in_app');
    expect(channels).not.toContain('email');
    expect(channels).not.toContain('sms');
    expect(channels).not.toContain('push');
  });

  it('delivers essential security notifications even when category channels are opted out', async () => {
    await prefService.update(customer, {
      securityEmail: false,
      securitySms: false,
      securityPush: false,
      securityInApp: false,
      marketingEmail: false,
    });
    await notifications.createOutboxEvent({
      idempotencyKey: `pc:sec:${customer}`,
      eventType: 'security.password_changed',
      category: 'security',
      priority: 'critical',
      recipientUserIds: [customer],
      organisationId: null,
      resourceType: null,
      resourceId: null,
      payload: {},
      channels: ['in_app', 'email'],
    });
    const outbox = await pool.query(`SELECT id FROM notification_outbox WHERE idempotency_key = $1`, [`pc:sec:${customer}`]);
    await notifications.processOutboxEvent(outbox.rows[0].id);
    const attempts = await pool.query(
      `SELECT channel FROM notification_delivery_attempts nda
         JOIN notifications n ON n.id = nda.notification_id WHERE n.user_id = $1`,
      [customer],
    );
    const channels = attempts.rows.map((r) => r.channel);
    expect(channels).toContain('in_app');
    expect(channels).toContain('email');
  });

  it('attaches a deep link to operational notifications', async () => {
    await notifications.createOutboxEvent({
      idempotencyKey: `pc:deep:${customer}`,
      eventType: 'moving_job.confirmed',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [customer],
      organisationId: null,
      resourceType: 'moving_job',
      resourceId: requestId,
      payload: {},
      channels: ['in_app'],
    });
    const outbox = await pool.query(`SELECT id FROM notification_outbox WHERE idempotency_key = $1`, [`pc:deep:${customer}`]);
    await notifications.processOutboxEvent(outbox.rows[0].id);
    const n = await pool.query(`SELECT metadata FROM notifications WHERE user_id = $1`, [customer]);
    expect(n.rows[0].metadata.deepLink).toBe(`getkeja://moving/jobs/${requestId}`);
  });
});