-- Migration: 090_messaging_centre_support
-- Description: Supporting schema for the centralized Messaging & Communication
-- Centre. The core conversations/messages/participants/read-state tables already
-- exist (migration 076); this migration only adds what the messaging centre
-- genuinely needs and does not duplicate existing structures.
--
--   1. conversations.archived_at  -> archive / reopen lifecycle.
--   2. conversations.site_visit_id index -> the FK existed without an index.
--   3. messages(conversation_id, created_at, id) -> stable keyset (cursor)
--      pagination ordered by (created_at, id).
--   4. conversations context dedup index -> fast lookup of the active
--      conversation for a given (type, context, participant) so a duplicate
--      conversation is not created for the same intended context.

ALTER TABLE conversations
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

COMMENT ON COLUMN conversations.archived_at IS
    'When set, the conversation is archived (hidden from the default inbox) until reopened.';

-- Index for site-visit-linked conversations (FK had no supporting index).
CREATE INDEX IF NOT EXISTS idx_conversations_site_visit_id
    ON conversations (site_visit_id);

-- Stable keyset pagination over a conversation's messages.
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_id
    ON messages (conversation_id, created_at, id);

-- Fast dedup lookups: find an existing active conversation for a context.
CREATE INDEX IF NOT EXISTS idx_conversations_enquiry_active
    ON conversations (enquiry_id) WHERE status = 'active' AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_site_visit_active
    ON conversations (site_visit_id) WHERE status = 'active' AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_tenancy_active
    ON conversations (tenancy_id) WHERE status = 'active' AND archived_at IS NULL;

-- Index supporting message attachment lookups by message.
CREATE INDEX IF NOT EXISTS idx_message_attachments_message_created
    ON message_attachments (message_id, created_at);