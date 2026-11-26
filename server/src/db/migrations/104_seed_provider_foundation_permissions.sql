-- Migration: 104_seed_provider_foundation_permissions
-- Description: Seed granular provider-domain permissions for the Service
--   Provider Platform foundation and grant them to the existing provider
--   roles. Non-destructive and idempotent (safe on fresh and existing DBs).
--   Endpoint authorization in Task 13.2 is resource-scoped (approved profile
--   / assignment); these permissions are additive for later tasks and for
--   role-based UI gating.

INSERT INTO permissions (id, name, description, category, is_system) VALUES
    ('provider.dashboard.read', 'View Provider Dashboard', 'View own provider dashboard counts', 'provider', FALSE),
    ('provider.requests.read', 'View Provider Requests', 'View eligible/assigned service requests', 'provider', FALSE),
    ('provider.requests.respond', 'Respond to Provider Requests', 'Accept or decline service requests', 'provider', FALSE),
    ('provider.jobs.read', 'View Provider Jobs', 'View assigned jobs', 'provider', FALSE),
    ('provider.jobs.update', 'Update Provider Jobs', 'Update assigned job status', 'provider', FALSE),
    ('provider.staff.read', 'View Provider Staff', 'View organization staff', 'provider', FALSE),
    ('provider.staff.manage', 'Manage Provider Staff', 'Invite/manage organization staff', 'provider', FALSE),
    ('provider.service_areas.manage', 'Manage Provider Service Areas', 'Manage service coverage areas', 'provider', FALSE)
ON CONFLICT (id) DO NOTHING;

-- Grant the full provider permission set to each provider role.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  CROSS JOIN permissions p
 WHERE r.id IN ('moving_company', 'individual_mover', 'garbage_provider', 'laundry_provider', 'service_provider')
   AND p.category = 'provider'
ON CONFLICT (role_id, permission_id) DO NOTHING;