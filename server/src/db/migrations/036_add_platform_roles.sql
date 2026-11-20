-- Migration: 038_add_platform_roles
-- Description: Add additional platform roles to the roles table

INSERT INTO roles (id, name, description, is_system, is_publicly_assignable) VALUES
    ('super_admin', 'Super Administrator', 'Super administrator with full platform access', TRUE, FALSE),
    ('security_admin', 'Security Administrator', 'Security administrator with user and audit access', TRUE, FALSE),
    ('financial_admin', 'Financial Administrator', 'Financial administrator with financial permissions', TRUE, FALSE),
    ('support_admin', 'Support Administrator', 'Support administrator with user view access', TRUE, FALSE),
    ('moderator', 'Moderator', 'Content moderator with limited admin access', TRUE, FALSE),
    ('compliance_officer', 'Compliance Officer', 'Compliance officer with audit access', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Add organization-scoped roles
INSERT INTO roles (id, name, description, is_system, is_publicly_assignable) VALUES
    ('organization_owner', 'Organization Owner', 'Owner of an organization', FALSE, FALSE),
    ('organization_admin', 'Organization Administrator', 'Administrator of an organization', FALSE, FALSE),
    ('organization_member', 'Organization Member', 'Member of an organization', FALSE, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Rename existing roles to match new naming
UPDATE roles SET name = 'Moving Company', description = 'Business providing moving services' WHERE id = 'moving_company';
UPDATE roles SET name = 'Individual Mover', description = 'Individual providing moving services' WHERE id = 'individual_mover';