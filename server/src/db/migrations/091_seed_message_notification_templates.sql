-- Migration: 091_seed_message_notification_templates
-- Description: Privacy-safe notification templates for new messages.
--
-- The message body/preview is intentionally NOT included so push and email
-- notifications never leak private message content. Recipients are nudged to
-- open the app to read the message. Push has no template (falls back to a
-- generic body) for the same privacy reason.

INSERT INTO notification_templates (template_key, event_type, channel, locale, subject, body, is_active, version, metadata, created_by)
SELECT v.column1, v.column2, v.column3, v.column4, v.column5, v.column6, v.column7, v.column8, v.column9::jsonb,
       u.id
  FROM (VALUES
  ('message.created.in_app.en', 'message.created', 'in_app', 'en',
   'New message',
   'You received a new message. Open the conversation to read it.',
   true, 1, '{}'),
  ('message.created.in_app.sw', 'message.created', 'in_app', 'sw',
   'Ujumbe mpya',
   'Umepokea ujumbe mpya. Fungua mazungumzo ili kuusoma.',
   true, 1, '{}'),
  ('message.created.email.en', 'message.created', 'email', 'en',
   'You have a new message on GetKeja',
   'You received a new message on GetKeja. Sign in to read and reply.',
   true, 1, '{}'),
  ('message.created.email.sw', 'message.created', 'email', 'sw',
   'Una ujumbe mpya kwenye GetKeja',
   'Umepokea ujumbe mpya kwenye GetKeja. Ingia ili usome na kujibu.',
   true, 1, '{}')
  ) AS v(column1, column2, column3, column4, column5, column6, column7, column8, column9)
  CROSS JOIN (SELECT id FROM users ORDER BY created_at LIMIT 1) AS u
  ON CONFLICT (template_key) DO NOTHING;