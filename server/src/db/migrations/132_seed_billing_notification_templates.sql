-- Migration: 132_seed_billing_notification_templates
-- Description: Seed English + Swahili notification templates for recurring
--              billing events (Task 14.1). created_by is a NOT NULL FK to
--              users(id); seed rows use the earliest user (never read at
--              delivery). Idempotent via ON CONFLICT (template_key).

INSERT INTO notification_templates (template_key, event_type, channel, locale, subject, body, is_active, version, metadata, created_by)
SELECT v.column1, v.column2, v.column3, v.column4, v.column5, v.column6, v.column7, v.column8, v.column9::jsonb, u.id
  FROM (VALUES
  -- Invoice issued (tenant)
  ('invoice.issued.in_app.en', 'invoice.issued', 'in_app', 'en',
   'Rent invoice {{invoiceNumber}}',
   'Your rent invoice {{invoiceNumber}} for {{amount}} {{currency}} is due on {{dueDate}}. View: {{deepLink}}',
   true, 1, '{}'),
  ('invoice.issued.push.en', 'invoice.issued', 'push', 'en',
   'New rent invoice {{invoiceNumber}}',
   'Rent of {{amount}} {{currency}} is due on {{dueDate}}.',
   true, 1, '{}'),
  ('invoice.issued.in_app.sw', 'invoice.issued', 'in_app', 'sw',
   'Ankara ya kodi {{invoiceNumber}}',
   'Ankara yako ya kodi {{invoiceNumber}} ya {{amount}} {{currency}} inadaiwa ifikapo {{dueDate}}. Angalia: {{deepLink}}',
   true, 1, '{}'),
  ('invoice.issued.push.sw', 'invoice.issued', 'push', 'sw',
   'Ankara mpya ya kodi {{invoiceNumber}}',
   'Kodi ya {{amount}} {{currency}} inadaiwa ifikapo {{dueDate}}.',
   true, 1, '{}'),
  -- Invoice overdue (tenant)
  ('invoice.overdue.in_app.en', 'invoice.overdue', 'in_app', 'en',
   'Overdue rent invoice {{invoiceNumber}}',
   'Your rent invoice {{invoiceNumber}} for {{amount}} {{currency}} was due on {{dueDate}} and is now overdue. View: {{deepLink}}',
   true, 1, '{}'),
  ('invoice.overdue.in_app.sw', 'invoice.overdue', 'in_app', 'sw',
   'Ankara ya kodi {{invoiceNumber}} imechelewa',
   'Ankara yako ya kodi {{invoiceNumber}} ya {{amount}} {{currency}} ilidaiwa ifikapo {{dueDate}} sasa imechelewa. Angalia: {{deepLink}}',
   true, 1, '{}'),
  -- Invoice voided (tenant)
  ('invoice.voided.in_app.en', 'invoice.voided', 'in_app', 'en',
   'Invoice {{invoiceNumber}} voided',
   'Your rent invoice {{invoiceNumber}} has been voided. Reason: {{reason}}.',
   true, 1, '{}'),
  ('invoice.voided.in_app.sw', 'invoice.voided', 'in_app', 'sw',
   'Ankara {{invoiceNumber}} imeghairiwa',
   'Ankara yako ya kodi {{invoiceNumber}} imeghairiwa. Sababu: {{reason}}.',
   true, 1, '{}')
  ) AS v(column1, column2, column3, column4, column5, column6, column7, column8, column9)
  CROSS JOIN LATERAL (SELECT id FROM users ORDER BY created_at ASC LIMIT 1) AS u
ON CONFLICT (template_key) DO NOTHING;