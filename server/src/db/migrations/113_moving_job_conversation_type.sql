-- Migration: 113_moving_job_conversation_type
-- Description: Task 13.6 — add 'moving_job' to conversation_type so moving-job
--   messaging reuses the existing conversations/messages infrastructure. Enum
--   only; the conversations.moving_job_id column and moving tables are added in
--   114 so this value is never used in the same transaction. Idempotent.

ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'moving_job';