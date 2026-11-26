// Payment routes — mounted at /api/v1/payments.
//
// Provider callbacks (M-Pesa, Pesapal, Paybill, Till) are public webhooks
// (no auth). All other endpoints require authentication and are scoped to
// the caller's tenant/tenancy or landlord ownership.

import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import {
  initiatePayment,
  mpesaCallback,
  pesapalCallback,
  pesapalIpn,
  paybillCallback,
  tillCallback,
  getPaymentStatus,
  getProviders,
  reconcilePayment as reconcilePaymentController,
  listReceipts,
  getReceipt,
  downloadReceipt,
  getStatement,
  listDeposits,
  listUnmatchedPayments,
  resolveUnmatchedPayment,
  recordReversal,
  getLandlordDashboard,
} from './payment.controller.js';
import {
  initiateMpesaPaymentSchema,
  receiptQuerySchema,
  statementQuerySchema,
} from './payments.schema.js';

export function createPaymentsRouter(): Router {
  const router = Router();

  const paymentRateLimit = createRateLimiter({
    windowMs: 60_000,
    max: 30,
    keyPrefix: 'payments',
    identifierField: 'userId',
    ipMax: 100,
  });

  // ---- Payment initiation (tenant-initiated, any provider) ----
  router.post(
    '/initiate',
    requireAuth,
    paymentRateLimit,
    validate(initiateMpesaPaymentSchema),
    initiatePayment,
  );

  // Backward-compatible alias for M-Pesa STK Push initiation.
  router.post(
    '/mpesa/initiate',
    requireAuth,
    paymentRateLimit,
    validate(initiateMpesaPaymentSchema),
    initiatePayment,
  );

  // ---- Available payment providers (tenant-facing configuration) ----
  router.get(
    '/providers',
    requireAuth,
    getProviders,
  );

  // ---- M-Pesa callbacks (public webhooks, no auth) ----
  router.post('/mpesa/callback', mpesaCallback);
  router.post('/paybill/callback', paybillCallback);
  router.post('/till/callback', tillCallback);

  // ---- Pesapal callbacks and IPN (public webhooks, no auth) ----
  router.post('/pesapal/callback', pesapalCallback);
  router.post('/pesapal/ipn', pesapalIpn);

  // ---- Payment status (tenant-pollable, idempotent) ----
  router.get(
    '/status/:providerTransactionId',
    requireAuth,
    getPaymentStatus,
  );

  // Backward-compatible alias for M-Pesa status polling.
  router.get(
    '/mpesa/status/:checkoutRequestId',
    requireAuth,
    getPaymentStatus,
  );

  // ---- Reconciliation (tenant-initiated for own payments) ----
  router.post(
    '/reconcile/:paymentTransactionId',
    requireAuth,
    reconcilePaymentController,
  );

  // ---- Receipts ----
  router.get(
    '/receipts',
    requireAuth,
    validate(receiptQuerySchema, 'query'),
    listReceipts,
  );
  router.get(
    '/receipts/:receiptId',
    requireAuth,
    getReceipt,
  );
  router.get(
    '/receipts/:receiptId/download',
    requireAuth,
    downloadReceipt,
  );

  // ---- Tenant statement ----
  router.get(
    '/statement',
    requireAuth,
    validate(statementQuerySchema, 'query'),
    getStatement,
  );

  // ---- Deposits ----
  router.get('/deposits', requireAuth, listDeposits);

  // ---- Unmatched payments (admin/landlord) ----
  router.get(
    '/unmatched',
    requireAuth,
    listUnmatchedPayments,
  );
  router.post(
    '/unmatched/:unmatchedPaymentId/resolve',
    requireAuth,
    resolveUnmatchedPayment,
  );

  // ---- Reversals/refunds ----
  router.post('/reversals', requireAuth, recordReversal);

  // ---- Landlord financial dashboard ----
  router.get(
    '/landlord/dashboard',
    requireAuth,
    getLandlordDashboard,
  );

  return router;
}
