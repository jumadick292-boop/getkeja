-- Migration: 098_unique_active_tenant_per_unit
-- Description: Ensure at most one active tenant per unit by adding a partial
--   unique index on tenants(unit_id) where status = 'active'. This provides a
--   database-level guarantee that concurrent tenant creation requests cannot
--   produce conflicting active tenancies for the same unit.

CREATE UNIQUE INDEX IF NOT EXISTS idx_tenants_unique_active_per_unit
    ON tenants (unit_id)
    WHERE status = 'active';
