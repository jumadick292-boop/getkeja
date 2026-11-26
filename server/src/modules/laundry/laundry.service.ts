// Laundry operations service (Task 13.8).
// Builds a laundry order FROM an accepted marketplace quotation (immutable
// snapshot) and drives intake, inspection/approval, processing (with stage
// skipping), scheduling/handover, amendments, completion and confirmation.
// Business change + history + outbox share one transaction. Reuses provider
// context, org permissions and the transactional outbox.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  CreateLaundryOrderInput,
  LaundryCompletionInput,
  LaundryCustomerConfirmationInput,
  LaundryInspectionInput,
  LaundryItemInput,
  LaundryProgressInput,
  ProposeLaundryAmendmentInput,
  ScheduleHandoverInput,
} from './laundry.schemas.js';
import type {
  LaundryActor,
  LaundryCollectionStatus,
  LaundryOrder,
  LaundryOrderDetail,
  LaundryOrderScope,
} from './laundry.types.js';
import {
  assertLaundryTransition,
  LAUNDRY_CHECKLIST_TEMPLATE,
  isLaundryTerminal,
} from './laundry.lifecycle.js';
import * as repo from './laundry.repository.js';

function actorFor(userId: string, order: LaundryOrder): LaundryActor {
  if (order.customerUserId === userId) return 'customer';
  return 'provider';
}

async function loadProviderContext(userId: string, organizationId?: string | null): Promise<ProviderContext> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

async function assertProviderAccess(context: ProviderContext, order: LaundryOrder, permission?: string): Promise<void> {
  const isOwnerProfile = context.effectiveProfileIds.includes(order.providerProfileId);
  if (isOwnerProfile) return;
  const isAssignedStaff = order.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM laundry_order_staff_assignments
        WHERE laundry_order_id = $1 AND user_id = $2 AND is_active`,
      [order.id, context.userId],
    )
  ).rowCount;
  if (!isAssignedStaff && !isActiveStaff) {
    throw new ForbiddenError('You are not authorized for this laundry order');
  }
  if (permission) {
    const roleIds = order.providerOrganisationId
      ? await authz.getUserOrganizationRoleIds(context.userId, order.providerOrganisationId)
      : [];
    if (roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r))) return;
    if (!(await authz.hasPermission(context.userId, permission))) {
      throw new ForbiddenError(`Missing permission: ${permission}`);
    }
  }
}

async function loadOrderForCustomer(userId: string, orderId: string): Promise<LaundryOrder> {
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  if (order.customerUserId !== userId) throw new ForbiddenError('You may not access this laundry order');
  return order;
}

async function quoteRequestId(quotationId: string): Promise<string> {
  const r = await pool.query<{ service_request_id: string }>(
    `SELECT service_request_id FROM service_quotations WHERE id = $1`,
    [quotationId],
  );
  if (!r.rows[0]) throw new NotFoundError('Quotation not found');
  return r.rows[0].service_request_id;
}

function defaultChecklist(): Record<string, boolean> {
  return Object.fromEntries(LAUNDRY_CHECKLIST_TEMPLATE.map((t) => [t.id, false]));
}

// ---------------------------------------------------------------------------
// Order creation from an accepted quotation
// ---------------------------------------------------------------------------
export async function createOrderFromQuotation(
  userId: string,
  input: CreateLaundryOrderInput,
  organizationId?: string | null,
): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);

  const requestId = await quoteRequestId(input.quotationId);
  const accepted = await repo.findAcceptedQuotation(requestId);
  if (!accepted) throw new ConflictError('Quotation is not accepted');
  if (!context.effectiveProfileIds.includes(accepted.providerProfileId)) {
    throw new ForbiddenError('You may not create an order for this quotation');
  }
  const existing = await repo.findOrderByRequestId(requestId);
  if (existing) throw new ConflictError('A laundry order already exists for this request');

  const requestRow = await pool.query<{ details: Record<string, unknown>; customer_user_id: string }>(
    `SELECT details, customer_user_id AS "customer_user_id" FROM service_requests WHERE id = $1`,
    [requestId],
  );
  if (!requestRow.rows[0]) throw new NotFoundError('Service request not found');
  const requestDetails = requestRow.rows[0].details ?? {};

  const scope: LaundryOrderScope = {
    services: input.scope?.services ?? [],
    capabilities: input.scope?.capabilities ?? [],
    specialInstructions: input.scope?.specialInstructions,
    preferredCollectionDate: input.scope?.preferredCollectionDate,
    preferredWindowStart: input.scope?.preferredWindowStart,
    preferredWindowEnd: input.scope?.preferredWindowEnd,
    requestDetails,
  };

  const orderId = await transaction(async (client) => {
    const created = await repo.insertOrder(client, {
      serviceRequestId: requestId,
      quotationId: accepted.id,
      quotationVersion: accepted.versionNumber,
      customerUserId: requestRow.rows[0]!.customer_user_id,
      providerProfileId: accepted.providerProfileId,
      providerOrganisationId: context.activeOrganizationId,
      fulfilmentMode: input.fulfilmentMode,
      collectionLocationId: input.collection?.locationId ?? null,
      collectionAddress: input.collection?.address ?? null,
      returnLocationId: input.returnLocation?.locationId ?? null,
      returnAddress: input.returnLocation?.address ?? null,
      propertyId: input.propertyId ?? null,
      unitId: input.unitId ?? null,
      tenancyId: input.tenancyId ?? null,
      agreedPrice: accepted.totalAmount,
      currency: accepted.currency,
      scope,
      checklist: defaultChecklist(),
      collectionDate: input.collectionDate ?? null,
      collectionWindowStart: input.collectionWindowStart ?? null,
      collectionWindowEnd: input.collectionWindowEnd ?? null,
      returnDate: input.returnDate ?? null,
      returnWindowStart: input.returnWindowStart ?? null,
      returnWindowEnd: input.returnWindowEnd ?? null,
      createdBy: userId,
    });
    for (const item of input.items ?? []) {
      await repo.insertItem(client, created.id, { ...item, photoDocumentIds: [], createdBy: userId });
    }
    await repo.insertHistory(client, {
      orderId: created.id,
      action: 'confirmed',
      changedBy: userId,
      newStatus: 'confirmed',
      metadata: { quotationId: accepted.id, version: accepted.versionNumber },
    });
    const eventType = 'laundry_order.confirmed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [requestRow.rows[0]!.customer_user_id],
      organisationId: context.activeOrganizationId,
      resourceType: 'laundry_order',
      resourceId: created.id,
      payload: { orderId: created.id, requestId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
    return created.id;
  });

  return (await repo.getOrderDetail(orderId))!;
}

// ---------------------------------------------------------------------------
// Customer
// ---------------------------------------------------------------------------
export async function listCustomerOrders(userId: string, query: { status?: LaundryCollectionStatus; limit: number; offset: number }) {
  return repo.listOrdersByCustomer(userId, query);
}

export async function getCustomerOrder(userId: string, orderId: string): Promise<LaundryOrderDetail> {
  await loadOrderForCustomer(userId, orderId);
  return (await repo.getOrderDetail(orderId))!;
}

export async function cancelOrder(userId: string, orderId: string, reason: string): Promise<LaundryOrderDetail> {
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  const actor = actorFor(userId, order);
  if (actor === 'provider') {
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, order);
  }
  assertLaundryTransition(order.status, 'cancelled', actor);
  await transaction(async (client) => {
    await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'cancelled', actorUserId: userId, reason });
    await repo.insertHistory(client, { orderId, action: 'cancelled', changedBy: userId, previousStatus: order.status, newStatus: 'cancelled', reason });
    const eventType = 'laundry_order.cancelled';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [actor === 'customer' ? order.providerProfileId : order.customerUserId].filter(Boolean) as string[],
      organisationId: null,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, reason },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function confirmCompletion(userId: string, orderId: string, input: LaundryCustomerConfirmationInput): Promise<LaundryOrderDetail> {
  const order = await loadOrderForCustomer(userId, orderId);
  if (order.status !== 'awaiting_customer_confirmation') {
    throw new ConflictError('Order is not awaiting customer confirmation');
  }
  if (!order.completionSubmittedAt) throw new ConflictError('Provider has not submitted completion yet');

  await transaction(async (client) => {
    await client.query(
      `UPDATE laundry_orders SET customer_confirmation_status = $2, customer_confirmation_notes = $3, customer_confirmation_at = NOW() WHERE id = $1`,
      [orderId, input.confirm ? 'confirmed' : 'exception', input.notes ?? null],
    );
    if (input.confirm) {
      await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'completed', actorUserId: userId });
      await repo.insertHistory(client, { orderId, action: 'completed', changedBy: userId, previousStatus: order.status, newStatus: 'completed' });
    } else if (input.exception) {
      await repo.insertException(client, orderId, userId, input.exception.type, input.exception.description);
      await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'exception', actorUserId: userId });
      await repo.insertHistory(client, { orderId, action: 'exception', changedBy: userId, previousStatus: order.status, newStatus: 'exception', metadata: { exception: input.exception } });
    }
    const eventType = input.confirm ? 'laundry_order.completed' : 'laundry_order.exception';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [],
      organisationId: null,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, confirm: input.confirm, exception: input.exception ?? null },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function reportException(userId: string, orderId: string, input: { type: string; description: string }): Promise<LaundryOrderDetail> {
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  const actor = actorFor(userId, order);
  if (actor === 'provider') {
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, order);
  }
  if (isLaundryTerminal(order.status)) throw new ConflictError('Order is closed');
  await transaction(async (client) => {
    await repo.insertException(client, orderId, userId, input.type, input.description);
    await repo.insertHistory(client, { orderId, action: 'exception_reported', changedBy: userId, metadata: { type: input.type } });
    const eventType = 'laundry_order.exception_reported';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}:${Date.now()}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [actor === 'customer' ? order.providerProfileId : order.customerUserId].filter(Boolean) as string[],
      organisationId: null,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, type: input.type },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// Resolve a customer-approval inspection (discrepancy / extra charge).
export async function resolveInspection(userId: string, orderId: string, inspectionId: string, decision: 'approve' | 'reject', notes?: string): Promise<LaundryOrderDetail> {
  const order = await loadOrderForCustomer(userId, orderId);
  const inspection = await repo.findInspection(orderId, inspectionId);
  if (!inspection) throw new NotFoundError('Inspection not found');
  if (!inspection.requiresCustomerApproval) throw new ConflictError('Inspection does not require approval');
  if (inspection.approvalStatus !== 'pending') throw new ConflictError('Inspection already decided');
  await transaction(async (client) => {
    await repo.resolveInspection(client, inspectionId, decision, userId);
    await repo.insertHistory(client, { orderId, action: `inspection_${decision}`, changedBy: userId, metadata: { inspectionId, notes: notes ?? null } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
export async function listProviderOrders(userId: string, query: { status?: LaundryCollectionStatus; organizationId?: string; limit: number; offset: number }) {
  const context = await loadProviderContext(userId, query.organizationId);
  return repo.listOrdersForProvider(context.effectiveProfileIds, userId, query);
}

export async function getProviderOrder(userId: string, orderId: string, organizationId?: string | null): Promise<LaundryOrderDetail & { canViewLocations: boolean }> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order);
  const detail = (await repo.getOrderDetail(orderId))!;
  const canViewLocations = await canViewSensitiveLocations(context, order);
  return { ...detail, canViewLocations };
}

async function canViewSensitiveLocations(context: ProviderContext, order: LaundryOrder): Promise<boolean> {
  const isOwnerProfile = context.effectiveProfileIds.includes(order.providerProfileId);
  const isAssignedStaff = order.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM laundry_order_staff_assignments WHERE laundry_order_id = $1 AND user_id = $2 AND is_active`,
      [order.id, context.userId],
    )
  ).rowCount;
  if (!isOwnerProfile && !isAssignedStaff && !isActiveStaff) return false;
  if (isOwnerProfile || isAssignedStaff) return true;
  return authz.hasPermission(context.userId, 'provider.laundry.view_locations');
}

export async function updateProgress(userId: string, orderId: string, input: LaundryProgressInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.update_progress');
  // Block progressing past an unresolved customer approval.
  if (order.status === 'awaiting_customer_approval' && await repo.hasPendingApprovals(orderId)) {
    throw new ConflictError('Resolve the pending customer approval before continuing');
  }
  assertLaundryTransition(order.status, input.toStatus, 'provider');

  await transaction(async (client) => {
    if (input.checklist) await repo.mergeChecklist(client, orderId, input.checklist);
    await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: input.toStatus, actorUserId: userId, reason: input.reason ?? null });
    await repo.insertHistory(client, { orderId, action: input.toStatus, changedBy: userId, previousStatus: order.status, newStatus: input.toStatus, reason: input.reason ?? null });
    const eventType = `laundry_order.${input.toStatus}`;
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}:${input.toStatus}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [order.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, status: input.toStatus },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function failOrder(userId: string, orderId: string, reason: string, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.update_progress');
  assertLaundryTransition(order.status, 'failed', 'provider');
  await transaction(async (client) => {
    await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'failed', actorUserId: userId, reason });
    await repo.insertHistory(client, { orderId, action: 'failed', changedBy: userId, previousStatus: order.status, newStatus: 'failed', reason });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Items ----
export async function addItem(userId: string, orderId: string, input: LaundryItemInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.manage_intake');
  if (isLaundryTerminal(order.status)) throw new ConflictError('Order is closed');
  await transaction(async (client) => {
    const created = await repo.insertItem(client, orderId, { ...input, createdBy: userId });
    if (input.photoDocumentIds.length > 0) {
      await repo.insertAttachments(client, orderId, input.photoDocumentIds, 'item', userId);
    }
    await repo.insertHistory(client, { orderId, action: 'item_added', changedBy: userId, metadata: { itemId: created.id, quantity: input.quantity } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function updateItem(userId: string, orderId: string, itemId: string, patch: Record<string, unknown>, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.manage_intake');
  const item = await repo.findItem(orderId, itemId);
  if (!item) throw new NotFoundError('Item not found');
  await transaction(async (client) => {
    await repo.updateItem(client, orderId, itemId, patch);
    await repo.insertHistory(client, { orderId, action: 'item_updated', changedBy: userId, metadata: { itemId } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Inspections ----
export async function recordInspection(userId: string, orderId: string, input: LaundryInspectionInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.manage_intake');
  if (input.itemId) {
    const item = await repo.findItem(orderId, input.itemId);
    if (!item) throw new ValidationError('Referenced item does not belong to this order');
  }
  const requiresApproval = input.requiresCustomerApproval
    || input.result === 'discrepancy'
    || input.result === 'missing'
    || input.result === 'damage';
  await transaction(async (client) => {
    const created = await repo.insertInspection(client, orderId, {
      itemId: input.itemId ?? null,
      reportedBy: userId,
      result: input.result,
      declaredQuantity: input.declaredQuantity ?? null,
      receivedQuantity: input.receivedQuantity ?? null,
      description: input.description,
      requiresCustomerApproval: requiresApproval,
    });
    await repo.insertHistory(client, { orderId, action: 'inspection_recorded', changedBy: userId, metadata: { inspectionId: created.id, result: input.result } });
    if (requiresApproval) {
      // Move to awaiting_customer_approval if not already there/terminal.
      if (!isLaundryTerminal(order.status) && order.status !== 'awaiting_customer_approval') {
        await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'awaiting_customer_approval', actorUserId: userId });
      }
      const eventType = 'laundry_order.customer_approval_required';
      await enqueueOutboxEventTransactional(client, {
        idempotencyKey: `${eventType}:${created.id}`,
        eventType,
        category: 'operational',
        priority: 'high',
        recipientUserIds: [order.customerUserId],
        organisationId: context.activeOrganizationId,
        resourceType: 'laundry_order',
        resourceId: orderId,
        payload: { orderId, inspectionId: created.id },
        channels: ['in_app'],
        classification: classifyEventType(eventType),
      });
    }
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Staff ----
export async function assignStaff(userId: string, orderId: string, input: { userId: string; label?: string }, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.assign_staff');
  if (order.providerOrganisationId) {
    const member = await pool.query(
      `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'`,
      [order.providerOrganisationId, input.userId],
    );
    if (!member.rowCount) throw new ValidationError('Staff member is not an active organization member');
  }
  await transaction(async (client) => {
    await client.query(
      `UPDATE laundry_order_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $2
        WHERE laundry_order_id = $1 AND user_id = $3 AND is_active`,
      [orderId, userId, input.userId],
    );
    await client.query(
      `INSERT INTO laundry_order_staff_assignments (laundry_order_id, user_id, assigned_by, label)
       VALUES ($1,$2,$3,$4)`,
      [orderId, input.userId, userId, input.label ?? null],
    );
    if (order.assignedStaffUserId !== input.userId) {
      await client.query(`UPDATE laundry_orders SET assigned_staff_user_id = $2 WHERE id = $1`, [orderId, input.userId]);
    }
    await repo.insertHistory(client, { orderId, action: 'staff_assigned', changedBy: userId, metadata: { userId: input.userId } });
    const eventType = 'laundry_order.staff_assigned';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}:${input.userId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [input.userId],
      organisationId: order.providerOrganisationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, staffUserId: input.userId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function revokeStaff(userId: string, orderId: string, staffUserId: string, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.assign_staff');
  await transaction(async (client) => {
    await client.query(
      `UPDATE laundry_order_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $2
        WHERE laundry_order_id = $1 AND user_id = $3 AND is_active`,
      [orderId, userId, staffUserId],
    );
    if (order.assignedStaffUserId === staffUserId) {
      await client.query(`UPDATE laundry_orders SET assigned_staff_user_id = NULL WHERE id = $1`, [orderId]);
    }
    await repo.insertHistory(client, { orderId, action: 'staff_revoked', changedBy: userId, metadata: { userId: staffUserId } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Checklist ----
export async function updateChecklist(userId: string, orderId: string, items: Record<string, boolean>, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.update_progress');
  await transaction(async (client) => {
    await repo.mergeChecklist(client, orderId, items);
    await repo.insertHistory(client, { orderId, action: 'checklist_updated', changedBy: userId, metadata: { items } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Handovers (collection / return) ----
export async function scheduleHandover(userId: string, orderId: string, input: ScheduleHandoverInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.manage_schedule');
  await transaction(async (client) => {
    const created = await repo.insertHandover(client, orderId, {
      kind: input.kind,
      locationId: input.location?.locationId ?? null,
      address: input.location?.address ?? null,
      scheduledAt: input.scheduledAt ?? null,
      windowStart: input.windowStart ?? null,
      windowEnd: input.windowEnd ?? null,
      notes: input.notes ?? null,
      createdBy: userId,
    });
    await repo.insertHistory(client, { orderId, action: 'handover_scheduled', changedBy: userId, metadata: { handoverId: created.id, kind: input.kind } });
    const eventType = `laundry_order.${input.kind}_scheduled`;
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [order.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, handoverId: created.id, kind: input.kind },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function confirmHandover(userId: string, orderId: string, handoverId: string, proofDocumentIds: string[], notes: string | undefined, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.upload_evidence');
  const handover = await repo.findHandover(orderId, handoverId);
  if (!handover) throw new NotFoundError('Handover not found');
  await transaction(async (client) => {
    await repo.confirmHandover(client, handoverId, userId, proofDocumentIds, notes ?? null);
    if (proofDocumentIds.length > 0) await repo.insertAttachments(client, orderId, proofDocumentIds, 'handover', userId);
    await repo.insertHistory(client, { orderId, action: 'handover_confirmed', changedBy: userId, metadata: { handoverId, kind: handover.kind } });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Amendments ----
export async function proposeAmendment(userId: string, orderId: string, input: ProposeLaundryAmendmentInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.propose_changes');
  if (isLaundryTerminal(order.status)) throw new ConflictError('Order is closed');
  await transaction(async (client) => {
    const created = await repo.insertAmendment(client, orderId, {
      proposedBy: userId,
      reason: input.reason,
      revisedScope: input.revisedScope ?? {},
      additionalCost: input.additionalCost.toFixed(2),
      currency: order.currency,
    });
    await repo.insertHistory(client, { orderId, action: 'amendment_proposed', changedBy: userId, metadata: { amendmentId: created.id, additionalCost: input.additionalCost } });
    const eventType = 'laundry_order.amendment_proposed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [order.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, amendmentId: created.id, additionalCost: input.additionalCost },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export async function decideAmendment(userId: string, orderId: string, amendmentId: string, accept: boolean): Promise<LaundryOrderDetail> {
  const order = await loadOrderForCustomer(userId, orderId);
  const amendment = await repo.findAmendment(orderId, amendmentId);
  if (!amendment) throw new NotFoundError('Amendment not found');
  if (amendment.status !== 'pending') throw new ConflictError('Amendment already decided');
  await transaction(async (client) => {
    await repo.resolveAmendment(client, amendmentId, accept, userId);
    if (accept) {
      // Apply the additional cost to the order total (quotation itself immutable).
      await client.query(`UPDATE laundry_orders SET agreed_price = agreed_price + $2 WHERE id = $1`, [orderId, amendment.additionalCost]);
    }
    await repo.insertHistory(client, {
      orderId,
      action: accept ? 'amendment_accepted' : 'amendment_rejected',
      changedBy: userId,
      metadata: { amendmentId, additionalCost: amendment.additionalCost },
    });
    const eventType = accept ? 'laundry_order.amendment_accepted' : 'laundry_order.amendment_rejected';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${amendmentId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [],
      organisationId: order.providerOrganisationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId, amendmentId, accept },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

// ---- Completion ----
export async function submitCompletion(userId: string, orderId: string, input: LaundryCompletionInput, organizationId?: string | null): Promise<LaundryOrderDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const order = await repo.findOrderById(orderId);
  if (!order) throw new NotFoundError('Laundry order not found');
  await assertProviderAccess(context, order, 'provider.laundry.upload_evidence');
  assertLaundryTransition(order.status, 'awaiting_customer_confirmation', 'provider');
  await transaction(async (client) => {
    await client.query(
      `UPDATE laundry_orders SET completion_notes = $2, completion_outstanding_issue = $3, completion_submitted_at = NOW(),
          checklist = COALESCE(checklist, '{}'::jsonb) || $4::jsonb WHERE id = $1`,
      [orderId, input.notes ?? null, input.outstandingIssue, JSON.stringify(input.checklist ?? {})],
    );
    if (input.evidenceDocumentIds.length > 0) await repo.insertAttachments(client, orderId, input.evidenceDocumentIds, 'completion', userId);
    await repo.updateOrderStatus(client, { orderId, expectedFrom: order.status, toStatus: 'awaiting_customer_confirmation', actorUserId: userId });
    await repo.insertHistory(client, { orderId, action: 'completion_submitted', changedBy: userId, previousStatus: order.status, newStatus: 'awaiting_customer_confirmation' });
    const eventType = 'laundry_order.completion_submitted';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${orderId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [order.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'laundry_order',
      resourceId: orderId,
      payload: { orderId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getOrderDetail(orderId))!;
}

export { actorFor };