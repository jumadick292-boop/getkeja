// Provider availability-expiry worker (Task 13.4).
// Periodically resets expired temporary closures (status 'unavailable' whose
// temporary_unavailable_to has passed) back to 'active'. Uses pg-boss cron
// (the established scheduling mechanism) — no uncontrolled setInterval.
import { PgBoss } from 'pg-boss';
import { expireTemporaryClosures } from './provider-catalogue.repository.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');
const CRON_QUEUE_NAME = 'provider-availability-expiry';

async function initializeBoss(): Promise<void> {
  await boss.start();
  await boss.createQueue(CRON_QUEUE_NAME);
}

async function processExpiryCron(): Promise<void> {
  try {
    const count = await expireTemporaryClosures();
    if (count > 0) {
      console.log(`Provider availability: reactivated ${count} expired offering(s)`);
    }
  } catch (error) {
    console.error('Provider availability expiry job failed:', error);
  }
}

async function startProviderAvailabilityWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(CRON_QUEUE_NAME, processExpiryCron as any);
  // Every 15 minutes.
  await boss.schedule(CRON_QUEUE_NAME, '*/15 * * * * *', {});
  console.log('Provider availability worker started');
}

async function stopProviderAvailabilityWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Provider availability worker stopped');
}

export { startProviderAvailabilityWorker, stopProviderAvailabilityWorker };