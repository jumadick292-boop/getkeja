-- Migration: 036_seed_permissions
-- Description: Seed permissions for the RBAC system

INSERT INTO permissions (id, name, description, category, is_system) VALUES
-- Property permissions
('property.view', 'View Property', 'View property details and listings', 'property', FALSE),
('property.create', 'Create Property', 'Create new property listings', 'property', FALSE),
('property.update', 'Update Property', 'Update property details', 'property', FALSE),
('property.delete', 'Delete Property', 'Delete property listings', 'property', FALSE),
('property.publish', 'Publish Property', 'Publish/unpublish property listings', 'property', FALSE),
('property.archive', 'Archive Property', 'Archive property listings', 'property', FALSE),
('property.assign_manager', 'Assign Property Manager', 'Assign property managers to properties', 'property', FALSE),

-- Unit permissions
('unit.view', 'View Unit', 'View unit details', 'unit', FALSE),
('unit.create', 'Create Unit', 'Create new units', 'unit', FALSE),
('unit.update', 'Update Unit', 'Update unit details', 'unit', FALSE),
('unit.delete', 'Delete Unit', 'Delete units', 'unit', FALSE),
('unit.manage_availability', 'Manage Unit Availability', 'Manage unit availability calendar', 'unit', FALSE),

-- Tenant permissions
('tenant.view', 'View Tenant', 'View tenant profiles', 'tenant', FALSE),
('tenant.create', 'Create Tenant', 'Create new tenant records', 'tenant', FALSE),
('tenant.update', 'Update Tenant', 'Update tenant details', 'tenant', FALSE),
('tenant.manage_onboarding', 'Manage Tenant Onboarding', 'Manage tenant onboarding process', 'tenant', FALSE),
('tenant.view_documents', 'View Tenant Documents', 'View tenant documents and verification', 'tenant', FALSE),

-- Tenancy permissions
('tenancy.view', 'View Tenancy', 'View tenancy agreements', 'tenancy', FALSE),
('tenancy.create', 'Create Tenancy', 'Create new tenancy agreements', 'tenancy', FALSE),
('tenancy.approve', 'Approve Tenancy', 'Approve/reject tenancy applications', 'tenancy', FALSE),
('tenancy.update', 'Update Tenancy', 'Update tenancy agreements', 'tenancy', FALSE),
('tenancy.terminate', 'Terminate Tenancy', 'Terminate tenancy agreements', 'tenancy', FALSE),

-- Organization permissions
('organization.view', 'View Organization', 'View organization details', 'organization', FALSE),
('organization.update', 'Update Organization', 'Update organization details', 'organization', FALSE),
('organization.manage_members', 'Manage Organization Members', 'Add/remove/update organization members', 'organization', FALSE),
('organization.assign_roles', 'Assign Organization Roles', 'Assign roles within organization', 'organization', FALSE),
('organization.manage_settings', 'Manage Organization Settings', 'Manage organization configuration', 'organization', FALSE),

-- Provider permissions
('provider.view', 'View Provider', 'View service provider profiles', 'provider', FALSE),
('provider.manage_profile', 'Manage Provider Profile', 'Manage own provider profile', 'provider', FALSE),
('provider.manage_services', 'Manage Provider Services', 'Manage services offered', 'provider', FALSE),
('provider.manage_assignments', 'Manage Provider Assignments', 'Manage service assignments', 'provider', FALSE),

-- Financial permissions
('financial.view', 'View Financial', 'View financial overview', 'financial', FALSE),
('financial.view_transactions', 'View Transactions', 'View financial transactions', 'financial', FALSE),
('financial.manage_refunds', 'Manage Refunds', 'Process refunds', 'financial', FALSE),
('financial.approve_payouts', 'Approve Payouts', 'Approve provider payouts', 'financial', FALSE),
('financial.export_reports', 'Export Financial Reports', 'Export financial reports', 'financial', FALSE),

-- Administrative permissions
('admin.users.view', 'View Users', 'View user management', 'admin', TRUE),
('admin.users.suspend', 'Suspend Users', 'Suspend/unsuspend users', 'admin', TRUE),
('admin.roles.manage', 'Manage Roles', 'Create/update/delete roles', 'admin', TRUE),
('admin.permissions.manage', 'Manage Permissions', 'Assign/revoke permissions to roles', 'admin', TRUE),
('admin.audit.view', 'View Audit Logs', 'View authorization audit logs', 'admin', TRUE),

-- Platform permissions (super-admin only)
('platform.roles.manage', 'Manage Platform Roles', 'Manage platform-wide roles', 'platform', TRUE),
('platform.permissions.manage', 'Manage Platform Permissions', 'Manage platform-wide permissions', 'platform', TRUE),
('platform.users.manage', 'Manage Platform Users', 'Manage platform user accounts', 'platform', TRUE),
('platform.organizations.manage', 'Manage Platform Organizations', 'Manage all organizations', 'platform', TRUE),
('platform.settings.manage', 'Manage Platform Settings', 'Manage platform configuration', 'platform', TRUE),
('platform.audit.view', 'View Platform Audit', 'View all platform audit logs', 'platform', TRUE)
ON CONFLICT (id) DO NOTHING;