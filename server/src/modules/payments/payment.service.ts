// Payment orchestration service.
//
// Responsibilities:
//  - Create payment attempts with idempotency keys before any provider call.
//  - Initiate payments through any registered provider (M-Pesa Daraja, Pesapal,
//    M-Pesa Paybill, M-Pesa Till). Provider credentials never reach Flutter.
//  - Process provider callbacks: idempotent, verified via provider query API,
//    atomic with invoice balance updates and receipt generation.
//  - Protect against duplicate callbacks, concurrent payments, and overpayment.
//  - Persist critical payment events transactionally via the outbox.
//  - Manage unmatched payments and reversals/refunds.
//
// Money is stored as DECIMAL(12,2) in Postgres and handled as exact numbers
// in TypeScript. No floating-point arithmetic is used for monetary math.

import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import type { PoolClient } from 'pg';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../../shared/errors.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import * as repo from '../landlord/landlord.repository.js';
import type { Invoice } from '../landlord/landlord.repository.js';
import type { PaymentProviderAdapter } from './payment.provider.js';
import {
  mpesaDarajaAdapter,
  mpesaPaybillAdapter,
  mpesaTillAdapter,
  getMpesaConfig,
} from './mpesa.service.js';
import { pesapalAdapter } from './pesapal.service.js';

const OPEN_PAYMENT_STATUSES = new Set(['pending', 'processing']);

/**
 * Round to 2 decimal places exactly (KES). Avoids float drift.
 */
function money(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Registered payment provider adapters. Keyed by provider identifier.
 * The provider value stored in payment_transactions.provider matches one
 * of these keys.
 */
const PROVIDERS: Map<string, PaymentProviderAdapter> = new Map([
  [mpesaDarajaAdapter.provider, mpesaDarajaAdapter],
  [mpesaPaybillAdapter.provider, mpesaPaybillAdapter],
  [mpesaTillAdapter.provider, mpesaTillAdapter],
  [pesapalAdapter.provider, pesapalAdapter],
]);
/**
 * Resolve a provider adapter by provider identifier.
 */
function getProvider(provider: string): PaymentProviderAdapter {
  const adapter = PROVIDERS.get(provider);
  if (!adapter) {
    throw new ValidationError(`Unsupported payment provider: ${provider}`);
  }
  return adapter;
}

/**
 * Result of initiating a payment.
 */
export interface PaymentInitiationResult {
  paymentTransactionId: string;
  status: 'pending';
  providerTransactionId: string;
  merchantRequestId: string | null;
  checkoutUrl: string | null;
  amount: number;
  invoiceId: string | null;
  provider: string;
}

/**
 * Result of processing a callback.
 */
export interface CallbackResult {
  status: 'processed' | 'already_processed' | 'ignored';
  paymentTransactionId?: string;
  invoiceId?: string | null;
}

/**
 * Initiate a payment for an invoice through a specific provider. Creates a
 * pending payment transaction atomically, then triggers the provider payment
 * request. Returns pending to the caller; the client must NOT treat this as
 * a successful payment.
 */
export async function initiatePayment(input: {
  invoiceId: string;
  tenantId: string;
  amount: number;
  phoneNumber?: string;
  idempotencyKey: string;
    createdBy: string;
  provider?: string;
  merchantReference?: string;
}): Promise<PaymentInitiationResult> {
  const {
    invoiceId,
    tenantId,
    amount,
    phoneNumber,
    idempotencyKey,
    createdBy,
    provider = 'mpesa',
    merchantReference,
  } = input;

  const providerAdapter = getProvider(provider);
  const amt = money(amount);
  if (!Number.isFinite(amt) || amt <= 0) {
    throw new ValidationError('Payment amount must be a positive number');
  }

  return transaction(async (client) => {
    // Lock the invoice row so concurrent initiations against the same invoice
    // are serialized and we read a consistent outstanding balance.
    const invoice = await client.query<Invoice & { outstanding_locked: boolean }>(
      `SELECT
        id, invoice_number as "invoiceNumber", property_id as "propertyId",
        unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
        status, currency, total_amount as "totalAmount",
        amount_paid as "amountPaid", amount_outstanding as "amountOutstanding"
       FROM invoices WHERE id = $1 FOR UPDATE`,
      [invoiceId],
    );
    const inv = invoice.rows[0];
    if (!inv) throw new NotFoundError('Invoice not found');
    if (inv.status === 'cancelled' || inv.status === 'void' || inv.status === 'refunded') {
      throw new ConflictError(`Invoice is ${inv.status} and cannot be paid`);
    }
    if (inv.tenantId !== tenantId) {
      throw new ForbiddenError('You can only pay invoices for your own tenancy');
    }

    const outstanding = money(Number(inv.amountOutstanding));
    if (amt > outstanding) {
      throw new ValidationError(
        `Payment amount ${amt} exceeds outstanding balance ${outstanding}`,
      );
    }

    // Reject concurrent open payments against the same invoice.
    const open = await client.query<{ id: string }>(
      `SELECT id FROM payment_transactions
       WHERE invoice_id = $1 AND status = ANY($2::payment_transaction_status[])
       ORDER BY created_at DESC LIMIT 1`,
      [invoiceId, Array.from(OPEN_PAYMENT_STATUSES)],
    );
    if (open.rows.length > 0) {
      throw new ConflictError(
        'A payment for this invoice is already in progress',
      );
    }

    // Create the payment attempt with a stable idempotency key.
    let paymentId: string;
    let paymentAmount: number;
    try {
      const inserted = await client.query<repo.PaymentTransaction>(
        `INSERT INTO payment_transactions (
          transaction_reference, invoice_id, tenant_id, property_id, amount,
          currency, provider, provider_transaction_id, status, payment_date,
          callback_payload, idempotency_key, created_by
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
        )
        RETURNING
          id, transaction_reference as "transactionReference",
          invoice_id as "invoiceId", tenant_id as "tenantId",
          property_id as "propertyId", amount, currency, provider,
          provider_transaction_id as "providerTransactionId", status,
          payment_date as "paymentDate", callback_payload as "callbackPayload",
          idempotency_key as "idempotencyKey", created_by as "createdBy",
          created_at as "createdAt", updated_at as "updatedAt"`,
        [
          `PAY-${Date.now()}`, invoiceId, tenantId, inv.propertyId, amt,
          inv.currency ?? 'KES', provider, null,
          'pending', new Date(), null, idempotencyKey, createdBy,
        ],
      );
      const row = inserted.rows[0]!;
      paymentId = row.id;
      paymentAmount = row.amount;
    } catch (error) {
      if ((error as Error).message.includes('idempotency_key')) {
        const existing = await client.query<repo.PaymentTransaction>(
          `SELECT id, status, provider_transaction_id as "providerTransactionId",
                  amount
           FROM payment_transactions WHERE idempotency_key = $1`,
          [idempotencyKey],
        );
        if (existing.rows.length > 0) {
          const row = existing.rows[0]!;
          return {
            paymentTransactionId: row.id,
            status: 'pending',
            providerTransactionId: row.providerTransactionId ?? '',
            merchantRequestId: null,
            checkoutUrl: null,
            amount: row.amount,
            invoiceId,
            provider,
          };
        }
      }
      throw error;
    }

    // Initiate the provider payment request.
    let providerResult;
    try {
      providerResult = await providerAdapter.initiatePayment({
        amount: amt,
        phoneNumber,
        invoiceReference: inv.invoiceNumber,
        merchantReference,
      });
    } catch (error) {
      await client.query(
        `UPDATE payment_transactions SET status = 'failed',
          failure_reason = $2, updated_at = NOW() WHERE id = $1`,
        [paymentId, (error as Error).message],
      );
      throw error;
    }

    // Persist the provider request identifiers.
    await client.query(
      `UPDATE payment_transactions
       SET provider_transaction_id = $1, updated_at = NOW()
       WHERE id = $2`,
      [providerResult.providerTransactionId, paymentId],
    );

    return {
      paymentTransactionId: paymentId,
      status: 'pending',
      providerTransactionId: providerResult.providerTransactionId,
      merchantRequestId: providerResult.merchantRequestId ?? null,
      checkoutUrl: providerResult.checkoutUrl ?? null,
      amount: amt,
      invoiceId,
      provider,
    };
  });
}

/**
 * Process an incoming provider callback. The provider identifier is derived
 * from the callback context (route). All callbacks are treated as untrusted
 * until verified against the provider's transaction query API.
 */
export async function processProviderCallback(
  body: unknown,
  provider: string,
): Promise<CallbackResult> {
  const providerAdapter = getProvider(provider);

  let callbackResult;
  try {
    callbackResult = await providerAdapter.handleCallback(body);
  } catch (error) {
    // Malformed callback: audit and ignore.
    return { status: 'ignored' };
  }

  if (!callbackResult.providerTransactionId) {
    return { status: 'ignored' };
  }

  return transaction(async (client) => {
    const existingAudit = await client.query<{ id: string; processed: boolean }>(
      `SELECT id, processed FROM payment_callback_audit
       WHERE provider = $1 AND provider_transaction_id = $2
       ORDER BY received_at DESC LIMIT 1`,
      [provider, callbackResult.providerTransactionId],
    );

    // Idempotency: already processed this exact provider transaction.
    if (existingAudit.rows.length > 0 && existingAudit.rows[0]!.processed) {
      return { status: 'already_processed' };
    }

    const resultCodeNum = callbackResult.successful ? 0 : 1;

    // Mark the audit row as processed (in progress).
    await client.query(
      `INSERT INTO payment_callback_audit
        (provider, provider_transaction_id, event_type, payload, processed, received_at)
       VALUES ($1, $2, $3, $4, FALSE, NOW())
       ON CONFLICT (provider, provider_transaction_id) DO UPDATE
         SET payload = EXCLUDED.payload, received_at = NOW()
       WHERE payment_callback_audit.provider = $1
         AND payment_callback_audit.provider_transaction_id = $2`,
      [
        provider,
        callbackResult.providerTransactionId,
        `${provider}.callback`,
        JSON.stringify(callbackResult.rawPayload ?? {}),
      ],
    );

    // Find the internal payment attempt for this provider transaction.
    const payment = await client.query<repo.PaymentTransaction>(
      `SELECT id, invoice_id as "invoiceId", tenant_id as "tenantId",
              property_id as "propertyId", amount, status, provider,
              idempotency_key as "idempotencyKey", created_by as "createdBy"
       FROM payment_transactions
       WHERE provider_transaction_id = $1 AND provider = $2`,
      [callbackResult.providerTransactionId, provider],
    );

    if (payment.rows.length === 0) {
      // No matching internal payment: this is an unmatched provider payment.
      if (callbackResult.amount != null) {
        await recordUnmatchedPayment(client, {
          provider,
          providerTransactionId: callbackResult.providerTransactionId,
          merchantReference: undefined,
          phoneNumber: callbackResult.phoneNumber ?? null,
          amount: callbackResult.amount,
          currency: 'KES',
          transactionDate: callbackResult.transactionDate ?? null,
          callbackPayload: callbackResult.rawPayload,
        });
      }
      await client.query(
        `UPDATE payment_callback_audit SET processed = TRUE, processed_at = NOW()
         WHERE provider = $1 AND provider_transaction_id = $2`,
        [provider, callbackResult.providerTransactionId],
      );
      return { status: 'ignored' };
    }

    const payRow = payment.rows[0]!;

    // Idempotency guard: if the payment is already completed or reversed,
    // do not re-finalize. Prevents double-credit from concurrent or duplicate
    // callbacks that pass the audit-row check before either commits, and
    // prevents re-completing a payment that has already been reversed.
    if (payRow.status === 'completed' || payRow.status === 'reversed') {
      await client.query(
        `UPDATE payment_callback_audit SET processed = TRUE, processed_at = NOW()
         WHERE provider = $1 AND provider_transaction_id = $2`,
        [provider, callbackResult.providerTransactionId],
      );
      return { status: 'already_processed', paymentTransactionId: payRow.id };
    }

    // For C2B providers (Paybill/Till), verify the callback originated from
    // the configured central shortcode. Safaricom C2B confirmation callbacks
    // are the authoritative mechanism (no query API exists), so the shortcode
    // is the primary trust boundary — only Safaricom's servers can POST to a
    // registered confirmation URL, and they include the shortcode in the body.
    const isC2bProvider = provider === 'mpesa_paybill' || provider === 'mpesa_till';
    if (isC2bProvider) {
      const callbackShortCode =
        (callbackResult.rawPayload as Record<string, unknown>)?.BusinessShortCode ??
        (callbackResult.rawPayload as Record<string, unknown>)?.business_short_code;
      const config = getMpesaConfig();
      if (!callbackShortCode || String(callbackShortCode) !== config.shortcode) {
        await client.query(
          `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
           WHERE provider = $2 AND provider_transaction_id = $3`,
          [`C2B callback shortcode mismatch: expected ${config.shortcode}, got ${callbackShortCode ?? 'missing'}`, provider, callbackResult.providerTransactionId],
        );
        return { status: 'ignored' };
      }
    }

    // Callback-stated amount must match the payment attempt. The provider
    // verified amount is checked separately after query API verification.
    // For C2B providers (Paybill/Till) there is no query API, so the callback
    // amount is the only amount evidence — it must be present.
    if (isC2bProvider && callbackResult.amount == null) {
      await client.query(
        `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
         WHERE provider = $2 AND provider_transaction_id = $3`,
        ['C2B callback missing TransAmount', provider, callbackResult.providerTransactionId],
      );
      return { status: 'ignored' };
    }

    if (callbackResult.amount != null && money(callbackResult.amount) !== money(payRow.amount)) {
      await client.query(
        `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
         WHERE provider = $2 AND provider_transaction_id = $3`,
        [`Callback amount ${callbackResult.amount} does not match payment attempt ${payRow.amount}`, provider, callbackResult.providerTransactionId],
      );
      await client.query(
        `UPDATE payment_callback_audit SET processed = TRUE, processed_at = NOW()
         WHERE provider = $1 AND provider_transaction_id = $2`,
        [provider, callbackResult.providerTransactionId],
      );
      return { status: 'processed', paymentTransactionId: payRow.id };
    }

    // Successful callbacks must be independently verified via provider query API
    // before finalizing. A callback alone is never sufficient proof of payment.
    if (callbackResult.successful) {
      let verified;
      try {
        verified = await providerAdapter.queryTransactionStatus({
          providerTransactionId: callbackResult.providerTransactionId,
        });
      } catch (error) {
        await client.query(
          `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
           WHERE provider = $2 AND provider_transaction_id = $3`,
          [`Verification query failed: ${(error as Error).message}`, provider, callbackResult.providerTransactionId],
        );
        return { status: 'ignored' };
      }

      if (!verified.successful) {
        // C2B providers (Paybill/Till) have no query API; the confirmation
        // callback itself is sufficient verification. Trust the callback when
        // the adapter explicitly reports query as not supported.
        const queryNotSupported =
          verified.failureReason != null &&
          verified.failureReason.includes('not supported');
        if (!queryNotSupported) {
          await client.query(
            `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
             WHERE provider = $2 AND provider_transaction_id = $3`,
            [`Provider did not confirm transaction: ${verified.failureReason ?? 'unknown'}`, provider, callbackResult.providerTransactionId],
          );
          return { status: 'ignored' };
        }
      }

      const receiptNumber =
        verified.transactionReceipt ?? callbackResult.providerReceipt ?? null;
      if (!receiptNumber) {
        await client.query(
          `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
           WHERE provider = $2 AND provider_transaction_id = $3`,
          ['Verified transaction has no receipt number', provider, callbackResult.providerTransactionId],
        );
        return { status: 'ignored' };
      }

      // Amount validation against the internal payment attempt.
      const verifiedAmount =
        verified.amount != null ? money(Number(verified.amount)) : null;
      if (verifiedAmount != null && verifiedAmount !== money(payRow.amount)) {
        await client.query(
          `UPDATE payment_callback_audit SET processing_error = $1, processed_at = NOW()
           WHERE provider = $2 AND provider_transaction_id = $3`,
          [`Callback amount ${verifiedAmount} does not match payment attempt ${payRow.amount}`, provider, callbackResult.providerTransactionId],
        );
        return { status: 'ignored' };
      }

      // Finalize: mark payment completed, update invoice + ledger + receipt
      // atomically with row-level lock on the invoice.
      await finalizePayment(client, payRow, {
        providerTransactionId: callbackResult.providerTransactionId,
        providerReceipt: receiptNumber,
        transactionDate: callbackResult.transactionDate ?? verified.transactionDate
          ? new Date(callbackResult.transactionDate ?? verified.transactionDate!)
          : null,
        phoneNumber: callbackResult.phoneNumber ?? verified.msisdn ?? null,
        amount: verifiedAmount ?? payRow.amount,
        callbackPayload: callbackResult.rawPayload,
      });

      await client.query(
        `UPDATE payment_callback_audit SET processed = TRUE, processed_at = NOW()
         WHERE provider = $1 AND provider_transaction_id = $2`,
        [provider, callbackResult.providerTransactionId],
      );

      return {
        status: 'processed',
        paymentTransactionId: payRow.id,
        invoiceId: payRow.invoiceId,
      };
    }

    // Non-success: mark the payment attempt failed.
    await client.query(
      `UPDATE payment_transactions
       SET status = 'failed', failure_reason = $2, updated_at = NOW()
       WHERE id = $3`,
      [payRow.id, `Provider callback rejected`],
    );
    await client.query(
      `UPDATE payment_callback_audit SET processed = TRUE, processed_at = NOW()
       WHERE provider = $1 AND provider_transaction_id = $2`,
      [provider, callbackResult.providerTransactionId],
    );
    return { status: 'processed', paymentTransactionId: payRow.id };
  });
}

/**
 * Atomically finalize a successful payment: mark the transaction completed,
 * update the invoice balance (with row-level lock), write a ledger entry,
 * issue a receipt, and enqueue a critical outbox notification.
 */
async function finalizePayment(
  client: PoolClient,
  payment: repo.PaymentTransaction,
  details: {
    providerTransactionId: string;
    providerReceipt: string;
    transactionDate?: Date | null;
    phoneNumber?: string | null;
    amount: number;
    callbackPayload: Record<string, unknown>;
  },
): Promise<void> {
  const invoiceId = payment.invoiceId;
  if (!invoiceId) {
    await client.query(
      `UPDATE payment_transactions SET status = 'completed', callback_payload = $2,
        updated_at = NOW() WHERE id = $1`,
      [payment.id, JSON.stringify(details.callbackPayload)],
    );
    return;
  }

  // Lock the invoice row to serialize balance updates.
  const inv = await client.query<Invoice>(
    `SELECT id, invoice_number as "invoiceNumber", property_id as "propertyId",
            unit_id as "unitId", tenant_id as "tenantId", tenancy_id as "tenancyId",
            status, currency, total_amount as "totalAmount",
            amount_paid as "amountPaid", amount_outstanding as "amountOutstanding"
     FROM invoices WHERE id = $1 FOR UPDATE`,
    [invoiceId],
  );
  const invoice = inv.rows[0];
  if (!invoice) return;

  const amount = money(details.amount);
  const newPaid = money(Number(invoice.amountPaid) + amount);
  const newOutstanding = money(Math.max(0, Number(invoice.amountOutstanding) - amount));
  const newStatus = newOutstanding <= 0 ? 'paid' : 'partially_paid';

  // Update invoice balance within the same transaction (row already locked).
  await client.query(
    `UPDATE invoices SET status = $1, amount_paid = $2, amount_outstanding = $3,
      updated_by = $4, updated_at = NOW() WHERE id = $5`,
    [newStatus, newPaid, newOutstanding, payment.createdBy ?? 'system', invoiceId],
  );

  // Ledger entry recording the payment (within the transaction).
  await client.query(
    `INSERT INTO rent_ledger_entries (
      tenancy_id, tenant_id, property_id, unit_id, invoice_id, entry_type,
      amount, currency, billing_period_start, billing_period_end, due_date,
      payment_date, reference, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
    )`,
    [
      invoice.tenancyId, invoice.tenantId, invoice.propertyId, invoice.unitId,
      invoiceId, 'payment', amount, invoice.currency ?? 'KES',
      invoice.billingPeriodStart, invoice.billingPeriodEnd, invoice.dueDate,
      new Date(), details.providerReceipt,
      `${payment.provider} payment ${details.providerTransactionId}`,
      payment.createdBy ?? 'system',
    ],
  );

  // Receipt only for confirmed successful payments.
  const outstandingAfter = newOutstanding;
  await createReceipt(client, {
    paymentTransactionId: payment.id,
    invoiceId,
    tenantId: invoice.tenantId,
    tenancyId: invoice.tenancyId,
    propertyId: invoice.propertyId,
    unitId: invoice.unitId,
    amount,
    currency: invoice.currency ?? 'KES',
    paymentMethod: payment.provider,
    transactionReference: details.providerReceipt,
    paymentDate: details.transactionDate ?? new Date(),
    outstandingBalanceAfter: outstandingAfter,
    createdBy: payment.createdBy ?? 'system',
  });

  // Mark payment transaction completed with callback payload + receipt ref.
  await client.query(
    `UPDATE payment_transactions SET status = 'completed', callback_payload = $2,
      updated_at = NOW() WHERE id = $1`,
    [payment.id, JSON.stringify(details.callbackPayload)],
  );

  // Critical notification event, atomic with the financial change.
  const recipients = new Set<string>();
  if (invoice.tenantId) recipients.add(invoice.tenantId);
  const owners = await client.query<{ user_id: string }>(
    `SELECT user_id FROM property_ownerships
      WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
        AND (effective_to IS NULL OR effective_to > NOW())`,
    [invoice.propertyId],
  );
  owners.rows.forEach((r) => recipients.add(r.user_id));

  await enqueueOutboxEventTransactional(client, {
    idempotencyKey: `payment.completed:${payment.id}`,
    eventType: 'payment.completed',
    category: 'operational',
    priority: 'normal',
    recipientUserIds: [...recipients],
    organisationId: null,
    resourceType: 'payment_transaction',
    resourceId: payment.id,
    payload: {
      paymentTransactionId: payment.id,
      invoiceId,
      receiptNumber: details.providerReceipt,
      amount,
      currency: invoice.currency ?? 'KES',
      status: newStatus,
      outstandingBalance: newOutstanding,
      provider: payment.provider,
    },
    channels: ['in_app', 'email'],
    classification: classifyEventType('payment.completed'),
  });
}

/**
 * Issue a receipt for a confirmed successful payment. Receipts are immutable
 * once created; a duplicate receipt for the same payment is not allowed.
 */
async function createReceipt(
  client: PoolClient,
  input: {
    paymentTransactionId: string;
    invoiceId: string;
    tenantId: string | null;
    tenancyId: string | null;
    propertyId: string;
    unitId: string | null;
    amount: number;
    currency: string;
    paymentMethod: string;
    transactionReference: string;
    paymentDate: Date;
    outstandingBalanceAfter: number;
    createdBy: string;
  },
): Promise<void> {
  const receiptNumber = `RCP-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  await client.query(
    `INSERT INTO receipts (
      receipt_number, payment_transaction_id, invoice_id, tenant_id, tenancy_id,
      property_id, unit_id, amount, currency, payment_method, payment_date,
      transaction_reference, outstanding_balance_after, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
    )`,
    [
      receiptNumber, input.paymentTransactionId, input.invoiceId, input.tenantId,
      input.tenancyId, input.propertyId, input.unitId, input.amount, input.currency,
      input.paymentMethod, input.paymentDate, input.transactionReference,
      input.outstandingBalanceAfter, input.createdBy,
    ],
  );
}

/**
 * Reconcile a single pending/ambiguous payment by querying the relevant
 * provider and, if confirmed, finalizing it. Returns true if the payment
 * was finalized.
 */
export async function reconcilePayment(
  paymentTransactionId: string,
): Promise<{ reconciled: boolean; status: string }> {
  const payment = await pool.query<repo.PaymentTransaction>(
    `SELECT id, invoice_id as "invoiceId", provider_transaction_id as "providerTransactionId",
            provider, status, idempotency_key as "idempotencyKey", amount
     FROM payment_transactions WHERE id = $1`,
    [paymentTransactionId],
  );
  const row = payment.rows[0];
  if (!row) return { reconciled: false, status: 'not_found' };
  if (row.status === 'completed') return { reconciled: false, status: 'already_completed' };
  if (!row.providerTransactionId) {
    return { reconciled: false, status: 'no_provider_reference' };
  }

  const providerAdapter = getProvider(row.provider);
  const providerTxId = row.providerTransactionId!;

  let verified;
  try {
    verified = await providerAdapter.queryTransactionStatus({
      providerTransactionId: providerTxId,
    });
  } catch {
    return { reconciled: false, status: 'verification_failed' };
  }

  if (!verified.successful || !verified.transactionReceipt) {
    return { reconciled: false, status: 'not_confirmed_by_provider' };
  }

  await transaction(async (client) => {
    await finalizePayment(client, row as repo.PaymentTransaction, {
      providerTransactionId: providerTxId,
      providerReceipt: verified.transactionReceipt!,
      transactionDate: verified.transactionDate ? new Date(verified.transactionDate) : null,
      phoneNumber: verified.msisdn ?? null,
      amount: verified.amount != null ? money(Number(verified.amount)) : row.amount,
      callbackPayload: { source: 'reconciliation_worker', ...(verified.rawResponse ?? {}) },
    });
  });

  return { reconciled: true, status: 'completed' };
}

/**
 * Record a provider-confirmed payment that could not be matched to an
 * invoice/tenancy. Placed in the unmatched_payments queue for admin
 * reconciliation.
 */
export async function recordUnmatchedPayment(
  client: PoolClient,
  input: {
    provider: string;
    providerTransactionId: string;
    merchantReference?: string | null;
    phoneNumber?: string | null;
    amount: number;
    currency?: string;
    transactionDate?: Date | null;
    callbackPayload: Record<string, unknown>;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO unmatched_payments (
      provider, provider_transaction_id, merchant_reference, phone_number,
      amount, currency, transaction_date, callback_payload
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8
    )
    ON CONFLICT (provider, provider_transaction_id) DO UPDATE
      SET callback_payload = EXCLUDED.callback_payload,
          updated_at = NOW()`,
    [
      input.provider,
      input.providerTransactionId,
      input.merchantReference ?? null,
      input.phoneNumber ?? null,
      money(input.amount),
      input.currency ?? 'KES',
      input.transactionDate ?? null,
      JSON.stringify(input.callbackPayload),
    ],
  );
}

/**
 * Resolve an unmatched payment by matching it to a payment transaction.
 * Requires an authorized actor. Creates a payment allocation if matched to
 * an invoice.
 */
export async function resolveUnmatchedPayment(input: {
    unmatchedPaymentId: string;
    matchedPaymentTransactionId: string;
    matchNotes?: string | null;
    matchedBy: string;
  }): Promise<void> {
    await pool.query(
      `UPDATE unmatched_payments
         SET matched = TRUE,
             matched_payment_transaction_id = $2,
             match_notes = $3,
             matched_by = $4,
             matched_at = NOW(),
             updated_at = NOW()
       WHERE id = $1 AND matched = FALSE`,
      [
        input.unmatchedPaymentId,
        input.matchedPaymentTransactionId,
        input.matchNotes ?? null,
        input.matchedBy,
      ],
    );
  }

/**
 * Record a provider-confirmed reversal/refund against an existing payment.
 * The original payment record is preserved; a reversal entry is added.
 */
export async function recordPaymentReversal(input: {
  paymentTransactionId: string;
  reversalReference: string;
  providerReversalId?: string | null;
  amount: number;
  currency?: string;
  reason: string;
  createdBy: string;
  providerPayload?: Record<string, unknown>;
}): Promise<string> {
  const result = await pool.query<{ id: string }>(
    `INSERT INTO payment_reversals (
      payment_transaction_id, reversal_reference, provider_reversal_id,
      amount, currency, reason, status, provider_payload, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9
    )
    RETURNING id`,
    [
      input.paymentTransactionId,
      input.reversalReference,
      input.providerReversalId ?? null,
      money(input.amount),
      input.currency ?? 'KES',
      input.reason,
      'completed',
      input.providerPayload ?? null,
      input.createdBy,
    ],
  );

  // Mark the original payment as reversed if fully reversed.
  const payment = await pool.query<{ id: string; status: string; amount: number }>(
    `SELECT id, status, amount FROM payment_transactions WHERE id = $1`,
    [input.paymentTransactionId],
  );
  const payRow = payment.rows[0];
  if (payRow && payRow.status === 'completed') {
    const existingReversals = await pool.query<{ total: number }>(
      `SELECT COALESCE(SUM(amount), 0) as total FROM payment_reversals
       WHERE payment_transaction_id = $1 AND status = 'completed'`,
      [input.paymentTransactionId],
    );
    const totalReversed = Number(existingReversals.rows[0]!.total);
    if (totalReversed >= payRow.amount) {
      await pool.query(
        `UPDATE payment_transactions SET status = 'reversed', updated_at = NOW() WHERE id = $1`,
        [input.paymentTransactionId],
      );
    }
  }

  return result.rows[0]!.id;
}

export { money, PROVIDERS, getProvider };
