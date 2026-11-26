-- Migration: 092_notification_templates_created_by_set_null
-- Description: Make notification_templates.created_by ON DELETE SET NULL (and
-- nullable) so that deleting a user account never fails because a seeded
-- template happens to reference them. Seed migrations (088, 091) pin
-- created_by to the earliest user purely to satisfy the NOT NULL FK; that makes
-- user deletion fragile on any database that already had users at migrate time.
-- This aligns created_by with updated_by (already ON DELETE SET NULL).

ALTER TABLE notification_templates
    ALTER COLUMN created_by DROP NOT NULL;

ALTER TABLE notification_templates
    DROP CONSTRAINT IF EXISTS notification_templates_created_by_fkey;

ALTER TABLE notification_templates
    ADD CONSTRAINT notification_templates_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;