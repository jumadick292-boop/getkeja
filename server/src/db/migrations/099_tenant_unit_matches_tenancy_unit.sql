-- Migration: 099_tenant_unit_matches_tenancy_unit
-- Description: Enforce database-level integrity that a tenant's unit_id must
--   match the linked tenancy's unit_id when both are set. Application-level
--   validation exists in createTenant/updateTenant, but a DB trigger protects
--   against direct SQL inserts and future code paths that bypass the API.

CREATE OR REPLACE FUNCTION trg_tenant_unit_matches_tenancy_unit()
RETURNS trigger AS $$
BEGIN
  IF NEW.tenancy_id IS NOT NULL AND NEW.unit_id IS NOT NULL THEN
    PERFORM 1
    FROM tenancies
    WHERE id = NEW.tenancy_id
      AND unit_id = NEW.unit_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'tenant unit_id (%) does not match tenancy unit_id for tenancy %',
        NEW.unit_id, NEW.tenancy_id
        USING ERRCODE = '23514'; -- check_violation
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tenant_unit_matches_tenancy_unit ON tenants;

CREATE TRIGGER trg_tenant_unit_matches_tenancy_unit
  BEFORE INSERT OR UPDATE OF unit_id, tenancy_id ON tenants
  FOR EACH ROW
  EXECUTE FUNCTION trg_tenant_unit_matches_tenancy_unit();
