// Site visit reminder worker.
//
// Uses the existing pg-boss infrastructure (same pattern as the notification
// outbox worker and the search-alert worker). Does not create a duplicate job
// queue or notification system.
//
// Reminders are derived from site_visits rows rather than a separate queue, so
// rescheduling automatically recomputes the correct reminder time and
// cancelling/removing a visit removes its reminders. Delivery itself goes
// through the notification outbox, so retries cannot produce duplicates: the
// outbox idempotency key includes the visit id, reminder kind and the UTC
// scheduled_at, and reminder dispatch rechecks the current visit status.

import { PgBoss } from 'pg-boss';
import { pool } from '../../db/pool.js';
import { dispatchReminder } from './site-visit-lifecycle.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');

const QUEUE_NAME = 'site-visit-reminders';
const CRON_QUEUE_NAME = 'site-visit-reminders-cron';

const REMINDER_KINDS = [
  { key: '24h', beforeMs: 24 * 60 * 60 * 1000 },
  { key: '2h', beforeMs: 2 * 60 * 60 * 1000 },
] as const;

interface ReminderJobData {
  visitId: string;
  reminderKey: string;
  attempt: number;
}

let initialized = false;

async function initializeBoss(): Promise<void> {
  if (initialized) return;
  await boss.start();
  await boss.createQueue(QUEUE_NAME);
  await boss.createQueue(CRON_QUEUE_NAME);
  initialized = true;
}

async function processReminderJob(job: {
  id: string;
  data: ReminderJobData;
  name: string;
}): Promise<void> {
  const { visitId, reminderKey, attempt } = job.data;
  const maxRetries = 3;
  try {
    await dispatchReminder(visitId, reminderKey);
  } catch (error) {
    console.error(`Error dispatching site visit reminder for ${visitId} (${reminderKey}):`, error);
    if (attempt < maxRetries) {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30_000);
      await boss.send(
        QUEUE_NAME,
        { visitId, reminderKey, attempt: attempt + 1 },
        { startAfter: delay },
      );
    }
  }
}

/**
 * Scan for visits whose reminder time has arrived and enqueue them.
 * Safe to run repeatedly: dispatchReminder is idempotent and the outbox
 * deduplicates on (visit, kind, scheduled_at).
 */
async function scanDueReminders(): Promise<{ scanned: number; enqueued: number }> {
  const result = await pool.query<{ id: string; scheduled_at: Date }>(
    `SELECT id, scheduled_at
       FROM site_visits
      WHERE status IN ('scheduled', 'confirmed', 'rescheduled')
        AND scheduled_at > NOW()
        AND scheduled_at <= NOW() + INTERVAL '24 hours'`,
  );

  let enqueued = 0;
  const rows = result.rows;
  for (const row of rows) {
    const scheduledAt = new Date(row.scheduled_at);
    const deltaMs = scheduledAt.getTime() - Date.now();
    for (const reminder of REMINDER_KINDS) {
      const dueAt = scheduledAt.getTime() - reminder.beforeMs;
      // Enqueue when the reminder instant has passed but the visit has not
      // started yet. dispatchReminder rechecks both status and window.
      if (Date.now() >= dueAt && deltaMs > 0) {
        await boss.send(QUEUE_NAME, {
          visitId: row.id,
          reminderKey: reminder.key,
          attempt: 1,
        });
        enqueued += 1;
      }
    }
  }

  return { scanned: rows.length, enqueued };
}

export async function startSiteVisitReminderWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(QUEUE_NAME, processReminderJob as never);
  await boss.schedule(CRON_QUEUE_NAME, '*/5 * * * *', {});
  await boss.work(CRON_QUEUE_NAME, async () => {
    try {
      const result = await scanDueReminders();
      if (result.enqueued > 0) {
        console.log(`Site visit reminders enqueued: ${result.enqueued}`);
      }
    } catch (error) {
      console.error('Site visit reminder scan failed:', error);
    }
  });
  console.log('Site visit reminder worker started');
}

export async function stopSiteVisitReminderWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Site visit reminder worker stopped');
}

export { boss, scanDueReminders };