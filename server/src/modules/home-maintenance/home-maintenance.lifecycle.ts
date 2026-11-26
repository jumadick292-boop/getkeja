// Home Maintenance & Repairs lifecycle (Task 13.12) — validated transition
// matrix with stage skipping. Providers may skip optional stages (e.g. a simple
// repair with no inspection) while invalid transitions are rejected.
import { ConflictError } from '../../shared/errors.js';
import type { HomeMaintenanceActor, HomeMaintenanceStatus } from './home-maintenance.types.js';

export const HOME_MAINTENANCE_STATUSES: HomeMaintenanceStatus[] = [
  'confirmed', 'inspection_scheduled', 'awaiting_inspection',
  'inspection_in_progress', 'awaiting_customer_approval', 'work_scheduled',
  'assigned', 'in_progress', 'awaiting_parts', 'awaiting_customer_decision',
  'quality_check', 'completed_pending_confirmation', 'completed',
  'cancelled', 'failed', 'exception',
];

export interface HomeMaintenanceTransition {
  from: HomeMaintenanceStatus;
  to: HomeMaintenanceStatus;
  actor: HomeMaintenanceActor;
}

const TERMINAL: HomeMaintenanceStatus[] = ['completed', 'cancelled', 'failed'];

function buildTransitions(): HomeMaintenanceTransition[] {
  const list: HomeMaintenanceTransition[] = [];
  const add = (from: HomeMaintenanceStatus, to: HomeMaintenanceStatus, actor: HomeMaintenanceActor) =>
    list.push({ from, to, actor });

  // Confirmed → inspection path (optional) or straight to scheduling/assignment.
  add('confirmed', 'inspection_scheduled', 'provider');
  add('confirmed', 'work_scheduled', 'provider');
  add('confirmed', 'assigned', 'provider');
  add('confirmed', 'in_progress', 'provider');
  add('inspection_scheduled', 'awaiting_inspection', 'provider');
  add('inspection_scheduled', 'inspection_in_progress', 'provider');
  add('awaiting_inspection', 'inspection_in_progress', 'provider');
  add('inspection_in_progress', 'awaiting_customer_approval', 'provider');
  add('inspection_in_progress', 'work_scheduled', 'provider');
  add('inspection_in_progress', 'assigned', 'provider');
  add('awaiting_customer_approval', 'work_scheduled', 'provider');
  add('awaiting_customer_approval', 'assigned', 'provider');
  add('awaiting_customer_approval', 'in_progress', 'provider');

  // Work execution with forward skipping + parts hold.
  add('work_scheduled', 'assigned', 'provider');
  add('work_scheduled', 'in_progress', 'provider');
  add('assigned', 'in_progress', 'provider');
  add('in_progress', 'awaiting_parts', 'provider');
  add('awaiting_parts', 'in_progress', 'provider');
  add('in_progress', 'awaiting_customer_decision', 'provider');
  add('awaiting_customer_decision', 'in_progress', 'provider');
  add('awaiting_customer_decision', 'awaiting_parts', 'provider');
  add('in_progress', 'quality_check', 'provider');
  add('awaiting_parts', 'quality_check', 'provider');
  add('quality_check', 'completed_pending_confirmation', 'provider');
  add('quality_check', 'in_progress', 'provider');

  // Completion requires customer confirmation.
  add('completed_pending_confirmation', 'completed', 'customer');
  add('completed_pending_confirmation', 'exception', 'customer');
  add('completed_pending_confirmation', 'in_progress', 'customer');

  // Cancellation / failure / exception from any non-terminal state.
  for (const status of HOME_MAINTENANCE_STATUSES) {
    if (TERMINAL.includes(status)) continue;
    add(status, 'cancelled', 'customer');
    add(status, 'cancelled', 'provider');
    add(status, 'failed', 'provider');
    if (status !== 'exception') add(status, 'exception', 'provider');
  }
  return list;
}

export const HOME_MAINTENANCE_TRANSITIONS: HomeMaintenanceTransition[] = buildTransitions();

export function isHomeMaintenanceTerminal(status: HomeMaintenanceStatus): boolean {
  return TERMINAL.includes(status);
}

export function isHomeMaintenanceTransitionAllowed(
  from: HomeMaintenanceStatus,
  to: HomeMaintenanceStatus,
  actor: HomeMaintenanceActor,
): boolean {
  return HOME_MAINTENANCE_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertHomeMaintenanceTransition(
  from: HomeMaintenanceStatus,
  to: HomeMaintenanceStatus,
  actor: HomeMaintenanceActor,
): void {
  if (isHomeMaintenanceTerminal(from) && from !== to) {
    throw new ConflictError(`Maintenance job is ${from} and cannot be transitioned`);
  }
  if (!isHomeMaintenanceTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}