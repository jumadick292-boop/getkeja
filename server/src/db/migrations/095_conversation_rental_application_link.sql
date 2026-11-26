-- Migration: 095_conversation_rental_application_link
-- Description: Link conversations to rental applications (and complete the
--   rental_proposal FK) so contextual conversations can be deduplicated per
--   application/proposal without duplicating tables.

ALTER TABLE conversations
    ADD COLUMN IF NOT EXISTS rental_application_id UUID REFERENCES rental_applications(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_conversations_rental_application_id
    ON conversations (rental_application_id);

-- Complete the existing rental_proposal FK (was previously unconstrained).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'conversations_rental_proposal_id_fkey'
          AND table_name = 'conversations'
    ) THEN
        ALTER TABLE conversations
            ADD CONSTRAINT conversations_rental_proposal_id_fkey
            FOREIGN KEY (rental_proposal_id) REFERENCES rental_proposals(id) ON DELETE CASCADE;
    END IF;
END $$;
