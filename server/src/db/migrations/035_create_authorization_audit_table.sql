-- Migration: 035_create_authorization_audit_table
-- Description: Create authorization_audit table for tracking authorization decisions

CREATE TABLE IF NOT EXISTS authorization_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    decision VARCHAR(20) NOT NULL, -- 'allow', 'deny'
    permission_id VARCHAR(100),
    resource_type VARCHAR(50),
    resource_id UUID,
    organization_id UUID REFERENCES organisations(id) ON DELETE SET NULL,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_audit_user_id ON authorization_audit (user_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_session_id ON authorization_audit (session_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_decision ON authorization_audit (decision);
CREATE INDEX IF NOT EXISTS idx_auth_audit_permission_id ON authorization_audit (permission_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_resource ON authorization_audit (resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_org_id ON authorization_audit (organization_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_created_at ON authorization_audit (created_at DESC);

-- Partition by month for performance (optional, can be enabled later)
-- ALTER TABLE authorization_audit SET (timescaledb.hypertable, timescaledb.chunk_time_interval = '1 month');