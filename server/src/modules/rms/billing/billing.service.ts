// Recurring billing service (Task 14.1).
//
// Orchestrates schedule lifecycle, rent-term changes, invoice voiding and
// previews. Authorization is enforced here (resource-scoped) in addition to the
// route-level requireAuth. Domain events are emitted through the transactional
// outbox with stable idempotency keys so retries never duplicate notifications.
import { ForbiddenError, NotFoundError, ValidationError, ConflictError } from '../../../shared/errors.js';
import * as authz from '../../auth/authorization.service.js';
import { findPropertyOwnerships, findPropertyAssignments } from '../../auth/auth.repository.js';
import { transaction } from '../../../db/tx.js';
import { enqueueOutboxEventTransactional } from '../../auth/transactional-outbox.service.js';
import * as repo from './billing.repository.js';
import type { BillingFrequency } from './billing.calculations.js';
import type { CreateScheduleInput, UpdateScheduleInput } from './billing.schema.js';

async function assertCanManageProperty(userId: string, propertyId: string): Promise<void> {
  const basic = await authz.canAccessProperty(userId, propertyId);
  if (!basic.allowed) throw new ForbiddenError(basic.reason);

  const ownerships = await findPropertyOwnerships(propertyId);
  const isOwner = ownerships.some((o) => o.userId === userId && o.status === 'active');
  if (isOwner) return;

  const assignments = await findPropertyAssignments(propertyId);
  const isManager = assignments.some(
    (a) =>
      a.userId === userId &&
      a.status === 'active' &&
      (a.assignment_type === 'property_manager' || a.assignment_type === 'letting_agent'),
  );
  if (!isManager) {
    throw new ForbiddenError('Only the property owner or an assigned manager may manage billing');
  }
}

export async function createSchedule(userId: string, input: CreateScheduleInput): Promise<repo.BillingSchedule> {
  await assertCanManageProperty(userId, input.propertyId);

  const tenancy = await repo.findTenancyBillingContext(input.tenancyId);
  if (!tenancy) throw new NotFoundError('Tenancy');
  if (tenancy.status !== 'active') {
    throw new ValidationError('Billing schedules require an active tenancy');
  }
  if (tenancy.propertyId !== input.propertyId || tenancy.unitId !== input.unitId) {
    throw new ValidationError('Unit/property do not match the tenancy');
  }
  if (!(await repo.unitBelongsToProperty(input.unitId, input.propertyId))) {
    throw new ValidationError('Unit does not belong to the selected property');
  }
  if (!(await repo.tenantBelongsToTenancy(input.tenantId, input.tenancyId))) {
    throw new ValidationError('Tenant is not assigned to the selected tenancy');
  }

  const schedule = await repo.createSchedule({
    propertyId: input.propertyId,
    unitId: input.unitId,
    tenancyId: input.tenancyId,
    tenantId: input.tenantId,
    leaseAgreementId: input.leaseAgreementId ?? null,
    rentAmount: input.rentAmount,
    currency: input.currency,
    billingFrequency: input.billingFrequency,
    billingDay: input.billingDay,
    firstBillingDate: input.firstBillingDate,
    dueDayOfMonth: input.dueDayOfMonth ?? null,
    gracePeriodDays: input.gracePeriodDays,
    status: input.activate ? 'active' : 'pending',
    createdBy: userId,
    approvedBy: input.activate ? userId : null,
  });

  await emitScheduleEvent(userId, 'billing.schedule_changed', schedule.id, schedule.tenancyId, schedule.propertyId, {
    action: 'created',
    status: schedule.status,
    rentAmount: schedule.rentAmount,
    currency: schedule.currency,
    billingFrequency: schedule.billingFrequency,
    firstBillingDate: schedule.firstBillingDate,
  });

  return schedule;
}

export async function listSchedules(userId: string, filters: Parameters<typeof repo.listSchedules>[0]): Promise<repo.BillingSchedule[]> {
  const schedules = await repo.listSchedules(filters);
  // Resource-scope: drop schedules the caller cannot access.
  const visible: repo.BillingSchedule[] = [];
  for (const s of schedules) {
    // eslint-disable-next-line no-await-in-loop
    const access = await authz.canAccessProperty(userId, s.propertyId);
    if (access.allowed) visible.push(s);
  }
  return visible;
}

export async function getSchedule(userId: string, scheduleId: string): Promise<repo.BillingSchedule> {
  const schedule = await repo.findScheduleById(scheduleId);
  if (!schedule) throw new NotFoundError('Billing schedule');
  const access = await authz.canAccessProperty(userId, schedule.propertyId);
  if (!access.allowed) throw new ForbiddenError(access.reason);
  return schedule;
}

export async function changeRent(userId: string, scheduleId: string, input: UpdateScheduleInput): Promise<repo.BillingSchedule> {
  const schedule = await getSchedule(userId, scheduleId);
  await assertCanManageProperty(userId, schedule.propertyId);
  if (input.rentAmount === undefined) throw new ValidationError('rentAmount is required');

  const effectiveDate = input.effectiveDate ?? repo.nairobiToday();
  const { schedule: updated } = await repo.changeRent(schedule, {
    rentAmount: input.rentAmount,
    currency: input.currency,
    effectiveDate,
    notes: input.notes ?? null,
    userId,
  });

  await emitScheduleEvent(userId, 'rent.terms_changed', schedule.id, schedule.tenancyId, schedule.propertyId, {
    action: 'rent_changed',
    rentAmount: updated.rentAmount,
    currency: updated.currency,
    effectiveDate,
  });

  return updated;
}

export async function setStatus(
  userId: string,
  scheduleId: string,
  status: 'active' | 'suspended' | 'cancelled',
  reason?: string | null,
): Promise<repo.BillingSchedule> {
  const schedule = await getSchedule(userId, scheduleId);
  await assertCanManageProperty(userId, schedule.propertyId);

  if (status === 'active' && schedule.status === 'active') {
    throw new ConflictError('Schedule is already active');
  }
  if (status === 'cancelled' && schedule.status === 'cancelled') {
    throw new ConflictError('Schedule is already cancelled');
  }

  const updated = await repo.setScheduleStatus(scheduleId, status, { userId, reason: reason ?? null });
  if (!updated) throw new NotFoundError('Billing schedule');

  await emitScheduleEvent(userId, 'billing.schedule_changed', scheduleId, schedule.tenancyId, schedule.propertyId, {
    action: status === 'active' ? 'activated' : status === 'suspended' ? 'suspended' : 'cancelled',
    status,
    reason: reason ?? null,
  });

  return updated;
}

export async function preview(userId: string, scheduleId: string, periodStart?: string): Promise<repo.InvoicePreview> {
  const schedule = await getSchedule(userId, scheduleId);
  return repo.previewScheduleInvoice(schedule, periodStart);
}

export async function listRentTerms(userId: string, scheduleId: string): Promise<repo.RentTermVersion[]> {
  const schedule = await getSchedule(userId, scheduleId);
  return repo.listRentTerms(schedule.tenancyId);
}

export async function listInvoices(userId: string, filters: Parameters<typeof repo.listInvoices>[0]): Promise<repo.GeneratedInvoiceRow[]> {
  const invoices = await repo.listInvoices(filters);
  const visible: repo.GeneratedInvoiceRow[] = [];
  for (const inv of invoices) {
    // eslint-disable-next-line no-await-in-loop
    const access = await authz.canAccessProperty(userId, inv.propertyId);
    if (access.allowed) visible.push(inv);
  }
  return visible;
}

export async function getInvoice(userId: string, invoiceId: string): Promise<{ invoice: repo.GeneratedInvoiceRow; items: Array<Record<string, unknown>> }> {
  const invoice = await repo.findInvoiceById(invoiceId);
  if (!invoice) throw new NotFoundError('Invoice');
  const access = await authz.canAccessProperty(userId, invoice.propertyId);
  if (!access.allowed) throw new ForbiddenError(access.reason);
  const items = await repo.findInvoiceLineItems(invoiceId);
  return { invoice, items };
}

export async function voidInvoice(userId: string, invoiceId: string, reason: string): Promise<repo.GeneratedInvoiceRow> {
  const invoice = await repo.findInvoiceById(invoiceId);
  if (!invoice) throw new NotFoundError('Invoice');
  await assertCanManageProperty(userId, invoice.propertyId);

  const updated = await repo.voidInvoice(invoiceId, reason, userId);
  if (!updated) {
    throw new ConflictError('Only issued/overdue invoices with an outstanding balance can be voided');
  }

  await emitInvoiceVoided(userId, invoice, reason);
  return updated;
}

async function emitScheduleEvent(
  userId: string,
  eventType: string,
  scheduleId: string,
  tenancyId: string,
  propertyId: string,
  payload: Record<string, unknown>,
): Promise<void> {
  void userId;
  void tenancyId;
  await transaction(async (client) => {
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${scheduleId}:${payload.action ?? ''}`,
      eventType,
      category: 'billing',
      priority: 'normal',
      recipientUserIds: [],
      organisationId: null,
      resourceType: 'billing_schedule',
      resourceId: scheduleId,
      payload: { ...payload, propertyId, tenancyId, deepLink: `/landlord/billing/schedules/${scheduleId}` },
      channels: ['in_app'],
      classification: 'best_effort',
    });
  });
}

async function emitInvoiceVoided(userId: string, invoice: repo.GeneratedInvoiceRow, reason: string): Promise<void> {
  void userId;
  await transaction(async (client) => {
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `invoice.voided:${invoice.id}`,
      eventType: 'invoice.voided',
      category: 'billing',
      priority: 'high',
      recipientUserIds: [],
      organisationId: null,
      resourceType: 'invoice',
      resourceId: invoice.id,
      payload: {
        invoiceId: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        reason,
        deepLink: `/tenant/invoices/${invoice.id}`,
      },
      channels: ['in_app'],
      classification: 'critical',
    });
  });
}

export type { BillingFrequency };