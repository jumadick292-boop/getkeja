// Scheduling reminders + overdue worker (Task 13.9).
// Idempotently sends due reminders and flags overdue confirmed activities as
// missed. Uses pg-boss cron; safe under retries (state transitions guard).
import { PgBoss } from 'pg-boss';
import { transaction } from '../../db/tx.js';
import { enqueueOutboxEventTransactional, classifyEventType } from '../auth/transactional-outbox.service.js';
import { dueReminders, markReminderSent, markOverdue, findActivityById } from './scheduling.repository.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');
const CRON_QUEUE_NAME = 'scheduling-reminders';

async function initializeBoss(): Promise<void> {
  await boss.start();
  await boss.createQueue(CRON_QUEUE_NAME);
}

async function processRemindersCron(): Promise<void> {
  try {
    const now = new Date().toISOString();
    const due = await dueReminders(now);
    for (const reminder of due) {
      const activity = await findActivityById(reminder.activityId);
      const eventType = 'schedule.reminder';
      const skip = activity && (activity.status === 'cancelled' || activity.status === 'completed');
      await transaction(async (client) => {
        if (!skip) {
          await enqueueOutboxEventTransactional(client, {
            idempotencyKey: `${eventType}:${reminder.id}`,
            eventType,
            category: 'operational',
            priority: 'normal',
            recipientUserIds: activity?.customerUserId ? [activity.customerUserId] : [],
            organisationId: activity?.providerOrganisationId ?? null,
            resourceType: 'scheduling_activity',
            resourceId: reminder.activityId,
            payload: { activityId: reminder.activityId, startAt: activity?.startAt ?? null },
            channels: ['in_app'],
            classification: classifyEventType(eventType),
          });
        }
        await markReminderSent(reminder.id);
      });
    }
    const overdue = await markOverdue(now);
    if (overdue > 0) {
      console.log(`Scheduling: flagged ${overdue} overdue activity(ies) as missed`);
    }
  } catch (error) {
    console.error('Scheduling reminder/overdue job failed:', error);
  }
}

async function startSchedulingWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(CRON_QUEUE_NAME, processRemindersCron as any);
  // Every 5 minutes for timely reminders/overdue detection.
  await boss.schedule(CRON_QUEUE_NAME, '*/5 * * * * *', {});
  console.log('Scheduling reminder/overdue worker started');
}

async function stopSchedulingWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('Scheduling reminder/overdue worker stopped');
}

export { startSchedulingWorker, stopSchedulingWorker };