// Recurring rent billing worker (Task 14.1).
//
// Idempotent, missed-run safe. Each tick generates due invoices for active
// billing schedules via the repository engine (DB unique index guarantees no
// duplicate invoices; schedule row locks serialise concurrent workers) and
// flips overdue invoices. Uses pg-boss cron with Africa/Nairobi date logic.
import { PgBoss } from 'pg-boss';
import { generateDueInvoices } from './billing.repository.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');
const CRON_QUEUE_NAME = 'recurring-rent-billing';

let initialized = false;

async function initializeBoss(): Promise<void> {
  if (initialized) return;
  await boss.start();
  await boss.createQueue(CRON_QUEUE_NAME);
  initialized = true;
}

async function processBillingCron(): Promise<void> {
  try {
    const result = await generateDueInvoices();
    if (result.invoicesCreated > 0 || result.overdueMarked > 0) {
      console.log(
        `Recurring billing: ${result.invoicesCreated} invoice(s) created, ` +
          `${result.invoicesSkipped} skipped, ${result.overdueMarked} marked overdue`,
      );
    }
  } catch (error) {
    // Never leak sensitive data; log a generic message with the error name.
    console.error('Recurring billing job failed:', error instanceof Error ? error.name : 'unknown');
  }
}

export async function startRecurringBillingWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(CRON_QUEUE_NAME, processBillingCron as never);
  // Every 15 minutes (6-field cron: second minute hour dom month dow).
  await boss.schedule(CRON_QUEUE_NAME, '*/15 * * * * *', {});
  console.log('Recurring rent billing worker started');
}

export async function stopRecurringBillingWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Recurring rent billing worker stopped');
}

export { boss, processBillingCron };