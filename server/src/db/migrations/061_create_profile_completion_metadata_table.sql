-- Migration: 061_create_profile_completion_metadata_table
-- Description: Create profile_completion_metadata for tracking completion status
-- Per blueprint Section 8 (Profile Completion Engine)

CREATE TABLE IF NOT EXISTS profile_completion_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID NOT NULL REFERENCES specialized_profiles(id) ON DELETE CASCADE,

    -- Completion tracking
    total_required_fields INTEGER NOT NULL DEFAULT 0,
    completed_fields INTEGER NOT NULL DEFAULT 0,
    completion_percentage INTEGER NOT NULL DEFAULT 0,
    missing_fields JSONB NOT NULL DEFAULT '[]',
    optional_fields JSONB NOT NULL DEFAULT '[]',

    -- Submission tracking
    is_submitted BOOLEAN NOT NULL DEFAULT FALSE,
    submitted_at TIMESTAMPTZ,
    can_submit BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_completion_metadata_profile_id ON profile_completion_metadata (specialized_profile_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_profile_completion_metadata_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_profile_completion_metadata_updated_at ON profile_completion_metadata;
CREATE TRIGGER trigger_update_profile_completion_metadata_updated_at
    BEFORE UPDATE ON profile_completion_metadata
    FOR EACH ROW
    EXECUTE FUNCTION update_profile_completion_metadata_updated_at();