-- Migration: 093_extend_rental_application_lifecycle
-- Description: Extend the rental application lifecycle (new states), add an
--   audit `updated_by`, private internal notes, secure application documents,
--   and an automatic status-history trigger so every status change is recorded.

-- ---------------------------------------------------------------------------
-- 1. Extend the application_status enum with the full lifecycle states.
--    Existing values (submitted, under_review, approved, rejected, withdrawn,
--    pending_documents, pending_payment, expired) are preserved. New values are
--    appended; enum ordering is not relied upon by application logic (the
--    lifecycle state machine in code is the authority).
-- ---------------------------------------------------------------------------
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'draft';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'information_requested';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'resubmitted';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'shortlisted';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'proposal_sent';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'negotiation';
ALTER TYPE application_status ADD VALUE IF NOT EXISTS 'cancelled';

-- ---------------------------------------------------------------------------
-- 2. Audit actor for application updates. The status-history trigger uses this
--    to attribute every change; falls back to the applicant when null.
-- ---------------------------------------------------------------------------
ALTER TABLE rental_applications
    ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 3. Private internal notes (landlord/staff only, never shown to applicants).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rental_application_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES rental_applications(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    note TEXT NOT NULL,
    -- Notes are internal by construction; the flag documents intent and lets a
    -- future applicant-visible comment thread coexist without schema change.
    is_internal BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_application_note_not_blank CHECK (length(btrim(note)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_rental_application_notes_application_id
    ON rental_application_notes (application_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 4. Secure application documents. Objects live in the existing private
--    document storage; this table holds metadata + verification state. The
--    legacy `rental_applications.documents` JSONB column is still accepted for
--    backwards compatibility, but new uploads go through this table so access
--    can be authorized and audited per document.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rental_application_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES rental_applications(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    storage_key TEXT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100),
    file_size_bytes BIGINT,
    -- Configurable requirement category (e.g. id_document, income_proof,
    -- reference, guarantor_id). 'supporting' is the generic bucket.
    category VARCHAR(100) NOT NULL DEFAULT 'supporting',
    verification_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_application_document_verification
        CHECK (verification_status IN ('pending', 'verified', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_rental_application_documents_application_id
    ON rental_application_documents (application_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 5. Automatic status-history. Whenever an application's status changes, an
--    append-only history row is written with the acting user and timestamp.
--    The authoritative lifecycle service always sets `updated_by`, so the
--    trigger attributes changes correctly; it falls back to the applicant and
--    skips only when no actor can be resolved (defensive).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_rental_application_status_history()
RETURNS TRIGGER AS $$
DECLARE
    actor UUID;
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        actor := COALESCE(NEW.updated_by, OLD.user_id);
        IF actor IS NOT NULL THEN
            INSERT INTO rental_application_history
                (application_id, action, previous_status, new_status, changed_by, change_reason, metadata)
            VALUES
                (OLD.id, NEW.status, OLD.status, NEW.status, actor, NULL,
                 jsonb_build_object('source', 'lifecycle'));
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_rental_application_status_history ON rental_applications;
CREATE TRIGGER trigger_record_rental_application_status_history
    AFTER UPDATE ON rental_applications
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION record_rental_application_status_history();