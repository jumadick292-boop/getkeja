// Garbage recurring-occurrence worker (Task 13.7).
// Idempotently materialises due occurrences of active recurring agreements into
// one-time collection jobs. Missed-run safe: each run regenerates any due
// occurrences within a lookback window. Uses pg-boss cron (Africa/Nairobi date
// logic lives in the repository). No history rewrite; suspensions/cancellations
// are respected because only 'active' agreements are processed.
import { PgBoss } from 'pg-boss';
import { generateRecurringWork } from './garbage.repository.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');
const CRON_QUEUE_NAME = 'garbage-recurring-occurrences';

async function initializeBoss(): Promise<void> {
  await boss.start();
  await boss.createQueue(CRON_QUEUE_NAME);
}

async function processRecurringCron(): Promise<void> {
  try {
    const result = await generateRecurringWork();
    if (result.occurrencesCreated > 0 || result.jobsCreated > 0) {
      console.log(
        `Garbage recurring: created ${result.occurrencesCreated} occurrence(s), ${result.jobsCreated} job(s)`,
      );
    }
  } catch (error) {
    console.error('Garbage recurring occurrence job failed:', error);
  }
}

async function startGarbageRecurringWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(CRON_QUEUE_NAME, processRecurringCron as any);
  // Every 15 minutes.
  await boss.schedule(CRON_QUEUE_NAME, '*/15 * * * * *', {});
  console.log('Garbage recurring occurrence worker started');
}

async function stopGarbageRecurringWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Garbage recurring occurrence worker stopped');
}

export { startGarbageRecurringWorker, stopGarbageRecurringWorker };