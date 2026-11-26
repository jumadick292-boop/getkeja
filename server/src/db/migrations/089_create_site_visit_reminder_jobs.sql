-- Migration: 089_create_site_visit_reminder_jobs
-- Description: Bookkeeping table for site visit reminder jobs.
--
-- Reminders are derived from site_visits rows by the reminder worker, so a
-- separate queue is not required for correctness. This table records pending
-- reminder dispatches so they can be cancelled immediately when a visit is
-- cancelled or rescheduled, and so the worker can skip work it has already
-- sent. The unique index makes reminder dispatch idempotent per visit/kind.

CREATE TABLE IF NOT EXISTS site_visit_reminder_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visit_id UUID NOT NULL REFERENCES site_visits(id) ON DELETE CASCADE,
    reminder_key VARCHAR(10) NOT NULL,
    scheduled_for TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_site_visit_reminder_jobs_pending
    ON site_visit_reminder_jobs (visit_id, reminder_key)
    WHERE sent_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_site_visit_reminder_jobs_visit
    ON site_visit_reminder_jobs (visit_id);

-- Trigger to maintain updated_at.
CREATE OR REPLACE FUNCTION update_site_visit_reminder_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_site_visit_reminder_jobs_updated_at ON site_visit_reminder_jobs;
CREATE TRIGGER trigger_update_site_visit_reminder_jobs_updated_at
    BEFORE UPDATE ON site_visit_reminder_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_site_visit_reminder_jobs_updated_at();

-- Amendment to 088: the reminder and no-show event types were missing from the
-- seeded templates. created_by is a NOT NULL FK to users(id), so seed rows are
-- joined against the earliest user and skipped on a database without users.
INSERT INTO notification_templates (template_key, event_type, channel, locale, subject, body, is_active, version, metadata, created_by)
SELECT v.column1, v.column2, v.column3, v.column4, v.column5, v.column6, v.column7, v.column8, v.column9::jsonb, u.id
  FROM (VALUES
  ('site_visit.reminder.email.en', 'site_visit.reminder', 'email', 'en',
   'Reminder: your site visit for {{propertyTitle}}',
   'Reminder: your site visit for {{propertyTitle}} is on {{scheduledAt}} ({{scheduledAtUtc}} UTC). Duration: {{durationMinutes}} minutes.',
   true, 1, '{}'),
  ('site_visit.reminder.in_app.en', 'site_visit.reminder', 'in_app', 'en',
   'Site visit reminder',
   'Your visit for {{propertyTitle}} is coming up on {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.reminder.email.sw', 'site_visit.reminder', 'email', 'sw',
   'Akikumbusho: muonekano wako wa {{propertyTitle}}',
   'Akikumbusho: muonekano wako wa {{propertyTitle}} ni tarehe {{scheduledAt}} ({{scheduledAtUtc}} UTC). Muduma: {{durationMinutes}} dakika.',
   true, 1, '{}'),
  ('site_visit.reminder.in_app.sw', 'site_visit.reminder', 'in_app', 'sw',
   'Akikumbusho cha muonekano',
   'Muonekano wako wa {{propertyTitle}} unakaribia tarehe {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.no_show.email.en', 'site_visit.no_show', 'email', 'en',
   'Site visit marked as no-show',
   'Your site visit for {{propertyTitle}} on {{scheduledAt}} was marked as a no-show.',
   true, 1, '{}'),
  ('site_visit.no_show.in_app.en', 'site_visit.no_show', 'in_app', 'en',
   'Site visit no-show',
   'Your visit for {{propertyTitle}} was marked as a no-show.',
   true, 1, '{}'),
  ('site_visit.no_show.email.sw', 'site_visit.no_show', 'email', 'sw',
   'Muonekano haujafanyika',
   'Muonekano wako wa {{propertyTitle}} tarehe {{scheduledAt}} uliwekwa alama kama hakujafanyika.',
   true, 1, '{}'),
  ('site_visit.no_show.in_app.sw', 'site_visit.no_show', 'in_app', 'sw',
   'Muonekano hakujafanyika',
   'Muonekano wako wa {{propertyTitle}} uliwekwa alama kama hakujafanyika.',
   true, 1, '{}')
  ) AS v
  CROSS JOIN (SELECT id FROM users ORDER BY created_at LIMIT 1) AS u
ON CONFLICT (template_key) DO NOTHING;