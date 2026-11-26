// Moving job lifecycle (Task 13.6) — single validated transition matrix.
// Each transition records actor + conditions; history is persisted by trigger
// and explicit inserts. Completed/failed/cancelled are terminal (no reopen).

import { ConflictError } from '../../shared/errors.js';
import type { MovingActor, MovingJobStatus } from './moving.types.js';

export const MOVING_JOB_STATUSES: MovingJobStatus[] = [
  'confirmed',
  'awaiting_customer_details',
  'preparation',
  'ready_for_move',
  'in_progress',
  'arrived_at_destination',
  'unloading',
  'awaiting_customer_confirmation',
  'completed',
  'cancelled',
  'failed',
];

export interface TransitionRule {
  from: MovingJobStatus;
  to: MovingJobStatus;
  actor: MovingActor;
  // Customer approval required before this transition is valid (informational).
  requiresCustomerApproval?: boolean;
  reversible?: boolean;
}

export const TRANSITIONS: TransitionRule[] = [
  // Provider prepares the job.
  { from: 'confirmed', to: 'awaiting_customer_details', actor: 'provider', reversible: true },
  { from: 'confirmed', to: 'preparation', actor: 'provider', reversible: true },
  { from: 'awaiting_customer_details', to: 'preparation', actor: 'provider', reversible: true },
  { from: 'preparation', to: 'ready_for_move', actor: 'provider', reversible: true },
  // Move day.
  { from: 'ready_for_move', to: 'in_progress', actor: 'provider' },
  { from: 'in_progress', to: 'arrived_at_destination', actor: 'provider' },
  { from: 'arrived_at_destination', to: 'unloading', actor: 'provider' },
  { from: 'unloading', to: 'awaiting_customer_confirmation', actor: 'provider' },
  // Customer confirmation (completion is customer-driven, never provider).
  { from: 'awaiting_customer_confirmation', to: 'completed', actor: 'customer', requiresCustomerApproval: true },
  // Cancellation (customer or provider) from any non-terminal state.
  ...MOVING_JOB_STATUSES.filter(
    (s) => !['completed', 'cancelled', 'failed'].includes(s),
  ).flatMap((s) => [
    { from: s, to: 'cancelled' as MovingJobStatus, actor: 'customer' as MovingActor },
    { from: s, to: 'cancelled' as MovingJobStatus, actor: 'provider' as MovingActor },
  ]),
  // Failure (provider) from active in-field states.
  ...(['confirmed', 'awaiting_customer_details', 'preparation', 'ready_for_move', 'in_progress', 'arrived_at_destination', 'unloading'] as MovingJobStatus[]).map(
    (s) => ({ from: s, to: 'failed' as MovingJobStatus, actor: 'provider' as MovingActor }),
  ),
];

export function isTerminal(status: MovingJobStatus): boolean {
  return status === 'completed' || status === 'cancelled' || status === 'failed';
}

export function isTransitionAllowed(
  from: MovingJobStatus,
  to: MovingJobStatus,
  actor: MovingActor,
): boolean {
  return TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertTransition(
  from: MovingJobStatus,
  to: MovingJobStatus,
  actor: MovingActor,
): void {
  if (isTerminal(from) && from !== to) {
    throw new ConflictError(`Job is ${from} and cannot be transitioned`);
  }
  if (!isTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}

// ---------------------------------------------------------------------------
// Configurable operational checklists per service scope.
// ---------------------------------------------------------------------------
export interface ChecklistTemplate {
  id: string;
  label: string;
}

const HOUSEHOLD: ChecklistTemplate[] = [
  { id: 'packing_materials', label: 'Packing materials arranged' },
  { id: 'fragile_items', label: 'Fragile items identified' },
  { id: 'furniture_inventory', label: 'Furniture inventory confirmed' },
  { id: 'parking', label: 'Access and parking arrangements confirmed' },
  { id: 'origin_access', label: 'Origin access confirmed' },
  { id: 'destination_access', label: 'Destination access confirmed' },
  { id: 'move_date', label: 'Moving date confirmed' },
];

const OFFICE: ChecklistTemplate[] = [
  { id: 'office_inventory', label: 'Office inventory confirmed' },
  { id: 'equipment_handling', label: 'Equipment handling requirements recorded' },
  { id: 'sensitive_equipment', label: 'Sensitive equipment identified' },
  { id: 'access', label: 'Access arrangements confirmed' },
  { id: 'relocation_window', label: 'Agreed relocation window confirmed' },
];

const PACKING: ChecklistTemplate[] = [
  { id: 'packing_items', label: 'Packing required items confirmed' },
  { id: 'fragile_items', label: 'Fragile items recorded' },
  { id: 'packing_materials', label: 'Packing materials agreed' },
  { id: 'unpacking', label: 'Unpacking requirements recorded' },
];

const DEFAULT_CHECKLIST: ChecklistTemplate[] = [
  { id: 'origin_access', label: 'Origin access confirmed' },
  { id: 'destination_access', label: 'Destination access confirmed' },
  { id: 'move_date', label: 'Moving date confirmed' },
];

// Pick a checklist template from the confirmed scope's service categories.
export function checklistTemplateForScope(serviceCategories: string[]): ChecklistTemplate[] {
  const set = new Set(serviceCategories);
  if (set.has('moving_office') || set.has('moving_commercial')) return OFFICE;
  if (set.has('moving_packing')) return PACKING;
  if (
    set.has('moving_household') ||
    set.has('moving_apartment') ||
    set.size === 0
  ) {
    return HOUSEHOLD;
  }
  return DEFAULT_CHECKLIST;
}