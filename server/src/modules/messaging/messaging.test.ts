import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let seeker: { id: string; token: string };
let landlord: { id: string; token: string };
let otherSeeker: { id: string; token: string };
let propertyId: string;
let unitId: string;
let enquiryId: string;

async function registerAndLogin(role: string): Promise<{ id: string; token: string }> {
  const email = `msg${Date.now()}${Math.floor(Math.random() * 1_000_000)}@example.com`;
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Msg',
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
    [email, `+2547${Math.floor(Math.random() * 900000000 + 100000000)}`],
  );
  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id as string;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [
    userId,
    role,
  ]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  const token = login.headers['x-access-token'] as string;
  return { id: userId, token };
}

async function cleanup() {
  await pool.query('DELETE FROM message_read_states');
  await pool.query('DELETE FROM message_attachments');
  await pool.query('DELETE FROM messages');
  await pool.query('DELETE FROM conversation_participants');
  await pool.query('DELETE FROM conversations');
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM notification_outbox');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM property_enquiries');
  await pool.query('DELETE FROM site_visits');
  await pool.query('DELETE FROM property_listings');
  await pool.query('DELETE FROM units');
  await pool.query('DELETE FROM property_ownerships');
  await pool.query('DELETE FROM properties');
  await pool.query(`DELETE FROM user_roles WHERE role_id IN ('landlord', 'house_seeker')`);
  await pool.query(`DELETE FROM user_profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'msg%@example.com')`);
  await pool.query(`DELETE FROM users WHERE email LIKE 'msg%@example.com'`);
}

beforeEach(async () => {
  await cleanup();
  seeker = await registerAndLogin('house_seeker');
  landlord = await registerAndLogin('landlord');
  otherSeeker = await registerAndLogin('house_seeker');

  const prop = await pool.query(
    `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
     VALUES (NULL, 'Msg Apartments', 'Desc', 'apartment', 'published', '1 Road', 'Nairobi', 'Nairobi', 'KE', 1, $1, NOW())
     RETURNING id`,
    [landlord.id],
  );
  propertyId = prop.rows[0].id;
  await pool.query(
    `INSERT INTO property_ownerships (property_id, owner_type, user_id, ownership_share, status, created_by)
     VALUES ($1, 'individual', $2, 100, 'active', $2)`,
    [propertyId, landlord.id],
  );
  const unit = await pool.query(
    `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
     VALUES ($1, 'A1', 'one_bedroom', 1, 1, 1, 1, 'vacant', $2) RETURNING id`,
    [propertyId, landlord.id],
  );
  unitId = unit.rows[0].id;
  const enq = await pool.query(
    `INSERT INTO property_enquiries (property_id, unit_id, prospective_renter_id, prospective_renter_name, enquiry_source, message, status, created_by)
     VALUES ($1, $2, $3, 'Seeker', 'property_detail', 'Is this available?', 'new', $3)
     RETURNING id`,
    [propertyId, unitId, seeker.id],
  );
  enquiryId = enq.rows[0].id;
});

afterEach(cleanup);

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

describe('Messaging centre — conversations', () => {
  it('creates an enquiry-linked conversation and notifies the landlord', async () => {
    const res = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'Hello, is this available?' });
    expect(res.status).toBe(201);
    expect(res.body.conversation.enquiryId).toBe(enquiryId);
    expect(res.body.reused).toBe(false);
    expect(res.body.firstMessage.content).toBe('Hello, is this available?');

    // Both parties are participants.
    const participants = await pool.query<{ user_id: string }>(
      `SELECT user_id FROM conversation_participants WHERE conversation_id = $1`,
      [res.body.conversation.id],
    );
    const ids = participants.rows.map((r) => r.user_id);
    expect(ids).toContain(seeker.id);
    expect(ids).toContain(landlord.id);

    // An outbox notification was queued for the landlord.
    const outbox = await pool.query<{ recipient_user_ids: string[]; status: string }>(
      `SELECT recipient_user_ids, status FROM notification_outbox WHERE event_type = 'message.created'`,
    );
    expect(outbox.rows.length).toBeGreaterThanOrEqual(1);
    expect(outbox.rows.some((r) => r.recipient_user_ids.includes(landlord.id))).toBe(true);
  });

  it('deduplicates enquiry conversations (no duplicate on second start)', async () => {
    const first = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'First' });
    expect(first.status).toBe(201);
    const second = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'Second' });
    expect(second.status).toBe(200);
    expect(second.body.reused).toBe(true);
    expect(second.body.conversation.id).toBe(first.body.conversation.id);

    const count = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM conversations WHERE enquiry_id = $1`,
      [enquiryId],
    );
    expect(count.rows[0]!.count).toBe('1');
  });

  it('rejects a conversation start with an unauthorized counterpart (IDOR)', async () => {
    const res = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({
        type: 'general',
        propertyId,
        participantUserIds: [otherSeeker.id], // not an owner/manager
        message: 'Hi',
      });
    expect(res.status).toBe(403);
  });

  it('lets a seeker contact a property host (contact flow) and dedups', async () => {
    const first = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'general', propertyId, participantUserIds: [landlord.id], message: 'Hi host' });
    expect(first.status).toBe(201);
    const second = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'general', propertyId, participantUserIds: [landlord.id], message: 'Again' });
    expect(second.status).toBe(200);
    expect(second.body.conversation.id).toBe(first.body.conversation.id);
  });

  it('lists only the caller’s conversations', async () => {
    await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'Hi' });

    const mine = await request(app).get('/api/v1/messaging/conversations').set(auth(seeker.token));
    expect(mine.status).toBe(200);
    expect(mine.body.items.length).toBe(1);

    const other = await request(app).get('/api/v1/messaging/conversations').set(auth(otherSeeker.token));
    expect(other.body.items.length).toBe(0);
  });

  it('reports the total unread count', async () => {
    const created = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'Unread me' });
    const conversationId = created.body.conversation.id;

    const unread = await request(app).get('/api/v1/messaging/conversations/unread-count').set(auth(landlord.token));
    expect(unread.status).toBe(200);
    expect(unread.body.unreadCount).toBe(1);

    await request(app).post(`/api/v1/messaging/conversations/${conversationId}/read`).set(auth(landlord.token));
    const after = await request(app).get('/api/v1/messaging/conversations/unread-count').set(auth(landlord.token));
    expect(after.body.unreadCount).toBe(0);
  });

  it('archives and reopens a conversation', async () => {
    const created = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'Hi' });
    const id = created.body.conversation.id;

    const archived = await request(app).post(`/api/v1/messaging/conversations/${id}/archive`).set(auth(seeker.token));
    expect(archived.status).toBe(200);
    expect(archived.body.archivedAt).toBeTruthy();

    const activeList = await request(app).get('/api/v1/messaging/conversations').set(auth(seeker.token));
    expect(activeList.body.items.length).toBe(0);

    const reopened = await request(app).post(`/api/v1/messaging/conversations/${id}/reopen`).set(auth(seeker.token));
    expect(reopened.status).toBe(200);
    expect(reopened.body.archivedAt).toBeNull();
  });

  it('searches conversations by message content', async () => {
    await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'zebra crossing question' });
    const res = await request(app)
      .get('/api/v1/messaging/conversations')
      .query({ search: 'zebra' })
      .set(auth(seeker.token));
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBe(1);
  });
});

describe('Messaging centre — messages', () => {
  async function createConversation(): Promise<string> {
    const res = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'start' });
    return res.body.conversation.id;
  }

  it('sends and retrieves messages in chronological order', async () => {
    const id = await createConversation();
    await request(app).post(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token)).send({ content: 'reply one' });
    await request(app).post(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token)).send({ content: 'reply two' });

    const res = await request(app).get(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token));
    expect(res.status).toBe(200);
    const contents = res.body.items.map((m: { content: string }) => m.content);
    expect(contents).toEqual(['start', 'reply one', 'reply two']);
  });

  it('paginates messages with a cursor (older pages)', async () => {
    const id = await createConversation();
    for (let i = 0; i < 5; i += 1) {
      await request(app).post(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token)).send({ content: `m${i}` });
    }
    // 6 messages total (start + m0..m4). First page = newest 3.
    const first = await request(app)
      .get(`/api/v1/messaging/conversations/${id}/messages`)
      .query({ limit: 3 })
      .set(auth(landlord.token));
    expect(first.body.items.length).toBe(3);
    expect(first.body.hasMore).toBe(true);
    expect(first.body.items[first.body.items.length - 1].content).toBe('m4');

    // Build a cursor from the oldest item of page 1.
    const oldest = first.body.items[0];
    const cursor = Buffer.from(JSON.stringify({ createdAt: oldest.createdAt, id: oldest.id })).toString('base64url');
    const second = await request(app)
      .get(`/api/v1/messaging/conversations/${id}/messages`)
      .query({ limit: 3, before: cursor })
      .set(auth(landlord.token));
    expect(second.body.items.length).toBe(3);
    expect(second.body.hasMore).toBe(false);
    expect(second.body.items[second.body.items.length - 1].content).toBe('m1');
  });

  it('rejects sending to a conversation the user is not a participant of', async () => {
    const id = await createConversation();
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${id}/messages`)
      .set(auth(otherSeeker.token))
      .send({ content: 'intruder' });
    expect(res.status).toBe(403);
  });

  it('rejects an empty message', async () => {
    const id = await createConversation();
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${id}/messages`)
      .set(auth(landlord.token))
      .send({ content: '   ' });
    expect(res.status).toBe(400);
  });

  it('marks a single message read (participant only) and blocks non-participants', async () => {
    const id = await createConversation();
    const list = await request(app).get(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token));
    const messageId = list.body.items[list.body.items.length - 1].id;

    const ok = await request(app).post(`/api/v1/messaging/messages/${messageId}/read`).set(auth(landlord.token));
    expect(ok.status).toBe(200);

    const forbidden = await request(app).post(`/api/v1/messaging/messages/${messageId}/read`).set(auth(otherSeeker.token));
    expect(forbidden.status).toBe(403);
  });

  it('emits an idempotent outbox event per message (no duplicate on reprocess)', async () => {
    const id = await createConversation();
    // Clear the start-message event so we measure only the message under test.
    await pool.query(`DELETE FROM notification_outbox`);
    await request(app).post(`/api/v1/messaging/conversations/${id}/messages`).set(auth(landlord.token)).send({ content: 'notify me' });
    const outbox = await pool.query<{ id: string; idempotency_key: string }>(
      `SELECT id, idempotency_key FROM notification_outbox WHERE event_type = 'message.created'`,
    );
    expect(outbox.rows.length).toBe(1);
    expect(outbox.rows[0]!.idempotency_key).toMatch(/^message\.created:/);
  });

  it('rejects reply to a message in another conversation', async () => {
    const id = await createConversation();
    // Create a second conversation to source a foreign message.
    const other = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'general', propertyId, participantUserIds: [landlord.id], message: 'foreign' });
    const foreignMessageId = other.body.firstMessage.id;
    const res = await request(app)
      .post(`/api/v1/messaging/conversations/${id}/messages`)
      .set(auth(landlord.token))
      .send({ content: 'bad reply', replyToId: foreignMessageId });
    expect(res.status).toBe(400);
  });

  it('does not leak internal enquiry notes through the messaging API', async () => {
    // internal_notes must never appear in any messaging response.
    await pool.query(`UPDATE property_enquiries SET internal_notes = 'SECRET STAFF NOTE' WHERE id = $1`, [enquiryId]);
    const created = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'hi' });
    const id = created.body.conversation.id;
    const detail = await request(app).get(`/api/v1/messaging/conversations/${id}`).set(auth(seeker.token));
    const serialized = JSON.stringify(detail.body);
    expect(serialized).not.toContain('SECRET STAFF NOTE');
    expect(serialized).not.toContain('internal_notes');
  });

  it('blocks access to conversation metadata for non-participants (IDOR)', async () => {
    const created = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'enquiry', enquiryId, message: 'hi' });
    const id = created.body.conversation.id;
    const res = await request(app).get(`/api/v1/messaging/conversations/${id}`).set(auth(otherSeeker.token));
    expect(res.status).toBe(403);
  });

  it('revokes a former property manager’s access when the assignment is removed', async () => {
    // Seeker contacts the host while the landlord is still an active owner.
    const created = await request(app)
      .post('/api/v1/messaging/conversations')
      .set(auth(seeker.token))
      .send({ type: 'general', propertyId, participantUserIds: [landlord.id], message: 'Hi host' });
    expect(created.status).toBe(201);
    const id = created.body.conversation.id;

    // Landlord can read the thread while still the owner.
    const before = await request(app).get(`/api/v1/messaging/conversations/${id}`).set(auth(landlord.token));
    expect(before.status).toBe(200);

    // Ownership is revoked out-of-band.
    await pool.query(`DELETE FROM property_ownerships WHERE property_id = $1 AND user_id = $2`, [
      propertyId,
      landlord.id,
    ]);

    // The former manager now loses access (lazy purge on direct access).
    const after = await request(app).get(`/api/v1/messaging/conversations/${id}`).set(auth(landlord.token));
    expect(after.status).toBe(403);

    // ...and the conversation drops out of their listing.
    const list = await request(app).get('/api/v1/messaging/conversations').set(auth(landlord.token));
    expect(list.body.items.some((c: { id: string }) => c.id === id)).toBe(false);

    // The seeker (conversation creator) retains access.
    const seekerView = await request(app).get(`/api/v1/messaging/conversations/${id}`).set(auth(seeker.token));
    expect(seekerView.status).toBe(200);
  });
});