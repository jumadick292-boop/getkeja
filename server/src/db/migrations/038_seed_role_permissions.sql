-- Migration: 037_seed_role_permissions
-- Description: Seed role-permission mappings for business and platform roles

-- Platform roles (system roles) - full access to their domains
-- super_admin: all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'super_admin', id FROM permissions
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- platform_admin: all admin + platform permissions except super_admin exclusives
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'platform_admin', id FROM permissions
WHERE category IN ('admin', 'platform', 'financial')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- security_admin: audit and user management
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'security_admin', id FROM permissions
WHERE category IN ('admin') AND id IN ('admin.users.view', 'admin.users.suspend', 'admin.audit.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- financial_admin: financial permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'financial_admin', id FROM permissions
WHERE category IN ('financial')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- support_admin: user view and limited management
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'support_admin', id FROM permissions
WHERE category IN ('admin') AND id IN ('admin.users.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- moderator: limited admin
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'moderator', id FROM permissions
WHERE category IN ('admin') AND id IN ('admin.users.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- compliance_officer: audit access
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'compliance_officer', id FROM permissions
WHERE category IN ('admin') AND id IN ('admin.audit.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Business roles - organization-scoped roles get organization permissions
-- organization_owner: full organization management
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_owner', id FROM permissions
WHERE category IN ('organization', 'property', 'unit', 'tenant', 'tenancy', 'provider', 'financial')
AND id NOT IN ('platform.roles.manage', 'platform.permissions.manage', 'platform.users.manage', 'platform.organizations.manage', 'platform.settings.manage', 'platform.audit.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- organization_admin: organization management minus owner-only
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_admin', id FROM permissions
WHERE category IN ('organization', 'property', 'unit', 'tenant', 'tenancy', 'provider', 'financial')
AND id NOT IN ('organization.assign_roles', 'organization.manage_settings')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- organization_member: basic member access
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_member', id FROM permissions
WHERE category IN ('organization') AND id IN ('organization.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- property_manager: property and unit management
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'property_manager', id FROM permissions
WHERE category IN ('property', 'unit', 'tenancy', 'tenant')
AND id IN ('property.view', 'property.update', 'property.assign_manager', 'unit.view', 'unit.update', 'unit.manage_availability', 'tenancy.view', 'tenancy.update', 'tenant.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- letting_agent: property and tenancy
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'letting_agent', id FROM permissions
WHERE category IN ('property', 'unit', 'tenancy', 'tenant')
AND id IN ('property.view', 'property.create', 'property.update', 'property.publish', 'unit.view', 'unit.create', 'unit.update', 'tenancy.view', 'tenancy.create', 'tenant.view', 'tenant.create')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- landlord: own properties and tenancies
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'landlord', id FROM permissions
WHERE category IN ('property', 'unit', 'tenancy', 'tenant', 'financial')
AND id IN ('property.view', 'property.create', 'property.update', 'property.publish', 'property.archive', 'unit.view', 'unit.create', 'unit.update', 'unit.manage_availability', 'tenancy.view', 'tenancy.create', 'tenancy.approve', 'tenancy.update', 'tenancy.terminate', 'tenant.view', 'tenant.view_documents', 'financial.view', 'financial.view_transactions')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- caretaker: assigned properties only
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'caretaker', id FROM permissions
WHERE category IN ('property', 'unit', 'tenancy')
AND id IN ('property.view', 'unit.view', 'unit.update', 'unit.manage_availability', 'tenancy.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- tenant: view own tenancy
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'tenant', id FROM permissions
WHERE category IN ('tenancy', 'tenant', 'financial')
AND id IN ('tenancy.view', 'tenant.view', 'financial.view_transactions')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- house_seeker: view properties
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'house_seeker', id FROM permissions
WHERE category IN ('property', 'unit')
AND id IN ('property.view', 'unit.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- moving_company: business mover
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'moving_company', id FROM permissions
WHERE category IN ('provider', 'organization')
AND id IN ('provider.view', 'provider.manage_profile', 'provider.manage_services', 'provider.manage_assignments', 'organization.view', 'organization.manage_members')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- individual_mover: individual mover
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'individual_mover', id FROM permissions
WHERE category IN ('provider')
AND id IN ('provider.view', 'provider.manage_profile', 'provider.manage_assignments')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- garbage_provider: garbage collection
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'garbage_provider', id FROM permissions
WHERE category IN ('provider')
AND id IN ('provider.view', 'provider.manage_profile', 'provider.manage_services', 'provider.manage_assignments')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- laundry_provider: laundry services
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'laundry_provider', id FROM permissions
WHERE category IN ('provider')
AND id IN ('provider.view', 'provider.manage_profile', 'provider.manage_services', 'provider.manage_assignments')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- service_provider: generic services
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'service_provider', id FROM permissions
WHERE category IN ('provider')
AND id IN ('provider.view', 'provider.manage_profile', 'provider.manage_services', 'provider.manage_assignments')
ON CONFLICT (role_id, permission_id) DO NOTHING;