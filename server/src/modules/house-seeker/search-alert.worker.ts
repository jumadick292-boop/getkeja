// Search alert background worker.
// Uses the existing pg-boss infrastructure (same as the notification outbox
// worker) to process search-alert matching jobs enqueued when listings are
// published.
//
// Does not create a duplicate job queue or notification system.

import { PgBoss } from 'pg-boss';
import { searchAlertService } from './search-alert.service.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');

const QUEUE_NAME = 'search-alert';
const CRON_QUEUE_NAME = 'search-alert-cron';
const JOB_NAME = 'process-search-alert';

interface SearchAlertJobData {
  listingId: string;
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

async function enqueueSearchAlert(listingId: string): Promise<void> {
  await initializeBoss();
  await boss.send(QUEUE_NAME, { listingId, attempt: 1 });
}

async function processSearchAlertJob(job: { id: string; data: SearchAlertJobData; name: string }): Promise<void> {
  const { listingId, attempt } = job.data;
  const maxRetries = 3;

  try {
    const result = await searchAlertService.matchListingAgainstSavedSearches(listingId);
    console.log(`Search alert processed for listing ${listingId}:`, result);
  } catch (error) {
    console.error(`Error processing search alert for listing ${listingId}:`, error);

    if (attempt < maxRetries) {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
      await boss.send(QUEUE_NAME, { listingId, attempt: attempt + 1 }, { startAfter: delay });
    } else {
      console.error(`Max retries exceeded for search alert listing ${listingId}`);
    }
  }
}

async function processSearchAlertCronJob(): Promise<void> {
  // Backfill: process any recently published listings that may have missed
  // alert matching (e.g., if the worker was down).
  const result = await searchAlertService.processPendingAlerts();
  console.log(`Search alert cron processed:`, result);
}

export async function startSearchAlertWorker(): Promise<void> {
  await initializeBoss();

  await boss.work(QUEUE_NAME, processSearchAlertJob as any);
  await boss.work(QUEUE_NAME, processSearchAlertJob as any); // retry handler shares the same processor

  // Cron job every 5 minutes to backfill missed alerts.
  await boss.schedule(CRON_QUEUE_NAME, '*/5 * * * *', {});
  await boss.work(CRON_QUEUE_NAME, processSearchAlertCronJob);

  console.log('Search alert worker started');
}

export async function stopSearchAlertWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Search alert worker stopped');
}

export { boss, enqueueSearchAlert };
