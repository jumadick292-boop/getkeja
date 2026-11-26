// Laundry overdue-order worker (Task 13.8).
// Idempotently flags orders that are past their return date but still in an
// active processing state as 'exception' so providers/customers can act.
// Uses pg-boss cron (the established mechanism). Safe under retries: only
// non-terminal, non-exception orders are transitioned.
import { PgBoss } from 'pg-boss';
import { flagOverdueOrders } from './laundry.repository.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');
const CRON_QUEUE_NAME = 'laundry-overdue-check';

async function initializeBoss(): Promise<void> {
  await boss.start();
  await boss.createQueue(CRON_QUEUE_NAME);
}

async function processOverdueCron(): Promise<void> {
  try {
    const result = await flagOverdueOrders();
    if (result.flagged > 0) {
      console.log(`Laundry overdue: flagged ${result.flagged} order(s) as exception`);
    }
  } catch (error) {
    console.error('Laundry overdue check failed:', error);
  }
}

async function startLaundryOverdueWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(CRON_QUEUE_NAME, processOverdueCron as any);
  // Every 15 minutes.
  await boss.schedule(CRON_QUEUE_NAME, '*/15 * * * * *', {});
  console.log('Laundry overdue worker started');
}

async function stopLaundryOverdueWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Laundry overdue worker stopped');
}

export { startLaundryOverdueWorker, stopLaundryOverdueWorker };