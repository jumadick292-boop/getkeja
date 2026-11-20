-- Migration: 046_create_property_documents_table
-- Description: Create property_documents table for secure document management

CREATE TYPE document_category AS ENUM (
    'ownership', 'title_deed', 'lease_agreement', 'tenant_id', 'tenant_passport',
    'inspection_report', 'maintenance_record', 'insurance', 'valuation',
    'floor_plan', 'compliance_certificate', 'utility_bill', 'correspondence', 'other'
);

CREATE TYPE document_visibility AS ENUM ('private', 'owner', 'manager', 'tenant', 'participant', 'organization', 'public');

CREATE TABLE IF NOT EXISTS property_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    -- Document info
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category document_category NOT NULL DEFAULT 'other',
    visibility document_visibility NOT NULL DEFAULT 'private',
    -- File storage
    file_path VARCHAR(500) NOT NULL, -- Private storage path (not public URL)
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_hash VARCHAR(64) NOT NULL, -- SHA-256 for integrity
    -- Access control
    allowed_roles VARCHAR(100)[], -- Roles that can access this document
    allowed_user_ids UUID[], -- Specific users who can access
    allowed_organisation_ids UUID[], -- Specific organizations who can access
    -- Versioning
    version INTEGER NOT NULL DEFAULT 1,
    previous_version_id UUID REFERENCES property_documents(id) ON DELETE SET NULL,
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'archived', 'deleted'
    -- Metadata
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- For temporary documents
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_documents_property_id ON property_documents (property_id);
CREATE INDEX IF NOT EXISTS idx_property_documents_unit_id ON property_documents (unit_id);
CREATE INDEX IF NOT EXISTS idx_property_documents_tenancy_id ON property_documents (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_property_documents_category ON property_documents (category);
CREATE INDEX IF NOT EXISTS idx_property_documents_visibility ON property_documents (visibility);
CREATE INDEX IF NOT EXISTS idx_property_documents_uploaded_by ON property_documents (uploaded_by);
CREATE INDEX IF NOT EXISTS idx_property_documents_file_hash ON property_documents (file_hash);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_property_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_documents_updated_at ON property_documents;
CREATE TRIGGER trigger_update_property_documents_updated_at
    BEFORE UPDATE ON property_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_property_documents_updated_at();

-- Document access log (audit)
CREATE TABLE IF NOT EXISTS property_document_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES property_documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'viewed', 'downloaded', 'shared', 'printed'
    ip_address INET,
    user_agent TEXT,
    access_granted BOOLEAN NOT NULL,
    denial_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_document_access_log_document_id ON property_document_access_log (document_id);
CREATE INDEX IF NOT EXISTS idx_property_document_access_log_user_id ON property_document_access_log (user_id);
CREATE INDEX IF NOT EXISTS idx_property_document_access_log_created_at ON property_document_access_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_document_access_log_action ON property_document_access_log (action);