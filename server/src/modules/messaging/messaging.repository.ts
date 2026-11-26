import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import { pool } from '../../db/pool.js';
import { HttpError, NotFoundError } from '../../shared/errors.js';

export type ConversationContextType =
  | 'enquiry'
  | 'site_visit'
  | 'rental_application'
  | 'rental_proposal'
  | 'tenancy'
  | 'maintenance'
  | 'garbage_service'
  | 'moving_job'
  | 'marketplace_request'
  | 'garbage_job'
  | 'laundry_order'
  | 'scheduling_activity'
  | 'general';

export interface ConversationRow {
  id: string;
  type: string;
  subject: string | null;
  propertyId: string | null;
  unitId: string | null;
  enquiryId: string | null;
  rentalApplicationId: string | null;
  rentalProposalId: string | null;
  tenancyId: string | null;
  siteVisitId: string | null;
  movingJobId: string | null;
  marketplaceRequestId: string | null;
  garbageJobId: string | null;
  laundryOrderId: string | null;
  schedulingActivityId: string | null;
  createdBy: string;
  status: string;
  archivedAt: Date | null;
  lastMessageAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ConversationListItem extends ConversationRow {
  propertyTitle: string | null;
  city: string | null;
  county: string | null;
  unreadCount: number;
  lastMessagePreview: string | null;
  lastMessageSenderId: string | null;
  participantCount: number;
}

export interface MessageRow {
  id: string;
  conversationId: string;
  senderId: string;
  type: string;
  content: string;
  status: string;
  replyToId: string | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

export interface MessageListItem extends MessageRow {
  isRead: boolean;
  attachments: AttachmentRow[];
}

export interface AttachmentRow {
  id: string;
  messageId: string;
  fileName: string;
  filePath: string;
  fileSizeBytes: string | null;
  mimeType: string | null;
  uploadedBy: string;
  createdAt: Date;
}

const CONVERSATION_COLUMNS = `
  id, type, subject, property_id AS "propertyId", unit_id AS "unitId",
  enquiry_id AS "enquiryId", rental_application_id AS "rentalApplicationId", rental_proposal_id AS "rentalProposalId",
  tenancy_id AS "tenancyId", site_visit_id AS "siteVisitId",
  moving_job_id AS "movingJobId", marketplace_request_id AS "marketplaceRequestId",
  garbage_job_id AS "garbageJobId", laundry_order_id AS "laundryOrderId",
  scheduling_activity_id AS "schedulingActivityId", created_by AS "createdBy",
  status, archived_at AS "archivedAt", last_message_at AS "lastMessageAt",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

const MESSAGE_COLUMNS = `
  id, conversation_id AS "conversationId", sender_id AS "senderId", type, content,
  status, reply_to_id AS "replyToId", created_at AS "createdAt",
  updated_at AS "updatedAt", deleted_at AS "deletedAt"`;

const ATTACHMENT_COLUMNS = `
  id, message_id AS "messageId", file_name AS "fileName", file_path AS "filePath",
  file_size_bytes AS "fileSizeBytes", mime_type AS "mimeType",
  uploaded_by AS "uploadedBy", created_at AS "createdAt"`;

// ---------------------------------------------------------------------------
// Cursor helpers: an opaque, tamper-evident cursor over (createdAt, id).
// ---------------------------------------------------------------------------
export interface MessageCursor {
  createdAt: string;
  id: string;
}

export function encodeMessageCursor(cursor: MessageCursor): string {
  return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
}

export function decodeMessageCursor(raw: string | undefined | null): MessageCursor | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as Partial<MessageCursor>;
    if (typeof parsed.createdAt === 'string' && typeof parsed.id === 'string') {
      return { createdAt: parsed.createdAt, id: parsed.id };
    }
    return null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Participant helpers
// ---------------------------------------------------------------------------
export async function isActiveParticipant(
  connection: PoolClient | typeof pool,
  conversationId: string,
  userId: string,
): Promise<boolean> {
  const result = await connection.query(
    `SELECT 1 FROM conversation_participants
      WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
    [conversationId, userId],
  );
  return Boolean(result.rows[0]);
}

export async function assertActiveParticipant(
  connection: PoolClient | typeof pool,
  conversationId: string,
  userId: string,
): Promise<void> {
  // Re-validate property-side participants against current ownership /
  // assignment data so a former manager loses access when revoked.
  await purgeRevokedManagers(connection, conversationId);
  if (!(await isActiveParticipant(connection, conversationId, userId))) {
    // Do not reveal whether the conversation exists to a non-participant.
    throw new HttpError('You do not have access to this conversation', 403);
  }
}

/**
 * Remove property-side participants who are no longer authorized managers.
 *
 * Rules (only for conversations tied to a property):
 *  - The conversation creator (`created_by`) is never purged (historical access).
 *  - If the creator is the customer side (not a current manager), every other
 *    participant must be a current active manager to keep access — a landlord
 *    or agent whose ownership/assignment was revoked is marked as left.
 *  - If the creator is a manager (landlord-initiated thread), the other
 *    participant is the customer and is never purged.
 */
export async function purgeRevokedManagers(
  connection: PoolClient | typeof pool,
  conversationId: string,
): Promise<void> {
  const convo = await connection.query<{ property_id: string | null; created_by: string }>(
    `SELECT property_id, created_by FROM conversations WHERE id = $1`,
    [conversationId],
  );
  const row = convo.rows[0];
  if (!row || !row.property_id) return;

  const managers = await deriveManagerUserIds(connection, row.property_id);
  const managerSet = new Set(managers);
  const creatorIsManager = managerSet.has(row.created_by);

  const participants = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM conversation_participants
      WHERE conversation_id = $1 AND left_at IS NULL AND user_id <> $2`,
    [conversationId, row.created_by],
  );
  const toRemove = participants.rows
    .map((p) => p.user_id)
    .filter((uid) => {
      if (managerSet.has(uid)) return false; // still an active manager
      // Customer-initiated thread: non-managers other than the creator must go.
      return !creatorIsManager;
    });

  for (const uid of toRemove) {
    await connection.query(
      `UPDATE conversation_participants SET left_at = NOW()
        WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [conversationId, uid],
    );
  }
}

async function deriveManagerUserIds(
  connection: PoolClient | typeof pool,
  propertyId: string,
): Promise<string[]> {
  const result = await connection.query<{ user_id: string }>(
    `SELECT po.user_id AS user_id
       FROM property_ownerships po
      WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
        AND (po.effective_to IS NULL OR po.effective_to > NOW())
      UNION
      SELECT pa.user_id AS user_id
       FROM property_assignments pa
      WHERE pa.property_id = $1 AND pa.status = 'active' AND pa.user_id IS NOT NULL
        AND (pa.effective_to IS NULL OR pa.effective_to > NOW())`,
    [propertyId],
  );
  return result.rows.map((r) => r.user_id);
}

export async function getConversation(
  connection: PoolClient | typeof pool,
  conversationId: string,
): Promise<ConversationRow | undefined> {
  const result = await connection.query<ConversationRow>(
    `SELECT ${CONVERSATION_COLUMNS} FROM conversations WHERE id = $1`,
    [conversationId],
  );
  return result.rows[0];
}

export async function getParticipantUserIds(
  connection: PoolClient | typeof pool,
  conversationId: string,
): Promise<string[]> {
  const result = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM conversation_participants
      WHERE conversation_id = $1 AND left_at IS NULL`,
    [conversationId],
  );
  return result.rows.map((row) => row.user_id);
}

export interface ParticipantSummary {
  userId: string;
  role: string;
  firstName: string | null;
  lastName: string | null;
  name: string | null;
  avatarUrl: string | null;
  isMuted: boolean;
  lastReadAt: Date | null;
}

export async function listParticipants(
  connection: PoolClient | typeof pool,
  conversationId: string,
): Promise<ParticipantSummary[]> {
  const result = await connection.query<ParticipantSummary>(
    `SELECT cp.user_id AS "userId", cp.role,
            u.first_name AS "firstName", u.last_name AS "lastName", u.name,
            up.profile_photo_url AS "avatarUrl",
            cp.is_muted AS "isMuted", cp.last_read_at AS "lastReadAt"
       FROM conversation_participants cp
       JOIN users u ON u.id = cp.user_id
       LEFT JOIN user_profiles up ON up.user_id = cp.user_id
      WHERE cp.conversation_id = $1 AND cp.left_at IS NULL
      ORDER BY cp.joined_at ASC`,
    [conversationId],
  );
  return result.rows;
}

// ---------------------------------------------------------------------------
// Listing / retrieval
// ---------------------------------------------------------------------------
export interface ListConversationsOptions {
  status?: string; // active | archived | all
  type?: string;
  propertyId?: string;
  search?: string;
  limit: number;
  offset: number;
}

export async function listConversationsForUser(
  userId: string,
  options: ListConversationsOptions,
): Promise<{ items: ConversationListItem[]; total: number }> {
  const conditions: string[] = [`cp.user_id = $1`, `cp.left_at IS NULL`];
  const values: unknown[] = [userId];
  let index = 2;

  const status = options.status ?? 'active';
  if (status === 'active') {
    conditions.push(`c.archived_at IS NULL`);
  } else if (status === 'archived') {
    conditions.push(`c.archived_at IS NOT NULL`);
  }

  if (options.type) {
    conditions.push(`c.type = $${index++}::conversation_type`);
    values.push(options.type);
  }
  if (options.propertyId) {
    conditions.push(`c.property_id = $${index++}`);
    values.push(options.propertyId);
  }
  if (options.search) {
    conditions.push(
      `(c.subject ILIKE $${index} OR EXISTS (
          SELECT 1 FROM messages sm
           WHERE sm.conversation_id = c.id AND sm.deleted_at IS NULL AND sm.content ILIKE $${index}
       ) OR EXISTS (
          SELECT 1 FROM properties sp WHERE sp.id = c.property_id AND sp.title ILIKE $${index}
       ))`,
    );
    values.push(`%${options.search}%`);
    index += 1;
  }

  const whereClause = `WHERE ${conditions.join(' AND ')}`;

  const countResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
      ${whereClause}`,
    values,
  );
  const total = Number.parseInt(countResult.rows[0]?.count ?? '0', 10);

  const limitValue = values.length + 1;
  const offsetValue = values.length + 2;
  values.push(options.limit, options.offset);

  const result = await pool.query<ConversationListItem>(
    `SELECT c.id, c.type, c.subject, c.property_id AS "propertyId", c.unit_id AS "unitId",
            c.enquiry_id AS "enquiryId", c.rental_application_id AS "rentalApplicationId",
            c.rental_proposal_id AS "rentalProposalId",
            c.tenancy_id AS "tenancyId", c.site_visit_id AS "siteVisitId", c.created_by AS "createdBy",
            c.status, c.archived_at AS "archivedAt", c.last_message_at AS "lastMessageAt",
            c.created_at AS "createdAt", c.updated_at AS "updatedAt",
            p.title AS "propertyTitle", p.city, p.county,
            (SELECT count(*)::int FROM messages m
              WHERE m.conversation_id = c.id AND m.deleted_at IS NULL
                AND m.sender_id <> $1
                AND NOT EXISTS (
                  SELECT 1 FROM message_read_states mrs
                   WHERE mrs.message_id = m.id AND mrs.user_id = $1)) AS "unreadCount",
            lm.content AS "lastMessagePreview",
            lm.sender_id AS "lastMessageSenderId",
            (SELECT count(*)::int FROM conversation_participants cpx
              WHERE cpx.conversation_id = c.id AND cpx.left_at IS NULL) AS "participantCount"
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       LEFT JOIN properties p ON p.id = c.property_id
       LEFT JOIN LATERAL (
         SELECT content, sender_id FROM messages m2
          WHERE m2.conversation_id = c.id AND m2.deleted_at IS NULL
          ORDER BY m2.created_at DESC, m2.id DESC
          LIMIT 1
       ) lm ON TRUE
      ${whereClause}
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC, c.id DESC
      LIMIT $${limitValue} OFFSET $${offsetValue}`,
    values,
  );
  return { items: result.rows, total };
}

export async function getTotalUnreadCount(userId: string): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
       FROM messages m
       JOIN conversation_participants cp ON cp.conversation_id = m.conversation_id
      WHERE cp.user_id = $1 AND cp.left_at IS NULL
        AND m.deleted_at IS NULL
        AND m.sender_id <> $1
        AND NOT EXISTS (
          SELECT 1 FROM message_read_states mrs
           WHERE mrs.message_id = m.id AND mrs.user_id = $1
        )`,
    [userId],
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}

export async function getConversationUnreadCount(
  conversationId: string,
  userId: string,
): Promise<number> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM messages m
      WHERE m.conversation_id = $1 AND m.deleted_at IS NULL AND m.sender_id <> $2
        AND NOT EXISTS (
          SELECT 1 FROM message_read_states mrs
           WHERE mrs.message_id = m.id AND mrs.user_id = $2
        )`,
    [conversationId, userId],
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}

// ---------------------------------------------------------------------------
// Contextual conversation resolution + creation
// ---------------------------------------------------------------------------
export async function findActiveConversationForContext(
  connection: PoolClient | typeof pool,
  context: {
    type: ConversationContextType;
    column:
      | 'enquiry_id'
      | 'site_visit_id'
      | 'tenancy_id'
      | 'rental_application_id'
      | 'rental_proposal_id'
      | 'moving_job_id'
      | 'marketplace_request_id'
      | 'garbage_job_id'
      | 'laundry_order_id'
      | 'scheduling_activity_id';
    id: string;
  },
): Promise<ConversationRow | undefined> {
  // `context.column` is a trusted internal literal (one of the five concrete
  // *_id columns), never user input, so it is safe to interpolate as an
  // identifier. The id is always bound as a parameter.
  const result = await connection.query<ConversationRow>(
    `SELECT ${CONVERSATION_COLUMNS}
       FROM conversations c
      WHERE c.${context.column} = $1
        AND c.archived_at IS NULL
      ORDER BY c.created_at ASC
      LIMIT 1`,
    [context.id],
  );
  return result.rows[0];
}

/**
 * Find an existing active property-contact conversation started by a given
 * user for a given property (no enquiry/site-visit/tenancy context). Used to
 * dedup "Message the host" taps.
 */
export async function findActivePropertyConversation(
  connection: PoolClient | typeof pool,
  propertyId: string,
  createdBy: string,
): Promise<ConversationRow | undefined> {
  const result = await connection.query<ConversationRow>(
    `SELECT ${CONVERSATION_COLUMNS}
       FROM conversations c
      WHERE c.property_id = $1
        AND c.created_by = $2
        AND c.enquiry_id IS NULL
        AND c.site_visit_id IS NULL
        AND c.tenancy_id IS NULL
        AND c.archived_at IS NULL
        AND EXISTS (
          SELECT 1 FROM conversation_participants cp
           WHERE cp.conversation_id = c.id AND cp.user_id = $2 AND cp.left_at IS NULL
        )
      ORDER BY c.created_at ASC
      LIMIT 1`,
    [propertyId, createdBy],
  );
  return result.rows[0];
}

export interface CreateConversationInput {
  type: ConversationContextType;
  subject: string | null;
  propertyId: string | null;
  unitId: string | null;
  enquiryId: string | null;
  rentalApplicationId: string | null;
  rentalProposalId: string | null;
  siteVisitId: string | null;
  tenancyId: string | null;
  movingJobId?: string | null;
  marketplaceRequestId?: string | null;
  garbageJobId?: string | null;
  laundryOrderId?: string | null;
  schedulingActivityId?: string | null;
  participantUserIds: string[];
  createdBy: string;
  firstMessage?: string | null;
}

export async function insertConversationWithMessage(
  input: CreateConversationInput,
): Promise<{ conversation: ConversationRow; firstMessage: MessageRow | null }> {
  return dbTransaction(async (client) => {
    const conversationId = randomUUID();
    const result = await client.query<ConversationRow>(
      `INSERT INTO conversations
         (id, type, subject, property_id, unit_id, enquiry_id, rental_application_id, rental_proposal_id, site_visit_id, tenancy_id,
          moving_job_id, marketplace_request_id, garbage_job_id, laundry_order_id, scheduling_activity_id, created_by)
       VALUES ($1, $2::conversation_type, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
       RETURNING ${CONVERSATION_COLUMNS}`,
      [
        conversationId,
        input.type,
        input.subject,
        input.propertyId,
        input.unitId,
        input.enquiryId,
        input.rentalApplicationId,
        input.rentalProposalId,
        input.siteVisitId,
        input.tenancyId,
        input.movingJobId ?? null,
        input.marketplaceRequestId ?? null,
        input.garbageJobId ?? null,
        input.laundryOrderId ?? null,
        input.schedulingActivityId ?? null,
        input.createdBy,
      ],
    );
    const conversation = result.rows[0]!;

    const participantIds = [...new Set([input.createdBy, ...input.participantUserIds])];
    for (const participantId of participantIds) {
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, role)
         VALUES ($1, $2, $3)
         ON CONFLICT (conversation_id, user_id) DO NOTHING`,
        [conversationId, participantId, participantId === input.createdBy ? 'owner' : 'participant'],
      );
    }

    let firstMessage: MessageRow | null = null;
    if (input.firstMessage && input.firstMessage.trim().length > 0) {
      const messageResult = await client.query<MessageRow>(
        `INSERT INTO messages (conversation_id, sender_id, type, content)
         VALUES ($1, $2, 'text', $3)
         RETURNING ${MESSAGE_COLUMNS}`,
        [conversationId, input.createdBy, input.firstMessage.trim()],
      );
      firstMessage = messageResult.rows[0] ?? null;
      await client.query(`UPDATE conversations SET last_message_at = NOW() WHERE id = $1`, [conversationId]);
    }

    return { conversation, firstMessage };
  });
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------
export interface ListMessagesOptions {
  // Cursor points at the oldest message already loaded; return messages older.
  before?: MessageCursor | null;
  limit: number;
}

export async function listMessages(
  conversationId: string,
  viewerId: string,
  options: ListMessagesOptions,
): Promise<{ items: MessageListItem[]; hasMore: boolean }> {
  const limit = options.limit;

  if (options.before) {
    // Keyset: messages strictly older than the cursor.
    const cursor = options.before;
    const result = await pool.query<MessageRow & { isRead: boolean }>(
      `SELECT ${MESSAGE_COLUMNS},
              EXISTS (SELECT 1 FROM message_read_states mrs
                       WHERE mrs.message_id = messages.id AND mrs.user_id = $2) AS "isRead"
         FROM messages
        WHERE conversation_id = $1 AND deleted_at IS NULL
          AND (created_at, id) < ($3::timestamptz, $4::uuid)
        ORDER BY created_at DESC, id DESC
        LIMIT $5`,
      [conversationId, viewerId, cursor.createdAt, cursor.id, limit + 1],
    );
    const rows = result.rows;
    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    page.reverse(); // chronological ascending for the client
    return { items: await attachMetadata(page), hasMore };
  }

  // Initial load: newest `limit` messages, returned ascending.
  const result = await pool.query<MessageRow & { isRead: boolean }>(
    `SELECT ${MESSAGE_COLUMNS},
            EXISTS (SELECT 1 FROM message_read_states mrs
                     WHERE mrs.message_id = messages.id AND mrs.user_id = $2) AS "isRead"
       FROM messages
      WHERE conversation_id = $1 AND deleted_at IS NULL
      ORDER BY created_at DESC, id DESC
      LIMIT $3`,
    [conversationId, viewerId, limit + 1],
  );
  const rows = result.rows;
  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  page.reverse();
  return { items: await attachMetadata(page), hasMore };
}

async function attachMetadata(
  rows: (MessageRow & { isRead: boolean })[],
): Promise<MessageListItem[]> {
  if (rows.length === 0) return [];
  const ids = rows.map((row) => row.id);
  const attachmentsResult = await pool.query<AttachmentRow>(
    `SELECT ${ATTACHMENT_COLUMNS}
       FROM message_attachments
      WHERE message_id = ANY($1::uuid[])
      ORDER BY created_at ASC`,
    [ids],
  );
  const byMessage = new Map<string, AttachmentRow[]>();
  for (const attachment of attachmentsResult.rows) {
    const list = byMessage.get(attachment.messageId) ?? [];
    list.push(attachment);
    byMessage.set(attachment.messageId, list);
  }
  return rows.map((row) => ({
    id: row.id,
    conversationId: row.conversationId,
    senderId: row.senderId,
    type: row.type,
    content: row.content,
    status: row.status,
    replyToId: row.replyToId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    isRead: row.isRead,
    attachments: byMessage.get(row.id) ?? [],
  }));
}

export async function getMessageById(
  connection: PoolClient | typeof pool,
  messageId: string,
): Promise<MessageRow | undefined> {
  const result = await connection.query<MessageRow>(
    `SELECT ${MESSAGE_COLUMNS} FROM messages WHERE id = $1 AND deleted_at IS NULL`,
    [messageId],
  );
  return result.rows[0];
}

export async function insertMessage(data: {
  conversationId: string;
  senderId: string;
  content: string;
  type?: string;
  replyToId?: string | null;
  client?: PoolClient;
}): Promise<MessageRow> {
  const executor = data.client ?? pool;
  const result = await executor.query<MessageRow>(
    `INSERT INTO messages (conversation_id, sender_id, type, content, reply_to_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING ${MESSAGE_COLUMNS}`,
    [data.conversationId, data.senderId, data.type ?? 'text', data.content, data.replyToId ?? null],
  );
  await executor.query(`UPDATE conversations SET last_message_at = NOW() WHERE id = $1`, [data.conversationId]);
  return result.rows[0]!;
}

// ---------------------------------------------------------------------------
// Read state
// ---------------------------------------------------------------------------
export async function markConversationRead(
  connection: PoolClient | typeof pool,
  conversationId: string,
  userId: string,
): Promise<number> {
  const result = await connection.query(
    `INSERT INTO message_read_states (message_id, user_id)
     SELECT m.id, $2 FROM messages m
      WHERE m.conversation_id = $1 AND m.deleted_at IS NULL AND m.sender_id <> $2
      ON CONFLICT (message_id, user_id) DO NOTHING`,
    [conversationId, userId],
  );
  await connection.query(
    `UPDATE conversation_participants SET last_read_at = NOW()
      WHERE conversation_id = $1 AND user_id = $2`,
    [conversationId, userId],
  );
  return result.rowCount ?? 0;
}

export async function markMessageRead(
  connection: PoolClient | typeof pool,
  messageId: string,
  userId: string,
): Promise<void> {
  await connection.query(
    `INSERT INTO message_read_states (message_id, user_id)
     VALUES ($1, $2)
     ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = NOW()`,
    [messageId, userId],
  );
}

// ---------------------------------------------------------------------------
// Archive / reopen
// ---------------------------------------------------------------------------
export async function setConversationArchived(
  conversationId: string,
  archived: boolean,
): Promise<ConversationRow | undefined> {
  const result = await pool.query<ConversationRow>(
    `UPDATE conversations
        SET archived_at = ${archived ? 'NOW()' : 'NULL'},
            status = ${archived ? "'archived'" : "'active'"}
      WHERE id = $1
      RETURNING ${CONVERSATION_COLUMNS}`,
    [conversationId],
  );
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Attachments
// ---------------------------------------------------------------------------
export async function insertAttachment(data: {
  messageId: string;
  fileName: string;
  filePath: string;
  fileSizeBytes: number | null;
  mimeType: string | null;
  uploadedBy: string;
  client?: PoolClient;
}): Promise<AttachmentRow> {
  const executor = data.client ?? pool;
  const result = await executor.query<AttachmentRow>(
    `INSERT INTO message_attachments
       (message_id, file_name, file_path, file_size_bytes, mime_type, uploaded_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING ${ATTACHMENT_COLUMNS}`,
    [
      data.messageId,
      data.fileName,
      data.filePath,
      data.fileSizeBytes,
      data.mimeType,
      data.uploadedBy,
    ],
  );
  return result.rows[0]!;
}

export async function getAttachment(
  connection: PoolClient | typeof pool,
  attachmentId: string,
): Promise<AttachmentRow | undefined> {
  const result = await connection.query<AttachmentRow>(
    `SELECT ${ATTACHMENT_COLUMNS} FROM message_attachments WHERE id = $1`,
    [attachmentId],
  );
  return result.rows[0];
}

export async function listAttachmentsForMessages(
  messageIds: string[],
): Promise<Map<string, AttachmentRow[]>> {
  if (messageIds.length === 0) return new Map();
  const result = await pool.query<AttachmentRow>(
    `SELECT ${ATTACHMENT_COLUMNS} FROM message_attachments
      WHERE message_id = ANY($1::uuid[]) ORDER BY created_at ASC`,
    [messageIds],
  );
  const map = new Map<string, AttachmentRow[]>();
  for (const row of result.rows) {
    const list = map.get(row.messageId) ?? [];
    list.push(row);
    map.set(row.messageId, list);
  }
  return map;
}

// ---------------------------------------------------------------------------
// Transaction helper (re-exported shape to keep callers import-light).
// ---------------------------------------------------------------------------
export async function dbTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export { NotFoundError };