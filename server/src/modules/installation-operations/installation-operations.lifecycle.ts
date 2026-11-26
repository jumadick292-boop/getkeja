// Installation & Technical Services lifecycle (Task 13.14) — validated transition
// matrix with stage skipping. A shared installation engine accommodates wifi,
// internet and solar differences (site survey, plan, equipment hold, testing,
// handover) without separate lifecycle engines.
import { ConflictError } from '../../shared/errors.js';
import type { InstallationActor, InstallationOperationStatus } from './installation-operations.types.js';

export const INSTALLATION_STATUSES: InstallationOperationStatus[] = [
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'plan_prepared', 'awaiting_customer_approval',
  'scheduled', 'assigned', 'in_progress', 'awaiting_equipment', 'testing',
  'awaiting_handover', 'completed_pending_confirmation', 'completed',
  'cancelled', 'failed', 'exception',
];

export interface InstallationTransition {
  from: InstallationOperationStatus;
  to: InstallationOperationStatus;
  actor: InstallationActor;
}

const TERMINAL: InstallationOperationStatus[] = ['completed', 'cancelled', 'failed'];

function buildTransitions(): InstallationTransition[] {
  const list: InstallationTransition[] = [];
  const add = (from: InstallationOperationStatus, to: InstallationOperationStatus, actor: InstallationActor) =>
    list.push({ from, to, actor });

  // Confirmed → optional assessment path, or straight to scheduling/assignment.
  add('confirmed', 'assessment_scheduled', 'provider');
  add('confirmed', 'scheduled', 'provider');
  add('confirmed', 'assigned', 'provider');
  add('confirmed', 'in_progress', 'provider');
  add('assessment_scheduled', 'awaiting_assessment', 'provider');
  add('assessment_scheduled', 'assessment_in_progress', 'provider');
  add('awaiting_assessment', 'assessment_in_progress', 'provider');
  add('assessment_in_progress', 'plan_prepared', 'provider');
  add('assessment_in_progress', 'awaiting_customer_approval', 'provider');
  add('assessment_in_progress', 'scheduled', 'provider');
  add('assessment_in_progress', 'assigned', 'provider');
  add('plan_prepared', 'awaiting_customer_approval', 'provider');
  add('plan_prepared', 'scheduled', 'provider');
  add('plan_prepared', 'assigned', 'provider');
  add('awaiting_customer_approval', 'scheduled', 'provider');
  add('awaiting_customer_approval', 'assigned', 'provider');
  add('awaiting_customer_approval', 'in_progress', 'provider');

  // Work execution with forward skipping + equipment hold.
  add('scheduled', 'assigned', 'provider');
  add('scheduled', 'in_progress', 'provider');
  add('assigned', 'in_progress', 'provider');
  add('in_progress', 'awaiting_equipment', 'provider');
  add('awaiting_equipment', 'in_progress', 'provider');
  add('in_progress', 'awaiting_customer_approval', 'provider');
  add('awaiting_equipment', 'awaiting_customer_approval', 'provider');
  add('in_progress', 'testing', 'provider');
  add('awaiting_equipment', 'testing', 'provider');
  add('testing', 'awaiting_handover', 'provider');
  add('testing', 'in_progress', 'provider');
  add('awaiting_handover', 'completed_pending_confirmation', 'provider');
  add('awaiting_handover', 'in_progress', 'provider');

  // Completion requires customer confirmation.
  add('completed_pending_confirmation', 'completed', 'customer');
  add('completed_pending_confirmation', 'exception', 'customer');
  add('completed_pending_confirmation', 'in_progress', 'customer');

  // Cancellation / failure / exception from any non-terminal state.
  for (const status of INSTALLATION_STATUSES) {
    if (TERMINAL.includes(status)) continue;
    add(status, 'cancelled', 'customer');
    add(status, 'cancelled', 'provider');
    add(status, 'failed', 'provider');
    if (status !== 'exception') add(status, 'exception', 'provider');
  }
  return list;
}

export const INSTALLATION_TRANSITIONS: InstallationTransition[] = buildTransitions();

export function isInstallationTerminal(status: InstallationOperationStatus): boolean {
  return TERMINAL.includes(status);
}

export function isInstallationTransitionAllowed(
  from: InstallationOperationStatus,
  to: InstallationOperationStatus,
  actor: InstallationActor,
): boolean {
  return INSTALLATION_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertInstallationTransition(
  from: InstallationOperationStatus,
  to: InstallationOperationStatus,
  actor: InstallationActor,
): void {
  if (isInstallationTerminal(from) && from !== to) {
    throw new ConflictError(`Installation job is ${from} and cannot be transitioned`);
  }
  if (!isInstallationTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}