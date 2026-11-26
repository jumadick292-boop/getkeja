// Zod validation for the payments module (M-Pesa STK Push, receipts,
// statements, deposits). All monetary amounts are exact KES values.

import { z } from 'zod';

const uuid = z.string().uuid();

export const initiateMpesaPaymentSchema = z.object({
  invoiceId: uuid,
  amount: z.coerce.number().positive(),
  phoneNumber: z.string().trim().min(9).max(15).optional(),
  idempotencyKey: z.string().trim().min(1).max(255).optional(),
  provider: z.enum(['mpesa', 'mpesa_paybill', 'mpesa_till', 'pesapal']).optional().default('mpesa'),
  merchantReference: z.string().trim().min(1).max(255).optional(),
});

export const mpesaPaymentStatusQuerySchema = z.object({
  checkoutRequestId: z.string().trim().min(1),
});

export const receiptQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
  status: z.enum(['pending', 'completed', 'failed', 'reversed', 'refunded']).optional(),
});

export const statementQuerySchema = z.object({
  fromDate: z.string().date().optional(),
  toDate: z.string().date().optional(),
});

export type InitiateMpesaPaymentInput = z.infer<typeof initiateMpesaPaymentSchema>;
export type ReceiptQueryInput = z.infer<typeof receiptQuerySchema>;
export type StatementQueryInput = z.infer<typeof statementQuerySchema>;
