-- Migration: 094_rental_application_initial_history
-- Description: Record an initial history row when a rental application is
--   created (the migration 093 trigger only covers status *changes*). This
--   captures the starting status (submitted/draft) with the applicant as actor.

CREATE OR REPLACE FUNCTION record_rental_application_initial_history()
RETURNS TRIGGER AS $$
DECLARE
    actor UUID;
BEGIN
    actor := COALESCE(NEW.updated_by, NEW.user_id);
    IF actor IS NOT NULL THEN
        INSERT INTO rental_application_history
            (application_id, action, previous_status, new_status, changed_by, metadata)
        VALUES
            (NEW.id, NEW.status, NULL, NEW.status, actor,
             jsonb_build_object('source', 'create'));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_record_rental_application_initial_history ON rental_applications;
CREATE TRIGGER trigger_record_rental_application_initial_history
    AFTER INSERT ON rental_applications
    FOR EACH ROW
    EXECUTE FUNCTION record_rental_application_initial_history();