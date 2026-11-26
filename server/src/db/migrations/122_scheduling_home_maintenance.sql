-- Migration: 122_scheduling_home_maintenance
-- Description: Task 13.12 — extend unified scheduling to home-maintenance jobs.
--   Adds the resource column + updates the per-resource CHECK constraint so a
--   home_maintenance activity references exactly one home_maintenance_jobs row.
--   Additive and idempotent. Does not change moving/garbage/laundry behavior.

ALTER TABLE scheduling_activities
  ADD COLUMN IF NOT EXISTS home_maintenance_job_id UUID REFERENCES home_maintenance_jobs(id) ON DELETE CASCADE;

-- Rebuild the resource CHECK to include home_maintenance (idempotent).
ALTER TABLE scheduling_activities DROP CONSTRAINT IF EXISTS chk_sched_activity_resource;
ALTER TABLE scheduling_activities ADD CONSTRAINT chk_sched_activity_resource CHECK (
    (domain = 'moving' AND moving_job_id IS NOT NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL)
    OR (domain = 'garbage' AND garbage_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL)
    OR (domain = 'garbage_occurrence' AND garbage_occurrence_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND laundry_order_id IS NULL AND home_maintenance_job_id IS NULL)
    OR (domain = 'laundry' AND laundry_order_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND home_maintenance_job_id IS NULL)
    OR (domain = 'home_maintenance' AND home_maintenance_job_id IS NOT NULL AND moving_job_id IS NULL AND garbage_job_id IS NULL AND garbage_occurrence_id IS NULL AND laundry_order_id IS NULL)
);