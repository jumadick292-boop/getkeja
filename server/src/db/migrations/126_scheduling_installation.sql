-- Migration: 126_scheduling_installation
-- Description: Task 13.14 — extend unified scheduling to installation jobs.
--   Adds the resource column + updates the per-resource CHECK constraint so an
--   installation activity references exactly one installation_jobs row.
--   Additive and idempotent. Does not change other domains' behavior.

ALTER TABLE scheduling_activities
  ADD COLUMN IF NOT EXISTS installation_job_id UUID REFERENCES installation_jobs(id) ON DELETE CASCADE;

-- Rebuild the resource CHECK to include installation (idempotent).
ALTER TABLE scheduling_activities DROP CONSTRAINT IF EXISTS chk_sched_activity_resource;
ALTER TABLE scheduling_activities ADD CONSTRAINT chk_sched_activity_resource CHECK (
    (domain = 'moving' AND moving_job_id IS NOT NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'garbage' AND garbage_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'garbage_occurrence' AND garbage_occurrence_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'laundry' AND laundry_order_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'home_maintenance' AND home_maintenance_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'cleaning' AND cleaning_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND installation_job_id IS NULL)
    OR (domain = 'installation' AND installation_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL)
);