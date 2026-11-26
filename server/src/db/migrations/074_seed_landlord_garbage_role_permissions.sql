-- Migration: 074_seed_landlord_garbage_role_permissions
-- Description: Seed role-permission mappings for listing and garbage permissions

-- landlord: own properties and tenancies, plus listings and garbage
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'landlord', id FROM permissions
WHERE category IN ('listing', 'garbage', 'tenant')
AND id IN ('listing.view', 'listing.create', 'listing.update', 'listing.publish', 'listing.pause', 'listing.withdraw', 'listing.archive', 'garbage.view', 'garbage.create', 'garbage.manage', 'tenant.view', 'tenant.view_documents')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- property_manager: listing and garbage view, tenant view
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'property_manager', id FROM permissions
WHERE category IN ('listing', 'garbage', 'tenant')
AND id IN ('listing.view', 'listing.create', 'listing.update', 'listing.publish', 'garbage.view', 'tenant.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- letting_agent: listing create/publish, garbage view
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'letting_agent', id FROM permissions
WHERE category IN ('listing', 'garbage')
AND id IN ('listing.view', 'listing.create', 'listing.update', 'listing.publish', 'garbage.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- caretaker: garbage view only
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'caretaker', id FROM permissions
WHERE category IN ('garbage')
AND id IN ('garbage.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- garbage_provider: garbage view for their assignments
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'garbage_provider', id FROM permissions
WHERE category IN ('garbage')
AND id IN ('garbage.view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- organization_owner: all listing and garbage permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_owner', id FROM permissions
WHERE category IN ('listing', 'garbage')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- organization_admin: listing and garbage permissions (minus archive)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_admin', id FROM permissions
WHERE category IN ('listing', 'garbage')
AND id NOT IN ('listing.archive')
ON CONFLICT (role_id, permission_id) DO NOTHING;
