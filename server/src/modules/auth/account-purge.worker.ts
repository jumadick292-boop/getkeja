import { PgBoss } from 'pg-boss';
import * as accountService from './account.service.js';

const QUEUE_NAME = 'account-personal-data-purge';
const boss = new PgBoss(process.env.DATABASE_URL || '');
let started = false;

export async function startAccountPurgeWorker(): Promise<void> {
  await boss.start();
  await boss.createQueue(QUEUE_NAME);
  await boss.work(QUEUE_NAME, async () => {
    let purgedCount = 0;
    let batchSize: number;
    do {
      batchSize = await accountService.purgeExpiredDeletedAccounts(20);
      purgedCount += batchSize;
    } while (batchSize === 20);
    if (purgedCount > 0) {
      console.info(`Purged personal data for ${purgedCount} expired deleted account(s)`);
    }
  });
  await boss.schedule(QUEUE_NAME, '0 3 * * *', {});
  started = true;
}

export async function stopAccountPurgeWorker(): Promise<void> {
  if (!started) return;
  await boss.stop({ graceful: true });
  started = false;
}
