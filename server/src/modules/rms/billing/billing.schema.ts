// Zod validation schemas for the recurring billing API (Task 14.1).
import { z } from 'zod';

const uuid = z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, 'Invalid UUID');
const currency = z.string().regex(/^[A-Z]{3}$/, 'Currency must be a 3-letter ISO code');
const billingFrequencySchema = z.enum(['monthly', 'quarterly', 'annual']);

export const createScheduleSchema = z.object({
  propertyId: uuid,
  unitId: uuid,
  tenancyId: uuid,
  tenantId: uuid,
  leaseAgreementId: uuid.optional().nullable(),
  rentAmount: z.coerce.number().positive(),
  currency: currency.default('KES'),
  billingFrequency: billingFrequencySchema.default('monthly'),
  billingDay: z.coerce.number().int().min(1).max(28).default(1),
  firstBillingDate: z.string().date(),
  dueDayOfMonth: z.coerce.number().int().min(1).max(28).optional().nullable(),
  gracePeriodDays: z.coerce.number().int().min(0).max(60).default(0),
  activate: z.boolean().default(false),
});

export const updateScheduleSchema = z.object({
  rentAmount: z.coerce.number().positive().optional(),
  currency: currency.optional(),
  billingDay: z.coerce.number().int().min(1).max(28).optional(),
  dueDayOfMonth: z.coerce.number().int().min(1).max(28).optional().nullable(),
  gracePeriodDays: z.coerce.number().int().min(0).max(60).optional(),
  effectiveDate: z.string().date().optional(),
  notes: z.string().max(2000).optional().nullable(),
});

export const scheduleIdParamSchema = z.object({ scheduleId: uuid });

export const scheduleQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  tenantId: uuid.optional(),
  tenancyId: uuid.optional(),
  status: z.enum(['pending', 'active', 'suspended', 'cancelled']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const previewInvoiceSchema = z.object({
  billingPeriodStart: z.string().date().optional(),
});

export const invoiceQuerySchema = z.object({
  propertyId: uuid.optional(),
  unitId: uuid.optional(),
  tenantId: uuid.optional(),
  tenancyId: uuid.optional(),
  billingScheduleId: uuid.optional(),
  status: z.enum(['draft', 'issued', 'sent', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded', 'void']).optional(),
  source: z.enum(['manual', 'recurring']).optional(),
  fromDate: z.string().date().optional(),
  toDate: z.string().date().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const invoiceIdParamSchema = z.object({ invoiceId: uuid });

export const voidInvoiceSchema = z.object({
  reason: z.string().trim().min(1).max(500),
});

export type CreateScheduleInput = z.infer<typeof createScheduleSchema>;
export type UpdateScheduleInput = z.infer<typeof updateScheduleSchema>;
export type ScheduleQueryInput = z.infer<typeof scheduleQuerySchema>;
export type InvoiceQueryInput = z.infer<typeof invoiceQuerySchema>;
export type VoidInvoiceInput = z.infer<typeof voidInvoiceSchema>;