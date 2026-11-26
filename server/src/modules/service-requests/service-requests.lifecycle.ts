// Service-request lifecycle foundation.
//
// Provides a shared, validated status-transition layer across the three
// service domains (moving, garbage, laundry) WITHOUT collapsing their
// distinct status enums. Each domain keeps its own DB enum and status-history
// table/trigger; this module only centralises the *rules* and the
// transaction-safe status update.
//
// Status history is recorded by the existing per-domain DB triggers
// (record_moving_status_history / record_laundry_status_history). This module
// therefore sets `updated_by` on every transition so the trigger attributes
// the change to the acting user. No duplicate history infrastructure is
// introduced.

import type { PoolClient } from 'pg';
import { ConflictError, ValidationError } from '../../shared/errors.js';

export type ServiceDomain = 'moving' | 'garbage' | 'laundry';
export type LifecycleActor = 'customer' | 'provider';

interface DomainConfig {
  table: string;
  statusEnum: string;
  idColumn: string;
  // moving/laundry carry cancellation metadata columns; garbage does not.
  hasCancellationColumns: boolean;
}

const DOMAIN_CONFIG: Record<ServiceDomain, DomainConfig> = {
  moving: { table: 'moving_requests', statusEnum: 'moving_request_status', idColumn: 'id', hasCancellationColumns: true },
  laundry: { table: 'laundry_requests', statusEnum: 'laundry_request_status', idColumn: 'id', hasCancellationColumns: true },
  garbage: { table: 'garbage_collection_requests', statusEnum: 'collection_request_status', idColumn: 'id', hasCancellationColumns: false },
};

// Allowed transitions for the foundation endpoints. Each entry is
// [fromStatus, toStatus, actor]. Later tasks extend these matrices with
// scheduling / in-progress / completion transitions.
const TRANSITIONS: Record<ServiceDomain, Array<[string, string, LifecycleActor]>> = {
  moving: [
    ['submitted', 'accepted', 'provider'],
    ['submitted', 'declined', 'provider'],
    ['pending_confirmation', 'accepted', 'provider'],
    ['pending_confirmation', 'declined', 'provider'],
    ['submitted', 'cancelled', 'customer'],
    ['pending_confirmation', 'cancelled', 'customer'],
  ],
  laundry: [
    ['submitted', 'accepted', 'provider'],
    ['submitted', 'declined', 'provider'],
    ['pending_confirmation', 'accepted', 'provider'],
    ['pending_confirmation', 'declined', 'provider'],
    ['submitted', 'cancelled', 'customer'],
    ['pending_confirmation', 'cancelled', 'customer'],
  ],
  garbage: [
    // Garbage has no `declined` enum value; a provider decline maps to
    // `cancelled` with a reason (documented in the foundation doc).
    ['pending', 'assigned', 'provider'],
    ['pending', 'cancelled', 'provider'],
    ['pending', 'cancelled', 'customer'],
  ],
};

export function isServiceDomain(value: string): value is ServiceDomain {
  return value === 'moving' || value === 'garbage' || value === 'laundry';
}

export function isTransitionAllowed(
  domain: ServiceDomain,
  fromStatus: string,
  toStatus: string,
  actor: LifecycleActor,
): boolean {
  return TRANSITIONS[domain].some(
    ([from, to, a]) => from === fromStatus && to === toStatus && a === actor,
  );
}

export function assertTransition(
  domain: ServiceDomain,
  fromStatus: string,
  toStatus: string,
  actor: LifecycleActor,
): void {
  if (!isTransitionAllowed(domain, fromStatus, toStatus, actor)) {
    throw new ConflictError(
      `Transition ${fromStatus} -> ${toStatus} is not permitted for ${actor} in ${domain}`,
    );
  }
}

export interface StatusUpdateInput {
  domain: ServiceDomain;
  requestId: string;
  expectedFromStatus: string;
  toStatus: string;
  actorUserId: string;
  reason?: string | null;
}

export interface StatusUpdateResult {
  id: string;
  status: string;
}

/**
 * Transaction-safe status update. Must be called with the caller's active
 * PoolClient so the status change, history trigger and (caller-enqueued)
 * outbox event share one transaction boundary.
 *
 * Concurrency is guarded by `AND status = expectedFromStatus`; a concurrent
 * modification yields zero rows and raises ConflictError (rolling back).
 */
export async function updateDomainRequestStatus(
  client: PoolClient,
  input: StatusUpdateInput,
): Promise<StatusUpdateResult> {
  const cfg = DOMAIN_CONFIG[input.domain];

  const assignments: string[] = [`status = $2::${cfg.statusEnum}`, 'updated_by = $3', 'updated_at = NOW()'];
  const values: unknown[] = [input.requestId, input.toStatus, input.actorUserId];
  let idx = 4;

  if (input.reason != null && cfg.hasCancellationColumns) {
    assignments.push(`cancellation_reason = $${idx++}`);
    values.push(input.reason);
  }

  // Maintain lifecycle timestamps consistent with the domain tables.
  if (input.toStatus === 'cancelled' && cfg.hasCancellationColumns) {
    assignments.push(`cancelled_at = NOW()`);
    assignments.push(`cancelled_by = $3`);
  }

  values.push(input.expectedFromStatus);

  const result = await client.query<{ id: string; status: string }>(
    `UPDATE ${cfg.table}
        SET ${assignments.join(', ')}
      WHERE id = $1 AND status = $${idx}::${cfg.statusEnum}
      RETURNING id, status::text as status`,
    values,
  );

  if (result.rows.length === 0) {
    throw new ConflictError('Request status changed concurrently; please retry');
  }
  return result.rows[0]!;
}

/**
 * Validate that a requested transition target is a known status for the
 * domain. Callers pass the *current* status separately.
 */
export function assertKnownStatus(domain: ServiceDomain, status: string): void {
  const allowed = new Set<string>();
  for (const [from, to] of TRANSITIONS[domain]) {
    allowed.add(from);
    allowed.add(to);
  }
  if (!allowed.has(status) && status !== 'scheduled' && status !== 'in_progress' && status !== 'completed') {
    // Only used to guard obviously invalid input; not a full enum check.
    throw new ValidationError(`Unknown ${domain} status: ${status}`);
  }
}