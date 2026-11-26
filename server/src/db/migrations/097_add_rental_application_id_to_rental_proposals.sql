-- Migration: 097_add_rental_application_id_to_rental_proposals
-- Description: Link rental proposals to rental applications so proposals
--   created via the send_proposal lifecycle transition carry an
--   rental_application_id foreign key, enabling proposal-to-application
--   traceability and onboarding preconditions.

ALTER TABLE rental_proposals
    ADD COLUMN IF NOT EXISTS rental_application_id UUID REFERENCES rental_applications(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_rental_proposals_rental_application_id
    ON rental_proposals (rental_application_id);
