-- Migration: 120_provider_communications_context
-- Description: Task 13.10 — extend the existing conversations infrastructure
--   with contextual conversation support for the service-provider domains
--   (marketplace service requests, garbage jobs, laundry orders, scheduling
--   activities). moving_job type/column already exist (113/114). This adds the
--   remaining conversation_type enum values and the nullable context columns +
--   partial unique indexes used to reuse a single authorized conversation per
--   business context. No new messaging/notification/outbox tables are created.
--   Idempotent.

-- 1. New conversation_type enum values (added independently so a partially
--    applied migration can be re-run).
ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'marketplace_request';
ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'garbage_job';
ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'laundry_order';
ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'scheduling_activity';

-- 2. Context columns on the existing conversations table.
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS marketplace_request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS garbage_job_id UUID REFERENCES garbage_jobs(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS laundry_order_id UUID REFERENCES laundry_orders(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS scheduling_activity_id UUID REFERENCES scheduling_activities(id) ON DELETE CASCADE;

-- 3. Partial unique indexes enforce one active conversation per business
--    context at the DB level (complements the advisory-lock dedup in the
--    service). Only active (non-archived) rows are constrained.
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_marketplace_request
  ON conversations (marketplace_request_id)
  WHERE marketplace_request_id IS NOT NULL AND archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_moving_job
  ON conversations (moving_job_id)
  WHERE moving_job_id IS NOT NULL AND archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_garbage_job
  ON conversations (garbage_job_id)
  WHERE garbage_job_id IS NOT NULL AND archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_laundry_order
  ON conversations (laundry_order_id)
  WHERE laundry_order_id IS NOT NULL AND archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_scheduling_activity
  ON conversations (scheduling_activity_id)
  WHERE scheduling_activity_id IS NOT NULL AND archived_at IS NULL;

-- 4. Lookup indexes for participant listing / context resolution.
CREATE INDEX IF NOT EXISTS idx_conversations_marketplace_request
  ON conversations (marketplace_request_id) WHERE marketplace_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_garbage_job
  ON conversations (garbage_job_id) WHERE garbage_job_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_laundry_order
  ON conversations (laundry_order_id) WHERE laundry_order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_scheduling_activity
  ON conversations (scheduling_activity_id) WHERE scheduling_activity_id IS NOT NULL;

-- 5. Notification template + preference support for provider communications.
--    Preferences already cover categories/channels (051). Add a per-user
--    marketing opt-in timestamp column for audit (marketing defaults FALSE in
--    051; this records when the user explicitly opted in).
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS marketing_opt_in_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- 6. Seed in-app + push templates for the new contextual message + operational
--    update events (en + sw). Idempotent via ON CONFLICT (template_key).
INSERT INTO notification_templates (template_key, event_type, channel, locale, subject, body, is_active)
VALUES
  ('message.created.in_app.en', 'message.created', 'in_app', 'en', 'New message', 'You have a new message from {{senderName}} about {{subject}}.', TRUE),
  ('message.created.in_app.sw', 'message.created', 'in_app', 'sw', 'Ujumbe mpya', 'Una ujumbe mpya kutoka kwa {{senderName}} kuhusu {{subject}}.', TRUE),
  ('message.created.push.en', 'message.created', 'push', 'en', 'New message', 'New message from {{senderName}}', TRUE),
  ('message.created.push.sw', 'message.created', 'push', 'sw', 'Ujumbe mpya', 'Ujumbe mpya kutoka kwa {{senderName}}', TRUE)
ON CONFLICT (template_key) DO NOTHING;