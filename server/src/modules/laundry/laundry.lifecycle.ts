// Laundry operations lifecycle (Task 13.8) — validated transition matrix with
// stage skipping. Providers may skip optional processing stages (e.g. ironing)
// while invalid transitions are rejected.
import { ConflictError } from '../../shared/errors.js';
import type { LaundryActor, LaundryCollectionStatus } from './laundry.types.js';

export const LAUNDRY_ORDER_STATUSES: LaundryCollectionStatus[] = [
  'confirmed', 'collection_scheduled', 'collected', 'received_at_facility',
  'inspection', 'awaiting_customer_approval', 'processing', 'washing',
  'drying', 'ironing', 'folding', 'quality_check', 'ready_for_return',
  'out_for_delivery', 'delivered', 'awaiting_customer_confirmation',
  'completed', 'cancelled', 'failed', 'exception',
];

// Ordered processing stages that may be skipped forward.
const PROCESSING_STAGES: LaundryCollectionStatus[] = [
  'processing', 'washing', 'drying', 'ironing', 'folding', 'quality_check',
];

export interface LaundryTransition {
  from: LaundryCollectionStatus;
  to: LaundryCollectionStatus;
  actor: LaundryActor;
}

const TERMINAL: LaundryCollectionStatus[] = ['completed', 'cancelled', 'failed', 'exception'];

function buildTransitions(): LaundryTransition[] {
  const list: LaundryTransition[] = [];
  const add = (from: LaundryCollectionStatus, to: LaundryCollectionStatus, actor: LaundryActor) =>
    list.push({ from, to, actor });

  // Intake / collection.
  add('confirmed', 'collection_scheduled', 'provider');
  add('confirmed', 'received_at_facility', 'provider');
  add('collection_scheduled', 'collected', 'provider');
  add('collected', 'received_at_facility', 'provider');
  add('received_at_facility', 'inspection', 'provider');
  add('inspection', 'awaiting_customer_approval', 'provider');
  add('inspection', 'processing', 'provider');
  // After approval (or directly from inspection) the provider may skip forward
  // into any processing stage.
  for (const stage of PROCESSING_STAGES) {
    add('awaiting_customer_approval', stage, 'provider');
  }
  add('awaiting_customer_approval', 'ready_for_return', 'provider');
  add('inspection', 'ready_for_return', 'provider');
  add('received_at_facility', 'ready_for_return', 'provider');

  // Processing with forward skipping.
  for (let i = 0; i < PROCESSING_STAGES.length; i += 1) {
    const from = PROCESSING_STAGES[i]!;
    for (let j = i + 1; j < PROCESSING_STAGES.length; j += 1) {
      add(from, PROCESSING_STAGES[j]!, 'provider');
    }
    // Any processing stage can jump to ready / rework / cancel.
    add(from, 'ready_for_return', 'provider');
  }
  // Rework loop.
  add('quality_check', 'processing', 'provider');

  // Return / delivery.
  add('ready_for_return', 'out_for_delivery', 'provider');
  add('ready_for_return', 'awaiting_customer_confirmation', 'provider');
  add('out_for_delivery', 'delivered', 'provider');
  add('delivered', 'awaiting_customer_confirmation', 'provider');

  // Customer confirmation.
  add('awaiting_customer_confirmation', 'completed', 'customer');
  add('awaiting_customer_confirmation', 'exception', 'customer');

  // Cancellation / failure / exception from any non-terminal state.
  for (const status of LAUNDRY_ORDER_STATUSES) {
    if (TERMINAL.includes(status)) continue;
    add(status, 'cancelled', 'customer');
    add(status, 'cancelled', 'provider');
    add(status, 'failed', 'provider');
    add(status, 'exception', 'provider');
  }
  return list;
}

export const LAUNDRY_TRANSITIONS: LaundryTransition[] = buildTransitions();

export function isLaundryTerminal(status: LaundryCollectionStatus): boolean {
  return TERMINAL.includes(status);
}

export function isLaundryTransitionAllowed(
  from: LaundryCollectionStatus,
  to: LaundryCollectionStatus,
  actor: LaundryActor,
): boolean {
  return LAUNDRY_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertLaundryTransition(
  from: LaundryCollectionStatus,
  to: LaundryCollectionStatus,
  actor: LaundryActor,
): void {
  if (isLaundryTerminal(from) && from !== to) {
    throw new ConflictError(`Laundry order is ${from} and cannot be transitioned`);
  }
  if (!isLaundryTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}

// Default operational checklist for a laundry order.
export const LAUNDRY_CHECKLIST_TEMPLATE = [
  { id: 'items_counted', label: 'Items counted at intake' },
  { id: 'condition_recorded', label: 'Condition recorded' },
  { id: 'stains_noted', label: 'Stains / damage noted' },
  { id: 'processing_done', label: 'Processing complete' },
  { id: 'quality_checked', label: 'Quality checked' },
  { id: 'packed', label: 'Packed for return' },
];