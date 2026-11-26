-- Migration: 128_scheduling_finishing
-- Description: Task 13.15 — extend unified scheduling to finishing jobs.
--   Adds the resource column + updates the per-resource CHECK constraint so a
--   finishing activity references exactly one finishing_jobs row.
--   Additive and idempotent. Does not change other domains' behavior.

ALTER TABLE scheduling_activities
  ADD COLUMN IF NOT EXISTS finishing_job_id UUID REFERENCES finishing_jobs(id) ON DELETE CASCADE;

-- Rebuild the resource CHECK to include finishing (idempotent).
ALTER TABLE scheduling_activities DROP CONSTRAINT IF EXISTS chk_sched_activity_resource;
ALTER TABLE scheduling_activities ADD CONSTRAINT chk_sched_activity_resource CHECK (
    (domain = 'moving' AND moving_job_id IS NOT NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'garbage' AND garbage_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'garbage_occurrence' AND garbage_occurrence_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'laundry' AND laundry_order_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'home_maintenance' AND home_maintenance_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'cleaning' AND cleaning_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND installation_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'installation' AND installation_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND finishing_job_id IS NULL)
    OR (domain = 'finishing' AND finishing_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL AND cleaning_job_id IS NULL AND installation_job_id IS NULL)
);