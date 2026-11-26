-- Migration: 082_add_units_building_column
-- Description: Add missing building column to units table referenced by landlord unit repository

ALTER TABLE units
  ADD COLUMN IF NOT EXISTS building TEXT NULL;

COMMENT ON COLUMN units.building IS 'Optional building or block name/number within the property';