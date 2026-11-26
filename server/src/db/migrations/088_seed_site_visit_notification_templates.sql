-- Migration: 088_seed_site_visit_notification_templates
-- Description: Seed notification templates for site visit events

-- created_by is a NOT NULL FK to users(id). Seed rows use the earliest user so
-- the migration is valid on a fresh database; the value is never read at
-- delivery time. On a database with no users yet the rows are skipped and can
-- be re-seeded later (the keys are idempotent via ON CONFLICT).
INSERT INTO notification_templates (template_key, event_type, channel, locale, subject, body, is_active, version, metadata, created_by)
SELECT v.column1, v.column2, v.column3, v.column4, v.column5, v.column6, v.column7, v.column8, v.column9::jsonb,
       u.id
  FROM (VALUES
  -- Site visit requested (to landlord/host)
  ('site_visit.requested.email.en', 'site_visit.requested', 'email', 'en',
   'New site visit request for {{propertyTitle}}',
   'A prospective renter has requested a site visit for {{propertyTitle}} on {{scheduledAt}}. Visitor: {{visitorName}} ({{visitorPhone}}). Please review and confirm or decline.',
   true, 1, '{}'),
  ('site_visit.requested.in_app.en', 'site_visit.requested', 'in_app', 'en',
   'New site visit request',
   'A site visit was requested for {{propertyTitle}} on {{scheduledAt}}.',
   true, 1, '{}'),

  -- Site visit confirmed (to house seeker)
  ('site_visit.confirmed.email.en', 'site_visit.confirmed', 'email', 'en',
   'Your site visit is confirmed',
   'Your site visit for {{propertyTitle}} is confirmed for {{scheduledAt}}. Duration: {{durationMinutes}} minutes. Location: {{location}}.',
   true, 1, '{}'),
  ('site_visit.confirmed.in_app.en', 'site_visit.confirmed', 'in_app', 'en',
   'Site visit confirmed',
   'Your visit for {{propertyTitle}} on {{scheduledAt}} has been confirmed.',
   true, 1, '{}'),

  -- Site visit declined (to house seeker)
  ('site_visit.declined.email.en', 'site_visit.declined', 'email', 'en',
   'Site visit request declined',
   'Your site visit request for {{propertyTitle}} on {{scheduledAt}} has been declined. Reason: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.declined.in_app.en', 'site_visit.declined', 'in_app', 'en',
   'Site visit declined',
   'Your visit request for {{propertyTitle}} was declined.',
   true, 1, '{}'),

  -- Site visit rescheduled (to house seeker)
  ('site_visit.rescheduled.email.en', 'site_visit.rescheduled', 'email', 'en',
   'Site visit rescheduled',
   'Your site visit for {{propertyTitle}} has been rescheduled to {{scheduledAt}}. Reason: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.rescheduled.in_app.en', 'site_visit.rescheduled', 'in_app', 'en',
   'Site visit rescheduled',
   'Your visit for {{propertyTitle}} was rescheduled to {{scheduledAt}}.',
   true, 1, '{}'),

  -- Site visit cancelled (to house seeker and landlord)
  ('site_visit.cancelled.email.en', 'site_visit.cancelled', 'email', 'en',
   'Site visit cancelled',
   'Your site visit for {{propertyTitle}} on {{scheduledAt}} has been cancelled. Reason: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.cancelled.in_app.en', 'site_visit.cancelled', 'in_app', 'en',
   'Site visit cancelled',
   'Your visit for {{propertyTitle}} was cancelled.',
   true, 1, '{}'),

  -- Site visit completed (to house seeker)
  ('site_visit.completed.email.en', 'site_visit.completed', 'email', 'en',
   'Site visit completed',
   'Your site visit for {{propertyTitle}} on {{scheduledAt}} has been marked as completed.',
   true, 1, '{}'),
  ('site_visit.completed.in_app.en', 'site_visit.completed', 'in_app', 'en',
   'Site visit completed',
   'Your visit for {{propertyTitle}} has been completed.',
   true, 1, '{}'),

  -- Site visit reminder 24h (to house seeker)
  ('site_visit.reminder_24h.email.en', 'site_visit.reminder', 'email', 'en',
   'Reminder: Site visit tomorrow',
   'Reminder: Your site visit for {{propertyTitle}} is scheduled for tomorrow, {{scheduledAt}}. Duration: {{durationMinutes}} minutes.',
   true, 1, '{}'),
  ('site_visit.reminder_24h.in_app.en', 'site_visit.reminder', 'in_app', 'en',
   'Reminder: Site visit tomorrow',
   'Your visit for {{propertyTitle}} is tomorrow at {{scheduledAt}}.',
   true, 1, '{}'),

  -- Site visit reminder 2h (to house seeker)
  ('site_visit.reminder_2h.email.en', 'site_visit.reminder', 'email', 'en',
   'Reminder: Site visit in 2 hours',
   'Reminder: Your site visit for {{propertyTitle}} is in 2 hours at {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.reminder_2h.in_app.en', 'site_visit.reminder', 'in_app', 'en',
   'Reminder: Site visit soon',
   'Your visit for {{propertyTitle}} starts in 2 hours at {{scheduledAt}}.',
   true, 1, '{}'),

  -- Swahili translations
  ('site_visit.requested.email.sw', 'site_visit.requested', 'email', 'sw',
   'Ombi jipya la kuangalia milki',
   'Mwakopesha ambao anatarajia kuangalia {{propertyTitle}} imepadana ombi la muonekano tarehe {{scheduledAt}}. Mwenyezi: {{visitorName}} ({{visitorPhone}}). Tafadhali angalia na kubaini au rudi.',
   true, 1, '{}'),
  ('site_visit.requested.in_app.sw', 'site_visit.requested', 'in_app', 'sw',
   'Ombi jipya la muonekano',
   'Ombi la muonekano limepadana kwa {{propertyTitle}} tarehe {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.confirmed.email.sw', 'site_visit.confirmed', 'email', 'sw',
   'Muonekano wako umethibitishwa',
   'Muonekano wako wa {{propertyTitle}} umethibitishwa tarehe {{scheduledAt}}. Muduma: {{durationMinutes}} dakika. Eneo: {{location}}.',
   true, 1, '{}'),
  ('site_visit.confirmed.in_app.sw', 'site_visit.confirmed', 'in_app', 'sw',
   'Muonekano umethibitishwa',
   'Muonekano wako wa {{propertyTitle}} tarehe {{scheduledAt}} umethibitishwa.',
   true, 1, '{}'),
  ('site_visit.declined.email.sw', 'site_visit.declined', 'email', 'sw',
   'Ombi la muonekano limepiridhiwa',
   'Ombi lako la muonekano la {{propertyTitle}} tarehe {{scheduledAt}} limepiridhiwa. Sababu: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.declined.in_app.sw', 'site_visit.declined', 'in_app', 'sw',
   'Muonekano limepiridhiwa',
   'Ombi lako la muonekano la {{propertyTitle}} limepiridhiwa.',
   true, 1, '{}'),
  ('site_visit.rescheduled.email.sw', 'site_visit.rescheduled', 'email', 'sw',
   'Muonekano upegwa',
   'Muonekano wako wa {{propertyTitle}} upegwa kwenda tarehe {{scheduledAt}}. Sababu: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.rescheduled.in_app.sw', 'site_visit.rescheduled', 'in_app', 'sw',
   'Muonekano upegwa',
   'Muonekano wako wa {{propertyTitle}} upegwa kwenda {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.cancelled.email.sw', 'site_visit.cancelled', 'email', 'sw',
   'Muonekano umeondolewa',
   'Muonekano wako wa {{propertyTitle}} tarehe {{scheduledAt}} umeondolewa. Sababu: {{reason}}.',
   true, 1, '{}'),
  ('site_visit.cancelled.in_app.sw', 'site_visit.cancelled', 'in_app', 'sw',
   'Muonekano umeondolewa',
   'Muonekano wako wa {{propertyTitle}} umeondolewa.',
   true, 1, '{}'),
  ('site_visit.completed.email.sw', 'site_visit.completed', 'email', 'sw',
   'Muonekano umekamilika',
   'Muonekano wako wa {{propertyTitle}} tarehe {{scheduledAt}} umeandaliwa kama imekamilika.',
   true, 1, '{}'),
  ('site_visit.completed.in_app.sw', 'site_visit.completed', 'in_app', 'sw',
   'Muonekano umekamilika',
   'Muonekano wako wa {{propertyTitle}} umekamilika.',
   true, 1, '{}'),
  ('site_visit.reminder_24h.email.sw', 'site_visit.reminder', 'email', 'sw',
   'Akirahimu: Muonekano kesho',
   'Akirahimu: Muonekano wako wa {{propertyTitle}} unategemea kesho, {{scheduledAt}}. Muduma: {{durationMinutes}} dakika.',
   true, 1, '{}'),
  ('site_visit.reminder_24h.in_app.sw', 'site_visit.reminder', 'in_app', 'sw',
   'Akirahimu: Muonekano kesho',
   'Muonekano wako wa {{propertyTitle}} unategemea kesho saa {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.reminder_2h.email.sw', 'site_visit.reminder', 'email', 'sw',
   'Akirahimu: Muonekano baada ya saa 2',
   'Akirahimu: Muonekano wako wa {{propertyTitle}} unategemea baada ya saa 2, {{scheduledAt}}.',
   true, 1, '{}'),
  ('site_visit.reminder_2h.in_app.sw', 'site_visit.reminder', 'in_app', 'sw',
   'Akirahimu: Muonekano hivi',
   'Muonekano wako wa {{propertyTitle}} huanza baada ya saa 2, saa {{scheduledAt}}.',
   true, 1, '{}')
  ) AS v
  CROSS JOIN (SELECT id FROM users ORDER BY created_at LIMIT 1) AS u
ON CONFLICT (template_key) DO NOTHING;
