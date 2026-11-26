// Notification API tests.
// Covers user-scoped notification retrieval, pagination, unread filtering,
// mark as read, cross-user access rejection (IDOR), notification payload
// privacy, and search-alert notification rendering data.

import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../app.js';
import { pool } from '../../db/pool.js';

const app = createApp({ nodeEnv: 'test' });

let userAId: string;
let userAToken: string;
let userBId: string;
let userBToken: string;

async function registerAndLogin(email: string): Promise<{ id: string; token: string }> {
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Test',
    lastName: 'User',
    email,
    password: 'password123',
    role: 'house_seeker',
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

  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  expect(login.status).toBe(200);
  const token = login.headers['x-access-token'] as string;
  expect(token).toBeDefined();
  return { id: userId, token };
}

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function createNotificationForUser(
  userId: string,
  overrides: {
    eventType?: string;
    category?: string;
    title?: string;
    body?: string;
    metadata?: Record<string, unknown>;
    priority?: string;
    isRead?: boolean;
  } = {},
): Promise<{ id: string }> {
  const {
    eventType = 'test.notification',
    category = 'property',
    title = 'Test notification',
    body = 'Test body',
    metadata = {},
    priority = 'normal',
    isRead = false,
  } = overrides;

  const result = await pool.query(
    `INSERT INTO notifications (user_id, event_type, category, title, body, metadata, priority, is_read, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
     RETURNING id`,
    [
      userId,
      eventType,
      category,
      title,
      body,
      JSON.stringify(metadata),
      priority,
      isRead,
    ],
  );
  return { id: result.rows[0].id };
}

async function cleanupTestData(): Promise<void> {
  await pool.query('DELETE FROM notification_recipients');
  await pool.query('DELETE FROM notification_delivery_attempts');
  await pool.query('DELETE FROM notification_dead_letters');
  await pool.query('DELETE FROM notifications');
  await pool.query('DELETE FROM saved_searches');
  await pool.query('DELETE FROM search_alert_deduplication');
  await pool.query('DELETE FROM user_roles WHERE role_id = (SELECT id FROM roles WHERE name = \'house_seeker\')');
  await pool.query('DELETE FROM user_login_identities');
  await pool.query('DELETE FROM users');
}

beforeEach(async () => {
  await cleanupTestData();

  const userA = await registerAndLogin(`usera${Date.now()}@example.com`);
  userAId = userA.id;
  userAToken = userA.token;

  const userB = await registerAndLogin(`userb${Date.now()}@example.com`);
  userBId = userB.id;
  userBToken = userB.token;
});

afterEach(async () => {
  await cleanupTestData();
});

describe('GET /api/auth/notifications', () => {
  it('returns an empty list when the user has no notifications', async () => {
    const response = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data).toEqual([]);
  });

  it('returns only the authenticated user\'s notifications (user-scoped)', async () => {
    await createNotificationForUser(userAId, { title: 'User A notification' });
    await createNotificationForUser(userBId, { title: 'User B notification' });

    const response = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].title).toBe('User A notification');
    expect(response.body.data[0].userId).toBe(userAId);
  });

  it('supports pagination with limit and offset', async () => {
    await createNotificationForUser(userAId, { title: 'Notification 1' });
    await createNotificationForUser(userAId, { title: 'Notification 2' });
    await createNotificationForUser(userAId, { title: 'Notification 3' });

    const page1 = await request(app)
      .get('/api/auth/notifications?limit=2&offset=0')
      .set(authHeaders(userAToken));
    expect(page1.body.data).toHaveLength(2);

    const page2 = await request(app)
      .get('/api/auth/notifications?limit=2&offset=2')
      .set(authHeaders(userAToken));
    expect(page2.body.data).toHaveLength(1);
  });

  it('supports filtering by unread status', async () => {
    await createNotificationForUser(userAId, { title: 'Unread', isRead: false });
    await createNotificationForUser(userAId, { title: 'Read', isRead: true });

    const unread = await request(app)
      .get('/api/auth/notifications?isRead=false')
      .set(authHeaders(userAToken));
    expect(unread.body.data).toHaveLength(1);
    expect(unread.body.data[0].title).toBe('Unread');

    const read = await request(app)
      .get('/api/auth/notifications?isRead=true')
      .set(authHeaders(userAToken));
    expect(read.body.data).toHaveLength(1);
    expect(read.body.data[0].title).toBe('Read');
  });

  it('supports filtering by category', async () => {
    await createNotificationForUser(userAId, { category: 'security', title: 'Security alert' });
    await createNotificationForUser(userAId, { category: 'property', title: 'Property match' });

    const property = await request(app)
      .get('/api/auth/notifications?category=property')
      .set(authHeaders(userAToken));
    expect(property.body.data).toHaveLength(1);
    expect(property.body.data[0].title).toBe('Property match');
  });

  it('does not expose private landlord or tenant information in metadata', async () => {
    await createNotificationForUser(userAId, {
      title: 'Search alert',
      metadata: {
        savedSearchId: 's1',
        listingId: 'l1',
        listingTitle: '2BR in Kilimani',
        listingLocation: 'Nairobi',
        listingPrice: 45000,
      },
    });

    const response = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    const notification = response.body.data[0];
    expect(notification.metadata.savedSearchId).toBe('s1');
    expect(notification.metadata.listingId).toBe('l1');
    expect(notification.metadata.listingTitle).toBe('2BR in Kilimani');
    expect(notification.metadata.listingLocation).toBe('Nairobi');
    expect(notification.metadata.listingPrice).toBe(45000);
    // No private coordinates, landlord contact, or tenant data in metadata.
    expect(notification.metadata.latitude).toBeUndefined();
    expect(notification.metadata.longitude).toBeUndefined();
    expect(notification.metadata.landlordPhone).toBeUndefined();
    expect(notification.metadata.tenantEmail).toBeUndefined();
  });
});

describe('GET /api/auth/notifications/unread-count', () => {
  it('returns the count of unread notifications', async () => {
    await createNotificationForUser(userAId, { title: 'Unread 1', isRead: false });
    await createNotificationForUser(userAId, { title: 'Unread 2', isRead: false });
    await createNotificationForUser(userAId, { title: 'Read', isRead: true });
    await createNotificationForUser(userBId, { title: 'Other user unread', isRead: false });

    const response = await request(app)
      .get('/api/auth/notifications/unread-count')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.count).toBe(2);
  });

  it('returns zero when all notifications are read', async () => {
    await createNotificationForUser(userAId, { title: 'Read', isRead: true });

    const response = await request(app)
      .get('/api/auth/notifications/unread-count')
      .set(authHeaders(userAToken));
    expect(response.body.data.count).toBe(0);
  });
});

describe('POST /api/auth/notifications/mark-read', () => {
  it('marks specified notifications as read', async () => {
    const n1 = await createNotificationForUser(userAId, { title: 'N1', isRead: false });
    const n2 = await createNotificationForUser(userAId, { title: 'N2', isRead: false });

    const response = await request(app)
      .post('/api/auth/notifications/mark-read')
      .set(authHeaders(userAToken))
      .send({ notificationIds: [n1.id, n2.id] });
    expect(response.status).toBe(200);
    expect(response.body.data.markedCount).toBe(2);

    // Verify they are now read.
    const notifications = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(notifications.body.data.every((n: { isRead: boolean }) => n.isRead)).toBe(true);
  });

  it('rejects marking another user\'s notification (IDOR)', async () => {
    const otherNotification = await createNotificationForUser(userBId, { title: 'User B notification' });

    const response = await request(app)
      .post('/api/auth/notifications/mark-read')
      .set(authHeaders(userAToken))
      .send({ notificationIds: [otherNotification.id] });
    expect(response.status).toBe(200);
    // User B's notification should not be marked as read by user A.
    expect(response.body.data.markedCount).toBe(0);
  });
});

describe('POST /api/auth/notifications/mark-all-read', () => {
  it('marks all notifications as read', async () => {
    await createNotificationForUser(userAId, { title: 'N1', isRead: false });
    await createNotificationForUser(userAId, { title: 'N2', isRead: false });

    const response = await request(app)
      .post('/api/auth/notifications/mark-all-read')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.data.markedCount).toBe(2);

    const notifications = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(notifications.body.data.every((n: { isRead: boolean }) => n.isRead)).toBe(true);
  });
});

describe('GET /api/auth/notifications/:id', () => {
  it('returns a single notification belonging to the authenticated user', async () => {
    const notification = await createNotificationForUser(userAId, { title: 'Specific notification' });

    const response = await request(app)
      .get(`/api/auth/notifications/${notification.id}`)
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.id).toBe(notification.id);
    expect(response.body.data.title).toBe('Specific notification');
  });

  it('returns 404 for another user\'s notification (IDOR protection)', async () => {
    const otherNotification = await createNotificationForUser(userBId, { title: 'User B notification' });

    const response = await request(app)
      .get(`/api/auth/notifications/${otherNotification.id}`)
      .set(authHeaders(userAToken));
    expect(response.status).toBe(404);
  });

  it('returns 404 for a non-existent notification', async () => {
    const response = await request(app)
      .get('/api/auth/notifications/00000000-0000-0000-0000-000000000000')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(404);
  });
});

describe('DELETE /api/auth/notifications/:id', () => {
  it('deletes a notification belonging to the authenticated user', async () => {
    const notification = await createNotificationForUser(userAId, { title: 'To be deleted' });

    const response = await request(app)
      .delete(`/api/auth/notifications/${notification.id}`)
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.data.deleted).toBe(true);

    // Verify it is gone.
    const getResponse = await request(app)
      .get(`/api/auth/notifications/${notification.id}`)
      .set(authHeaders(userAToken));
    expect(getResponse.status).toBe(404);
  });

  it('returns 404 when deleting another user\'s notification (IDOR)', async () => {
    const otherNotification = await createNotificationForUser(userBId, { title: 'User B notification' });

    const response = await request(app)
      .delete(`/api/auth/notifications/${otherNotification.id}`)
      .set(authHeaders(userAToken));
    expect(response.status).toBe(404);
  });
});

describe('Search-alert notification data', () => {
  it('contains structured data for Flutter to render search alerts', async () => {
    await createNotificationForUser(userAId, {
      eventType: 'saved_search.match',
      category: 'property',
      title: 'New match: Nairobi 2BR under 50k',
      body: 'A new property matches your saved search "Nairobi 2BR under 50k": 2-bedroom apartment · Nairobi · KES 45000.',
      metadata: {
        savedSearchId: 's1',
        listingId: 'l1',
        listingTitle: '2-bedroom apartment in Kilimani',
        listingLocation: 'Nairobi',
        listingPrice: 45000,
        searchName: 'Nairobi 2BR under 50k',
        summary: '2-bedroom apartment · Nairobi · KES 45000',
      },
      priority: 'normal',
    });

    const response = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);

    const notification = response.body.data[0];
    expect(notification.eventType).toBe('saved_search.match');
    expect(notification.category).toBe('property');
    expect(notification.metadata.savedSearchId).toBe('s1');
    expect(notification.metadata.listingId).toBe('l1');
    expect(notification.metadata.listingTitle).toBe('2-bedroom apartment in Kilimani');
    expect(notification.metadata.listingLocation).toBe('Nairobi');
    expect(notification.metadata.listingPrice).toBe(45000);
    expect(notification.metadata.searchName).toBe('Nairobi 2BR under 50k');
    expect(notification.metadata.summary).toBe('2-bedroom apartment · Nairobi · KES 45000');
  });
});

describe('Security notification regression', () => {
  it('security notifications remain functional alongside search alerts', async () => {
    await createNotificationForUser(userAId, {
      eventType: 'security.login',
      category: 'security',
      title: 'New sign-in detected',
      body: 'New sign-in from Chrome on Windows in Nairobi.',
      priority: 'high',
    });
    await createNotificationForUser(userAId, {
      eventType: 'saved_search.match',
      category: 'property',
      title: 'New match',
      body: 'A new property matches.',
      priority: 'normal',
    });

    const security = await request(app)
      .get('/api/auth/notifications?category=security')
      .set(authHeaders(userAToken));
    expect(security.body.data).toHaveLength(1);
    expect(security.body.data[0].category).toBe('security');
    expect(security.body.data[0].priority).toBe('high');

    const all = await request(app)
      .get('/api/auth/notifications')
      .set(authHeaders(userAToken));
    expect(all.body.data).toHaveLength(2);
  });
});
