-- Migration: 060_create_profile_verification_records_table
-- Description: Create profile_verification_records for verification history
-- Per blueprint Section 7 (Profile Verification and Approval)

CREATE TABLE IF NOT EXISTS profile_verification_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,

    -- Verification state
    previous_status profile_verification_status,
    new_status profile_verification_status NOT NULL,

    -- Reviewer
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewer_role VARCHAR(100),

    -- Documents
    documents_submitted JSONB NOT NULL DEFAULT '[]',
    documents_reviewed JSONB NOT NULL DEFAULT '[]',

    -- Outcome
    decision VARCHAR(30) NOT NULL, -- 'approved', 'rejected', 'request_changes', 'suspended'
    review_notes TEXT,
    rejection_reason TEXT,
    requested_changes TEXT,

    -- Timestamps
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_verification_records_profile_id ON profile_verification_records (specialized_profile_id);
CREATE INDEX IF NOT EXISTS idx_profile_verification_records_reviewed_by ON profile_verification_records (reviewed_by);
CREATE INDEX IF NOT EXISTS idx_profile_verification_records_created_at ON profile_verification_records (created_at DESC);