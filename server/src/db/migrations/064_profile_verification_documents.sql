CREATE TABLE profile_verification_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specialized_profile_id UUID REFERENCES specialized_profiles(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organisations(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    storage_key VARCHAR(500) NOT NULL UNIQUE,
    original_file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    byte_size BIGINT NOT NULL CHECK (byte_size > 0 AND byte_size <= 10485760),
    sha256 CHAR(64) NOT NULL,
    document_type VARCHAR(80) NOT NULL DEFAULT 'supporting_document',
    status VARCHAR(20) NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted', 'reviewed', 'rejected', 'deleted')),
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT profile_verification_document_owner_scope CHECK (
        (specialized_profile_id IS NOT NULL AND organization_id IS NULL) OR
        (specialized_profile_id IS NULL AND organization_id IS NOT NULL)
    )
);

CREATE INDEX idx_profile_verification_documents_profile
    ON profile_verification_documents (specialized_profile_id, created_at DESC)
    WHERE specialized_profile_id IS NOT NULL;
CREATE INDEX idx_profile_verification_documents_organization
    ON profile_verification_documents (organization_id, created_at DESC)
    WHERE organization_id IS NOT NULL;

CREATE TABLE profile_verification_document_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES profile_verification_documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(30) NOT NULL,
    access_granted BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_profile_verification_document_access_document
    ON profile_verification_document_access_log (document_id, created_at DESC);

ALTER TABLE organization_verification_records
    ADD COLUMN documents_submitted JSONB NOT NULL DEFAULT '[]',
    ADD COLUMN documents_reviewed JSONB NOT NULL DEFAULT '[]';
