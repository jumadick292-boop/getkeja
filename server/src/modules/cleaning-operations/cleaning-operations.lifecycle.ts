// Cleaning & Property Care lifecycle (Task 13.13) — validated transition matrix
// with stage skipping. A shared visit engine accommodates cleaning, pest control
// and landscaping differences (optional assessment, supplies hold, additional
// scope approval) without separate lifecycle engines.
import { ConflictError } from '../../shared/errors.js';
import type { CleaningActor, CleaningOperationStatus } from './cleaning-operations.types.js';

export const CLEANING_STATUSES: CleaningOperationStatus[] = [
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'scheduled', 'assigned', 'in_progress',
  'awaiting_supplies', 'awaiting_customer_decision', 'quality_check',
  'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
  'exception',
];

export interface CleaningTransition {
  from: CleaningOperationStatus;
  to: CleaningOperationStatus;
  actor: CleaningActor;
}

const TERMINAL: CleaningOperationStatus[] = ['completed', 'cancelled', 'failed'];

function buildTransitions(): CleaningTransition[] {
  const list: CleaningTransition[] = [];
  const add = (from: CleaningOperationStatus, to: CleaningOperationStatus, actor: CleaningActor) =>
    list.push({ from, to, actor });

  // Confirmed → optional assessment path, or straight to scheduling/assignment.
  add('confirmed', 'assessment_scheduled', 'provider');
  add('confirmed', 'scheduled', 'provider');
  add('confirmed', 'assigned', 'provider');
  add('confirmed', 'in_progress', 'provider');
  add('assessment_scheduled', 'awaiting_assessment', 'provider');
  add('assessment_scheduled', 'assessment_in_progress', 'provider');
  add('awaiting_assessment', 'assessment_in_progress', 'provider');
  add('assessment_in_progress', 'awaiting_customer_decision', 'provider');
  add('assessment_in_progress', 'scheduled', 'provider');
  add('assessment_in_progress', 'assigned', 'provider');
  add('awaiting_customer_decision', 'scheduled', 'provider');
  add('awaiting_customer_decision', 'assigned', 'provider');
  add('awaiting_customer_decision', 'in_progress', 'provider');

  // Work execution with forward skipping + supplies hold.
  add('scheduled', 'assigned', 'provider');
  add('scheduled', 'in_progress', 'provider');
  add('assigned', 'in_progress', 'provider');
  add('in_progress', 'awaiting_supplies', 'provider');
  add('awaiting_supplies', 'in_progress', 'provider');
  add('in_progress', 'awaiting_customer_decision', 'provider');
  add('awaiting_supplies', 'awaiting_customer_decision', 'provider');
  add('in_progress', 'quality_check', 'provider');
  add('awaiting_supplies', 'quality_check', 'provider');
  add('quality_check', 'completed_pending_confirmation', 'provider');
  add('quality_check', 'in_progress', 'provider');

  // Completion requires customer confirmation.
  add('completed_pending_confirmation', 'completed', 'customer');
  add('completed_pending_confirmation', 'exception', 'customer');
  add('completed_pending_confirmation', 'in_progress', 'customer');

  // Cancellation / failure / exception from any non-terminal state.
  for (const status of CLEANING_STATUSES) {
    if (TERMINAL.includes(status)) continue;
    add(status, 'cancelled', 'customer');
    add(status, 'cancelled', 'provider');
    add(status, 'failed', 'provider');
    if (status !== 'exception') add(status, 'exception', 'provider');
  }
  return list;
}

export const CLEANING_TRANSITIONS: CleaningTransition[] = buildTransitions();

export function isCleaningTerminal(status: CleaningOperationStatus): boolean {
  return TERMINAL.includes(status);
}

export function isCleaningTransitionAllowed(
  from: CleaningOperationStatus,
  to: CleaningOperationStatus,
  actor: CleaningActor,
): boolean {
  return CLEANING_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertCleaningTransition(
  from: CleaningOperationStatus,
  to: CleaningOperationStatus,
  actor: CleaningActor,
): void {
  if (isCleaningTerminal(from) && from !== to) {
    throw new ConflictError(`Cleaning job is ${from} and cannot be transitioned`);
  }
  if (!isCleaningTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}