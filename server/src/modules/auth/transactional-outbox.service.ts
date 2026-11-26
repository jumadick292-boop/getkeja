// Transactional outbox service.
//
// Guarantees that critical business state changes and their notification
// events are persisted atomically within the same database transaction. If
// the outbox insert fails, the entire business transaction is rolled back,
// so the state change never persists without its notification event.
//
// Events are classified:
//  - CRITICAL: must be persisted atomically with the business change. A
//    missing event means data loss (e.g. proposal expiry, proposal status
//    transitions, tenancy creation).
//  - BEST_EFFORT: persisted after commit with retry; a lost event is
//    recoverable through other means (e.g. listing publish triggers a
//    search-alert re-index that can be re-run manually).

import type { PoolClient } from 'pg';
import { createOutboxEvent } from './auth.repository.js';
import type { NotificationOutbox } from './auth.types.js';

export type OutboxClassification = 'critical' | 'best_effort';

export interface OutboxEventInput {
  idempotencyKey: string;
  eventType: string;
  category: string;
  priority: 'low' | 'normal' | 'high' | 'critical';
  recipientUserIds: string[];
  organisationId: string | null;
  resourceType: string | null;
  resourceId: string | null;
  payload: Record<string, unknown>;
  channels: string[];
  maxRetries?: number;
  classification: OutboxClassification;
}

/**
 * Persist an outbox event within the same transaction as the caller's
 * business work. The caller must pass the active PoolClient so the insert
 * shares the transaction boundary. Throws on failure, causing the caller's
 * transaction to roll back.
 */
export async function enqueueOutboxEventTransactional(
  client: PoolClient,
  input: OutboxEventInput,
): Promise<NotificationOutbox> {
  return createOutboxEvent({
    idempotencyKey: input.idempotencyKey,
    eventType: input.eventType,
    category: input.category,
    priority: input.priority,
    recipientUserIds: input.recipientUserIds,
    organisationId: input.organisationId,
    resourceType: input.resourceType,
    resourceId: input.resourceId,
    payload: input.payload,
    channels: input.channels,
    maxRetries: input.maxRetries,
    client,
  });
}

/**
 * Classify an event type for outbox durability.
 *
 * CRITICAL events are persisted atomically with their business change.
 * BEST_EFFORT events are persisted post-commit and may be lost; they must
 * have an alternate recovery path.
 */
export function classifyEventType(eventType: string): OutboxClassification {
  const critical = new Set([
    // Proposal lifecycle — expiry and status transitions must be atomic.
    'proposal.expired',
    'proposal.accepted',
    'proposal.declined',
    'proposal.withdrawn',
    'proposal.counter',
    'proposal.changes_requested',
    'proposal.confirmed',
    'proposal.sent',
    'proposal.request_changes',
    // Tenancy / onboarding
    'tenancy.created',
    'onboarding.initiated',
    // Rental application lifecycle
    'application.approved',
    'application.rejected',
    'application.withdrawn',
    'application.cancelled',
    'application.expired',
    'application.proposal_sent',
    'application.negotiation_started',
    'application.shortlisted',
    'application.under_review',
    'application.information_requested',
    'application.resubmitted',
    'application.submitted',
    // Financial lifecycle (critical: must be atomic with the state change)
    'payment.completed',
    'payment.failed',
    'payment.reversed',
    'invoice.issued',
    'invoice.overdue',
    'receipt.generated',
    // Message delivery
    'message.created',
    // Service-request lifecycle (customer + provider) — must be atomic with
    // the committed request/state transition.
    'moving_request.created',
    'garbage_request.created',
    'laundry_request.created',
    'service_request.accepted',
    'service_request.declined',
    'service_request.cancelled',
    'service_request.scheduled',
    'service_request.completed',
    // Marketplace quotation lifecycle (Task 13.5) — atomic with the change.
    'service_request.created',
    'service_request.quoted',
    'quotation.submitted',
    'quotation.revised',
    'quotation.withdrawn',
    // Moving operations lifecycle (Task 13.6) — atomic with the change.
    'moving_job.confirmed',
    'moving_job.cancelled',
    'moving_job.completed',
    'moving_job.completion_exception',
    'moving_job.completion_submitted',
    'moving_job.staff_assigned',
    'moving_job.assessment_requested',
    'moving_job.amendment_proposed',
    'moving_job.amendment_accepted',
    'moving_job.amendment_rejected',
    'moving_job.preparation',
    'moving_job.ready_for_move',
    'moving_job.in_progress',
    'moving_job.arrived_at_destination',
    'moving_job.unloading',
    'moving_job.awaiting_customer_confirmation',
    // Garbage operations lifecycle (Task 13.7) — atomic with the change.
    'garbage_job.confirmed',
    'garbage_job.cancelled',
    'garbage_job.completed',
    'garbage_job.completion_exception',
    'garbage_job.completion_submitted',
    'garbage_job.missed',
    'garbage_job.staff_assigned',
    'garbage_job.scheduled',
    'garbage_job.provider_assigned',
    'garbage_job.en_route',
    'garbage_job.arrived',
    'garbage_job.collecting',
    'garbage_job.awaiting_customer_confirmation',
    'garbage_job.rescheduled',
    'garbage_agreement.proposed',
    'garbage_agreement.accepted',
    'garbage_agreement.declined',
    'garbage_agreement.suspended',
    'garbage_agreement.cancelled',
    'garbage_agreement.completed',
    // Laundry operations lifecycle (Task 13.8) — atomic with the change.
    'laundry_order.confirmed',
    'laundry_order.cancelled',
    'laundry_order.completed',
    'laundry_order.exception',
    'laundry_order.exception_reported',
    'laundry_order.completion_submitted',
    'laundry_order.customer_approval_required',
    'laundry_order.staff_assigned',
    'laundry_order.collection_scheduled',
    'laundry_order.return_scheduled',
    'laundry_order.amendment_proposed',
    'laundry_order.amendment_accepted',
    'laundry_order.amendment_rejected',
    'laundry_order.collection_scheduled',
    'laundry_order.collected',
    'laundry_order.received_at_facility',
    'laundry_order.inspection',
    'laundry_order.processing',
    'laundry_order.washing',
    'laundry_order.drying',
    'laundry_order.ironing',
    'laundry_order.folding',
    'laundry_order.quality_check',
    'laundry_order.ready_for_return',
    'laundry_order.out_for_delivery',
    'laundry_order.delivered',
    'laundry_order.awaiting_customer_confirmation',
    // Home Maintenance operations lifecycle (Task 13.12) — atomic with the change.
    'home_maintenance_job.confirmed',
    'home_maintenance_job.inspection_scheduled',
    'home_maintenance_job.awaiting_inspection',
    'home_maintenance_job.inspection_in_progress',
    'home_maintenance_job.awaiting_customer_approval',
    'home_maintenance_job.work_scheduled',
    'home_maintenance_job.assigned',
    'home_maintenance_job.in_progress',
    'home_maintenance_job.awaiting_parts',
    'home_maintenance_job.awaiting_customer_decision',
    'home_maintenance_job.quality_check',
    'home_maintenance_job.completed_pending_confirmation',
    'home_maintenance_job.completed',
    'home_maintenance_job.cancelled',
    'home_maintenance_job.failed',
    'home_maintenance_job.exception',
    // Shared scheduling (Task 13.9) — atomic with the change.
    'schedule.confirmed',
    'schedule.reschedule_requested',
    'schedule.reschedule_approved',
    'schedule.reschedule_rejected',
    'schedule.cancelled',
    'schedule.staff_assigned',
    'schedule.staff_revoked',
    'schedule.reminder',
  ]);
  return critical.has(eventType) ? 'critical' : 'best_effort';
}

/**
 * Build a stable idempotency key for a proposal event.
 *
 * Distinct proposal versions and distinct negotiation actions must have
 * appropriately distinct event identities to prevent duplicate delivery
 * during retries and concurrent processing.
 */
export function proposalIdempotencyKey(
  base: string,
  proposalId: string,
  versionNumber?: number | null,
): string {
  return versionNumber != null ? `${base}:${proposalId}:v${versionNumber}` : `${base}:${proposalId}`;
}