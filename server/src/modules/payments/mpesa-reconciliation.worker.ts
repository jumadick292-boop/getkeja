// M-Pesa reconciliation worker.
//
// Scans for pending/processing M-Pesa payment transactions that have a
// provider reference but no callback (or a stale callback), and reconciles
// them by querying the Daraja transaction status API. Confirmed payments are
// finalized atomically via paymentService.reconcilePayment.
//
// Safe to run repeatedly: reconcilePayment is idempotent (completed payments
// are skipped, already-finalized payments return early).

import { PgBoss } from 'pg-boss';
import { pool } from '../../db/pool.js';
import { reconcilePayment } from './payment.service.js';

const boss = new PgBoss(process.env.DATABASE_URL || '');

const QUEUE_NAME = 'mpesa-reconciliation';
const CRON_QUEUE_NAME = 'mpesa-reconciliation-cron';

// Only reconcile payments that have been pending for at least this long,
// to avoid racing with a callback that is still in flight.
const PENDING_AGE_MS = 10 * 60 * 1000; // 10 minutes

interface ReconcileJobData {
  paymentTransactionId: string;
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

async function processReconcileJob(job: {
  id: string;
  data: ReconcileJobData;
  name: string;
}): Promise<void> {
  const { paymentTransactionId, attempt } = job.data;
  const maxRetries = 3;
  try {
    const result = await reconcilePayment(paymentTransactionId);
    if (result.reconciled) {
      console.log(`Reconciled payment ${paymentTransactionId}: ${result.status}`);
    } else if (result.status !== 'already_completed') {
      console.log(`Payment ${paymentTransactionId} not yet reconciled: ${result.status}`);
    }
  } catch (error) {
    console.error(`Error reconciling payment ${paymentTransactionId} (attempt ${attempt}):`, error);
    if (attempt < maxRetries) {
      const delay = Math.min(1000 * Math.pow(2, attempt), 30_000);
      await boss.send(
        QUEUE_NAME,
        { paymentTransactionId, attempt: attempt + 1 },
        { startAfter: delay },
      );
    }
  }
}

/**
 * Scan for pending/processing payments due for reconciliation and enqueue them.
 */
async function scanDuePayments(): Promise<{ scanned: number; enqueued: number }> {
  const cutoff = new Date(Date.now() - PENDING_AGE_MS).toISOString();
  const result = await pool.query<{ id: string }>(
    `SELECT id
     FROM payment_transactions
     WHERE provider = 'mpesa'
       AND status = ANY($1::payment_transaction_status[])
       AND provider_transaction_id IS NOT NULL
       AND (callback_received_at IS NULL OR callback_received_at < $2)
     ORDER BY created_at ASC
     LIMIT 100`,
    [['pending', 'processing'], cutoff],
  );

  let enqueued = 0;
  for (const row of result.rows) {
    await boss.send(QUEUE_NAME, {
      paymentTransactionId: row.id,
      attempt: 1,
    });
    enqueued += 1;
  }

  return { scanned: result.rows.length, enqueued };
}

export async function startMpesaReconciliationWorker(): Promise<void> {
  await initializeBoss();
  await boss.work(QUEUE_NAME, processReconcileJob as never);
  await boss.schedule(CRON_QUEUE_NAME, '*/5 * * * *', {});
  await boss.work(CRON_QUEUE_NAME, async () => {
    try {
      const result = await scanDuePayments();
      if (result.enqueued > 0) {
        console.log(`M-Pesa reconciliation scan: ${result.scanned} scanned, ${result.enqueued} enqueued`);
      }
    } catch (error) {
      console.error('M-Pesa reconciliation scan failed:', error);
    }
  });
  console.log('M-Pesa reconciliation worker started');
}

export async function stopMpesaReconciliationWorker(): Promise<void> {
  await boss.stop({ graceful: true });
  console.log('M-Pesa reconciliation worker stopped');
}

export { boss, scanDuePayments };
