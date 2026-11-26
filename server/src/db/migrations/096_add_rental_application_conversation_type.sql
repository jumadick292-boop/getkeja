-- Migration: 096_add_rental_application_conversation_type
--
-- The messaging centre already resolves and deduplicates conversations for the
-- rental_application context (migration 095 added conversations.rental_application_id),
-- but the conversation_type enum was never extended with the matching value, so
-- persisting an application-scoped conversation failed with an invalid enum
-- value. Add the missing enum label. PG 12+ permits ADD VALUE inside a
-- transaction as long as the new label is not used in the same transaction; this
-- migration only declares it.

ALTER TYPE conversation_type ADD VALUE IF NOT EXISTS 'rental_application';