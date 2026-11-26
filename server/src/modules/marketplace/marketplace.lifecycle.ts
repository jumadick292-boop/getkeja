// Service marketplace lifecycle — a single validated status-transition layer
// shared by every category. Each transition is (fromStatus, toStatus, actor).
// The quotation-acceptance path is modelled as a distinct operation that
// validates the request is in a quotable state before flipping it to `accepted`.

import { ConflictError } from '../../shared/errors.js';
import type { LifecycleActor, ServiceRequestStatus } from './marketplace.types.js';

export const REQUEST_STATUSES: ServiceRequestStatus[] = [
  'open',
  'quoted',
  'accepted',
  'in_progress',
  'completed',
  'cancelled',
  'expired',
];

const TRANSITIONS: Array<[ServiceRequestStatus, ServiceRequestStatus, LifecycleActor]> = [
  // Customer cancels while still shopping for / reviewing quotations.
  ['open', 'cancelled', 'customer'],
  ['quoted', 'cancelled', 'customer'],
  ['accepted', 'cancelled', 'customer'],
  // Provider progresses an accepted job.
  ['accepted', 'in_progress', 'provider'],
  ['in_progress', 'completed', 'provider'],
  // System expiry of stale, un-actioned requests.
  ['open', 'expired', 'system'],
  ['quoted', 'expired', 'system'],
];

export function isRequestStatus(value: string): value is ServiceRequestStatus {
  return (REQUEST_STATUSES as string[]).includes(value);
}

export function isTransitionAllowed(
  from: ServiceRequestStatus,
  to: ServiceRequestStatus,
  actor: LifecycleActor,
): boolean {
  return TRANSITIONS.some(([f, t, a]) => f === from && t === to && a === actor);
}

export function assertTransition(
  from: ServiceRequestStatus,
  to: ServiceRequestStatus,
  actor: LifecycleActor,
): void {
  if (!isTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}

// A request accepts quotations only while open or quoted.
export function isQuotable(status: ServiceRequestStatus): boolean {
  return status === 'open' || status === 'quoted';
}

export function assertQuotable(status: ServiceRequestStatus): void {
  if (!isQuotable(status)) {
    throw new ConflictError(`Request is not accepting quotations (status: ${status})`);
  }
}