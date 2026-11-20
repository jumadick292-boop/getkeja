import { PgBoss } from 'pg-boss';
import { pool } from '../../db/pool.js';
import {
  findPendingOutboxEvents,
  updateOutboxEvent,
  findOutboxEventById,
} from './auth.repository.js';
import type { NotificationOutbox, NotificationChannel } from './auth.types.js';
import { NotificationService } from './notification.service.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');

const notificationService = new NotificationService();

const QUEUE_NAME = 'notification-outbox';
const CRON_QUEUE_NAME = 'notification-outbox-cron';
const PROCESSING_JOB_NAME = 'process-notification-outbox';
const RETRY_JOB_NAME = 'retry-notification-outbox';

interface OutboxJobData {
  outboxId: string;
  attempt: number;
}

async function initializeBoss(): Promise<void> {
  await boss.start();
  await boss.createQueue(QUEUE_NAME);
  await boss.createQueue(CRON_QUEUE_NAME);
}

async function scheduleOutboxProcessing(): Promise<void> {
  await boss.schedule(CRON_QUEUE_NAME, '*/30 * * * * *', {});
}

async function queueOutboxEvent(outboxId: string): Promise<void> {
  await boss.send(QUEUE_NAME, { outboxId, attempt: 1 });
}

async function processOutboxJob(job: { id: string; data: OutboxJobData; name: string }): Promise<void> {
  const { outboxId, attempt } = job.data;
  const maxRetries = 3;

  try {
    const event = await findOutboxEventById(outboxId);
    if (!event) {
      console.warn(`Outbox event ${outboxId} not found`);
      return;
    }

    if (event.status === 'completed') {
      return;
    }

    if (event.status === 'dead_letter') {
      return;
    }

    await notificationService.processOutboxEvent(outboxId);

    const updatedEvent = await findOutboxEventById(outboxId);
    if (updatedEvent?.status === 'failed' && attempt < maxRetries) {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
      await boss.send(QUEUE_NAME, { outboxId, attempt: attempt + 1 }, { startAfter: delay });
    }
  } catch (error) {
    console.error(`Error processing outbox event ${outboxId}:`, error);

    if (attempt < maxRetries) {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
      await boss.send(QUEUE_NAME, { outboxId, attempt: attempt + 1 }, { startAfter: delay });
    } else {
      await updateOutboxEvent(outboxId, {
        status: 'dead_letter',
        errorMessage: error instanceof Error ? error.message : 'Max retries exceeded',
      });
    }
  }
}

async function processRetryJob(job: { id: string; data: OutboxJobData; name: string }): Promise<void> {
  await processOutboxJob(job);
}

async function processOutboxCronJob(): Promise<void> {
  await enqueuePendingOutboxEvents();
}

async function startOutboxWorker(): Promise<void> {
  await initializeBoss();

  await boss.work(QUEUE_NAME, processOutboxJob as any);
  await boss.work(QUEUE_NAME, processRetryJob as any);
  await boss.work(CRON_QUEUE_NAME, processOutboxCronJob);

  await scheduleOutboxProcessing();

  console.log('Notification outbox worker started');
}

async function stopOutboxWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Notification outbox worker stopped');
}

async function enqueuePendingOutboxEvents(): Promise<void> {
  const events = await findPendingOutboxEvents(100);
  for (const event of events) {
    await queueOutboxEvent(event.id);
  }
}

async function enqueueOutboxEvent(outboxId: string): Promise<void> {
  await queueOutboxEvent(outboxId);
}

export {
  boss,
  initializeBoss,
  startOutboxWorker,
  stopOutboxWorker,
  enqueuePendingOutboxEvents,
  enqueueOutboxEvent,
  queueOutboxEvent,
};