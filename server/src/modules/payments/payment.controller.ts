// Tenant-facing payment controller: multi-provider payment initiation,
// callback handling, payment status, receipts, statements, deposits.
//
// All financial reads are scoped to the authenticated tenant's authorized
// tenancy. Provider callbacks are public webhooks (no auth) and are treated
// as untrusted until verified by the payment service.

import type { Request, Response } from 'express';
import {
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import * as tenantRepo from '../tenant/tenant.repository.js';
import * as landlordRepo from '../landlord/landlord.repository.js';
import * as authz from '../auth/authorization.service.js';
import * as paymentService from './payment.service.js';
import {
  mpesaDarajaAdapter,
  mpesaPaybillAdapter,
  mpesaTillAdapter,
  getMpesaConfig,
} from './mpesa.service.js';
import { pesapalAdapter } from './pesapal.service.js';
import { pool } from '../../db/pool.js';
import {
  initiateMpesaPaymentSchema,
  receiptQuerySchema,
  statementQuerySchema,
} from './payments.schema.js';
import { SignJWT } from 'jose';
import { loadEnv } from '../../config/env.js';

const env = loadEnv();
const RECEIPT_URL_SECRET = env.JWT_PRIVATE_KEY ?? 'receipt-download-secret';
const RECEIPT_URL_TTL = 900; // 15 minutes

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

/**
 * Resolve the authenticated tenant and their active tenancy, enforcing
 * tenancy access.
 */
async function resolveTenantTenancy(
  req: AuthenticatedRequest,
): Promise<{
  userId: string;
  tenant: tenantRepo.TenantRecord;
  activeTenancy: tenantRepo.TenancyRecord;
}> {
  const userId = assertAuth(req);
  const tenant = await tenantRepo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }
  if (!tenant.tenancyId) {
    throw new ForbiddenError('No active tenancy found for this tenant');
  }
  const activeTenancy = await tenantRepo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy) {
    throw new ForbiddenError('No active tenancy found for this tenant');
  }
  const access = await authz.canAccessTenancy(userId, activeTenancy.id);
  if (!access.allowed) {
    throw new ForbiddenError(access.reason);
  }
  return { userId, tenant, activeTenancy };
}

/**
 * Resolve the authenticated user and verify they are an active owner of a
 * property (for landlord financial views).
 */
async function resolveLandlordProperty(
  req: AuthenticatedRequest,
  propertyId: string,
): Promise<{ userId: string }> {
  const userId = assertAuth(req);
  const ownership = await pool.query<{ user_id: string }>(
    `SELECT user_id FROM property_ownerships
     WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
       AND (effective_to IS NULL OR effective_to > NOW())`,
    [propertyId],
  );
  if (ownership.rows.length === 0 || ownership.rows[0]!.user_id !== userId) {
    throw new ForbiddenError('You are not an owner of this property');
  }
  return { userId };
}

/**
 * GET /api/v1/payments/providers
 * Return the list of configured payment providers and their configuration
 * for the tenant-facing payment selection UI. Provider credentials and
 * callback URLs are never exposed.
 */
export async function getProviders(_req: Request, res: Response) {
  const providers: Array<{
    id: string;
    name: string;
    type: 'stk_push' | 'manual' | 'hosted_checkout';
    displayName: string;
    requiresPhoneNumber: boolean;
    businessShortCode?: string;
    accountReferenceLabel?: string;
    accountReferencePlaceholder?: string;
    description: string;
    instruction?: string;
  }> = [];

  // M-Pesa STK Push (Daraja) — server-initiated, requires phone number.
  try {
    getMpesaConfig();
    providers.push({
      id: mpesaDarajaAdapter.provider,
      name: mpesaDarajaAdapter.displayName,
      type: 'stk_push',
      displayName: mpesaDarajaAdapter.displayName,
      requiresPhoneNumber: true,
      description: 'Pay directly from your M-Pesa phone using STK Push',
      instruction: 'Enter your M-Pesa registered phone number. You will receive an STK Push prompt on your phone to enter your PIN.',
    });
  } catch {
    // M-Pesa not configured; skip this provider.
  }

  // M-Pesa Paybill (C2B) — customer-initiated, manual payment.
  try {
    const config = getMpesaConfig();
    providers.push({
      id: mpesaPaybillAdapter.provider,
      name: mpesaPaybillAdapter.displayName,
      type: 'manual',
      displayName: mpesaPaybillAdapter.displayName,
      requiresPhoneNumber: false,
      businessShortCode: config.shortcode,
      accountReferenceLabel: 'Account Reference',
      accountReferencePlaceholder: 'Invoice number or tenant reference',
      description: 'Pay via M-Pesa Paybill using your phone\'s STK menu',
      instruction: `Go to M-Pesa → Lipa na M-Pesa → Pay Bill. Business number: ${config.shortcode}. Account reference: use your invoice number. Amount: as shown on the invoice.`,
    });
  } catch {
    // M-Pesa not configured; skip this provider.
  }

  // M-Pesa Till / Buy Goods (C2B) — customer-initiated, manual payment.
  try {
    const config = getMpesaConfig();
    providers.push({
      id: mpesaTillAdapter.provider,
      name: mpesaTillAdapter.displayName,
      type: 'manual',
      displayName: mpesaTillAdapter.displayName,
      requiresPhoneNumber: false,
      businessShortCode: config.shortcode,
      accountReferenceLabel: 'Account Reference',
      accountReferencePlaceholder: 'Invoice number or tenant reference',
      description: 'Pay via M-Pesa Buy Goods Till',
      instruction: `Go to M-Pesa → Lipa na M-Pesa → Buy Goods (Till). Till number: ${config.shortcode}. Account reference: use your invoice number. Amount: as shown on the invoice.`,
    });
  } catch {
    // M-Pesa not configured; skip this provider.
  }

  // Pesapal — hosted checkout redirect.
  try {
    const pesapalEnv = (process.env.PESAPAL_ENV ?? 'sandbox') as string;
    if (process.env.PESAPAL_CONSUMER_KEY && process.env.PESAPAL_CONSUMER_SECRET) {
      providers.push({
        id: pesapalAdapter.provider,
        name: 'Pesapal',
        type: 'hosted_checkout',
        displayName: 'Pesapal',
        requiresPhoneNumber: false,
        description: 'Pay via Pesapal hosted checkout (card, mobile money, bank)',
        instruction: 'You will be redirected to a secure Pesapal checkout page to complete your payment.',
      });
    }
  } catch {
    // Pesapal not configured; skip this provider.
  }

  res.json({ success: true, data: { providers } });
}

/**
 * POST /api/v1/payments/initiate
 * Tenant initiates a payment for an invoice through a configured provider.
 */
export async function initiatePayment(
  req: AuthenticatedRequest,
  res: Response,
) {
  const { tenant, activeTenancy } = await resolveTenantTenancy(req);
  const data = initiateMpesaPaymentSchema.parse(req.body);

  const invoice = await landlordRepo.findInvoiceById(data.invoiceId);
  if (!invoice) throw new NotFoundError('Invoice not found');
  if (invoice.tenancyId !== activeTenancy.id) {
    throw new ForbiddenError('Invoice does not belong to your active tenancy');
  }

  const idempotencyKey =
    data.idempotencyKey ||
    `pay:${tenant.id}:${data.invoiceId}:${Date.now()}`;

  const result = await paymentService.initiatePayment({
    invoiceId: data.invoiceId,
    tenantId: tenant.id,
    amount: data.amount,
    phoneNumber: data.phoneNumber,
    idempotencyKey,
    createdBy: assertAuth(req),
    provider: data.provider,
    merchantReference: data.merchantReference,
  });

  res.status(201).json({
    success: true,
    data: {
      status: result.status,
      paymentTransactionId: result.paymentTransactionId,
      providerTransactionId: result.providerTransactionId,
      checkoutRequestId: result.providerTransactionId,
      merchantRequestId: result.merchantRequestId,
      checkoutUrl: result.checkoutUrl,
      amount: result.amount,
      invoiceId: result.invoiceId,
      provider: result.provider,
      message:
        'Complete the payment through your selected channel. Confirmation may take a short time.',
    },
  });
}

/**
 * POST /api/v1/payments/mpesa/callback
 * M-Pesa STK Push / Paybill / Till webhook. Public (no auth).
 */
export async function mpesaCallback(req: Request, res: Response) {
  const result = await paymentService.processProviderCallback(
    req.body,
    'mpesa',
  );
  res.status(200).json({ status: result.status });
}

/**
 * POST /api/v1/payments/pesapal/callback
 * Pesapal callback/webhook. Public (no auth).
 */
export async function pesapalCallback(req: Request, res: Response) {
  const result = await paymentService.processProviderCallback(
    req.body,
    'pesapal',
  );
  res.status(200).json({ status: result.status });
}

/**
 * POST /api/v1/payments/pesapal/ipn
 * Pesapal Instant Payment Notification. Public (no auth).
 */
export async function pesapalIpn(req: Request, res: Response) {
  const result = await paymentService.processProviderCallback(
    req.body,
    'pesapal',
  );
  res.status(200).json({ status: result.status });
}

/**
 * POST /api/v1/payments/paybill/callback
 * M-Pesa Paybill C2B confirmation/validation. Public (no auth).
 */
export async function paybillCallback(req: Request, res: Response) {
  const result = await paymentService.processProviderCallback(
    req.body,
    'mpesa_paybill',
  );
  res.status(200).json({ status: result.status });
}

/**
 * POST /api/v1/payments/till/callback
 * M-Pesa Buy Goods Till payment notification. Public (no auth).
 */
export async function tillCallback(req: Request, res: Response) {
  const result = await paymentService.processProviderCallback(
    req.body,
    'mpesa_till',
  );
  res.status(200).json({ status: result.status });
}

/**
 * GET /api/v1/payments/status/:providerTransactionId
 * Check the status of a payment initiation (safe to poll).
 */
export async function getPaymentStatus(
  req: AuthenticatedRequest,
  res: Response,
) {
  const { tenant } = await resolveTenantTenancy(req);
  const param = req.params.providerTransactionId ?? req.params.checkoutRequestId;
  const ptId = typeof param === 'string' ? param : Array.isArray(param) ? param[0] : undefined;
  if (!ptId) {
    throw new NotFoundError('Payment reference not found');
  }

  const payment = await pool.query(
    `SELECT id, transaction_reference as "transactionReference",
            provider_transaction_id as "providerTransactionId", tenant_id as "tenantId", amount, currency,
            provider, status, failure_reason as "failureReason",
            callback_payload as "callbackPayload", created_at as "createdAt",
            updated_at as "updatedAt"
     FROM payment_transactions
     WHERE provider_transaction_id = $1`,
    [ptId],
  );
  const row = payment.rows[0];
  if (!row) throw new NotFoundError('Payment not found');
  if (row.tenantId !== tenant.id) {
    throw new ForbiddenError('You can only view your own payments');
  }

  res.json({
    success: true,
    data: {
      paymentTransactionId: row.id,
      providerTransactionId: row.providerTransactionId,
      checkoutRequestId: row.providerTransactionId,
      status: row.status,
      amount: row.amount,
      currency: row.currency,
      provider: row.provider,
      transactionReference: row.transactionReference,
      providerReceipt: row.providerTransactionId,
      failureReason: row.failureReason,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    },
  });
}

/**
 * POST /api/v1/payments/reconcile/:paymentTransactionId
 * Trigger reconciliation for a pending payment (tenant-initiated).
 */
export async function reconcilePayment(
  req: AuthenticatedRequest,
  res: Response,
) {
  const { tenant } = await resolveTenantTenancy(req);
  const { paymentTransactionId } = req.params;
  const pmtId = typeof paymentTransactionId === 'string' ? paymentTransactionId : Array.isArray(paymentTransactionId) ? paymentTransactionId[0] : undefined;

  const payment = await pool.query<{ id: string; tenant_id: string }>(
    `SELECT id, tenant_id FROM payment_transactions WHERE id = $1`,
    [pmtId],
  );
  const row = payment.rows[0];
  if (!row) throw new NotFoundError('Payment not found');
  if (row.tenant_id !== tenant.id) {
    throw new ForbiddenError('You can only reconcile your own payments');
  }

  const result = await paymentService.reconcilePayment(pmtId!);
  res.json({ success: true, data: result });
}

/**
 * GET /api/v1/payments/receipts
 * List receipts for the authenticated tenant.
 */
export async function listReceipts(req: AuthenticatedRequest, res: Response) {
  const { tenant } = await resolveTenantTenancy(req);
  const query = receiptQuerySchema.parse(req.query);

  const result = await pool.query(
    `SELECT r.id, r.receipt_number as "receiptNumber",
            r.payment_transaction_id as "paymentTransactionId",
            r.invoice_id as "invoiceId", r.amount, r.currency,
            r.payment_method as "paymentMethod", r.payment_date as "paymentDate",
            r.transaction_reference as "transactionReference",
            r.outstanding_balance_after as "outstandingBalanceAfter",
            r.created_at as "createdAt"
     FROM receipts r
     WHERE r.tenant_id = $1
     ORDER BY r.created_at DESC
     LIMIT $2 OFFSET $3`,
    [tenant.id, query.limit, query.offset],
  );

  res.json({ success: true, data: result.rows });
}

/**
 * GET /api/v1/payments/receipts/:receiptId
 * Get a single receipt (tenant owner).
 */
export async function getReceipt(req: AuthenticatedRequest, res: Response) {
  const { tenant } = await resolveTenantTenancy(req);
  const receiptId = req.params.receiptId;
  if (!receiptId) throw new NotFoundError('Receipt not found');

  const receipt = await pool.query(
    `SELECT r.id, r.receipt_number as "receiptNumber",
            r.payment_transaction_id as "paymentTransactionId",
            r.invoice_id as "invoiceId", r.tenant_id as "tenantId",
            r.tenancy_id as "tenancyId", r.property_id as "propertyId",
            r.unit_id as "unitId", r.amount, r.currency,
            r.payment_method as "paymentMethod", r.payment_date as "paymentDate",
            r.transaction_reference as "transactionReference",
            r.outstanding_balance_after as "outstandingBalanceAfter",
            r.created_at as "createdAt"
     FROM receipts r WHERE r.id = $1`,
    [receiptId],
  );
  const row = receipt.rows[0];
  if (!row) throw new NotFoundError('Receipt not found');
  if (row.tenantId !== tenant.id) {
    throw new ForbiddenError('You can only view your own receipts');
  }

  res.json({ success: true, data: row });
}

/**
 * GET /api/v1/payments/receipts/:receiptId/download
 * Authorized signed URL to download a receipt.
 */
export async function downloadReceipt(req: AuthenticatedRequest, res: Response) {
  const { tenant } = await resolveTenantTenancy(req);
  const receiptId = req.params.receiptId;
  if (!receiptId) throw new NotFoundError('Receipt not found');

  const receipt = await pool.query(
    `SELECT id, tenant_id as "tenantId" FROM receipts WHERE id = $1`,
    [receiptId],
  );
  const row = receipt.rows[0];
  if (!row) throw new NotFoundError('Receipt not found');
  if (row.tenantId !== tenant.id) {
    throw new ForbiddenError('You can only download your own receipts');
  }

  const now = Math.floor(Date.now() / 1000);
  const token = await new SignJWT({
    receiptId,
    userId: tenant.id,
    purpose: 'download',
    iat: now,
    exp: now + RECEIPT_URL_TTL,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt(now)
    .setExpirationTime(now + RECEIPT_URL_TTL)
    .sign(new TextEncoder().encode(RECEIPT_URL_SECRET));

  const baseUrl = env.EMAIL_BASE_URL ?? 'http://localhost:3000';
  const url = `${baseUrl}/api/v1/payments/receipts/${receiptId}/signed?token=${token}`;

  res.json({ success: true, data: { url, expiresInSeconds: RECEIPT_URL_TTL } });
}

/**
 * GET /api/v1/payments/statement
 * Tenant statement reconciling to the rent ledger: opening balance, charges,
 * payments, closing balance. Supports all providers.
 */
export async function getStatement(req: AuthenticatedRequest, res: Response) {
  const { tenant, activeTenancy } = await resolveTenantTenancy(req);
  const query = statementQuerySchema.parse(req.query);

  const fromDate = query.fromDate
    ? new Date(query.fromDate)
    : new Date(activeTenancy.startDate ?? new Date());
  const toDate = query.toDate ? new Date(query.toDate) : new Date();

  // Charges: invoices issued for the tenancy/unit in the period.
  const charges = await pool.query(
    `SELECT id, invoice_number as "invoiceNumber", status, total_amount as "amount",
            due_date as "dueDate", billing_period_start as "billingPeriodStart",
            billing_period_end as "billingPeriodEnd", amount_paid as "amountPaid",
            amount_outstanding as "amountOutstanding"
     FROM invoices
     WHERE tenancy_id = $1 AND billing_period_end >= $2 AND billing_period_start <= $3
     ORDER BY billing_period_end`,
    [activeTenancy.id, fromDate, toDate],
  );

  // Payments: completed payment transactions for the tenancy in the period (all providers).
  const payments = await pool.query(
    `SELECT pt.id, pt.transaction_reference as "reference", pt.amount,
            pt.currency, pt.status, pt.payment_date as "paymentDate",
            pt.provider_transaction_id as "providerReceipt",
            pt.provider, i.invoice_number as "invoiceNumber"
     FROM payment_transactions pt
     LEFT JOIN invoices i ON i.id = pt.invoice_id
     WHERE pt.tenant_id = $1 AND pt.status = 'completed'
       AND pt.payment_date >= $2 AND pt.payment_date <= $3
     ORDER BY pt.payment_date`,
    [tenant.id, fromDate, toDate],
  );

  const totalCharges = charges.rows.reduce(
    (sum: number, r: any) => sum + Number(r.amount), 0,
  );
  const totalPaid = payments.rows.reduce(
    (sum: number, r: any) => sum + Number(r.amount), 0,
  );
  const closingBalance = Math.round((totalCharges - totalPaid) * 100) / 100;

  res.json({
    success: true,
    data: {
      tenantId: tenant.id,
      tenancyId: activeTenancy.id,
      fromDate,
      toDate,
      openingBalance: Math.round(
        charges.rows.reduce((sum: number, r: any) => sum + Number(r.amountPaid), 0) * 100,
      ) / 100,
      totalCharges,
      totalPaid,
      closingBalance,
      currency: 'KES',
      charges: charges.rows,
      payments: payments.rows,
    },
  });
}

/**
 * GET /api/v1/payments/deposits
 * Deposit information for the authenticated tenant.
 */
export async function listDeposits(req: AuthenticatedRequest, res: Response) {
  const { tenant, activeTenancy } = await resolveTenantTenancy(req);

  const deposits = await pool.query(
    `SELECT id, expected_amount as "expectedAmount",
            received_amount as "receivedAmount",
            outstanding_amount as "outstandingAmount", currency, status,
            deposit_scheme_reference as "depositSchemeReference",
            held_by as "heldBy", refund_due_date as "refundDueDate",
            refund_amount as "refundAmount", refunded_at as "refundedAt",
            created_at as "createdAt", updated_at as "updatedAt"
     FROM tenant_deposits
     WHERE tenant_id = $1
     ORDER BY created_at DESC`,
    [tenant.id],
  );

  const depositIds = deposits.rows.map((r) => r.id);
  let transactions: any[] = [];
  if (depositIds.length > 0) {
    const tx = await pool.query(
      `SELECT id, deposit_id as "depositId",
              transaction_type as "transactionType", amount, currency,
              transaction_date as "transactionDate", reference, notes,
              created_at as "createdAt"
       FROM deposit_transactions
       WHERE deposit_id = ANY($1)
       ORDER BY transaction_date DESC`,
      [depositIds],
    );
    transactions = tx.rows;
  }

  res.json({ success: true, data: { deposits: deposits.rows, transactions } });
}

/**
 * GET /api/v1/payments/unmatched
 * List unmatched provider payments (admin/landlord only).
 */
export async function listUnmatchedPayments(
  req: AuthenticatedRequest,
  res: Response,
) {
  const userId = assertAuth(req);

  // Only platform financial administrators can view unmatched payments.
  const hasFinancePerm = await authz.hasPermission(userId, 'finance.unmatched.manage');
  if (!hasFinancePerm) {
    throw new ForbiddenError('Insufficient permissions to view unmatched payments');
  }

  // Only authorized users (landlords/admins) can view unmatched payments.
  const result = await pool.query(
    `SELECT id, provider, provider_transaction_id as "providerTransactionId",
            merchant_reference as "merchantReference", phone_number as "phoneNumber",
            amount, currency, transaction_date as "transactionDate",
            matched, match_notes as "matchNotes", matched_by as "matchedBy",
            matched_at as "matchedAt", created_at as "createdAt"
     FROM unmatched_payments
     ORDER BY created_at DESC
     LIMIT 100`,
    [],
  );

  res.json({ success: true, data: result.rows });
}

/**
 * POST /api/v1/payments/unmatched/:unmatchedPaymentId/resolve
 * Resolve an unmatched payment by matching it to a payment transaction.
 */
export async function resolveUnmatchedPayment(
  req: AuthenticatedRequest,
  res: Response,
) {
  const userId = assertAuth(req);

  // Only platform financial administrators can resolve unmatched payments.
  const hasFinancePerm = await authz.hasPermission(userId, 'finance.unmatched.manage');
  if (!hasFinancePerm) {
    throw new ForbiddenError('Insufficient permissions to resolve unmatched payments');
  }

  const { unmatchedPaymentId } = req.params;
  const umId = typeof unmatchedPaymentId === 'string' ? unmatchedPaymentId : Array.isArray(unmatchedPaymentId) ? unmatchedPaymentId[0] : undefined;
  const { matchedPaymentTransactionId, matchNotes } = req.body;

  if (!matchedPaymentTransactionId) {
    throw new ValidationError('matchedPaymentTransactionId is required');
  }
  if (!umId) {
    throw new NotFoundError('Unmatched payment not found');
  }

  await paymentService.resolveUnmatchedPayment({
    unmatchedPaymentId: umId,
    matchedPaymentTransactionId,
    matchNotes: matchNotes ?? null,
    matchedBy: userId,
  });

  res.json({ success: true });
}

/**
 * POST /api/v1/payments/reversals
 * Record a provider-confirmed reversal/refund against a payment.
 */
export async function recordReversal(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);

  // Only platform financial administrators can record reversals/refunds.
  const hasFinancePerm = await authz.hasPermission(userId, 'finance.reversals.manage');
  if (!hasFinancePerm) {
    throw new ForbiddenError('Insufficient permissions to record reversals');
  }

  const {
    paymentTransactionId,
    reversalReference,
    amount,
    reason,
    providerReversalId,
    providerPayload,
  } = req.body;

  if (!paymentTransactionId || !reversalReference || !amount || !reason) {
    throw new ValidationError(
      'paymentTransactionId, reversalReference, amount and reason are required',
    );
  }

  const id = await paymentService.recordPaymentReversal({
    paymentTransactionId,
    reversalReference,
    providerReversalId: providerReversalId ?? null,
    amount: Number(amount),
    reason,
    createdBy: userId,
    providerPayload: providerPayload ?? null,
  });

  res.status(201).json({ success: true, data: { id } });
}

/**
 * GET /api/v1/payments/landlord/dashboard
 * Landlord financial dashboard: collections, outstanding, arrears by property.
 */
export async function getLandlordDashboard(
  req: AuthenticatedRequest,
  res: Response,
) {
  const userId = assertAuth(req);

  const properties = await pool.query(
    `SELECT p.id, p.title, p.address, p.city, p.county,
            po.ownership_share as "ownershipShare"
     FROM properties p
     JOIN property_ownerships po ON po.property_id = p.id
     WHERE po.user_id = $1 AND po.status = 'active'
       AND (po.effective_to IS NULL OR po.effective_to > NOW())
     ORDER BY p.created_at DESC`,
    [userId],
  );

  const propertySummaries = await Promise.all(
    properties.rows.map(async (prop: any) => {
      // Invoiced (total amounts of all invoices for this property).
      const invoiced = await pool.query<{ total: string }>(
        `SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE property_id = $1`,
        [prop.id],
      );

      // Collected (sum of completed payments for this property).
      const collected = await pool.query<{ total: string }>(
        `SELECT COALESCE(SUM(amount), 0) as total FROM payment_transactions
         WHERE property_id = $1 AND status = 'completed'`,
        [prop.id],
      );

      // Outstanding (sum of amount_outstanding across all invoices).
      const outstanding = await pool.query<{ total: string }>(
        `SELECT COALESCE(SUM(amount_outstanding), 0) as total FROM invoices WHERE property_id = $1`,
        [prop.id],
      );

      // Arrears (overdue invoices).
      const arrears = await pool.query<{ total: string }>(
        `SELECT COALESCE(SUM(amount_outstanding), 0) as total FROM invoices
         WHERE property_id = $1 AND status = 'overdue'`,
        [prop.id],
      );

      // Deposits held.
      const deposits = await pool.query<{ total: string }>(
        `SELECT COALESCE(SUM(received_amount), 0) as total FROM tenant_deposits
         WHERE property_id = $1`,
        [prop.id],
      );

      // Unmatched payments attributable to this property (via payment transactions).
      const unmatched = await pool.query<{ total: string; count: string }>(
        `SELECT COALESCE(SUM(up.amount), 0) as total, COUNT(*) as count
         FROM unmatched_payments up
         LEFT JOIN payment_transactions pt ON pt.id = up.matched_payment_transaction_id
         WHERE (pt.property_id = $1 OR up.provider_transaction_id ILIKE $2)
           AND up.matched = FALSE`,
        [prop.id, `%${prop.id}%`],
      );

      return {
        propertyId: prop.id,
        title: prop.title,
        address: prop.address,
        city: prop.city,
        county: prop.county,
        ownershipShare: prop.ownershipshare,
        invoiced: Number(invoiced.rows[0]!.total),
        collected: Number(collected.rows[0]!.total),
        outstanding: Number(outstanding.rows[0]!.total),
        arrears: Number(arrears.rows[0]!.total),
        depositsHeld: Number(deposits.rows[0]!.total),
        unmatchedPayments: {
          total: Number(unmatched.rows[0]!.total),
          count: Number(unmatched.rows[0]!.count),
        },
      };
    }),
  );

  const totals = propertySummaries.reduce(
    (acc: any, p: any) => ({
      invoiced: acc.invoiced + p.invoiced,
      collected: acc.collected + p.collected,
      outstanding: acc.outstanding + p.outstanding,
      arrears: acc.arrears + p.arrears,
      depositsHeld: acc.depositsHeld + p.depositsHeld,
    }),
    { invoiced: 0, collected: 0, outstanding: 0, arrears: 0, depositsHeld: 0 },
  );

  res.json({
    success: true,
    data: {
      properties: propertySummaries,
      totals,
    },
  });
}
